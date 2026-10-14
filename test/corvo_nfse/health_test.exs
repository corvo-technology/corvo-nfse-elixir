defmodule CorvoNfse.HealthTest do
  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Resources.Health

  setup :verify_on_exit!

  @base "http://localhost:4000/v1"

  test "live and ready are public and return the raw (unwrapped) body" do
    expect_request(json_response(%{"status" => "ok"}))
    assert {:ok, %{"status" => "ok"}} = Health.live(client())
    request = assert_request()
    assert request.method == :get
    assert request.url == @base <> "/health/live"
    assert {"x-api-key", api_key()} in request.headers

    expect_request(json_response(%{"status" => "ready"}))
    assert {:ok, %{"status" => "ready"}} = Health.ready(client())
    request = assert_request()
    assert request.url == @base <> "/health/ready"
  end

  test "a failing readiness probe surfaces as {:error, ...}" do
    expect_request(json_response(%{"status" => "down"}, status: 503))

    assert {:error, error} = Health.ready(client())
    assert error.status == 503
    assert error.code == "http_503"
  end
end
