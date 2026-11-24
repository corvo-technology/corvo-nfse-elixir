defmodule CorvoNfse.Resources.IntegrationOperations do
  @moduledoc "Operations (sales) received by an integration connection (`/v1/integrations/operations`)."

  alias CorvoNfse.{Client, Error, Transport}

  @doc """
  Fills in the customer of an operation waiting for it. Params: `taxId`
  (required), `name` and `email`.
  """
  @spec complete_customer(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def complete_customer(client, id, params) when is_map(params) do
    Transport.request(client, :patch, path(id) <> "/customer", json: params)
  end

  @doc "Tries to issue the invoice of an operation again."
  @spec retry(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def retry(client, id), do: Transport.request(client, :post, path(id) <> "/retry")

  defp path(id), do: "/integrations/operations/#{Transport.segment(id)}"
end
