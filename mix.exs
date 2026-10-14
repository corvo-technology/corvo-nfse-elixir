defmodule CorvoNfse.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/corvo-technology/corvo-nfse-elixir"

  def project do
    [
      app: :corvo_nfse,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Corvo NFS-e",
      source_url: @source_url,
      homepage_url: "https://corvo.tech",
      docs: [
        main: "CorvoNfse",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {CorvoNfse.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Official Elixir SDK for the Corvo NFS-e API: 28 API-key operations plus public " <>
      "health checks, cursor pagination, result-style errors and webhook signature verification."
  end

  defp deps do
    [
      {:finch, "~> 0.18"},
      {:jason, "~> 1.4"},
      {:mox, "~> 1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end
end
