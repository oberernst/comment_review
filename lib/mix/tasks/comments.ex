defmodule Mix.Tasks.Comments do
  use Mix.Task

  alias Mix.Tasks.Comments.Check
  alias Mix.Tasks.Comments.Offense
  alias Mix.Tasks.Comments.Unit

  @shortdoc "Reviews comments and documentation against the source conventions"

  @default_paths ~w(lib test config mix.exs)
  @comment_words 35
  @doc_words 40
  @fence ~s(""")

  @moduledoc """
  Reviews every comment and documentation string under the given roots.

      mix comments
      mix comments lib/my_app

  Roots default to `lib`, `test`, `config` and `mix.exs`. Each offense reports
  a file, a line and the text that matched, and the task exits non-zero when it
  finds any.

  A unit is one run of `#` lines, or one paragraph of a `@moduledoc`, `@doc` or
  `@typedoc` string. Indented samples, fenced blocks and `iex>` lines carry
  code, and the review skips them.

  ## Checks

    * `register` — counterfactual, negated definition, prohibition, analogy,
      comparison to a sibling module, reference to a prior implementation
    * `causal_chain` — a second causal connective in one unit
    * `semicolon` — clauses joined by a semicolon
    * `aside` — a pair of em dashes inside one sentence
    * `justification` — the vocabulary of design defence
    * `length` — a comment past #{@comment_words} words, a paragraph past #{@doc_words}
    * `divider` — a section divider
    * `addressee` — the second person
    * `marker` — a work marker left in the source
    * `commented_code` — code behind a comment marker
    * `doc_channel` — documentation in a comment above a public definition
    * `duration_unit` — a duration attribute whose name omits its unit

  `aside`, `divider`, `causal_chain`, `justification` and `length` are
  derived: each holds at a rate near zero across 13 reference corpora,
  339k words. `docs/comment-corpora.md` records the measurement.

  `semicolon` is the weakest of those: two reference corpora and three
  controls run above 2%.

  `register`, `addressee` and `marker` are house policy. The reference set
  breaks all three — Elixir core carries the register lexicon in 8.34% of
  its units.
  """

  @register [
    {~r/\bwould\b/i, "counterfactual"},
    {~r/\brather than\b/i, "negated definition"},
    {~r/,\s+not\b/i, "negated definition"},
    {~r/\binstead of\b/i, "negated definition"},
    {~r/\bnot an?\b/i, "negated definition"},
    {~r/\bcannot\b/i, "negated definition"},
    {~r/\bnever\b/i, "negated definition"},
    {~r/\bunlike\b/i, "comparison to a sibling"},
    {~r/\b(no longer|used to)\b/i, "prior implementation"},
    {~r/\b(don't|do not|must not|resist)\b/i, "prohibition"},
    {~r/\b(like an?|as if|think of)\b/i, "analogy"}
  ]

  @causal ~r/(,\s+so\b|\bbecause\b|\bwhich is why\b|\bso that\b|\btherefore\b|\bhence\b)/i
  @justification ~r/\b(deliberately|by design|on purpose|the whole point|the point of|the reason|genuinely|actually|for simplicity|the trick)\b/i
  # A hyphenated compound naming a property (`read-your-writes`) addresses
  # nobody.
  @addressee ~r/(?<![-\w])(you|your|yours)(?![-\w])/i
  @marker ~r/\b(TODO|FIXME|XXX|HACK)\b/
  @divider ~r/(-{3,}|={3,}|\*{3,}|_{3,})/
  @sentence ~r/(?<=[.!?])\s+(?=[A-Z`*"'(])/
  @code_token ~r/(\|>|->|\bdefp?\b|=)/
  @definition ~r/^(@doc\b|@spec\b|def\s|defdelegate\s)/
  @directive ~r/^(credo:|sobelow_skip|coveralls-ignore|dialyzer)/
  @attribute ~r/^@([a-z_]+)\s+(?:\d|:timer\.)/
  @doc_attribute ~r/^@(module|type)?doc\s/
  @durations ~w(interval timeout period cooldown backoff retention delay ttl)
  @units ~w(ns us ms s min h d nanoseconds microseconds milliseconds seconds minutes hours days weeks months)

  @checks [
    %Check{id: :register, title: "states the present positively"},
    %Check{id: :causal_chain, title: "one causal connective per unit"},
    %Check{id: :semicolon, title: "clauses stand as sentences"},
    %Check{id: :aside, title: "one em dash per sentence"},
    %Check{id: :justification, title: "states the mechanism, leaving the defence"},
    %Check{id: :length, title: "a unit stays inside its word budget"},
    %Check{id: :divider, title: "structure comes from the code"},
    %Check{id: :addressee, title: "a comment addresses nobody"},
    %Check{id: :marker, title: "work lives in the tracker"},
    %Check{id: :commented_code, title: "the comment marker carries prose"},
    %Check{id: :doc_channel, title: "documentation belongs in @doc"},
    %Check{id: :duration_unit, title: "a duration attribute names its unit"}
  ]

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    roots = roots(argv)
    exclude = excluded()
    offenses = review_paths(roots, exclude)

    report(offenses, roots)
  end

  defp excluded do
    config = Mix.Project.config()
    options = Keyword.get(config, :comments, [])

    Keyword.get(options, :exclude, [])
  end

  defp roots([]), do: @default_paths
  defp roots(argv), do: argv

  @doc "The conventions this task reports on."
  @spec checks() :: [Check.t()]
  def checks, do: @checks

  @doc """
  Every offense in the sources under `roots`.

  A root names a file or a directory, and a directory is walked for `.ex` and
  `.exs` sources. A file listed in `exclude` is skipped. The task reads that
  list from `comments: [exclude: [...]]` in the project config.
  """
  @spec review_paths([String.t()], [String.t()]) :: [Offense.t()]
  def review_paths(roots, exclude \\ []) do
    skipped = MapSet.new(exclude, &Path.expand/1)

    roots
    |> Enum.flat_map(&sources/1)
    |> Enum.uniq()
    |> Enum.reject(&MapSet.member?(skipped, Path.expand(&1)))
    |> Enum.flat_map(&review_file/1)
  end

  @doc "Every offense in one file's `source`, ordered by line."
  @spec review(String.t(), String.t()) :: [Offense.t()]
  def review(file, source) do
    scanned = scan(source)
    code = code_lines(scanned)
    units = units(scanned)
    prose = Enum.flat_map(units, &prose_offenses(file, &1, code))
    durations = duration_offenses(file, code)

    prose
    |> Enum.concat(durations)
    |> Enum.sort_by(& &1.line)
  end

  defp sources(root) do
    cond do
      String.ends_with?(root, ".ex") -> [root]
      String.ends_with?(root, ".exs") -> [root]
      true -> walk(root)
    end
  end

  defp walk(root) do
    ~w(**/*.ex **/*.exs)
    |> Enum.flat_map(fn pattern -> expand(root, pattern) end)
    |> Enum.sort()
  end

  defp expand(root, pattern) do
    root
    |> Path.join(pattern)
    |> Path.wildcard()
  end

  defp review_file(path) do
    source = File.read!(path)

    review(path, source)
  end

  # Classifies every line as prose, code or skipped, tracking the heredoc and
  # fenced-block state a `#` or a paragraph is read against.
  defp scan(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce(%{state: :code, margin: nil, last: :none, lines: []}, &classify/2)
    |> Map.fetch!(:lines)
    |> Enum.reverse()
  end

  defp classify({raw, number}, %{state: :code} = acc) do
    trimmed = String.trim(raw)

    cond do
      doc_open?(trimmed) -> %{acc | state: :doc, margin: nil, last: :none}
      doc_single?(trimmed) -> push(acc, number, :doc, doc_text(trimmed), :prose)
      comment?(trimmed) -> push(acc, number, :comment, comment_text(trimmed), :prose)
      heredoc_open?(trimmed) -> %{acc | state: :string}
      true -> push(acc, number, :code, trimmed, :none)
    end
  end

  defp classify({raw, number}, %{state: :string} = acc) do
    trimmed = String.trim(raw)

    if String.starts_with?(trimmed, @fence) do
      %{acc | state: :code}
    else
      push(acc, number, :code, "", :none)
    end
  end

  defp classify({raw, number}, %{state: :fenced} = acc) do
    trimmed = String.trim(raw)

    if String.starts_with?(trimmed, "```") do
      %{acc | state: :doc}
    else
      push(acc, number, :break, "", :none)
    end
  end

  defp classify({raw, number}, %{state: :doc} = acc) do
    trimmed = String.trim(raw)

    cond do
      trimmed == @fence -> %{acc | state: :code, margin: nil}
      String.starts_with?(trimmed, "```") -> %{acc | state: :fenced}
      separator?(trimmed) -> push(acc, number, :break, "", :none)
      bullet?(trimmed) -> bullet(acc, raw, number, trimmed)
      sample?(raw, acc) -> push(acc, number, :break, "", :none)
      true -> prose(acc, raw, number, trimmed)
    end
  end

  defp bullet(acc, raw, number, trimmed) do
    text = String.trim_leading(trimmed, "* ")

    acc
    |> margin(raw)
    |> push(number, :break, "", :none)
    |> push(number, :doc, text, :bullet)
  end

  defp prose(acc, raw, number, trimmed) do
    acc
    |> margin(raw)
    |> push(number, :doc, trimmed, :prose)
  end

  defp margin(%{margin: nil} = acc, raw) do
    %{acc | margin: indent(raw)}
  end

  defp margin(acc, _raw), do: acc

  defp push(acc, number, kind, text, last) do
    %{acc | lines: [{number, kind, text} | acc.lines], last: last}
  end

  defp indent(raw) do
    trimmed = String.trim_leading(raw)

    String.length(raw) - String.length(trimmed)
  end

  defp sample?(_raw, %{margin: nil}), do: false
  defp sample?(_raw, %{last: :bullet}), do: false

  defp sample?(raw, %{margin: margin}) do
    indent(raw) >= margin + 4
  end

  defp bullet?(trimmed), do: String.starts_with?(trimmed, "* ")

  # A blank line, a heading and an `iex>` prompt each end a paragraph.
  defp separator?(""), do: true

  defp separator?(trimmed) do
    Enum.any?(~w(iex> ...> #), &String.starts_with?(trimmed, &1))
  end

  defp comment?(trimmed) do
    String.starts_with?(trimmed, "#") and not String.starts_with?(trimmed, "#!")
  end

  defp comment_text(trimmed) do
    trimmed
    |> String.trim_leading("#")
    |> String.trim()
  end

  defp doc_open?(trimmed) do
    trimmed =~ @doc_attribute and String.ends_with?(trimmed, @fence)
  end

  defp doc_single?(trimmed) do
    trimmed =~ @doc_attribute and String.contains?(trimmed, ~s("))
  end

  defp doc_text(trimmed) do
    trimmed
    |> String.replace(@doc_attribute, "")
    |> String.trim()
    |> String.trim("~S")
    |> String.trim(~s("))
  end

  defp heredoc_open?(trimmed), do: String.ends_with?(trimmed, @fence)

  defp units(scanned) do
    scanned
    |> Enum.chunk_by(fn {_number, kind, _text} -> kind in [:comment, :doc] end)
    |> Enum.filter(&prose_run?/1)
    |> Enum.map(&unit/1)
  end

  defp prose_run?([{_number, kind, _text} | _rest]), do: kind in [:comment, :doc]

  defp unit(run) do
    {first, kind, _text} = hd(run)
    {last, _kind, _text} = List.last(run)
    text = Enum.map_join(run, " ", fn {_number, _kind, text} -> text end)

    %Unit{kind: kind, line: first, last: last, text: text}
  end

  defp code_lines(scanned) do
    scanned
    |> Enum.filter(fn {_number, kind, _text} -> kind == :code end)
    |> Map.new(fn {number, _kind, text} -> {number, text} end)
  end

  defp prose_offenses(file, unit, code) do
    [
      register(file, unit),
      causal_chain(file, unit),
      semicolon(file, unit),
      aside(file, unit),
      justification(file, unit),
      length_budget(file, unit),
      divider(file, unit),
      addressee(file, unit),
      marker(file, unit),
      commented_code(file, unit),
      doc_channel(file, unit, code)
    ]
    |> Enum.concat()
  end

  defp register(file, unit) do
    @register
    |> Enum.find(fn {pattern, _kind} -> unit.text =~ pattern end)
    |> registered(file, unit)
  end

  defp registered(nil, _file, _unit), do: []

  defp registered({_pattern, kind}, file, unit) do
    [offense(file, unit, :register, kind)]
  end

  defp causal_chain(file, unit) do
    found = Regex.scan(@causal, unit.text)

    count = length(found)

    (count >= 2)
    |> when_true(file, unit, :causal_chain, "#{count} causal connectives")
  end

  defp semicolon(file, unit) do
    unit.text
    |> String.contains?(";")
    |> when_true(file, unit, :semicolon, "clauses joined by a semicolon")
  end

  defp aside(file, unit) do
    @sentence
    |> Regex.split(unit.text)
    |> Enum.any?(&dashed?/1)
    |> when_true(file, unit, :aside, "a pair of em dashes inside one sentence")
  end

  defp dashed?(sentence) do
    parts = String.split(sentence, "—")

    length(parts) >= 3
  end

  defp justification(file, unit) do
    matched = Regex.run(@justification, unit.text)

    justified(matched, file, unit)
  end

  defp justified(nil, _file, _unit), do: []

  defp justified([found | _rest], file, unit) do
    [offense(file, unit, :justification, "design defence: #{found}")]
  end

  defp length_budget(file, unit) do
    budget = budget(unit.kind)
    words = String.split(unit.text)
    count = length(words)

    (count > budget)
    |> when_true(file, unit, :length, "#{count} words against a budget of #{budget}")
  end

  defp budget(:comment), do: @comment_words
  defp budget(:doc), do: @doc_words

  defp divider(file, %Unit{kind: :comment} = unit) do
    (unit.text =~ @divider)
    |> when_true(file, unit, :divider, "a section divider")
  end

  defp divider(_file, _unit), do: []

  defp addressee(file, unit) do
    (unit.text =~ @addressee)
    |> when_true(file, unit, :addressee, "the second person")
  end

  defp marker(file, unit) do
    (unit.text =~ @marker)
    |> when_true(file, unit, :marker, "a work marker")
  end

  defp commented_code(file, %Unit{kind: :comment} = unit) do
    code?(unit.text)
    |> when_true(file, unit, :commented_code, "code behind a comment marker")
  end

  defp commented_code(_file, _unit), do: []

  # Code that parses and carries a token prose has no use for. A function name
  # inside a sentence parses too, and lacks the token.
  defp code?(text) do
    text =~ @code_token and parses?(text)
  end

  defp parses?(text) do
    case Code.string_to_quoted(text) do
      {:ok, _quoted} -> true
      {:error, _reason} -> false
    end
  end

  defp doc_channel(file, %Unit{kind: :comment} = unit, code) do
    next = unit.last + 1
    following = Map.get(code, next, "")

    (following =~ @definition and not (unit.text =~ @directive))
    |> when_true(file, unit, :doc_channel, "documentation above a public definition")
  end

  defp doc_channel(_file, _unit, _code), do: []

  defp duration_offenses(file, code) do
    code
    |> Enum.filter(&unitless?/1)
    |> Enum.map(fn {number, text} -> attribute_offense(file, number, text) end)
  end

  defp unitless?({_number, text}) do
    case Regex.run(@attribute, text, capture: :all_but_first) do
      [name] -> duration?(name) and not united?(name)
      nil -> false
    end
  end

  defp duration?(name) do
    segments = String.split(name, "_")

    Enum.any?(@durations, &(&1 in segments))
  end

  defp united?(name), do: Enum.any?(@units, &String.ends_with?(name, "_" <> &1))

  defp attribute_offense(file, number, text) do
    %Offense{
      file: file,
      line: number,
      check: :duration_unit,
      message: "a duration attribute whose name omits its unit",
      excerpt: text
    }
  end

  defp when_true(false, _file, _unit, _check, _message), do: []

  defp when_true(true, file, unit, check, message) do
    [offense(file, unit, check, message)]
  end

  defp offense(file, unit, check, message) do
    %Offense{file: file, line: unit.line, check: check, message: message, excerpt: excerpt(unit)}
  end

  defp excerpt(unit) do
    unit.text
    |> String.slice(0, 88)
    |> String.trim()
  end

  defp report([], roots) do
    joined = Enum.join(roots, ", ")

    Mix.shell().info([:green, "comments: clean — ", :reset, joined])
  end

  defp report(offenses, _roots) do
    grouped = Enum.group_by(offenses, & &1.check)
    width = column(offenses)

    Mix.shell().info("")

    @checks
    |> Enum.each(fn check -> section(check, grouped, width) end)

    total = length(offenses)
    files = Enum.uniq_by(offenses, & &1.file)

    Mix.raise("#{total} offenses in #{length(files)} files")
  end

  defp section(check, grouped, width) do
    case Map.get(grouped, check.id) do
      nil -> :ok
      found -> print_section(check, found, width)
    end
  end

  defp print_section(check, found, width) do
    Mix.shell().info([
      :yellow,
      "#{check.id} (#{length(found)})  ",
      :reset,
      :faint,
      check.title,
      :reset
    ])

    Enum.each(found, fn offense -> print_offense(offense, width) end)
    Mix.shell().info("")
  end

  defp print_offense(offense, width) do
    site = "#{offense.file}:#{offense.line}"
    padded = String.pad_trailing(site, width)

    Mix.shell().info(["  ", padded, "  ", :faint, offense.excerpt, :reset])
  end

  defp column(offenses) do
    offenses
    |> Enum.map(&site_width/1)
    |> Enum.max()
  end

  defp site_width(offense) do
    site = "#{offense.file}:#{offense.line}"

    String.length(site)
  end
end
