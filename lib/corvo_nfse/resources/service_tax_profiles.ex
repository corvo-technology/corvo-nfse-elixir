defmodule CorvoNfse.Resources.ServiceTaxProfiles do
  @moduledoc "Service tax profiles of a company catalog (`/v1/companies/:id/service-tax-profiles`)."

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Lists the profiles effective on `date:` (`YYYY-MM-DD`, default today)."
  @spec list(Client.t(), String.t(), [{:date, String.t()}]) ::
          {:ok, [map()]} | {:error, Error.t()}
  def list(client, company_id, opts \\ []) do
    Transport.request(client, :get, base(company_id), query: [date: Keyword.get(opts, :date)])
  end

  @doc "Creates a profile in the company catalog."
  @spec create(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, company_id, params) when is_map(params) do
    Transport.request(client, :post, base(company_id), json: params)
  end

  @doc "Updates a profile."
  @spec update(Client.t(), String.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, company_id, service_id, params) when is_map(params) do
    Transport.request(client, :patch, item(company_id, service_id), json: params)
  end

  @doc "Deletes an expired, not yet approved profile."
  @spec remove(Client.t(), String.t(), String.t()) :: {:ok, map() | nil} | {:error, Error.t()}
  def remove(client, company_id, service_id) do
    Transport.request(client, :delete, item(company_id, service_id))
  end

  @doc "Approves the saved classification."
  @spec approve(Client.t(), String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def approve(client, company_id, service_id) do
    Transport.request(client, :post, item(company_id, service_id) <> "/approve")
  end

  defp base(company_id), do: "/companies/#{Transport.segment(company_id)}/service-tax-profiles"
  defp item(company_id, service_id), do: base(company_id) <> "/" <> Transport.segment(service_id)
end
