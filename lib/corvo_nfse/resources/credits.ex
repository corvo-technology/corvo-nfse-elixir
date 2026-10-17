defmodule CorvoNfse.Resources.Credits do
  @moduledoc """
  Credit balance, purchasable plans and the credit ledger.

      CorvoNfse.Resources.Credits.balance(client)
      CorvoNfse.Resources.Credits.history(client, limit: 50)
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.Common

  @type list_option :: {:limit, pos_integer()} | {:cursor, String.t()}

  @doc "Reads the credit balance (`GET /v1/credits`)."
  @spec balance(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def balance(client) do
    Transport.request(client, :get, "/credits")
  end

  @doc "Lists credit plans (`GET /v1/credits/plans`)."
  @spec plans(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def plans(client, opts \\ []) do
    Transport.list(client, "/credits/plans", list_query(opts), :raw)
  end

  @doc "Lists credit transactions (`GET /v1/credits/history`)."
  @spec history(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def history(client, opts \\ []) do
    Transport.list(client, "/credits/history", list_query(opts), :raw)
  end

  @doc """
  Lazily iterates every credit transaction across pages.

  The first page is fetched eagerly: `{:error, error}` means it failed and
  nothing was produced; `{:ok, stream}` yields transactions one by one. A
  failure in a later page raises the `%CorvoNfse.Error{}` while consuming the
  stream.
  """
  @spec iterate_history(Client.t(), [list_option()]) ::
          {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate_history(client, opts \\ []) do
    Transport.paginate(client, "/credits/history", list_query(opts), :raw)
  end

  defp list_query(opts) do
    [limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)]
  end
end
