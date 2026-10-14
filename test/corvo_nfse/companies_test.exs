defmodule CorvoNfse.CompaniesTest do
  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Resources.Companies

  setup :verify_on_exit!

  @base "http://localhost:4000/v1"

  test "create posts to /companies" do
    expect_request(json_response(%{"data" => %{"id" => "comp_1"}}))

    assert {:ok, %{"id" => "comp_1"}} =
             Companies.create(client(), %{"legalName" => "Acme", "taxId" => "1", "taxRegime" => "MEI"})

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/companies"
  end

  test "list passes limit and cursor through" do
    expect_request(json_response(%{"data" => [], "pagination" => %{"hasMore" => false}}))

    assert {:ok, page} = Companies.list(client(), limit: 3, cursor: "Y3VyMQ")
    assert page.data == []

    request = assert_request()
    assert request.url == @base <> "/companies?limit=3&cursor=Y3VyMQ"
  end

  test "iterate yields every page" do
    expect_requests([
      json_response(%{
        "data" => [%{"id" => "comp_1"}],
        "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "Y3VyMg"}
      }),
      json_response(%{
        "data" => [%{"id" => "comp_2"}],
        "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
      })
    ])

    assert {:ok, stream} = Companies.iterate(client(), limit: 1)
    assert Enum.to_list(stream) == [%{"id" => "comp_1"}, %{"id" => "comp_2"}]
  end

  test "get, update and remove address the company path" do
    expect_request(json_response(%{"data" => %{"id" => "comp_1"}}))
    assert {:ok, _company} = Companies.get(client(), "comp_1")
    request = assert_request()
    assert request.method == :get
    assert request.url == @base <> "/companies/comp_1"

    expect_request(json_response(%{"data" => %{"id" => "comp_1", "legalName" => "New"}}))
    assert {:ok, _company} = Companies.update(client(), "comp_1", %{"legalName" => "New"})
    request = assert_request()
    assert request.method == :patch
    assert Jason.decode!(request.body) == %{"legalName" => "New"}

    expect_request(empty_response(204))
    assert {:ok, nil} = Companies.remove(client(), "comp_1")
    request = assert_request()
    assert request.method == :delete
    assert request.url == @base <> "/companies/comp_1"
  end
end
