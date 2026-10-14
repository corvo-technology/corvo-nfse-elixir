defmodule CorvoNfse.ContractTest do
  @moduledoc """
  Contract test against a live Corvo instance.

  Runs only when both `CORVO_API_KEY` and `CORVO_BASE_URL` are set; otherwise
  it is excluded (see `test/test_helper.exs`) and reported as excluded.
  """

  use ExUnit.Case, async: false

  @moduletag :contract

  test "reads health and a company page" do
    client = CorvoNfse.new([])

    assert {:ok, %{"status" => "ok"}} = CorvoNfse.Resources.Health.live(client)

    assert {:ok, page} = CorvoNfse.Resources.Companies.list(client, limit: 1)
    assert page.pagination["limit"] == 1
    assert is_list(page.data)
  end
end
