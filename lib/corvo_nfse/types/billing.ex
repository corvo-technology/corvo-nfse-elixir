defmodule CorvoNfse.Types.Billing do
  @moduledoc """
  Wire shapes of the billing plan (snake_case fields, nested `plan`,
  `subscription` and `usage` objects - exactly as the server sends them) and
  the camelCase quota status.
  """

  defmodule PlanResponse do
    @moduledoc "Wire shape of `GET /billing/plan` (nested snake_case objects)."

    defstruct [:plan, :subscription, :usage]

    @type t :: %__MODULE__{
            plan: %{
              required("slug") => String.t(),
              required("name") => String.t(),
              required("monthly_allowance") => integer(),
              required("daily_limit") => integer() | nil,
              required("max_active_companies") => integer(),
              required("monthly_price_cents") => integer()
            },
            subscription: %{
              required("status") => String.t(),
              required("paid_until") => String.t() | nil,
              required("cancel_at_period_end") => boolean(),
              required("scheduled_plan") => String.t() | nil,
              required("blocked") => boolean()
            },
            usage: %{
              required("overage_units") => integer(),
              required("overage_amount_cents") => integer(),
              required("hard_limit") => integer() | nil,
              required("credits_used") => integer(),
              required("credits_reserved") => integer(),
              required("credits_remaining") => integer(),
              required("monthly_allowance") => integer(),
              required("daily_usage") => integer(),
              required("daily_limit") => integer() | nil,
              required("active_companies") => integer(),
              required("max_active_companies") => integer(),
              required("period_start") => String.t() | nil,
              required("period_end") => String.t() | nil
            }
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
      :periodEnd
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
            periodEnd: String.t() | nil
          }
  end

  @type plan_response :: PlanResponse.t()
  @type quota_status :: QuotaStatus.t()
end
