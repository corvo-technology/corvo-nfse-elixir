defmodule CorvoNfse.Resources.ServiceFavorites do
  @moduledoc """
  Favorite services of a company (`/v1/companies/:companyId/service-favorites`).

      CorvoNfse.Resources.ServiceFavorites.create(client, company_id, %{
        "label" => "Consultoria",
        "serviceCode" => "010101",
        "description" => "Consultoria em TI"
      })
  """

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Lists the favorite services of a company."
  @spec list(Client.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def list(client, company_id) do
    Transport.request(client, :get, base(company_id))
  end

  @doc """
  Saves a favorite service. Params: `"label"`, `"serviceCode"`,
  `"description"` (required) and `"municipalityCode"`, `"amountCents"` (optional).
  """
  @spec create(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, company_id, params) when is_map(params) do
    Transport.request(client, :post, base(company_id), json: params)
  end

  @doc "Removes a favorite service."
  @spec remove(Client.t(), String.t(), String.t()) :: {:ok, map() | nil} | {:error, Error.t()}
  def remove(client, company_id, favorite_id) do
    Transport.request(client, :delete, base(company_id) <> "/" <> Transport.segment(favorite_id))
  end

  defp base(company_id), do: "/companies/#{Transport.segment(company_id)}/service-favorites"
end
