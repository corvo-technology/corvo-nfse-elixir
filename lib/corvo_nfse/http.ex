defmodule CorvoNfse.HTTP do
  @moduledoc """
  Behaviour for the HTTP layer used by `CorvoNfse.Transport`.

  The default adapter is `CorvoNfse.HTTP.Finch`. Inject your own adapter with
  `CorvoNfse.new(http: MyAdapter)` - useful for tests (Mox), recording proxies
  or alternative HTTP stacks.

  Adapters must never raise: they return `{:ok, response}` on any HTTP
  response (including 4xx/5xx) and `{:error, reason}` for transport-level
  failures such as refused connections or timeouts. The transport maps both
  onto `CorvoNfse.Error`.
  """

  @type method :: :get | :post | :patch | :delete

  @type request :: %{
          method: method(),
          url: String.t(),
          headers: [{String.t(), String.t()}],
          body: iodata() | nil,
          receive_timeout: pos_integer(),
          finch: atom() | nil
        }

  @type response :: %{
          status: pos_integer(),
          headers: [{String.t(), String.t()}],
          body: binary()
        }

  @callback send(request()) :: {:ok, response()} | {:error, term()}
end
