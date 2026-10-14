defmodule CorvoNfse.Types.Webhook do
  @moduledoc """
  Wire shapes of webhook configs, deliveries and delivery stats, plus the
  canonical list of webhook events.
  """

  @events [
    "nfse.invoice.authorized",
    "nfse.invoice.rejected",
    "nfse.invoice.failed",
    "nfse.invoice.reconciliation_required",
    "nfse.invoice.manual_review",
    "nfse.invoice.documents_ready",
    "nfse.invoice.email_sent",
    "nfse.invoice.email_failed",
    "webhook.test"
  ]

  @typedoc """
  Webhook event wire value - one of the canonical 9 events from `events/0`:
  `nfse.invoice.authorized`, `nfse.invoice.rejected`, `nfse.invoice.failed`,
  `nfse.invoice.reconciliation_required`, `nfse.invoice.manual_review`,
  `nfse.invoice.documents_ready`, `nfse.invoice.email_sent`,
  `nfse.invoice.email_failed`, `webhook.test`.
  """
  @type event :: String.t()

  @typedoc ~S(Environment wire value: "test" | "live".)
  @type environment :: String.t()

  @doc "The canonical 9 webhook events."
  @spec events() :: [String.t()]
  def events, do: @events

  defstruct [:id, :url, :events, :active, :createdAt, :updatedAt]

  @type t :: %__MODULE__{
          id: String.t(),
          url: String.t(),
          events: [String.t()],
          active: boolean(),
          createdAt: String.t(),
          updatedAt: String.t()
        }

  @typedoc """
  A webhook config including its signing secret - returned only by
  `CorvoNfse.Resources.Webhooks.create/2`.
  """
  @type with_secret :: map()

  @typedoc "Params for `CorvoNfse.Resources.Webhooks.create/2`: `%{url:, events:}`."
  @type create_params :: map()

  @typedoc """
  Stats returned by `Deliveries.stats/2`: a plain JSON string-keyed map of
  integers under the keys `total`, `sent`, `failed`, `pending`, `delayed`.
  """
  @type delivery_stats :: %{optional(String.t()) => term()}

  defmodule Delivery do
    @moduledoc "Wire shape of a webhook delivery attempt."

    defstruct [
      :id,
      :tenantId,
      :webhookConfigId,
      :eventType,
      :environment,
      :url,
      :payload,
      :statusCode,
      :responseBody,
      :errorMessage,
      :status,
      :durationMs,
      :retryCount,
      :nextRetryAt,
      :lastError,
      :createdAt
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            tenantId: String.t(),
            webhookConfigId: String.t(),
            eventType: String.t(),
            environment: CorvoNfse.Types.Webhook.environment(),
            url: String.t(),
            payload: map(),
            statusCode: integer() | nil,
            responseBody: term(),
            errorMessage: String.t() | nil,
            status: String.t(),
            durationMs: integer() | nil,
            retryCount: integer(),
            nextRetryAt: String.t() | nil,
            lastError: String.t() | nil,
            createdAt: String.t()
          }
  end

  @type delivery :: Delivery.t()
end
