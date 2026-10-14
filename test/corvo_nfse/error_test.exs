defmodule CorvoNfse.ErrorTest do
  use ExUnit.Case, async: true

  alias CorvoNfse.Error

  doctest CorvoNfse.Error

  test "mirrors the wire error contract as a struct" do
    error = %Error{
      status: 400,
      code: "ERROR_VALIDATION",
      message: "Validation failed",
      details: [%{"field" => "amount", "code" => "too_small", "message" => "must be > 0"}],
      request_id: "req_01J",
      retry_after: nil
    }

    assert error.status == 400
    assert error.code == "ERROR_VALIDATION"
    assert error.message == "Validation failed"
    assert [%{"field" => "amount", "code" => "too_small"}] = error.details
    assert error.request_id == "req_01J"
    assert error.retry_after == nil
    assert Exception.message(error) == "Validation failed"
  end

  test "message falls back to status and code when message is missing" do
    assert Exception.message(%Error{status: 503, code: "http_503"}) ==
             ~s|Corvo NFS-e API error (status=503, code="http_503")|
  end

  test "fields default to nil" do
    error = %Error{}

    assert error.status == nil
    assert error.code == nil
    assert error.message == nil
    assert error.details == nil
    assert error.request_id == nil
    assert error.retry_after == nil
  end

  test "is a proper exception so iterate can raise it" do
    assert_raise Error, "page failed", fn ->
      raise %Error{status: 503, code: "http_503", message: "page failed"}
    end
  end
end
