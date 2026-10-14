defmodule CorvoNfse.Types.Credits do
  @moduledoc """
  Wire shapes of the credit balance, purchasable plans and the credit ledger.

  Plans and history entries are serialized as `{props: {...}}` inside the
  `data` envelope; the SDK unwraps both layers.
  """

  defmodule Balance do
    @moduledoc "Wire shape of `GET /credits`."

    defstruct [:tenantId, :balance, :overageUnits, :overageAmountCents, :hardLimit]

    @type t :: %__MODULE__{
            tenantId: String.t(),
            balance: integer(),
            overageUnits: integer(),
            overageAmountCents: integer(),
            hardLimit: integer() | nil
          }
  end

  defmodule Plan do
    @moduledoc "Wire shape of an entry of `GET /credits/plans`."

    defstruct [
      :id,
      :slug,
      :name,
      :description,
      :dailyLimit,
      :maxActiveCompanies,
      :creditUnitPriceCents,
      :throughputRps,
      :includesWebhooks,
      :includesXmlDownload,
      :includesPdfDownload,
      :includesApiKeys,
      :supportTier,
      :active,
      :createdAt,
      :updatedAt
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            slug: String.t(),
            name: String.t(),
            description: String.t(),
            dailyLimit: integer(),
            maxActiveCompanies: integer(),
            creditUnitPriceCents: integer(),
            throughputRps: integer(),
            includesWebhooks: boolean(),
            includesXmlDownload: boolean(),
            includesPdfDownload: boolean(),
            includesApiKeys: boolean(),
            supportTier: String.t(),
            active: boolean(),
            createdAt: String.t(),
            updatedAt: String.t()
          }
  end

  defmodule Transaction do
    @moduledoc "Wire shape of an entry of `GET /credits/history`."

    defstruct [
      :id,
      :type,
      :amount,
      :creditDelta,
      :balanceAfter,
      :environment,
      :source,
      :referenceType,
      :referenceId,
      :createdAt
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            type: String.t(),
            amount: integer(),
            creditDelta: integer(),
            balanceAfter: integer(),
            environment: CorvoNfse.Types.Common.environment(),
            source: String.t(),
            referenceType: String.t() | nil,
            referenceId: String.t() | nil,
            createdAt: String.t()
          }
  end

  @type balance :: Balance.t()
  @type plan :: Plan.t()
  @type transaction :: Transaction.t()
end
