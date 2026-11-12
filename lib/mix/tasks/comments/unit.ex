defmodule Mix.Tasks.Comments.Unit do
  @moduledoc """
  One run of `#` lines, or one paragraph of a documentation string: the kind,
  the first and last line it spans, and its text joined into one string.
  """

  @enforce_keys [:kind, :line, :last, :text]
  defstruct [:kind, :line, :last, :text]

  @type t :: %__MODULE__{
          kind: :comment | :doc,
          line: pos_integer(),
          last: pos_integer(),
          text: String.t()
        }
end
