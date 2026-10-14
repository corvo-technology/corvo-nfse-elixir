defmodule CorvoNfse.Resources.Webhooks.Deliveries do
  @moduledoc """
  Webhook delivery inspection: `list`, `iterate`, `stats` and `retry`
  (`/v1/webhooks/deliveries/...`).
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.{Common, Webhook}

  @type list_option ::
          {:hours, pos_integer()}
          | {:environment, Webhook.environment()}
          | {:limit, pos_integer()}
          | {:cursor, String.t()}

  @type stats_option :: {:hours, pos_integer()} | {:environment, Webhook.environment()}

  @doc "Lists delivery attempts (`GET /v1/webhooks/deliveries`)."
  @spec list(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def list(client, opts \\ []) do
    Transport.list(client, "/webhooks/deliveries", list_query(opts), :raw)
  end

  @doc """
  Lazily iterates every delivery across pages.

  The first page is fetched eagerly: `{:error, error}` means it failed and
  nothing was produced; `{:ok, stream}` yields deliveries one by one. A failure
  in a later page raises the `%CorvoNfse.Error{}` while consuming the stream.
  """
  @spec iterate(Client.t(), [list_option()]) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate(client, opts \\ []) do
    Transport.paginate(client, "/webhooks/deliveries", list_query(opts), :raw)
  end

  @doc "Delivery counters for the last `hours` (`GET /v1/webhooks/deliveries/stats`)."
  @spec stats(Client.t(), [stats_option()]) :: {:ok, map()} | {:error, Error.t()}
  def stats(client, opts \\ []) do
    query = [
      hours: Keyword.get(opts, :hours),
      environment: Keyword.get(opts, :environment)
    ]

    Transport.request(client, :get, "/webhooks/deliveries/stats", query: query)
  end

  @doc "Requeues a delivery (`POST /v1/webhooks/deliveries/:id/retry`)."
  @spec retry(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def retry(client, delivery_id) do
    Transport.request(client, :post, "/webhooks/deliveries/#{Transport.segment(delivery_id)}/retry")
  end

  defp list_query(opts) do
    [
      hours: Keyword.get(opts, :hours),
      environment: Keyword.get(opts, :environment),
      limit: Keyword.get(opts, :limit),
      cursor: Keyword.get(opts, :cursor)
    ]
  end
end
