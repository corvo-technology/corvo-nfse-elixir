defmodule CorvoNfse.Webhooks do
  @moduledoc """
  Webhook signature verification.

  Corvo signs every webhook delivery with HMAC-SHA256 over the **raw** request
  body using your endpoint secret, and sends the hex digest in the
  `X-Corvo-Signature` header as `sha256=<hex>`.

  ## Example

      {:ok, raw_body, _conn} = Plug.Conn.read_body(conn)
      [signature] = Plug.Conn.get_req_header(conn, "x-corvo-signature")

      true = CorvoNfse.Webhooks.verify_signature(raw_body, signature, secret)

  Always verify against the **raw** body, before any JSON parsing or
  re-serialization. Comparison is constant-time (`:crypto.hash_equals/2`).
  """

  @spec verify_signature(binary(), String.t() | nil, String.t()) :: boolean()
  def verify_signature(raw_body, signature_header, secret)
      when is_binary(raw_body) and is_binary(secret) and secret != "" do
    with true <- is_binary(signature_header),
         [_, hex] <- Regex.run(~r/^sha256=([0-9a-f]{64})$/, String.trim(signature_header)),
         {:ok, received} <- Base.decode16(hex, case: :lower) do
      expected = :crypto.mac(:hmac, :sha256, secret, raw_body)
      :crypto.hash_equals(received, expected)
    else
      _other -> false
    end
  end

  def verify_signature(_raw_body, _signature_header, _secret), do: false
end
