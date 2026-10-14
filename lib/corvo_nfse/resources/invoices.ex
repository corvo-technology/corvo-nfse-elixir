defmodule CorvoNfse.Resources.Invoices do
  @moduledoc """
  NFS-e invoice lifecycle: create, read, list, iterate, events, downloads and
  email.

  Invoice entities are serialized as `{props: {...}}` inside the `data`
  envelope; this module unwraps both layers, so `{:ok, invoice}` is the invoice
  map itself (camelCase wire keys, unchanged).
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.{Common, Invoice}

  @type list_option ::
          {:company_id, String.t()}
          | {:status, Invoice.status()}
          | {:from, String.t()}
          | {:to, String.t()}
          | {:external_id, String.t()}
          | {:limit, pos_integer()}
          | {:cursor, String.t()}

  @type option ::
          {:idempotency_key, String.t()}
          | {:limit, pos_integer()}
          | {:cursor, String.t()}

  @doc """
  Creates an invoice (`POST /v1/invoices`).

  Pass `idempotency_key:` to send the `Idempotency-Key` header. The response
  is `202 Accepted`; `{:ok, invoice}` carries the invoice entity.
  """
  @spec create(Client.t(), Invoice.create_params(), [{:idempotency_key, String.t()}]) ::
          {:ok, map()} | {:error, Error.t()}
  def create(client, params, opts \\ []) when is_map(params) do
    Transport.request(client, :post, "/invoices",
      json: params,
      idempotency_key: Keyword.get(opts, :idempotency_key),
      unwrap: :data_props
    )
  end

  @doc "Reads an invoice (`GET /v1/invoices/:id`)."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, id) do
    Transport.request(client, :get, "/invoices/#{Transport.segment(id)}", unwrap: :data_props)
  end

  @doc """
  Lists invoices (`GET /v1/invoices`) with cursor pagination.

  Filters use snake_case options (`company_id:`, `external_id:`) and are sent
  on the wire as `companyId`, `externalId`, etc.
  """
  @spec list(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def list(client, opts \\ []) do
    Transport.list(client, "/invoices", list_query(opts), :props)
  end

  @doc """
  Lazily iterates every invoice across pages.

  The first page is fetched eagerly: `{:error, error}` means it failed and
  nothing was produced; `{:ok, stream}` yields invoices one by one. A failure
  in a later page raises the `%CorvoNfse.Error{}` while consuming the stream.
  """
  @spec iterate(Client.t(), [list_option()]) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate(client, opts \\ []) do
    Transport.paginate(client, "/invoices", list_query(opts), :props)
  end

  @doc "Lists an invoice's events (`GET /v1/invoices/:id/events`)."
  @spec events(Client.t(), String.t(), [option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def events(client, id, opts \\ []) do
    query = [limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)]

    Transport.list(client, "/invoices/#{Transport.segment(id)}/events", query, :props)
  end

  @doc "Downloads the invoice PDF (`GET /v1/invoices/:id/pdf`) as raw bytes."
  @spec pdf(Client.t(), String.t()) :: {:ok, Invoice.download()} | {:error, Error.t()}
  def pdf(client, id) do
    Transport.request_raw(client, :get, "/invoices/#{Transport.segment(id)}/pdf")
  end

  @doc "Downloads the invoice XML (`GET /v1/invoices/:id/xml`) as raw bytes."
  @spec xml(Client.t(), String.t()) :: {:ok, Invoice.download()} | {:error, Error.t()}
  def xml(client, id) do
    Transport.request_raw(client, :get, "/invoices/#{Transport.segment(id)}/xml")
  end

  @doc """
  Creates a short-lived signed download URL
  (`POST /v1/invoices/:id/download-url`).

  `format` is `:pdf` or `:xml` (sent as `"pdf"`/`"xml"`).
  """
  @spec download_url(Client.t(), String.t(), Invoice.download_format()) ::
          {:ok, map()} | {:error, Error.t()}
  def download_url(client, id, format) do
    Transport.request(client, :post, "/invoices/#{Transport.segment(id)}/download-url",
      json: %{format: format}
    )
  end

  @doc """
  Triggers the fiscal document email (`POST /v1/invoices/:id/email`).

  Pass `idempotency_key:` to send the `Idempotency-Key` header. The response
  is `202 Accepted`.
  """
  @spec send_email(Client.t(), String.t(), [{:idempotency_key, String.t()}]) ::
          {:ok, map()} | {:error, Error.t()}
  def send_email(client, id, opts \\ []) do
    Transport.request(client, :post, "/invoices/#{Transport.segment(id)}/email",
      idempotency_key: Keyword.get(opts, :idempotency_key)
    )
  end

  defp list_query(opts) do
    [
      companyId: Keyword.get(opts, :company_id),
      status: Keyword.get(opts, :status),
      from: Keyword.get(opts, :from),
      to: Keyword.get(opts, :to),
      externalId: Keyword.get(opts, :external_id),
      limit: Keyword.get(opts, :limit),
      cursor: Keyword.get(opts, :cursor)
    ]
  end
end
