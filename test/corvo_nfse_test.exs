defmodule CorvoNfseTest do
  use ExUnit.Case, async: true

  alias CorvoNfse.Types.Webhook

  test "exposes the package version" do
    assert CorvoNfse.version() == "0.2.0"
  end

  test "new/1 builds a configured client" do
    client = CorvoNfse.new(api_key: "corvo_test_" <> String.duplicate("a", 40))

    assert %CorvoNfse.Client{} = client
    assert client.base_url == "https://api.corvo.tech"
  end

  test "webhook events are the canonical 9" do
    events = Webhook.events()

    assert is_list(events)
    assert length(events) == 9
    assert Enum.all?(events, &is_binary/1)
    assert "nfse.invoice.fiscal_discrepancy" in events
    refute "webhook.test" in events
    assert "nfse.invoice.authorized" in events

    # function_exported?/3 returns false for modules that are compiled but not
    # yet loaded, so load it explicitly instead of relying on test order.
    Code.ensure_loaded!(CorvoNfse.Webhooks)
    assert function_exported?(CorvoNfse.Webhooks, :verify_signature, 3)
  end

  test "resource surface matches the shared contract exactly" do
    assert public_functions(CorvoNfse.Resources.Companies) ==
             [
               create: 2,
               get: 2,
               iterate: 1,
               iterate: 2,
               list: 1,
               list: 2,
               remove: 2,
               update: 3
             ]

    assert public_functions(CorvoNfse.Resources.Certificates) ==
             [list: 2, list: 3, remove: 3, upload: 4, upload: 5]

    assert public_functions(CorvoNfse.Resources.Invoices) ==
             [
               calculate: 2,
               create: 2,
               create: 3,
               download_url: 3,
               events: 2,
               events: 3,
               get: 2,
               iterate: 1,
               iterate: 2,
               list: 1,
               list: 2,
               pdf: 2,
               send_email: 2,
               send_email: 3,
               xml: 2
             ]

    assert public_functions(CorvoNfse.Resources.Webhooks) ==
             [create: 2, list: 1, list: 2, remove: 2, test: 2]

    assert public_functions(CorvoNfse.Resources.Webhooks.Deliveries) ==
             [iterate: 1, iterate: 2, list: 1, list: 2, retry: 2, stats: 1, stats: 2]

    assert public_functions(CorvoNfse.Resources.Credits) ==
             [
               balance: 1,
               history: 1,
               history: 2,
               iterate_history: 1,
               iterate_history: 2,
               plans: 1,
               plans: 2
             ]

    assert public_functions(CorvoNfse.Resources.Billing) == [plan: 1, usage: 1]
    assert public_functions(CorvoNfse.Resources.Plans) == [get: 2, list: 1, list: 2, quote: 2]
    assert public_functions(CorvoNfse.Resources.Health) == [live: 1, ready: 1]
  end

  defp public_functions(module) do
    Code.ensure_loaded!(module)
    module.__info__(:functions) |> Enum.sort()
  end
end
