defmodule CorvoNfse.Resources.Schedules do
  @moduledoc """
  Scheduled and recurring invoices (`/v1/schedules`).

  A schedule is created by `CorvoNfse.Resources.Invoices.create/3` with
  `"options" => %{"type" => "SCHEDULE"}` or `"RECURRING"`. Schedules are
  answered in `snake_case`; the pagination cursor is an offset, pass it back
  untouched.
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.Common

  @type list_option ::
          {:status, String.t()}
          | {:company_id, String.t()}
          | {:limit, pos_integer()}
          | {:cursor, String.t()}

  @type page_option :: {:limit, pos_integer()} | {:cursor, String.t()}

  @doc "Lists schedules (`GET /v1/schedules`); `status:` is `active`, `paused`, `completed` or `cancelled`."
  @spec list(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def list(client, opts \\ []) do
    Transport.list(client, "/schedules", list_query(opts), :raw)
  end

  @doc "Lazily iterates every schedule across pages."
  @spec iterate(Client.t(), [list_option()]) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate(client, opts \\ []) do
    Transport.paginate(client, "/schedules", list_query(opts), :raw)
  end

  @doc "Reads a schedule."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, id), do: Transport.request(client, :get, path(id))

  @doc """
  Changes a schedule; applies to the next runs only. Params: `"frequency"`,
  `"anchorOn"`, `"endsOn"` (nil clears it) and `"invoice"`.
  """
  @spec update(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, id, params) when is_map(params) do
    Transport.request(client, :patch, path(id), json: params)
  end

  @doc "Pauses a schedule."
  @spec pause(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def pause(client, id), do: Transport.request(client, :post, path(id) <> "/pause")

  @doc "Resumes a paused schedule at its next occurrence."
  @spec resume(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def resume(client, id), do: Transport.request(client, :post, path(id) <> "/resume")

  @doc "Cancels a schedule (final)."
  @spec cancel(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def cancel(client, id), do: Transport.request(client, :post, path(id) <> "/cancel")

  @doc "Log of every attempt to run a schedule, newest first."
  @spec list_runs(Client.t(), String.t(), [page_option()]) ::
          {:ok, Common.page()} | {:error, Error.t()}
  def list_runs(client, id, opts \\ []) do
    Transport.list(client, path(id) <> "/runs", page_query(opts), :raw)
  end

  @doc "Lazily iterates every run of a schedule."
  @spec iterate_runs(Client.t(), String.t(), [page_option()]) ::
          {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate_runs(client, id, opts \\ []) do
    Transport.paginate(client, path(id) <> "/runs", page_query(opts), :raw)
  end

  defp path(id), do: "/schedules/#{Transport.segment(id)}"

  defp page_query(opts),
    do: [limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)]

  defp list_query(opts) do
    [
      status: Keyword.get(opts, :status),
      companyId: Keyword.get(opts, :company_id),
      limit: Keyword.get(opts, :limit),
      cursor: Keyword.get(opts, :cursor)
    ]
  end
end
