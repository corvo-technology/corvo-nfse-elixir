defmodule CorvoNfse.Types.Company do
  @moduledoc """
  Wire shape of a fiscal company. Optional fields are absent from the JSON when
  unset.

  Responses come back as plain maps with these string keys, passed through
  unchanged from the server.
  """

  @typedoc ~S(Tax regime wire value: "MEI" | "Simples Nacional" | "Lucro Presumido" | "Lucro Real".)
  @type tax_regime :: String.t()

  @typedoc ~S(Environment wire value: "test" | "live".)
  @type environment :: String.t()

  defstruct [
    :id,
    :tenantId,
    :legalName,
    :tradeName,
    :taxId,
    :municipalReg,
    :sendMunicipalReg,
    :municipalityCode,
    :defaultServiceCode,
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
          sendMunicipalReg: boolean() | nil,
          municipalityCode: String.t() | nil,
          defaultServiceCode: String.t() | nil,
          taxRegime: tax_regime() | nil,
          simpleNational: boolean(),
          specialRegime: String.t() | nil,
          addressStreet: String.t() | nil,
          addressNumber: String.t() | nil,
          addressComplement: String.t() | nil,
          addressDistrict: String.t() | nil,
          addressCity: String.t() | nil,
          addressState: String.t() | nil,
          addressZip: String.t() | nil,
          fiscalSchemaVersion: String.t(),
          environment: environment(),
          status: String.t(),
          createdAt: String.t(),
          updatedAt: String.t(),
          deletedAt: String.t() | nil,
          # pending setup: "municipality_code", "certificate"
          setupGaps: [String.t()]
        }

  @typedoc """
  Params for `CorvoNfse.Resources.Companies.create/2`. Wire keys (camelCase),
  passed through unchanged; string keys or camelCase atom keys are accepted:

    * `legalName`, `taxId` (CNPJ), `taxRegime`, `municipalityCode` (IBGE, 7
      digits) - required
    * `tradeName`, `municipalReg`, `sendMunicipalReg` (default `false`),
      `defaultServiceCode` (6 digits), `simpleNational`, `specialRegime`,
      `address` - optional
  """
  @type create_params :: map()

  @typedoc """
  Params for `CorvoNfse.Resources.Companies.update/3`; same wire keys as
  `create_params`, all optional (`null` clears a field server-side).
  """
  @type update_params :: map()

  @typedoc """
  Nested address object for create/update params: a plain JSON string-keyed
  map. Every key is optional: `street`, `number`, `complement`, `district`,
  `city`, `state` (UF) and `zip` (8 digits).
  """
  @type address_input :: %{optional(String.t()) => term()}
end
