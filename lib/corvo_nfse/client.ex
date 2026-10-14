defmodule CorvoNfse.Client do
  @moduledoc """
  Configuration for a Corvo NFS-e API connection.

  Build one with `CorvoNfse.new/1` (or `%CorvoNfse.Client{}` directly) and pass
  it as the first argument to every resource function.

      client = CorvoNfse.new(api_key: "corvo_test_...")
      CorvoNfse.Resources.Health.live(client)

  ## Options

    * `:api_key` - required unless `CORVO_API_KEY` is set. Sent as the
      `X-API-Key` header (never `Authorization: Bearer`).
    * `:base_url` - defaults to `CORVO_BASE_URL`, then to the public
      `https://api.corvo.tech`. Trailing slashes are stripped. Plain `http://`
      is only accepted for loopback/private hosts unless
      `allow_insecure_http: true`.
    * `:prefix` - API prefix segment, defaults to `CORVO_API_PREFIX` or
      `"v1"`. Pass `""` for installs without a prefix. Surrounding slashes
      are trimmed.
    * `:receive_timeout` - per-request receive timeout in milliseconds,
      defaults to 30_000.
    * `:allow_insecure_http` - allow `http://` for public hosts (default
      `false`).
    * `:finch` - Finch pool name, defaults to `CorvoNfse.Finch` (started with
      the application).
    * `:http` - HTTP adapter module, defaults to `CorvoNfse.HTTP.Finch`.

  Construction problems (missing API key, invalid base URL) raise
  `ArgumentError`; API, network and timeout failures are never raised - they
  come back as `{:error, %CorvoNfse.Error{}}`.
  """

  alias CorvoNfse.HTTP

  @default_base_url "https://api.corvo.tech"
  @default_prefix "v1"
  @default_receive_timeout 30_000

  @enforce_keys [:api_key, :base_url]
  defstruct [
    :api_key,
    :base_url,
    :prefix,
    :receive_timeout,
    :allow_insecure_http,
    :finch,
    :http
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t(),
          prefix: String.t(),
          receive_timeout: pos_integer(),
          allow_insecure_http: boolean(),
          finch: atom(),
          http: module()
        }

  @typedoc "Accepted options for `new/1`."
  @type option ::
          {:api_key, String.t()}
          | {:base_url, String.t()}
          | {:prefix, String.t() | nil}
          | {:receive_timeout, pos_integer()}
          | {:allow_insecure_http, boolean()}
          | {:finch, atom()}
          | {:http, module()}

  @doc """
  Builds a client from options with environment fallbacks.

  Raises `ArgumentError` when the configuration is unusable.
  """
  @spec new([option()]) :: t()
  def new(opts \\ []) when is_list(opts) do
    api_key = fetch_api_key!(opts)
    allow_insecure_http = Keyword.get(opts, :allow_insecure_http, false)
    base_url = opts |> fetch_base_url!() |> String.trim_trailing("/")
    prefix = fetch_prefix(opts)
    receive_timeout = fetch_receive_timeout!(opts)

    validate_base_url!(base_url, allow_insecure_http)

    %__MODULE__{
      api_key: api_key,
      base_url: base_url,
      prefix: prefix,
      receive_timeout: receive_timeout,
      allow_insecure_http: allow_insecure_http,
      finch: Keyword.get(opts, :finch) || CorvoNfse.Finch,
      http: Keyword.get(opts, :http) || HTTP.Finch
    }
  end

  defp fetch_api_key!(opts) do
    key =
      case Keyword.get(opts, :api_key) do
        candidate when is_binary(candidate) and candidate != "" -> candidate
        _ -> System.get_env("CORVO_API_KEY")
      end

    if is_binary(key) and key != "" do
      key
    else
      raise ArgumentError,
            "CorvoNfse: api_key is required - pass api_key: or set CORVO_API_KEY"
    end
  end

  defp fetch_base_url!(opts) do
    url =
      case Keyword.get(opts, :base_url) do
        candidate when is_binary(candidate) and candidate != "" -> candidate
        _ -> System.get_env("CORVO_BASE_URL") || @default_base_url
      end

    unless is_binary(url) and url != "" do
      raise ArgumentError, "CorvoNfse: invalid base_url: #{inspect(url)}"
    end

    url
  end

  defp fetch_prefix(opts) do
    case Keyword.get(opts, :prefix) do
      nil -> @default_prefix
      prefix when is_binary(prefix) -> String.trim(prefix, "/")
      other -> raise ArgumentError, "CorvoNfse: prefix must be a string, got: #{inspect(other)}"
    end
  end

  defp fetch_receive_timeout!(opts) do
    timeout = Keyword.get(opts, :receive_timeout, @default_receive_timeout)

    unless is_integer(timeout) and timeout > 0 do
      raise ArgumentError,
            "CorvoNfse: receive_timeout must be a positive integer (ms), got: #{inspect(timeout)}"
    end

    timeout
  end

  defp validate_base_url!(base_url, allow_insecure_http) do
    uri = URI.parse(base_url)

    if is_nil(uri.scheme) or is_nil(uri.host) do
      raise ArgumentError, "CorvoNfse: invalid base_url: #{base_url}"
    end

    if uri.scheme == "http" and not allow_insecure_http and not private_host?(uri.host) do
      raise ArgumentError,
            "CorvoNfse: http:// is only allowed for loopback/private hosts (got #{uri.host}). " <>
              "Use https:// or pass allow_insecure_http: true."
    end

    :ok
  end

  defp private_host?(host) do
    host = String.downcase(host)

    if host in ["localhost", "[::1]", "::1"] or String.ends_with?(host, ".localhost") do
      true
    else
      case ipv4(host) do
        nil -> false
        address -> private_ipv4?(address)
      end
    end
  end

  defp ipv4(host) do
    case Regex.run(~r/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/, host) do
      [_, a, b, c, d] ->
        case Enum.map([a, b, c, d], &Integer.parse/1) do
          [{a, ""}, {b, ""}, {c, ""}, {d, ""}] -> {a, b, c, d}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp private_ipv4?({127, _, _, _}), do: true
  defp private_ipv4?({10, _, _, _}), do: true
  defp private_ipv4?({0, _, _, _}), do: true
  defp private_ipv4?({192, 168, _, _}), do: true
  defp private_ipv4?({172, b, _, _}) when b >= 16 and b <= 31, do: true
  defp private_ipv4?({169, 254, _, _}), do: true
  defp private_ipv4?(_), do: false
end
