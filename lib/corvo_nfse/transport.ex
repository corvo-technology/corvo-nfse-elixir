defmodule CorvoNfse.Transport do
  @moduledoc """
  HTTP plumbing shared by every resource module.

  Builds the URL (`base_url <> "/" <> prefix <> path`), sets the `X-API-Key`
  header, performs the request through the client's `CorvoNfse.HTTP` adapter,
  decodes JSON, unwraps the Corvo response envelope and maps every failure
  onto `CorvoNfse.Error`.

  Nothing here raises for API, network or timeout failures: every call returns
  `{:ok, data}` or `{:error, %CorvoNfse.Error{}}`. Server field names are
  passed through untouched - no re-casing of the wire format.

  ## Envelope unwrapping

    * `:data` (default) - `{data: X}` returns `X`; anything else returns
      `nil`. A `204` or empty body returns `nil`.
    * `:data_props` - like `:data`, then returns `data.props` if `data` is an
      object with `props`, otherwise `nil` (used by invoice endpoints).
    * `:none` - the parsed body as-is (used by the health endpoints).

  ## Pagination

  `list/4` returns `{:ok, %{data: [...], pagination: map}}` where
  `pagination` is the server's `%{"limit" =>, "hasMore" =>, "nextCursor" =>}`
  object passed through unchanged (camelCase preserved).
  """

  alias CorvoNfse.{Client, Error}

  @type unwrap :: :data | :data_props | :none
  @type item_mode :: :raw | :props
  @type option ::
          {:json, map() | list() | nil}
          | {:raw_body, iodata() | nil}
          | {:content_type, String.t() | nil}
          | {:query, map() | keyword() | nil}
          | {:idempotency_key, String.t() | nil}
          | {:unwrap, unwrap()}

  @typedoc "A page as returned by `list/4`."
  @type page :: %{data: [term()], pagination: map() | nil}

  @doc """
  Performs a request and unwraps the response envelope.

  ## Options

    * `:json` - map/list encoded as the JSON body (sets `Content-Type`).
    * `:raw_body` / `:content_type` - pre-built body, e.g. multipart.
    * `:query` - map or keyword list of query parameters; `nil` values are
      skipped.
    * `:idempotency_key` - sent as `Idempotency-Key`.
    * `:unwrap` - `:data` (default), `:data_props` or `:none`.
  """
  @spec request(Client.t(), :get | :post | :patch | :delete, String.t(), [option()]) ::
          {:ok, term()} | {:error, Error.t()}
  def request(client, method, path, opts \\ []) do
    case dispatch(client, method, path, opts) do
      {:ok, response} -> handle_success(response, Keyword.get(opts, :unwrap, :data))
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Performs a request and returns the raw body (used by the PDF/XML downloads).

  Returns `{:ok, %{body: binary, mime_type: binary | nil, file_name: binary | nil}}`.
  """
  @spec request_raw(Client.t(), :get | :post | :patch | :delete, String.t(), [option()]) ::
          {:ok, map()} | {:error, Error.t()}
  def request_raw(client, method, path, opts \\ []) do
    case dispatch(client, method, path, opts) do
      {:ok, response} ->
        if success?(response.status) do
          {:ok,
           %{
             body: response.body,
             mime_type: header(response, "content-type"),
             file_name: filename_from(header(response, "content-disposition"))
           }}
        else
          {:error, to_error(response)}
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  @doc """
  Fetches a single page of a list endpoint.

  Items are mapped according to `item_mode`:

    * `:raw` - items passed through unchanged.
    * `:props` - each item's `props` object is extracted (invoice endpoints
      serialize entities as `{props: {...}}`).
  """
  @spec list(Client.t(), String.t(), map() | keyword() | nil, item_mode()) ::
          {:ok, page()} | {:error, Error.t()}
  def list(client, path, query, item_mode) do
    case request(client, :get, path, query: query, unwrap: :none) do
      {:ok, body} -> {:ok, page(body, item_mode)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Lazily walks every page of a list endpoint.

  The **first page is fetched eagerly**: when it fails, `paginate/4` returns
  `{:error, %CorvoNfse.Error{}}` and nothing was streamed. On success it
  returns `{:ok, stream}`; the stream yields items one by one, following
  `pagination.hasMore` / `pagination.nextCursor`.

  If a page *after the first* fails while the stream is being consumed, the
  stream raises the `%CorvoNfse.Error{}` (this is the single documented
  raising site in the SDK).
  """
  @spec paginate(Client.t(), String.t(), map() | keyword() | nil, item_mode()) ::
          {:ok, Enumerable.t()} | {:error, Error.t()}
  def paginate(client, path, query, item_mode) do
    case list(client, path, query, item_mode) do
      {:ok, first_page} ->
        state = %{
          client: client,
          path: path,
          query: query,
          item_mode: item_mode,
          items: first_page.data,
          next_cursor: next_cursor(first_page.pagination),
          done?: not more?(first_page.pagination)
        }

        {:ok, Stream.resource(fn -> state end, &next_batch/1, fn _state -> :ok end)}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  @doc """
  Percent-encodes a path segment with `encodeURIComponent` semantics.
  """
  @spec segment(String.t() | atom() | integer()) :: String.t()
  def segment(id) do
    id
    |> to_string()
    |> URI.encode(fn byte ->
      URI.char_unreserved?(byte) or byte in [?!, ?*, ?', ?(, ?)]
    end)
  end

  ## Request building

  defp dispatch(client, method, path, opts) do
    request = %{
      method: method,
      url: build_url(client, path, Keyword.get(opts, :query)),
      headers: build_headers(client.api_key, opts),
      body: build_body(opts),
      receive_timeout: client.receive_timeout,
      finch: client.finch
    }

    try do
      case client.http.send(request) do
        {:ok, %{status: status, headers: headers, body: body}} when is_integer(status) ->
          {:ok, %{status: status, headers: headers || [], body: body || ""}}

        {:error, reason} ->
          {:error, transport_error(reason, request.receive_timeout)}

        other ->
          {:error, transport_error(other, request.receive_timeout)}
      end
    rescue
      exception ->
        {:error, transport_error(exception, request.receive_timeout)}
    catch
      kind, reason ->
        {:error, transport_error({kind, reason}, request.receive_timeout)}
    end
  end

  defp build_url(client, path, query) do
    prefix = if client.prefix in [nil, ""], do: "", else: "/" <> client.prefix
    client.base_url <> prefix <> path <> encode_query(query)
  end

  defp encode_query(nil), do: ""

  defp encode_query(query) do
    pairs =
      query
      |> Enum.to_list()
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    case pairs do
      [] ->
        ""

      _pairs ->
        "?" <>
          Enum.map_join(pairs, "&", fn {key, value} ->
            encode_form(key) <> "=" <> encode_form(value)
          end)
    end
  end

  defp encode_form(value) do
    value |> to_string() |> URI.encode_www_form()
  end

  defp build_headers(api_key, opts) do
    headers = [
      {"x-api-key", api_key},
      {"accept", "application/json"}
    ]

    headers =
      cond do
        Keyword.has_key?(opts, :raw_body) ->
          [{"content-type", Keyword.get(opts, :content_type, "application/octet-stream")} | headers]

        is_map(Keyword.get(opts, :json)) or is_list(Keyword.get(opts, :json)) ->
          [{"content-type", "application/json"} | headers]

        true ->
          headers
      end

    case Keyword.get(opts, :idempotency_key) do
      key when is_binary(key) and key != "" -> [{"idempotency-key", key} | headers]
      _ -> headers
    end
  end

  defp build_body(opts) do
    cond do
      Keyword.has_key?(opts, :raw_body) -> Keyword.get(opts, :raw_body)
      Keyword.has_key?(opts, :json) -> encode_json(Keyword.get(opts, :json))
      true -> nil
    end
  end

  defp encode_json(nil), do: nil
  defp encode_json(body), do: Jason.encode!(body)

  ## Response handling

  defp handle_success(response, unwrap_mode) do
    cond do
      not success?(response.status) ->
        {:error, to_error(response)}

      response.status == 204 or response.body == "" ->
        {:ok, nil}

      true ->
        case decode(response.body) do
          {:ok, parsed} ->
            {:ok, unwrap(parsed, unwrap_mode)}

          :error ->
            {:error,
             %Error{
               status: response.status,
               code: "invalid_json",
               message: "Invalid JSON in response",
               request_id: header(response, "x-request-id")
             }}
        end
    end
  end

  defp success?(status), do: status >= 200 and status < 300

  defp unwrap(parsed, :none), do: parsed
  defp unwrap(parsed, :data), do: envelope_data(parsed)

  defp unwrap(parsed, :data_props) do
    case envelope_data(parsed) do
      data when is_map(data) -> Map.get(data, "props")
      _other -> nil
    end
  end

  defp envelope_data(parsed) when is_map(parsed), do: Map.get(parsed, "data")
  defp envelope_data(_parsed), do: nil

  defp page(body, item_mode) when is_map(body) do
    items =
      case body do
        %{"data" => data} when is_list(data) -> Enum.map(data, &map_item(&1, item_mode))
        _other -> []
      end

    %{data: items, pagination: Map.get(body, "pagination")}
  end

  defp page(_body, _item_mode), do: %{data: [], pagination: nil}

  defp map_item(item, :raw), do: item
  defp map_item(item, :props) when is_map(item), do: Map.get(item, "props")
  defp map_item(_item, :props), do: nil

  defp more?(pagination) when is_map(pagination) do
    Map.get(pagination, "hasMore") == true and is_binary(Map.get(pagination, "nextCursor"))
  end

  defp more?(_pagination), do: false

  defp next_cursor(pagination) when is_map(pagination) do
    case Map.get(pagination, "nextCursor") do
      cursor when is_binary(cursor) -> cursor
      _other -> nil
    end
  end

  defp next_cursor(_pagination), do: nil

  defp next_batch(%{items: [_ | _] = items} = state) do
    {items, %{state | items: []}}
  end

  defp next_batch(%{items: [], done?: true} = state), do: {:halt, state}

  defp next_batch(%{items: []} = state) do
    query = put_cursor(state.query, state.next_cursor)

    case list(state.client, state.path, query, state.item_mode) do
      {:ok, next_page} ->
        {next_page.data,
         %{
           state
           | items: [],
             next_cursor: next_cursor(next_page.pagination),
             done?: not more?(next_page.pagination)
         }}

      {:error, %Error{} = error} ->
        raise error
    end
  end

  defp put_cursor(query, cursor) when is_list(query) do
    if Keyword.has_key?(query, :cursor) do
      Keyword.replace(query, :cursor, cursor)
    else
      query ++ [cursor: cursor]
    end
  end

  defp put_cursor(query, cursor) when is_map(query), do: Map.put(query, :cursor, cursor)

  ## Error mapping

  defp transport_error(reason, receive_timeout) do
    if timeout?(reason) do
      %Error{
        status: 0,
        code: "timeout",
        message: "Request timed out after #{receive_timeout}ms"
      }
    else
      %Error{
        status: 0,
        code: "network_error",
        message: "Network request failed: #{describe(reason)}"
      }
    end
  end

  defp timeout?(:timeout), do: true
  defp timeout?(:timed_out), do: true
  defp timeout?({:error, reason}), do: timeout?(reason)
  defp timeout?(%{reason: reason}) when is_atom(reason), do: timeout?(reason)
  defp timeout?(_reason), do: false

  defp describe(%{__exception__: true} = exception), do: Exception.message(exception)
  defp describe({kind, reason}) when is_atom(kind), do: "#{kind}: #{inspect(reason)}"
  defp describe(reason), do: inspect(reason)

  defp to_error(response) do
    parsed =
      case decode(response.body) do
        {:ok, value} -> value
        :error -> nil
      end

    data = if is_map(parsed), do: parsed, else: %{}
    status = response.status

    %Error{
      status: status,
      code: error_code(data, status),
      message: error_message(data, status),
      details: if(is_list(Map.get(data, "details")), do: Map.get(data, "details"), else: nil),
      request_id: error_request_id(data, response),
      retry_after: error_retry_after(data, header(response, "retry-after"))
    }
  end

  defp error_code(data, status) do
    case Map.get(data, "code") do
      code when is_binary(code) and code != "" -> code
      _other -> "http_#{status}"
    end
  end

  defp error_message(data, status) do
    message = Map.get(data, "message")

    cond do
      is_binary(message) -> message
      is_list(message) -> Enum.map_join(message, "; ", &to_string/1)
      is_binary(Map.get(data, "error")) -> Map.get(data, "error")
      true -> "Request failed with status #{status}"
    end
  end

  defp error_request_id(data, response) do
    case Map.get(data, "requestId") do
      request_id when is_binary(request_id) and request_id != "" -> request_id
      _other -> header(response, "x-request-id")
    end
  end

  defp error_retry_after(data, header_value) do
    case Map.get(data, "retryAfter") do
      retry_after when is_number(retry_after) ->
        retry_after

      _other ->
        parse_retry_after(header_value)
    end
  end

  defp parse_retry_after(nil), do: nil

  defp parse_retry_after(value) do
    trimmed = String.trim(value)

    case Integer.parse(trimmed) do
      {seconds, ""} -> seconds
      _other -> parse_float(trimmed)
    end
  end

  defp parse_float(value) do
    case Float.parse(value) do
      {seconds, ""} -> seconds
      _other -> nil
    end
  end

  defp decode(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _decode_error} -> :error
    end
  rescue
    _exception -> :error
  end

  defp decode(_body), do: :error

  defp header(response, name) do
    case List.keyfind(response.headers, name, 0) do
      {_name, value} when is_binary(value) -> value
      _other -> nil
    end
  end

  defp filename_from(nil), do: nil

  defp filename_from(content_disposition) do
    case Regex.run(~r/filename="([^"]*)"/i, content_disposition) do
      [_match, filename] ->
        filename

      nil ->
        case Regex.run(~r/filename\*=(?:UTF-8'')?([^;]+)/i, content_disposition) do
          [_match, filename] -> filename |> String.trim() |> String.trim("\"")
          nil -> bare_filename(content_disposition)
        end
    end
  end

  defp bare_filename(content_disposition) do
    case Regex.run(~r/filename=([^;\s]+)/i, content_disposition) do
      [_match, filename] -> String.trim(filename, "\"")
      nil -> nil
    end
  end
end
