defmodule CorvoNfse.Resources.Webhooks do
  @moduledoc """
  Webhook configuration and delivery inspection.

  Endpoint secret verification lives in `CorvoNfse.Webhooks`.

      CorvoNfse.Resources.Webhooks.create(client, %{
        url: "https://example.com/hooks/corvo",
        events: ["nfse.invoice.authorized"]
      })
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.{Common, Webhook}

  @type list_option :: {:limit, pos_integer()} | {:cursor, String.t()}

  @doc "Lists webhook configs (`GET /v1/webhooks`)."
  @spec list(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def list(client, opts \\ []) do
    query = [limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)]
    Transport.list(client, "/webhooks", query, :raw)
  end

  @doc """
  Creates a webhook config (`POST /v1/webhooks`).

  The response includes the endpoint `secret` used to verify signatures -
  store it before discarding the result.
  """
  @spec create(Client.t(), Webhook.create_params()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, params) when is_map(params) do
    Transport.request(client, :post, "/webhooks", json: params)
  end

  @doc "Deletes a webhook config (`DELETE /v1/webhooks/:id`)."
  @spec remove(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def remove(client, id) do
    Transport.request(client, :delete, "/webhooks/#{Transport.segment(id)}")
  end

  @doc "Sends a `webhook.test` event (`POST /v1/webhooks/:id/test`)."
  @spec test(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def test(client, id) do
    Transport.request(client, :post, "/webhooks/#{Transport.segment(id)}/test")
  end
end
