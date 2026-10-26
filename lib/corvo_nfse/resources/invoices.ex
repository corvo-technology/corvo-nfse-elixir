defmodule CorvoNfse.Resources.Invoices do
  @moduledoc """
  NFS-e invoice lifecycle: create, create in batch, read, list, iterate, events,
  downloads, email and cancellation.

  Resources come straight in the response `data`, so `{:ok, invoice}` is the
  invoice map itself (camelCase wire keys, unchanged).
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
      idempotency_key: Keyword.get(opts, :idempotency_key)
    )
  end

  @doc """
  Creates 1 to 50 invoices in one call (`POST /v1/invoices/batches`), for one
  company or several.

  Each item takes the keys of `create/3` plus an optional `"idempotencyKey"`
  (up to 255 characters); the `Idempotency-Key` header is not used by this
  route. Items are checked one by one: valid ones are saved together, invalid
  ones come back `"rejected"` and are not saved. Match each result's `"index"`
  to the item you sent, fix only the rejected ones and send them again.
  """
  @spec create_batch(Client.t(), [Invoice.batch_item()]) ::
          {:ok, Invoice.batch_summary()} | {:error, Error.t()}
  def create_batch(client, invoices) when is_list(invoices) do
    Transport.request(client, :post, "/invoices/batches", json: %{"invoices" => invoices})
  end

  @doc """
  Estimates the taxes of an invoice without issuing, storing or charging
  anything (`POST /v1/invoices/calculate`).

  Takes the same params as `create/3`. A fiscal gap is not an error: the
  result has `"status" => "blocked"` with `"blocking"` and `"pendingFields"`.
  Money values are decimal strings.
  """
  @spec calculate(Client.t(), Invoice.create_params()) :: {:ok, map()} | {:error, Error.t()}
  def calculate(client, params) when is_map(params) do
    Transport.request(client, :post, "/invoices/calculate", json: params)
  end

  @doc "Reads an invoice (`GET /v1/invoices/:id`)."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, id) do
    Transport.request(client, :get, "/invoices/#{Transport.segment(id)}")
  end

  @doc """
  Lists invoices (`GET /v1/invoices`) with cursor pagination.

  Filters use snake_case options (`company_id:`, `external_id:`) and are sent
  on the wire as `companyId`, `externalId`, etc.
  """
  @spec list(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def list(client, opts \\ []) do
    Transport.list(client, "/invoices", list_query(opts), :raw)
  end

  @doc """
  Lazily iterates every invoice across pages.

  The first page is fetched eagerly: `{:error, error}` means it failed and
  nothing was produced; `{:ok, stream}` yields invoices one by one. A failure
  in a later page raises the `%CorvoNfse.Error{}` while consuming the stream.
  """
  @spec iterate(Client.t(), [list_option()]) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate(client, opts \\ []) do
    Transport.paginate(client, "/invoices", list_query(opts), :raw)
  end

  @doc "Lists an invoice's events (`GET /v1/invoices/:id/events`)."
  @spec events(Client.t(), String.t(), [option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def events(client, id, opts \\ []) do
    query = [limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)]

    Transport.list(client, "/invoices/#{Transport.segment(id)}/events", query, :raw)
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
  Cancels an invoice (`POST /v1/invoices/:id/cancel`).

  `reason` is `"issue_error"`, `"service_not_provided"` or `"other"`. The
  `description:` option (15 to 255 characters) is required to cancel an
  authorized or processing invoice and optional for a queued one.

  A queued invoice is cancelled at once (`"status" => "cancelled"`); an
  authorized one moves to `"cancelling"` while the cancellation is processed,
  and a processing one stays `"processing"` with `"cancellationRequestedAt"`
  set. Call `get/2` later: `"cancelled"` when done, or back to `"authorized"`
  with `"lastErrorCode"` when the cancellation was rejected.
  """
  @spec cancel(Client.t(), String.t(), Invoice.cancellation_reason(), [{:description, String.t()}]) ::
          {:ok, map()} | {:error, Error.t()}
  def cancel(client, id, reason, opts \\ []) do
    body =
      case Keyword.get(opts, :description) do
        nil -> %{"reason" => reason}
        description -> %{"reason" => reason, "description" => description}
      end

    Transport.request(client, :post, "/invoices/#{Transport.segment(id)}/cancel", json: body)
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
