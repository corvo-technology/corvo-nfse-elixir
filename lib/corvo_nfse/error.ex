defmodule CorvoNfse.Error do
  @moduledoc """
  The single error type returned by every Corvo NFS-e API call.

  Each field mirrors the wire error contract shared by all Corvo SDKs:

    * `:status` - HTTP status code; `0` for network/timeout failures.
    * `:code` - stable machine-readable code (`"ERROR_VALIDATION"`,
      `"http_500"`, `"network_error"`, `"timeout"`, `"invalid_json"`).
    * `:message` - human-readable message.
    * `:details` - list of `%{"field" => ..., "code" => ..., "message" => ...}`
      maps for body validation failures (passed through unchanged).
    * `:request_id` - `requestId` body field or `X-Request-Id` header.
    * `:retry_after` - seconds to wait, from `retryAfter` or `Retry-After`.

  API, network and timeout failures are returned as `{:error, %CorvoNfse.Error{}}`
  instead of raised. The struct is nevertheless a proper exception so the one
  documented raising site - a subsequent page failure inside an `iterate`
  stream - can `raise` it.

  ## Examples

      iex> CorvoNfse.Error.message(%CorvoNfse.Error{message: "company not found"})
      "company not found"

      iex> CorvoNfse.Error.message(%CorvoNfse.Error{status: 404, code: "http_404"})
      "Corvo NFS-e API error (status=404, code=\\"http_404\\")"
  """

  defexception [:status, :code, :message, :details, :request_id, :retry_after]

  @type detail :: %{required(String.t()) => String.t()}

  @type t :: %__MODULE__{
          status: non_neg_integer() | nil,
          code: String.t() | nil,
          message: String.t() | nil,
          details: [detail()] | nil,
          request_id: String.t() | nil,
          retry_after: non_neg_integer() | nil
        }

  def message(%__MODULE__{message: message}) when is_binary(message) and message != "", do: message

  def message(%__MODULE__{} = error) do
    "Corvo NFS-e API error (status=#{inspect(error.status)}, code=#{inspect(error.code)})"
  end
end
