defmodule CorvoNfse.TestHelpers do
  @moduledoc """
  Shared helpers: a client wired to the `CorvoNfse.MockHTTP` adapter, canned
  responses and request capture.

  The transport never raises out of the adapter, so tests capture requests via
  messages instead of asserting inside the mock.
  """

  import ExUnit.Assertions, only: [flunk: 1]

  @base_url "http://localhost:4000"

  @spec api_key() :: String.t()
  def api_key, do: "corvo_test_" <> String.duplicate("a", 40)

  @spec base_url() :: String.t()
  def base_url, do: @base_url

  @doc "A client with test credentials pointed at a local base URL."
  @spec client(keyword()) :: CorvoNfse.Client.t()
  def client(opts \\ []) do
    CorvoNfse.new(
      Keyword.merge(
        [
          api_key: api_key(),
          base_url: @base_url,
          allow_insecure_http: true,
          http: CorvoNfse.MockHTTP
        ],
        opts
      )
    )
  end

  @doc "Queues one adapter reply and captures the outgoing request."
  @spec expect_request({:ok, map()} | {:error, term()}) :: :ok
  def expect_request(response) do
    expect_fun(fn _request -> response end)
  end

  @doc "Queues a sequence of adapter replies, capturing each request."
  @spec expect_requests([{:ok, map()} | {:error, term()}]) :: :ok
  def expect_requests(responses) when is_list(responses) do
    test_pid = self()

    Enum.each(responses, fn response ->
      Mox.expect(CorvoNfse.MockHTTP, :send, fn request ->
        send(test_pid, {:corvo_request, request})
        response
      end)
    end)
  end

  @doc "Queues a raw adapter function (e.g. to raise or return an error)."
  @spec expect_fun((map() -> {:ok, map()} | {:error, term()})) :: :ok
  def expect_fun(fun) when is_function(fun, 1) do
    test_pid = self()

    Mox.expect(CorvoNfse.MockHTTP, :send, fn request ->
      send(test_pid, {:corvo_request, request})
      fun.(request)
    end)
  end

  @doc "A successful JSON response."
  @spec json_response(term(), keyword()) :: {:ok, map()}
  def json_response(body, opts \\ []) do
    {:ok,
     %{
       status: Keyword.get(opts, :status, 200),
       headers: Keyword.get(opts, :headers, [{"content-type", "application/json"}]),
       body: Jason.encode!(body)
     }}
  end

  @doc "A response with no body (204 by default)."
  @spec empty_response(integer()) :: {:ok, map()}
  def empty_response(status \\ 204) do
    {:ok, %{status: status, headers: [], body: ""}}
  end

  @doc "Returns every request captured so far, in order."
  @spec pop_requests() :: [map()]
  def pop_requests do
    receive do
      {:corvo_request, request} -> [request | pop_requests()]
    after
      0 -> []
    end
  end

  @doc "Returns the single captured request, failing the test when absent."
  @spec assert_request() :: map()
  def assert_request do
    case pop_requests() do
      [request | _rest] -> request
      [] -> flunk("expected an HTTP request to have been captured")
    end
  end

  @doc "Fails the test when a request was captured."
  @spec assert_no_request() :: :ok
  def assert_no_request do
    case pop_requests() do
      [] -> :ok
      requests -> flunk("expected no HTTP request, got #{length(requests)}")
    end
  end
end
