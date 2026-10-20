defmodule CorvoNfse.Resources.Invoices do
  @moduledoc """
  NFS-e invoice lifecycle: create, read, list, iterate, events, downloads,
  email and cancellation.

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

  @doc """
  Cancels an invoice (`POST /v1/invoices/:id/cancel`).

  `params` takes `reason` (required: `:issue_error`, `:service_not_provided`
  or `:other`, or the same strings) and `description` (optional, up to 255
  characters). The API requires a 15 to 255 character `description` to cancel
  an `authorized` or `processing` invoice and accepts none for a `queued` one;
  the SDK does not validate it.

  `{:ok, invoice}` carries the updated invoice, like `get/2`:

    * `200` - a queued invoice is cancelled at once: `"status" => "cancelled"`
      with `"cancelledAt"` set.
    * `202` - `"status" => "cancelling"` while the Sefin processes the
      cancellation, or `"status" => "processing"` with
      `"cancellationRequestedAt"` set when the invoice is still being issued.

  Repeating the request returns the current state (the first request wins).
  Follow the outcome with `get/2` (or the `nfse.invoice.cancelled` and
  `nfse.invoice.cancellation_rejected` webhooks): `"cancelled"` is done,
  `"cancelling"` is in progress, and a rejected cancellation goes back to
  `"authorized"` with `"lastErrorCode"`/`"lastErrorMessage"` set.

  An invoice in `retry_pending`, `reconciliation_required` or `manual_review`
  returns `{:error, %CorvoNfse.Error{status: 409, code:
  "ERROR_INVOICE_NOT_CANCELLABLE"}}`; an invalid description returns a `422`
  error.

  ## Example

      {:ok, invoice} =
        CorvoNfse.Resources.Invoices.cancel(client, "inv_1", %{
          reason: :issue_error,
          description: "Wrong amount on the invoice"
        })

      invoice["status"]
      #=> "cancelling"

      {:ok, %{"status" => "cancelled"}} = CorvoNfse.Resources.Invoices.get(client, "inv_1")
  """
  @spec cancel(Client.t(), String.t(), Invoice.cancel_params()) ::
          {:ok, map()} | {:error, Error.t()}
  def cancel(client, id, params) when is_map(params) do
    Transport.request(client, :post, "/invoices/#{Transport.segment(id)}/cancel", json: params)
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
