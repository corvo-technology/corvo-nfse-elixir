defmodule CorvoNfse.Types.Credits do
  @moduledoc """
  Wire shapes of the credit balance, purchasable plans and the credit ledger.

  Responses come back as plain maps with these string keys.
  """

  defmodule Balance do
    @moduledoc "Wire shape of `GET /credits`."

    defstruct [:balance, :planRemaining, :avulsoBalance, :hardLimit]

    @typedoc """
    `balance` is `planRemaining` (plan notes left, 0 for a lapsed plan) plus
    `avulsoBalance` (loose notes bought separately).
    """
    @type t :: %__MODULE__{
            balance: integer(),
            planRemaining: integer(),
            avulsoBalance: integer(),
            hardLimit: integer()
          }
  end

  defmodule Plan do
    @moduledoc "Wire shape of an entry of `GET /credits/plans`."

    defstruct [
      :id,
      :slug,
      :name,
      :description,
      :monthlyCreditAllowance,
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
            monthlyCreditAllowance: integer(),
            dailyLimit: integer() | nil,
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
    @moduledoc """
    Wire shape of an entry of `GET /credits/history`. `amount` is in credits
    (not BRL); fields ending in `Cents` are in centavos.
    """

    defstruct [
      :id,
      :tenantId,
      :type,
      :amount,
      :description,
      :source,
      :amountBrlCents,
      :unitPriceCentsApplied,
      :planIdSnapshot,
      :reservedInvoiceId,
      :periodId,
      :isReservation,
      :relatedTransactionId,
      :createdAt
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            tenantId: String.t(),
            type: String.t(),
            amount: number(),
            description: String.t() | nil,
            source: String.t() | nil,
            amountBrlCents: integer() | nil,
            unitPriceCentsApplied: integer() | nil,
            planIdSnapshot: String.t() | nil,
            reservedInvoiceId: String.t() | nil,
            periodId: String.t() | nil,
            isReservation: boolean() | nil,
            relatedTransactionId: String.t() | nil,
            createdAt: String.t()
          }
  end

  defmodule PlanQuote do
    @moduledoc "Wire shape of an entry of the public catalog (`GET /plans`); prices in centavos."

    defstruct [
      :slug,
      :name,
      :monthlyAllowance,
      :basePriceCents,
      :perCreditOverageCents,
      :monthlyTotalCents,
      :currency
    ]

    @type t :: %__MODULE__{
            slug: String.t(),
            name: String.t(),
            monthlyAllowance: integer(),
            basePriceCents: integer(),
            perCreditOverageCents: integer(),
            monthlyTotalCents: integer(),
            currency: String.t()
          }
  end

  defmodule PurchasePreview do
    @moduledoc "Wire shape of `GET /credits/purchase/preview`."

    defstruct [:units, :unitPriceCents, :totalCents]

    @type t :: %__MODULE__{units: integer(), unitPriceCents: integer(), totalCents: integer()}
  end

  @type purchase_preview :: PurchasePreview.t()
  @type balance :: Balance.t()
  @type plan :: Plan.t()
  @type transaction :: Transaction.t()
  @type plan_quote :: PlanQuote.t()
end
