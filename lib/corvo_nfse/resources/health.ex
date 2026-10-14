defmodule CorvoNfse.Resources.Health do
  @moduledoc """
  The two public (no API key scope required) health checks.

  These return the raw response body (`unwrap: :none`), since the health
  endpoints do not use the `{data: ...}` envelope.
  """

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Liveness probe (`GET /v1/health/live`)."
  @spec live(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def live(client) do
    Transport.request(client, :get, "/health/live", unwrap: :none)
  end

  @doc "Readiness probe (`GET /v1/health/ready`)."
  @spec ready(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def ready(client) do
    Transport.request(client, :get, "/health/ready", unwrap: :none)
  end
end
