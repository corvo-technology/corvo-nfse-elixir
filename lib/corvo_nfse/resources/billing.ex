defmodule CorvoNfse.Resources.Billing do
  @moduledoc """
  Billing plan and quota usage (`/v1/billing`).
  """

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Reads the current plan, subscription and usage (`GET /v1/billing/plan`)."
  @spec plan(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def plan(client) do
    Transport.request(client, :get, "/billing/plan")
  end

  @doc "Reads the quota status used for emission gating (`GET /v1/billing/usage`)."
  @spec usage(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def usage(client) do
    Transport.request(client, :get, "/billing/usage")
  end
end
