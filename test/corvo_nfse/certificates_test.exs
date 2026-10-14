defmodule CorvoNfse.CertificatesTest do
  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Resources.Certificates

  setup :verify_on_exit!

  @base "http://localhost:4000/v1"

  @tag :tmp_dir
  test "upload reads {:file, path} and posts multipart/form-data", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "cert.p12")
    File.write!(path, <<0, 1, 2, 255>>)

    expect_request(json_response(%{"data" => %{"id" => "cert_1"}}))

    assert {:ok, %{"id" => "cert_1"}} =
             Certificates.upload(client(), "comp_1", {:file, path}, "s3cret")

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/companies/comp_1/certificates"

    assert {"content-type", content_type} = List.keyfind(request.headers, "content-type", 0)
    assert String.starts_with?(content_type, "multipart/form-data; boundary=")
    refute header_named(request, "idempotency-key")

    body = IO.iodata_to_binary(request.body)
    assert body =~ ~s(name="file")
    assert body =~ ~s(filename="cert.p12")
    assert body =~ "content-type: application/x-pkcs12"
    assert body =~ ~s(name="password")
    assert body =~ "s3cret"
    assert body =~ <<0, 1, 2, 255>>
    refute body =~ "application/json"
  end

  test "upload accepts in-memory bytes with a custom file name" do
    expect_request(json_response(%{"data" => %{"id" => "cert_1"}}))

    assert {:ok, %{"id" => "cert_1"}} =
             Certificates.upload(client(), "comp_1", {:binary, "BYTES"}, "pw",
               file_name: "acme.p12"
             )

    request = assert_request()
    assert IO.iodata_to_binary(request.body) =~ ~s(filename="acme.p12")
  end

  test "upload rejects unknown sources" do
    assert_raise ArgumentError, ~r/certificate source/, fn ->
      Certificates.upload(client(), "comp_1", "not-a-source", "pw")
    end
  end

  test "list and remove address the certificate paths" do
    expect_request(json_response(%{"data" => [], "pagination" => nil}))
    assert {:ok, %{data: []}} = Certificates.list(client(), "comp_1", limit: 2)
    request = assert_request()
    assert request.url == @base <> "/companies/comp_1/certificates?limit=2"

    expect_request(empty_response(204))
    assert {:ok, nil} = Certificates.remove(client(), "comp_1", "cert_1")
    request = assert_request()
    assert request.method == :delete
    assert request.url == @base <> "/companies/comp_1/certificates/cert_1"
  end

  defp header_named(request, name) do
    Enum.find_value(request.headers, fn
      {^name, value} -> value
      _other -> nil
    end)
  end
end
