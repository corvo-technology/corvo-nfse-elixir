defmodule CorvoNfse.HTTP.Finch do
  @moduledoc false

  @behaviour CorvoNfse.HTTP

  @impl true
  def send(request) do
    req = Finch.build(request.method, request.url, request.headers, request.body)

    case Finch.request(req, request.finch, receive_timeout: request.receive_timeout) do
      {:ok, %Finch.Response{} = response} ->
        {:ok, %{status: response.status, headers: response.headers, body: response.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
