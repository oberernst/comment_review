# Comment corpora

Where `mix comments`' thresholds come from, and what it takes to move one.

Measured 2026-08-08. The method: extract every `#` run and every paragraph of
a `@moduledoc`, `@doc` or `@typedoc` from `lib/**/*.ex`, drop indented
samples, fenced blocks and `iex>` lines, and count. A *unit* is one such run
or paragraph. Rates below are the share of units carrying the trait, except
`you/kw`, which is occurrences per thousand words.

## Reference set

Thirteen corpora, 19,588 units, 338,901 words. Chosen for governance (core
team or long-lived maintainer), for genre coverage (four applications, nine
libraries), and for lineage spread.

| corpus | at | units | words |
| --- | --- | --- | --- |
| elixir (`lib/elixir`) | `0bd52d4` | 7,893 | 141,344 |
| mix (`lib/mix`) | `0bd52d4` | 1,666 | 31,803 |
| ex_unit (`lib/ex_unit`) | `0bd52d4` | 486 | 8,043 |
| logger (`lib/logger`) | `0bd52d4` | 229 | 3,670 |
| ecto | `270acebe` | 2,132 | 40,281 |
| oban | `9d0e636` | 772 | 11,373 |
| plug | `d2580b0` | 695 | 12,384 |
| phoenix | v1.8.9 | 1,403 | 22,923 |
| phoenix_live_view | v1.1.32 | 1,242 | 20,333 |
| realtime (Supabase) | `744c6d6` | 691 | 11,072 |
| livebook | `1c0941f` | 2,080 | 29,485 |
| horde | `d5c941f` | 156 | 3,546 |
| libcluster | `6d8c11f` | 143 | 2,644 |

## Measurements

| corpus | 2+causal | semicolon | dash pair | justification | comment p90 | doc p90 | you/kw |
| --- | --- | --- | --- | --- | --- | --- | --- |
| elixir | 0.30% | 0.65% | 0.00% | 0.57% | 30 | 39 | 6.4 |
| mix | 0.72% | 0.66% | 0.00% | 0.42% | 31 | 45 | 13.7 |
| ex_unit | 0.21% | 0.00% | 0.00% | 0.21% | 20 | 37 | 10.8 |
| logger | 0.44% | 0.00% | 0.00% | 0.00% | 23 | 36 | 15.0 |
| ecto | 0.23% | 0.70% | 0.00% | 0.61% | 27 | 40 | 11.1 |
| oban | 0.00% | 1.17% | 0.10% | 0.26% | 24 | 33 | 8.4 |
| plug | 0.29% | 1.15% | 0.00% | 0.72% | 20 | 39 | 8.8 |
| phoenix | 0.07% | 0.36% | 0.05% | 0.36% | 24 | 36 | 15.2 |
| liveview | 0.40% | 0.48% | 0.00% | 0.40% | 26 | 40 | 9.8 |
| realtime | 1.16% | 2.75% | 0.00% | 0.58% | 39 | 30 | 2.7 |
| livebook | 1.01% | 0.05% | 0.00% | 0.67% | 49 | 17 | 0.6 |
| horde | 0.00% | 2.56% | 0.00% | 1.28% | 84 | 42 | 12.1 |
| libcluster | 0.00% | 0.70% | 0.00% | 0.00% | 18 | 38 | 18.2 |
| **median** | **0.29%** | **0.66%** | **0.00%** | **0.42%** | | | |
| **pooled p90** | | | | | **33** | **38** | |
| **pooled p95** | | | | | **47** | **48** | |

## Controls

Measured and excluded from derivation. A rule that survives the reference set
and dies here is a rule worth knowing is contested.

| corpus | 2+causal | semicolon | dash pair | justification | register | comment p90 | doc p90 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| bandit | 0.00% | 4.50% | 0.00% | 2.70% | 10.36% | 54 | 38 |
| thousand_island | 0.53% | 6.91% | 0.00% | 0.53% | 8.51% | 37 | 62 |
| postgrex | 0.47% | 3.53% | 0.00% | 0.71% | 4.47% | 19 | 39 |
| credo | 0.00% | 0.00% | 0.00% | 0.00% | 3.82% | 13 | 25 |
| reactmobile-api-elixir | 0.50% | 9.05% | 1.57% | 1.71% | 14.83% | 39 | 46 |

Bandit and Thousand Island alone would end the `semicolon` rule. Credo alone
would halve both word budgets.

## What each check rests on

**Derived** — near zero across all thirteen, and across the controls too:

| check | reference median | reference max | fleet before |
| --- | --- | --- | --- |
| `aside` | 0.00% | 0.10% (oban) | 4.97% |
| `divider` | 0 | 6 units of 19,588 | 3 |
| `causal_chain` | 0.29% | 1.16% (realtime) | 4.40% |
| `justification` | 0.42% | 1.28% (horde) | 3.88% |

**Derived, contested** — `semicolon`. Median 0.66%, and eleven of thirteen sit
under 2%. Realtime (2.75%) and horde (2.56%) exceed it, and three controls
reach 3.5–6.9%. Fleet ran 13.59%, above every corpus measured, so the rule
earns its place here while resting on thinner ground than the four above.

**Budgets** — `length` takes the pooled p90 of the reference set, rounded up
to the nearest five: 35 words a comment (p90 33), 40 a paragraph (p90 38).
The p95 pair is 47 and 48, so a budget at p95 would permit roughly what the
reference set's most verbose decile writes. The p90 is the stricter reading
and the one fleet takes.

**Policy** — fleet is deliberately stricter than every corpus measured:

| check | reference rate | note |
| --- | --- | --- |
| `register` | 4.02%–8.54% | elixir itself 8.34%. No corpus avoids the lexicon. |
| `addressee` | 0.6–18.2/kw | Splits on genre: applications 0.6–2.7, libraries 5.5–18.2. |
| `marker` | 0–39/1k units | elixir carries 95 markers, phoenix 26, livebook 14. |

`register` is the house rule this whole discipline started from. It has no
support in the reference set and needs none — it is a decision about how
fleet's comments read, and the corpora record only that fleet is alone in it.

`doc_channel` and `duration_unit` come from the NASA C++ coding standards'
comment section rather than from measurement. `commented_code` is universal
lint.

## Re-deriving

The corpora are checkouts under `~/work`, absent from this repo and absent
from CI. Re-measuring means cloning them again, at which point the numbers
above move with upstream. Treat a threshold change as the same kind of work
as the original: measure the whole set, publish the table, then change the
number.
