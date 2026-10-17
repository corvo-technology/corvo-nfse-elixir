defmodule CorvoNfse.Resources.Plans do
  @moduledoc """
  The public price catalog (monthly cycle only). Values are in centavos.

      CorvoNfse.Resources.Plans.list(client)
      CorvoNfse.Resources.Plans.quote(client, 20_000)
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.Common

  @type list_option :: {:limit, pos_integer()} | {:cursor, String.t()}

  @doc "Lists plan prices, from the smallest to the largest allowance (`GET /v1/plans`)."
  @spec list(Client.t(), [list_option()]) :: {:ok, Common.page()} | {:error, Error.t()}
  def list(client, opts \\ []) do
    Transport.list(
      client,
      "/plans",
      [limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)],
      :raw
    )
  end

  @doc """
  Reads the price of one plan (`GET /v1/plans/:slug`): `"free"`, `"developer"`,
  `"growth"`, `"scale"` or `"volume"`.
  """
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, slug) do
    Transport.request(client, :get, "/plans/#{Transport.segment(slug)}")
  end

  @doc """
  Recommends the plan for `volume` invoices per month (`GET /v1/plans/quote`).

  `{:ok, nil}` when the volume is missing or not positive. The keys of the
  recommendation are snake_case (`"recommended_plan"`, `"total_estimated_cents"`).
  """
  @spec quote(Client.t(), non_neg_integer()) :: {:ok, map() | nil} | {:error, Error.t()}
  def quote(client, volume) do
    Transport.request(client, :get, "/plans/quote", query: [volume: volume])
  end
end
