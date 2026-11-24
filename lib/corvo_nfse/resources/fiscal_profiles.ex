defmodule CorvoNfse.Resources.FiscalProfiles do
  @moduledoc "Fiscal profile history of a company (`/v1/companies/:id/fiscal-profile`)."

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Lists the fiscal profile history."
  @spec list(Client.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def list(client, company_id) do
    Transport.request(client, :get, base(company_id))
  end

  @doc "Creates a fiscal profile validity period (idempotent for an identical desired state)."
  @spec upsert(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def upsert(client, company_id, params) when is_map(params) do
    Transport.request(client, :put, base(company_id), json: params)
  end

  @doc "Approves a fiscal profile."
  @spec approve(Client.t(), String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def approve(client, company_id, profile_id) do
    Transport.request(
      client,
      :post,
      base(company_id) <> "/#{Transport.segment(profile_id)}/approve"
    )
  end

  defp base(company_id), do: "/companies/#{Transport.segment(company_id)}/fiscal-profile"
end
