defmodule CommentReview.MixProject do
  use Mix.Project

  @version "0.1.2"
  @source_url "https://github.com/oberernst/comment_review"

  def project do
    [
      app: :comment_review,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: [],
      description:
        "mix comments: reviews Elixir comments and docs against NASA SWE-061 conventions",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: []]
  end
end
