defmodule CorvoNfse.Types.Invoice do
  @moduledoc """
  Wire shape of an NFS-e invoice.

  The SDK returns the invoice as a plain map with these string keys.
  """

  @typedoc ~S(Environment wire value: "test" | "live".)
  @type environment :: String.t()

  @typedoc """
  Invoice status wire value: `"queued" | "processing" | "authorized" |
  "rejected" | "retry_pending" | "reconciliation_required" |
  "manual_review" | "failed" | "cancelling" | "cancelled"`.

  `"cancelling"` means the cancellation event is being processed at the Sefin;
  `"cancelled"` means the invoice is cancelled (`cancelledAt` is set). When the
  Sefin rejects a cancellation the invoice goes back to `"authorized"` with
  `lastErrorCode`/`lastErrorMessage` set.
  """
  @type status :: String.t()

  @typedoc """
  Cancellation reason for `CorvoNfse.Resources.Invoices.cancel/3`:
  `:issue_error | :service_not_provided | :other`, or the same values as
  strings. Responses carry it as a string in `"cancellationReason"`.
  """
  @type cancellation_reason :: :issue_error | :service_not_provided | :other | String.t()

  @typedoc """
  Params for `CorvoNfse.Resources.Invoices.cancel/3` (atom or string keys,
  sent unchanged):

    * `reason` (required) - a `t:cancellation_reason/0`
    * `description` (optional) - up to 255 characters; the API requires 15 to
      255 characters to cancel an `authorized` or `processing` invoice and
      accepts none for a `queued` one
  """
  @type cancel_params ::
          %{
            required(:reason) => cancellation_reason(),
            optional(:description) => String.t()
          }
          | %{required(String.t()) => String.t()}

  @typedoc ~S(Stage wire value: "pending" | "authorized" | "documents_ready" | "completed" | "failed".)
  @type stage :: String.t()

  @type download_format :: :pdf | :xml | String.t()

  defstruct [
    :id,
    :companyId,
    :tenantId,
    :environment,
    :documentKeyVersion,
    :emailSnapshot,
    :externalId,
    :idempotencyKey,
    :status,
    :customerSnapshot,
    :serviceSnapshot,
    :taxSnapshot,
    :amount,
    :currency,
    :competenceDate,
    :dpsId,
    :dpsSeries,
    :dpsNumber,
    :accessKey,
    :nfseNumber,
    :fiscalProvider,
    :fiscalSchemaVersion,
    :issuedAt,
    :authorizedAt,
    :lastErrorCode,
    :lastErrorMessage,
    :lastErrorProvider,
    :documentsReadyAt,
    :lastEmailStatus,
    :lastEmailSentAt,
    :createdAt,
    :updatedAt,
    :documentsStatus,
    :emailStatus,
    :stage,
    :scheduledFor,
    :cancellationReason,
    :cancellationDescription,
    :cancelledAt,
    :cancellationRequestedAt
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          companyId: String.t(),
          tenantId: String.t(),
          environment: environment(),
          documentKeyVersion: integer(),
          emailSnapshot: map(),
          externalId: String.t() | nil,
          idempotencyKey: String.t() | nil,
          status: status(),
          customerSnapshot: map(),
          serviceSnapshot: map(),
          taxSnapshot: map(),
          amount: number(),
          currency: String.t(),
          competenceDate: String.t(),
          dpsId: String.t() | nil,
          dpsSeries: String.t() | nil,
          dpsNumber: integer() | nil,
          accessKey: String.t() | nil,
          nfseNumber: integer() | nil,
          fiscalProvider: String.t() | nil,
          fiscalSchemaVersion: String.t() | nil,
          issuedAt: String.t() | nil,
          authorizedAt: String.t() | nil,
          lastErrorCode: String.t() | nil,
          lastErrorMessage: String.t() | nil,
          lastErrorProvider: String.t() | nil,
          documentsReadyAt: String.t() | nil,
          lastEmailStatus: String.t() | nil,
          lastEmailSentAt: String.t() | nil,
          createdAt: String.t(),
          updatedAt: String.t(),
          documentsStatus: String.t(),
          emailStatus: String.t() | nil,
          stage: stage(),
          scheduledFor: String.t() | nil,
          cancellationReason: String.t() | nil,
          cancellationDescription: String.t() | nil,
          cancelledAt: String.t() | nil,
          cancellationRequestedAt: String.t() | nil
        }

  @typedoc """
  Params for `CorvoNfse.Resources.Invoices.create/3` and `calculate/2`
  (camelCase wire keys, passed through unchanged):

    * `companyId` or `companyTaxId` (CNPJ) - the issuing company
    * `service` (required) - `%{code?:, municipalityCode?:, description?:}`;
      `code` (6 digits) defaults to the company's, then to `100901`
    * `amount` (required) - BRL, positive, up to 2 decimal places
    * `competenceDate` (required) - `YYYY-MM-DD`
    * `customer` (optional) - `%{taxId:, name?:, email?:, address?:}`; when
      sent, `taxId` (CPF or CNPJ) is required
    * `discount` (optional) - unconditional discount, from 0 up to `amount`
    * `email` (optional) - boolean; `options.email.send` wins when set
    * `options` (optional) - `%{email?: %{send: boolean}, type?: "IMMEDIATE" | "SCHEDULE"}`
    * `externalId` (optional)
  """
  @type create_params :: map()

  @typedoc "Customer input for `create_params`."
  @type customer_input :: map()

  @typedoc "Raw download body returned by `pdf/2` and `xml/2`."
  @type download :: %{
          body: binary(),
          mime_type: String.t() | nil,
          file_name: String.t() | nil
        }

  @typedoc "A single entry of `Invoices.events/3`."
  @type event :: map()
end
