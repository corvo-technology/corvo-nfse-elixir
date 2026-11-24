defmodule CorvoNfse.Resources.Cnpj do
  @moduledoc """
  Registration data of a CNPJ (`GET /v1/cnpj/:cnpj`).

  Errors use the codes `CNPJ_INVALID` and `CNPJ_LOOKUP_UNAVAILABLE`.
  """

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Looks up legal name, address, situation and Simples/MEI status of a CNPJ (digits)."
  @spec lookup(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def lookup(client, cnpj) do
    Transport.request(client, :get, "/cnpj/#{Transport.segment(cnpj)}")
  end
end
