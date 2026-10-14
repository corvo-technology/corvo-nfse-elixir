defmodule CorvoNfse.ClientTest do
  use ExUnit.Case, async: false

  alias CorvoNfse.Client

  @env_vars ~w(CORVO_API_KEY CORVO_BASE_URL CORVO_API_PREFIX)

  setup do
    saved = Map.new(@env_vars, fn name -> {name, System.get_env(name)} end)
    Enum.each(saved, fn {name, _value} -> System.delete_env(name) end)

    on_exit(fn ->
      Enum.each(saved, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    :ok
  end

  test "requires an api key" do
    assert_raise ArgumentError, ~r/api_key is required/, fn -> Client.new([]) end
  end

  test "reads the api key from CORVO_API_KEY" do
    System.put_env("CORVO_API_KEY", "corvo_test_env")

    assert %Client{api_key: "corvo_test_env"} = Client.new([])
  end

  test "explicit options win over the environment" do
    System.put_env("CORVO_API_KEY", "corvo_test_env")
    System.put_env("CORVO_BASE_URL", "https://env.example.com")

    client = Client.new(api_key: "corvo_test_opt", base_url: "https://opt.example.com/")

    assert client.api_key == "corvo_test_opt"
    assert client.base_url == "https://opt.example.com"
  end

  test "defaults to the public base URL and the v1 prefix" do
    client = Client.new(api_key: "corvo_test_a")

    assert client.base_url == "https://api.corvo.tech"
    assert client.prefix == "v1"
    assert client.receive_timeout == 30_000
    assert client.allow_insecure_http == false
    assert client.finch == CorvoNfse.Finch
    assert client.http == CorvoNfse.HTTP.Finch
  end

  test "reads base URL from CORVO_BASE_URL and trims trailing slashes" do
    System.put_env("CORVO_BASE_URL", "https://env.example.com///")

    assert %Client{base_url: "https://env.example.com"} = Client.new(api_key: "corvo_test_a")
  end

  test "trims surrounding slashes from a custom prefix" do
    client = Client.new(api_key: "corvo_test_a", prefix: "/api/v1/")
    assert client.prefix == "api/v1"

    client = Client.new(api_key: "corvo_test_a", prefix: "")
    assert client.prefix == ""
  end

  test "rejects plain http:// for public hosts unless allowed" do
    message = ~r/http:\/\/ is only allowed for loopback\/private hosts/

    assert_raise ArgumentError, message, fn ->
      Client.new(api_key: "corvo_test_a", base_url: "http://api.example.com")
    end

    assert %Client{} =
             Client.new(
               api_key: "corvo_test_a",
               base_url: "http://api.example.com",
               allow_insecure_http: true
             )
  end

  test "allows http:// for loopback and private hosts" do
    for host <- [
          "http://localhost:4000",
          "http://127.0.0.1:4000",
          "http://10.1.2.3",
          "http://192.168.1.7",
          "http://172.16.0.9",
          "http://169.254.1.1",
          "http://0.0.0.0",
          "http://[::1]:4000",
          "http://box.localhost"
        ] do
      assert %Client{} = Client.new(api_key: "corvo_test_a", base_url: host),
             "expected #{host} to be accepted"
    end
  end

  test "rejects an invalid base URL" do
    assert_raise ArgumentError, ~r/invalid base_url/, fn ->
      Client.new(api_key: "corvo_test_a", base_url: "not a url")
    end
  end

  test "receive_timeout must be a positive integer" do
    assert %Client{receive_timeout: 5_000} =
             Client.new(api_key: "corvo_test_a", receive_timeout: 5_000)

    assert_raise ArgumentError, ~r/receive_timeout/, fn ->
      Client.new(api_key: "corvo_test_a", receive_timeout: 0)
    end
  end
end
