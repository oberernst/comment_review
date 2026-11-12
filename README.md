# comment_review

`mix comments` reviews every comment and documentation string in an Elixir project against conventions anchored on NASA SWE-061:

> "Comments: An English description in the code that explains the logic of the code. (Quality code is usually self-documenting by default.) The use of quality commenting gives quality code better maintainability and easier understandability."

## Install

```elixir
def deps do
  [
    {:comment_review, github: "oberernst/comment_review", tag: "v0.1.0", only: [:dev, :test], runtime: false}
  ]
end
```

## Use

```sh
mix comments                  # lib, test, config, mix.exs
mix comments lib/my_app/voice # any files or directories
```

Each offense prints its file, line and an excerpt. The task exits non-zero when it finds any, so it can sit in a `verify` alias or a CI step.

A unit is one run of `#` lines, or one paragraph of a `@moduledoc`, `@doc` or `@typedoc` string. Indented samples, fenced blocks and `iex>` lines are skipped.

## Checks

| Check | Reports |
|---|---|
| `register` | counterfactual, negated definition, prohibition, analogy, comparison to a sibling module, reference to a prior implementation |
| `causal_chain` | a second causal connective in one unit |
| `semicolon` | clauses joined by a semicolon |
| `aside` | a pair of em dashes inside one sentence |
| `justification` | the vocabulary of design defence ("deliberately", "by design", "the reason") |
| `length` | a comment past 35 words, a doc paragraph past 40 |
| `divider` | a section divider |
| `addressee` | the second person |
| `marker` | `TODO`, `FIXME`, `XXX`, `HACK` |
| `commented_code` | code behind a comment marker |
| `doc_channel` | documentation in a comment above a public definition |
| `duration_unit` | a duration attribute whose name omits its unit |

`aside`, `divider`, `causal_chain`, `justification` and `length` hold at a rate near zero across 13 reference corpora (339k words of Elixir core, ecto, oban, plug, phoenix, liveview and others). `register`, `addressee` and `marker` are house policy. [docs/comment-corpora.md](docs/comment-corpora.md) records the corpora, their SHAs and every rate.
