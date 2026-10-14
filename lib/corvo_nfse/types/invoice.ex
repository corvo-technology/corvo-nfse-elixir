defmodule CorvoNfse.Types.Invoice do
  @moduledoc """
  Wire shape of an NFS-e invoice.

  Invoice endpoints serialize entities as `{props: {...}}` inside the `data`
  envelope; the SDK unwraps both layers and returns the invoice as a plain map
  with these string keys.
  """

  @type environment :: "test" | "live"

  @type status ::
          "queued"
          | "processing"
          | "authorized"
          | "rejected"
          | "retry_pending"
          | "reconciliation_required"
          | "manual_review"
          | "failed"

  @type stage :: "pending" | "authorized" | "documents_ready" | "completed" | "failed"

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
    :lastErrorAt,
    :retryCount,
    :nextRetryAt,
    :stage,
    :createdAt,
    :updatedAt
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
          lastErrorAt: String.t() | nil,
          retryCount: integer(),
          nextRetryAt: String.t() | nil,
          stage: stage() | nil,
          createdAt: String.t(),
          updatedAt: String.t()
        }

  @typedoc """
  Params for `CorvoNfse.Resources.Invoices.create/3` (camelCase wire keys,
  passed through unchanged):

    * `customer` (required) - `%{name:, taxId:, email?:, address?:}`
    * `service` (required) - `%{code:, municipalityCode?:, description?:}`
    * `amount` (required) - number
    * `competenceDate` (required) - `YYYY-MM-DD`
    * `companyId`, `companyTaxId`, `externalId`, `correlationId`, `email`,
      `options` (optional)
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
