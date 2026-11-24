defmodule CorvoNfse.Resources.IntegrationConnections do
  @moduledoc """
  Connections to payment platforms that issue invoices automatically from
  sales (`/v1/integrations/connections`). A connection follows the environment
  of the API key that created it.

      {:ok, conn} =
        CorvoNfse.Resources.IntegrationConnections.create(client, %{
          "provider" => "...",
          "companyId" => company_id,
          "credentials" => %{"apiKey" => "..."}
        })

      {:ok, _} = CorvoNfse.Resources.IntegrationConnections.activate(client, conn["id"])
  """

  alias CorvoNfse.{Client, Error, Transport}

  @type limit_option :: {:limit, pos_integer()}

  @doc "Lists connections."
  @spec list(Client.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def list(client), do: Transport.request(client, :get, "/integrations/connections")

  @doc """
  Creates a connection. Params: `"provider"`, `"companyId"`, `"credentials"`
  (required) and `"environment"`, `"activeFrom"` (optional).
  """
  @spec create(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, params) when is_map(params) do
    Transport.request(client, :post, "/integrations/connections", json: params)
  end

  @doc "Reads a connection."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, id), do: Transport.request(client, :get, path(id))

  @doc "Checks the credentials and identifies the external account."
  @spec validate(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def validate(client, id), do: Transport.request(client, :post, path(id) <> "/validate")

  @doc "Replaces the credentials (for example a rotated API key): `%{\"credentials\" => %{...}}`."
  @spec update_credentials(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update_credentials(client, id, params) when is_map(params) do
    Transport.request(client, :put, path(id) <> "/credentials", json: params)
  end

  @doc "Starts issuing invoices automatically."
  @spec activate(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def activate(client, id), do: Transport.request(client, :post, path(id) <> "/activate")

  @doc "Stops issuing; events are still recorded."
  @spec pause(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def pause(client, id), do: Transport.request(client, :post, path(id) <> "/pause")

  @doc "Disconnects for good."
  @spec disconnect(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def disconnect(client, id), do: Transport.request(client, :post, path(id) <> "/disconnect")

  @doc "Lists the rules of a connection."
  @spec list_rules(Client.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_rules(client, id), do: Transport.request(client, :get, path(id) <> "/rules")

  @doc "Replaces the rules of a connection: `%{\"rules\" => [%{...}]}`."
  @spec replace_rules(Client.t(), String.t(), map()) :: {:ok, [map()]} | {:error, Error.t()}
  def replace_rules(client, id, params) when is_map(params) do
    Transport.request(client, :put, path(id) <> "/rules", json: params)
  end

  @doc "Recent events received for a connection."
  @spec list_events(Client.t(), String.t(), [limit_option()]) ::
          {:ok, [map()]} | {:error, Error.t()}
  def list_events(client, id, opts \\ []) do
    Transport.request(client, :get, path(id) <> "/events",
      query: [limit: Keyword.get(opts, :limit)]
    )
  end

  @doc "Recent operations (sales) and their invoice status."
  @spec list_operations(Client.t(), String.t(), [limit_option()]) ::
          {:ok, [map()]} | {:error, Error.t()}
  def list_operations(client, id, opts \\ []) do
    Transport.request(client, :get, path(id) <> "/operations",
      query: [limit: Keyword.get(opts, :limit)]
    )
  end

  defp path(id), do: "/integrations/connections/#{Transport.segment(id)}"
end
