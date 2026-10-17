defmodule CorvoNfse.Types.Billing do
  @moduledoc """
  Wire shapes of the billing plan (snake_case fields, nested `plan`,
  `subscription` and `usage` objects - exactly as the server sends them) and
  the camelCase quota status.
  """

  defmodule PlanResponse do
    @moduledoc "Wire shape of `GET /billing/plan` (nested snake_case objects)."

    defstruct [:plan, :subscription, :usage]

    @typedoc """
    Wire shape of `GET /billing/plan`. `plan`, `subscription` and `usage` are
    plain JSON snake_case string-keyed objects:

      * `plan` - `slug`, `name`, `monthly_allowance`, `daily_limit`,
        `max_active_companies`, `monthly_price_cents`
      * `subscription` - `status`, `paid_until`, `cancel_at_period_end`,
        `scheduled_plan`, `blocked`
      * `usage` - `overage_units`, `overage_amount_cents`, `hard_limit`,
        `credits_used`, `credits_reserved`, `credits_remaining`,
        `monthly_allowance`, `daily_usage`, `daily_limit`,
        `active_companies`, `max_active_companies`, `period_start`,
        `period_end`
    """
    @type t :: %__MODULE__{
            plan: %{optional(String.t()) => term()},
            subscription: %{optional(String.t()) => term()},
            usage: %{optional(String.t()) => term()}
          }
  end

  defmodule QuotaStatus do
    @moduledoc "Wire shape of `GET /billing/usage` (camelCase)."

    defstruct [
      :canEmit,
      :creditsRemaining,
      :creditsUsed,
      :creditsReserved,
      :monthlyAllowance,
      :dailyUsage,
      :dailyLimit,
      :activeCompanies,
      :maxActiveCompanies,
      :periodStart,
      :periodEnd,
      :reason
    ]

    @type t :: %__MODULE__{
            canEmit: boolean(),
            creditsRemaining: integer(),
            creditsUsed: integer(),
            creditsReserved: integer(),
            monthlyAllowance: integer(),
            dailyUsage: integer(),
            dailyLimit: integer() | nil,
            activeCompanies: integer(),
            maxActiveCompanies: integer(),
            periodStart: String.t() | nil,
            periodEnd: String.t() | nil,
            # set when canEmit is false: no_credits, daily_limit_exceeded,
            # company_limit_exceeded or plan_blocked
            reason: String.t() | nil
          }
  end

  @type plan_response :: PlanResponse.t()
  @type quota_status :: QuotaStatus.t()
end
