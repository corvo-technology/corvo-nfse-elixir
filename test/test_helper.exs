ExUnit.start()

Mox.defmock(CorvoNfse.MockHTTP, for: CorvoNfse.HTTP)

contract_enabled? =
  Enum.all?(["CORVO_API_KEY", "CORVO_BASE_URL"], fn name ->
    case System.get_env(name) do
      nil -> false
      "" -> false
      _set -> true
    end
  end)

unless contract_enabled? do
  ExUnit.configure(exclude: [:contract])
end
