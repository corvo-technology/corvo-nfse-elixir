defmodule CorvoNfse.WebhooksResourceTest do
  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Resources.Webhooks
  alias CorvoNfse.Resources.Webhooks.Deliveries

  setup :verify_on_exit!

  @base "http://localhost:4000/v1"

  test "create posts url and events" do
    expect_request(
      json_response(%{"data" => %{"id" => "wh_1", "url" => "https://x.test/hook", "secret" => "whsec_1"}})
    )

    params = %{url: "https://x.test/hook", events: ["nfse.invoice.authorized"]}

    assert {:ok, %{"id" => "wh_1", "secret" => "whsec_1"}} = Webhooks.create(client(), params)

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/webhooks"
    assert Jason.decode!(request.body) == %{"url" => "https://x.test/hook", "events" => ["nfse.invoice.authorized"]}
  end

  test "list, remove and test address the webhook paths" do
    expect_request(json_response(%{"data" => [], "pagination" => nil}))
    assert {:ok, %{data: []}} = Webhooks.list(client(), limit: 5)
    request = assert_request()
    assert request.url == @base <> "/webhooks?limit=5"

    expect_request(json_response(%{"data" => %{"deleted" => true}}))
    assert {:ok, %{"deleted" => true}} = Webhooks.remove(client(), "wh_1")
    request = assert_request()
    assert request.method == :delete
    assert request.url == @base <> "/webhooks/wh_1"

    expect_request(json_response(%{"data" => %{"sent" => true}}))
    assert {:ok, %{"sent" => true}} = Webhooks.test(client(), "wh_1")
    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/webhooks/wh_1/test"
  end

  test "deliveries list passes hours, environment, limit and cursor" do
    expect_request(json_response(%{"data" => [], "pagination" => nil}))

    assert {:ok, %{data: []}} =
             Deliveries.list(client(), hours: 24, environment: "test", limit: 10)

    request = assert_request()
    assert request.url ==
             @base <> "/webhooks/deliveries?hours=24&environment=test&limit=10"
  end

  test "deliveries stats reads the stats endpoint" do
    expect_request(
      json_response(%{"data" => %{"total" => 3, "sent" => 2, "failed" => 1, "pending" => 0, "delayed" => 0}})
    )

    assert {:ok, %{"total" => 3}} = Deliveries.stats(client(), hours: 6, environment: "live")

    request = assert_request()
    assert request.url == @base <> "/webhooks/deliveries/stats?hours=6&environment=live"
  end

  test "deliveries retry posts to the retry path" do
    expect_request(json_response(%{"data" => %{"retried" => true}}))

    assert {:ok, %{"retried" => true}} = Deliveries.retry(client(), "del_1")

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/webhooks/deliveries/del_1/retry"
  end

  test "deliveries iterate walks every page" do
    expect_requests([
      json_response(%{
        "data" => [%{"id" => "del_1"}],
        "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "Y3VyMg"}
      }),
      json_response(%{
        "data" => [%{"id" => "del_2"}],
        "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
      })
    ])

    assert {:ok, stream} = Deliveries.iterate(client(), hours: 24, limit: 1)
    assert Enum.to_list(stream) == [%{"id" => "del_1"}, %{"id" => "del_2"}]

    [_first, second] = pop_requests()
    assert second.url == @base <> "/webhooks/deliveries?hours=24&limit=1&cursor=Y3VyMg"
  end
end
