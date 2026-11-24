defmodule CorvoNfse.Resources.Customers do
  @moduledoc """
  Customers saved from issued invoices (`/v1/customers`), keyed by CPF or CNPJ
  (digits only).

      {:ok, page} = CorvoNfse.Resources.Customers.search(client, search: "ada")
      {:ok, customer} = CorvoNfse.Resources.Customers.get(client, "52998224725")

  The pagination cursor of `search/2` is the offset of the next page; pass it
  back untouched.
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.Common

  @type search_option ::
          {:search, String.t()} | {:limit, pos_integer()} | {:cursor, String.t()}

  @doc "Lists saved customers, most recently used first (`GET /v1/customers`)."
  @spec search(Client.t(), [search_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def search(client, opts \\ []) do
    Transport.list(client, "/customers", search_query(opts), :raw)
  end

  @doc "Lazily iterates every saved customer across pages (first page eager, see `CorvoNfse.Transport.paginate/4`)."
  @spec iterate(Client.t(), [search_option()]) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate(client, opts \\ []) do
    Transport.paginate(client, "/customers", search_query(opts), :raw)
  end

  @doc "Reads a saved customer by CPF or CNPJ (`GET /v1/customers/:taxId`)."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, tax_id) do
    Transport.request(client, :get, "/customers/#{Transport.segment(tax_id)}")
  end

  @doc """
  Corrects the `"name"` or `"email"` (`nil` clears it) of a saved customer
  (`PATCH /v1/customers/:taxId`).
  """
  @spec update(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, tax_id, params) when is_map(params) do
    Transport.request(client, :patch, "/customers/#{Transport.segment(tax_id)}", json: params)
  end

  @doc "Forgets a saved customer; issued invoices are not changed (`DELETE /v1/customers/:taxId`)."
  @spec remove(Client.t(), String.t()) :: {:ok, map() | nil} | {:error, Error.t()}
  def remove(client, tax_id) do
    Transport.request(client, :delete, "/customers/#{Transport.segment(tax_id)}")
  end

  defp search_query(opts) do
    [
      search: Keyword.get(opts, :search),
      limit: Keyword.get(opts, :limit),
      cursor: Keyword.get(opts, :cursor)
    ]
  end
end
