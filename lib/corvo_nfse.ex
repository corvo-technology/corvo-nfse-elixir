defmodule CorvoNfse do
  @moduledoc """
  Official Elixir SDK for the Corvo NFS-e API.

  28 API-key operations plus 2 public health checks, cursor pagination,
  envelope unwrapping and result-style errors.

  ## Quickstart

      client = CorvoNfse.new(api_key: "corvo_test_...")

      {:ok, page} = CorvoNfse.Resources.Companies.list(client, limit: 10)
      page.data          #=> [%{"id" => "comp_...", "legalName" => "..."}, ...]
      page.pagination    #=> %{"limit" => 10, "hasMore" => true, "nextCursor" => "..."}

      {:ok, invoice} =
        CorvoNfse.Resources.Invoices.create(client, %{
          "customer" => %{"name" => "Ada Lovelace", "taxId" => "12345678900"},
          "service" => %{"code" => "0101", "municipalityCode" => "3550308"},
          "amount" => 10.5,
          "competenceDate" => "2026-10-01"
        })

  ## Results, never exceptions

  Every API, network or timeout failure is returned - never raised:

      case CorvoNfse.Resources.Companies.get(client, "comp_missing") do
        {:ok, company} -> company
        {:error, %CorvoNfse.Error{status: 404, code: code, request_id: rid}} -> {code, rid}
      end

  Construction problems (missing API key, invalid base URL) raise
  `ArgumentError`. The one documented raising site is a page failure *after*
  the first page of an `iterate` stream.

  ## Configuration

  See `CorvoNfse.Client` for all options; `CORVO_API_KEY`, `CORVO_BASE_URL`
  and `CORVO_API_PREFIX` are picked up from the environment.

  ## Modules

    * `CorvoNfse.Client` - connection/config struct.
    * `CorvoNfse.Error` - the single error type.
    * `CorvoNfse.Webhooks` - `verify_signature/3` (HMAC-SHA256).
    * `CorvoNfse.Resources.*` - `Companies`, `Certificates`, `Invoices`,
      `Webhooks` (+ `Webhooks.Deliveries`), `Credits`, `Billing`, `Health`.
    * `CorvoNfse.Types.*` - wire types mirroring the Node SDK.
  """

  @version Mix.Project.config()[:version]

  @doc "Builds a `CorvoNfse.Client` from options/environment (raises `ArgumentError` when misconfigured)."
  @spec new([CorvoNfse.Client.option()]) :: CorvoNfse.Client.t()
  def new(opts \\ []), do: CorvoNfse.Client.new(opts)

  @doc "The SDK version."
  @spec version() :: String.t()
  def version, do: @version
end
