defmodule CorvoNfse.Resources.DpsSequence do
  @moduledoc """
  DPS numbering of a company (`/v1/companies/:id/dps-sequence`), to continue
  from the last note issued in another system. Setting a number below the
  current one fails with `DPS_NUMBER_BELOW_CURRENT`.
  """

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Reads the `series` and the `lastNumber` used."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, company_id) do
    Transport.request(client, :get, path(company_id))
  end

  @doc "Sets the last used number: a map with the `lastNumber` key."
  @spec set(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def set(client, company_id, params) when is_map(params) do
    Transport.request(client, :put, path(company_id), json: params)
  end

  defp path(company_id), do: "/companies/#{Transport.segment(company_id)}/dps-sequence"
end
