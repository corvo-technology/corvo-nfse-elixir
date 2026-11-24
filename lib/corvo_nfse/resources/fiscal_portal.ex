defmodule CorvoNfse.Resources.FiscalPortal do
  @moduledoc "Status of the national NFS-e portal (`GET /v1/fiscal-portal/status`)."

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Whether the national portal is answering for this environment."
  @spec status(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def status(client) do
    Transport.request(client, :get, "/fiscal-portal/status")
  end
end
