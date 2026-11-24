defmodule CorvoNfse.Resources.Integrations do
  @moduledoc "Payment platforms Corvo can connect to (`GET /v1/integrations/providers`)."

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Lists the available providers."
  @spec list_providers(Client.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_providers(client) do
    Transport.request(client, :get, "/integrations/providers")
  end
end
