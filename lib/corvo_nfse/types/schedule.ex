defmodule CorvoNfse.Types.Schedule do
  @moduledoc """
  Wire shape of a schedule (`snake_case`), returned by `Schedules.*` and by
  `Invoices.create/3` when `options.type` is `SCHEDULE` or `RECURRING`.
  """

  defstruct [
    :id,
    :company_id,
    :kind,
    :status,
    :frequency,
    :anchor_on,
    :ends_on,
    :next_run_on,
    :last_run_on,
    :attempts,
    :pause_reason,
    :invoice,
    :created_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          company_id: String.t(),
          # "once" | "recurring"
          kind: String.t(),
          # "active" | "paused" | "completed" | "cancelled"
          status: String.t(),
          # "WEEKLY" | "BIWEEKLY" | "MONTHLY"
          frequency: String.t(),
          anchor_on: String.t(),
          ends_on: String.t() | nil,
          next_run_on: String.t() | nil,
          last_run_on: String.t() | nil,
          attempts: integer(),
          # "customer" | "failures" (meaningful when paused)
          pause_reason: String.t() | nil,
          invoice: map(),
          created_at: String.t()
        }

  defmodule Run do
    @moduledoc "Wire shape of an entry of `Schedules.list_runs/3`."

    defstruct [
      :id,
      :occurrence_on,
      :ran_on,
      :attempt,
      :outcome,
      :invoice_id,
      :error_code,
      :error_message,
      :created_at
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            occurrence_on: String.t(),
            ran_on: String.t(),
            attempt: integer(),
            # "issued" | "failed"
            outcome: String.t(),
            invoice_id: String.t() | nil,
            error_code: String.t() | nil,
            error_message: String.t() | nil,
            created_at: String.t()
          }
  end
end
