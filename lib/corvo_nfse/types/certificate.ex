defmodule CorvoNfse.Types.Certificate do
  @moduledoc """
  Wire shape of an A1 (`.p12`) certificate stored for a company.
  """

  defstruct [
    :id,
    :companyId,
    :serialNumber,
    :issuer,
    :subject,
    :fingerprint,
    :validFrom,
    :validUntil,
    :status,
    :createdAt
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          companyId: String.t(),
          serialNumber: String.t(),
          issuer: String.t(),
          subject: String.t(),
          fingerprint: String.t(),
          validFrom: String.t(),
          validUntil: String.t(),
          status: String.t(),
          createdAt: String.t()
        }

  @typedoc """
  A `.p12` file plus password for `CorvoNfse.Resources.Certificates.upload/4`:

    * `{:file, path}` - reads the file from disk.
    * `{:binary, bytes}` - in-memory bytes; pass `file_name:` in the options.
  """
  @type upload_source :: {:file, Path.t()} | {:binary, binary()}
end
