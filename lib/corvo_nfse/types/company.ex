defmodule CorvoNfse.Types.Company do
  @moduledoc """
  Wire shape of a fiscal company (24 fields).

  Responses come back as plain maps with these string keys, passed through
  unchanged from the server.
  """

  @type tax_regime :: "MEI" | "Simples Nacional" | "Lucro Presumido" | "Lucro Real"
  @type environment :: "test" | "live"

  defstruct [
    :id,
    :tenantId,
    :legalName,
    :tradeName,
    :taxId,
    :municipalReg,
    :municipalityCode,
    :taxRegime,
    :simpleNational,
    :specialRegime,
    :addressStreet,
    :addressNumber,
    :addressComplement,
    :addressDistrict,
    :addressCity,
    :addressState,
    :addressZip,
    :fiscalSchemaVersion,
    :environment,
    :status,
    :createdAt,
    :updatedAt,
    :deletedAt,
    :setupGaps
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          tenantId: String.t(),
          legalName: String.t(),
          tradeName: String.t() | nil,
          taxId: String.t(),
          municipalReg: String.t() | nil,
          municipalityCode: String.t() | nil,
          taxRegime: tax_regime(),
          simpleNational: boolean(),
          specialRegime: String.t() | nil,
          addressStreet: String.t() | nil,
          addressNumber: String.t() | nil,
          addressComplement: String.t() | nil,
          addressDistrict: String.t() | nil,
          addressCity: String.t(),
          addressState: String.t(),
          addressZip: String.t(),
          fiscalSchemaVersion: String.t(),
          environment: environment(),
          status: String.t(),
          createdAt: String.t(),
          updatedAt: String.t(),
          deletedAt: String.t() | nil,
          setupGaps: [String.t()]
        }

  @typedoc """
  Params for `CorvoNfse.Resources.Companies.create/2`. Wire keys (camelCase),
  passed through unchanged; string keys or camelCase atom keys are accepted:

    * `legalName` (required), `taxId` (required), `taxRegime` (required)
    * `tradeName`, `municipalReg`, `municipalityCode`, `simpleNational`,
      `specialRegime`, `address` (optional)
  """
  @type create_params :: map()

  @typedoc """
  Params for `CorvoNfse.Resources.Companies.update/3`; same wire keys as
  `create_params`, all optional (`null` clears a field server-side).
  """
  @type update_params :: map()

  @typedoc "Nested address object for create/update params."
  @type address_input :: %{
          required("street") => String.t(),
          required("district") => String.t(),
          required("city") => String.t(),
          required("state") => String.t(),
          required("zip") => String.t(),
          optional("number") => String.t(),
          optional("complement") => String.t()
        }
end
