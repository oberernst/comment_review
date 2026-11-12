defmodule Mix.Tasks.Comments.Offense do
  @moduledoc "One finding: the file and line, the check it failed, the message and an excerpt of the unit."

  @enforce_keys [:file, :line, :check, :message, :excerpt]
  defstruct [:file, :line, :check, :message, :excerpt]

  @type t :: %__MODULE__{
          file: String.t(),
          line: pos_integer(),
          check: atom(),
          message: String.t(),
          excerpt: String.t()
        }
end
