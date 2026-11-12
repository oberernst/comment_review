defmodule Mix.Tasks.Comments.Check do
  @moduledoc "A convention `mix comments` reports on, by the id an offense carries."

  @enforce_keys [:id, :title]
  defstruct [:id, :title]

  @type t :: %__MODULE__{id: atom(), title: String.t()}
end
