defmodule Supabase.Storage.MixProject do
  use Mix.Project

  @version "0.3.4"
  @source_url "https://github.com/zoedsoupe/storage-ex"

  def project do
    [
      app: :supabase_storage,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs(),
      dialyzer: [plt_local_path: "priv/plts", ignore_warnings: ".dialyzerignore"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:supabase_potion, path: "../supabase-ex"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    %{
      name: "supabase_storage",
      licenses: ["MIT"],
      contributors: ["zoedsoupe"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/supabase_storage"
      },
      files: ~w[lib mix.exs README.md LICENSE]
    }
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp description do
    """
    High level Elixir client for Supabase Storage.
    """
  end
end
