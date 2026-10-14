defmodule CorvoNfse.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: CorvoNfse.Finch, pools: %{default: [size: 16, count: 4]}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CorvoNfse.Supervisor)
  end
end
