defmodule Mix.Tasks.CommentsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Comments
  alias Mix.Tasks.Comments.Check
  alias Mix.Tasks.Comments.Offense

  defp flagged(source) do
    "lib/example.ex"
    |> Comments.review(source)
    |> Enum.map(& &1.check)
  end

  defp wrap(prose) do
    """
    defmodule Example do
      @moduledoc \"\"\"
      #{prose}
      \"\"\"
    end
    """
  end

  describe "review/2" do
    test "passes source whose documentation states what holds" do
      source = """
      defmodule Example do
        @moduledoc \"\"\"
        Counts relayed frames against a period.

        The counter is cumulative. A flush writes the total and leaves the
        counter in place.
        \"\"\"

        @flush_interval_ms 60_000

        @doc "The total counted for `device_id`."
        def total(device_id), do: device_id
      end
      """

      assert Comments.review("lib/example.ex", source) == []
    end

    test "reports the file, line, check and excerpt of an offense" do
      source = wrap("A queue, not a cache.")

      assert [offense] = Comments.review("lib/example.ex", source)
      assert offense.file == "lib/example.ex"
      assert offense.line == 3
      assert offense.check == :register
      assert offense.excerpt =~ "A queue"
      assert is_binary(offense.message)
    end
  end

  describe "register" do
    test "flags a counterfactual" do
      assert :register in flagged(wrap("Reading it twice would double the count."))
    end

    test "flags a negated definition" do
      assert :register in flagged(wrap("The table holds totals rather than deltas."))
    end

    test "flags a prohibition" do
      assert :register in flagged(wrap("Do not drain the counters on flush."))
    end

    test "flags a comparison to a sibling module" do
      assert :register in flagged(wrap("Unlike the replay store, this one is required."))
    end

    test "flags a reference to a prior implementation" do
      assert :register in flagged(wrap("The pool no longer serves one consumer each."))
    end
  end

  describe "causal_chain" do
    test "flags a second causal connective in one unit" do
      prose = "Counters are cumulative, so a flush is free, because it rewrites."

      assert :causal_chain in flagged(wrap(prose))
    end

    test "passes a single causal connective" do
      prose = "Counters are cumulative, so a repeated flush is free."

      refute :causal_chain in flagged(wrap(prose))
    end
  end

  describe "semicolon" do
    test "flags clauses joined by a semicolon" do
      assert :semicolon in flagged(wrap("Writes go through the server; reads go to ETS."))
    end
  end

  describe "aside" do
    test "flags a sentence carrying a pair of em dashes" do
      prose = "A crash-looping database — a driver bug, a bad URL — restarts here."

      assert :aside in flagged(wrap(prose))
    end

    test "passes a single em dash" do
      prose = "The counter spans two periods — the open one and the period before it."

      refute :aside in flagged(wrap(prose))
    end
  end

  describe "justification" do
    test "flags the vocabulary of design defence" do
      assert :justification in flagged(wrap("The check is deliberately unfenced."))
      assert :justification in flagged(wrap("Open by design: the set grows."))
      assert :justification in flagged(wrap("The reason is that exit reasons vary."))
    end
  end

  describe "length" do
    test "flags a doc paragraph over its word budget" do
      prose = Enum.map_join(1..60, " ", fn n -> "word#{n}" end)

      assert :length in flagged(wrap(prose))
    end

    test "holds a doc paragraph to the reference set's p90" do
      prose = Enum.map_join(1..45, " ", fn n -> "word#{n}" end)

      assert :length in flagged(wrap(prose))

      shorter = Enum.map_join(1..38, " ", fn n -> "word#{n}" end)

      refute :length in flagged(wrap(shorter))
    end

    test "flags a comment block over its word budget" do
      body = Enum.map_join(1..40, " ", fn n -> "word#{n}" end)

      source = """
      defmodule Example do
        # #{body}
        defp read, do: :ok
      end
      """

      assert :length in flagged(source)
    end
  end

  describe "divider" do
    test "flags a section divider" do
      source = """
      defmodule Example do
        # --- parsing --------------------------------------------------------
        defp read, do: :ok
      end
      """

      assert :divider in flagged(source)
    end
  end

  describe "addressee" do
    test "flags the second person" do
      assert :addressee in flagged(wrap("You can pass an id here."))
    end
  end

  describe "marker" do
    test "flags a work marker" do
      source = """
      defmodule Example do
        # TODO: drain the counters.
        defp read, do: :ok
      end
      """

      assert :marker in flagged(source)
    end
  end

  describe "commented_code" do
    test "flags commented-out code" do
      source = """
      defmodule Example do
        # counters |> Enum.map(&flush/1)
        defp read, do: :ok
      end
      """

      assert :commented_code in flagged(source)
    end

    test "passes prose naming a function" do
      source = """
      defmodule Example do
        # Placement decides the owner before Devices.ensure_started(id) runs.
        defp read, do: :ok
      end
      """

      refute :commented_code in flagged(source)
    end
  end

  describe "doc_channel" do
    test "flags documentation in a comment above a public definition" do
      source = """
      defmodule Example do
        # The total counted for a device.
        def total(id), do: id
      end
      """

      assert :doc_channel in flagged(source)
    end

    test "passes a tool directive above a public definition" do
      source = """
      defmodule Example do
        # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
        def total(id), do: id

        # sobelow_skip ["SQL.Query"]
        # Every clause binds its values with `^`.
        def query(id), do: id
      end
      """

      refute :doc_channel in flagged(source)
    end
  end

  describe "duration_unit" do
    test "flags a duration attribute without its unit" do
      source = """
      defmodule Example do
        @flush_interval 60_000
      end
      """

      assert :duration_unit in flagged(source)
    end

    test "passes a duration attribute naming its unit" do
      source = """
      defmodule Example do
        @flush_interval_ms 60_000
      end
      """

      refute :duration_unit in flagged(source)
    end

    test "reads whole name segments" do
      source = """
      defmodule Example do
        @settle_days 14
        @overdue_intervals 3
      end
      """

      refute :duration_unit in flagged(source)
    end
  end

  describe "heredoc strings" do
    test "closes a heredoc whose delimiter carries trailing code" do
      source = """
      defmodule Example do
        def body(email) do
          email
          |> text_body(\"\"\"
          Visit the portal.
          \"\"\")
        end

        def sms(name) do
          \"\"\"
          \#{name} is safe and no longer in need of assistance.
          \"\"\"
        end
      end
      """

      assert flagged(source) == []
    end
  end

  describe "code samples" do
    test "skips indented samples and fenced blocks inside documentation" do
      source = """
      defmodule Example do
        @moduledoc \"\"\"
        Encodes one frame.

            <<version::8, seq::32, rest::binary>>

        ```elixir
        iex> Example.encode(frame)
        ```
        \"\"\"
      end
      """

      assert Comments.review("lib/example.ex", source) == []
    end

    test "skips the contents of a plain heredoc" do
      source = ~S'''
      defmodule Example do
        defp template do
          """
          # TODO: this is data, not a comment.
          """
        end
      end
      '''

      assert Comments.review("lib/example.ex", source) == []
    end
  end

  describe "checks/0" do
    test "names every check the reviewer can report" do
      ids = Enum.map(Comments.checks(), & &1.id)

      assert Enum.sort(ids) ==
               Enum.sort([
                 :addressee,
                 :aside,
                 :causal_chain,
                 :commented_code,
                 :divider,
                 :doc_channel,
                 :duration_unit,
                 :justification,
                 :length,
                 :marker,
                 :register,
                 :semicolon
               ])

      assert Enum.all?(Comments.checks(), &is_binary(&1.title))
    end
  end

  describe "review_paths/1" do
    test "reads every source under the given roots" do
      offenses = Comments.review_paths(["lib", "test", "config", "mix.exs"])

      assert offenses == []
    end

    @tag :tmp_dir
    test "skips excluded files", %{tmp_dir: dir} do
      fixture = Path.join(dir, "fixture.exs")
      File.write!(fixture, "# DO NOT ALTER THE CONTENTS OF THIS FILE!!!\n")

      assert [%Offense{check: :register}] = Comments.review_paths([dir])
      assert Comments.review_paths([dir], [fixture]) == []
    end
  end

  describe "structs" do
    test "checks/0 lists Check structs" do
      assert [%Check{id: :register} | _rest] = Comments.checks()
    end

    test "review/2 reports Offense structs" do
      source = wrap("Please note this is deliberately a cache, not a queue.")

      assert [%Offense{file: "lib/example.ex", check: _check} | _rest] =
               Comments.review("lib/example.ex", source)
    end
  end
end
