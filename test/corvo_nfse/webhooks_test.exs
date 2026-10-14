defmodule CorvoNfse.WebhooksTest do
  use ExUnit.Case, async: true

  alias CorvoNfse.Webhooks

  @body ~s({"type":"nfse.invoice.authorized","data":{"id":"inv_1"}})
  @secret "whsec_test_123"
  @signature "sha256=8f9bd040d8f717b19618ab3395ddfa4b8c176b8dc863195227b88dd85426bbbc"

  describe "verify_signature/3" do
    test "accepts the known HMAC-SHA256 vector" do
      assert Webhooks.verify_signature(@body, @signature, @secret)
    end

    test "rejects a tampered body" do
      tampered = String.replace(@body, "inv_1", "inv_2")
      refute Webhooks.verify_signature(tampered, @signature, @secret)
    end

    test "rejects a wrong secret" do
      refute Webhooks.verify_signature(@body, @signature, "whsec_other")
    end

    test "rejects malformed headers" do
      raw = String.replace_prefix(@signature, "sha256=", "")

      refute Webhooks.verify_signature(@body, nil, @secret)
      refute Webhooks.verify_signature(@body, "", @secret)
      refute Webhooks.verify_signature(@body, raw, @secret)
      refute Webhooks.verify_signature(@body, "sha256=zzzz", @secret)
      refute Webhooks.verify_signature(@body, String.upcase(@signature), @secret)
    end

    test "rejects an empty secret or a non-binary body" do
      refute Webhooks.verify_signature(@body, @signature, "")
      refute Webhooks.verify_signature(nil, @signature, @secret)
    end

    test "accepts a header padded with whitespace" do
      assert Webhooks.verify_signature(@body, "  " <> @signature <> "  ", @secret)
    end
  end
end
