defmodule CorvoNfse.Resources.Companies do
  @moduledoc """
  Company management: create, list, iterate, get, update and remove.

      CorvoNfse.Resources.Companies.create(client, %{
        "legalName" => "Acme Ltda",
        "taxId" => "12345678000199",
        "taxRegime" => "Simples Nacional"
      })
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.{Common, Company}

  @type list_option :: {:limit, pos_integer()} | {:cursor, String.t()}

  @doc "Creates a company (`POST /v1/companies`)."
  @spec create(Client.t(), Company.create_params()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, params) when is_map(params) do
    Transport.request(client, :post, "/companies", json: params)
  end

  @doc """
  Lists companies (`GET /v1/companies`) with cursor pagination.

  Returns `{:ok, %{data: [map], pagination: map}}`; `pagination` keeps the
  server's camelCase keys (`limit`, `hasMore`, `nextCursor`) unchanged.
  """
  @spec list(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def list(client, opts \\ []) do
    Transport.list(client, "/companies", list_query(opts), :raw)
  end

  @doc """
  Lazily iterates every company across pages.

  The first page is fetched eagerly: `{:error, error}` means it failed and
  nothing was produced; `{:ok, stream}` yields companies one by one. A failure
  in a later page raises the `%CorvoNfse.Error{}` while consuming the stream.
  """
  @spec iterate(Client.t(), [list_option()]) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate(client, opts \\ []) do
    Transport.paginate(client, "/companies", list_query(opts), :raw)
  end

  @doc "Reads one company (`GET /v1/companies/:id`)."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, id) do
    Transport.request(client, :get, "/companies/#{Transport.segment(id)}")
  end

  @doc "Updates a company (`PATCH /v1/companies/:id`)."
  @spec update(Client.t(), String.t(), Company.update_params()) ::
          {:ok, map()} | {:error, Error.t()}
  def update(client, id, params) when is_map(params) do
    Transport.request(client, :patch, "/companies/#{Transport.segment(id)}", json: params)
  end

  @doc "Deletes a company (`DELETE /v1/companies/:id`); 204 yields `{:ok, nil}`."
  @spec remove(Client.t(), String.t()) :: {:ok, nil} | {:error, Error.t()}
  def remove(client, id) do
    Transport.request(client, :delete, "/companies/#{Transport.segment(id)}")
  end

  defp list_query(opts) do
    [limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)]
  end
end
