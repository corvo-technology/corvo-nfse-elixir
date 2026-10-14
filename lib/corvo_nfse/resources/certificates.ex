defmodule CorvoNfse.Resources.Certificates do
  @moduledoc """
  A1 (`.p12`) certificate management for a company.

      CorvoNfse.Resources.Certificates.upload(client, company_id, {:file, "cert.p12"}, "secret")
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.{Certificate, Common}

  @type list_option :: {:limit, pos_integer()} | {:cursor, String.t()}
  @type upload_option :: {:file_name, String.t()}

  @doc """
  Uploads a certificate as `multipart/form-data` (`POST
  /v1/companies/:companyId/certificates`).

  The source is `{:file, path}` (read from disk) or `{:binary, bytes}`; for
  the latter pass `file_name:` (defaults to `certificate.p12`).
  """
  @spec upload(Client.t(), String.t(), Certificate.upload_source(), String.t(), [upload_option()]) ::
          {:ok, map()} | {:error, Error.t()}
  def upload(client, company_id, source, password, opts \\ [])
      when is_binary(password) do
    {bytes, default_name} = read_source!(source)
    file_name = opts |> Keyword.get(:file_name, default_name) |> sanitize_file_name()

    {body, content_type} = multipart(bytes, file_name, password)

    Transport.request(client, :post, "/companies/#{Transport.segment(company_id)}/certificates",
      raw_body: body,
      content_type: content_type
    )
  end

  @doc "Lists a company's certificates (`GET /v1/companies/:companyId/certificates`)."
  @spec list(Client.t(), String.t(), [list_option()]) ::
          {:ok, Common.page()} | {:error, Error.t()}
  def list(client, company_id, opts \\ []) do
    query = [limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)]

    Transport.list(
      client,
      "/companies/#{Transport.segment(company_id)}/certificates",
      query,
      :raw
    )
  end

  @doc "Deletes a certificate; 204 yields `{:ok, nil}`."
  @spec remove(Client.t(), String.t(), String.t()) :: {:ok, nil} | {:error, Error.t()}
  def remove(client, company_id, cert_id) do
    path =
      "/companies/#{Transport.segment(company_id)}/certificates/#{Transport.segment(cert_id)}"

    Transport.request(client, :delete, path)
  end

  defp read_source!({:file, path}) do
    {File.read!(path), Path.basename(path)}
  end

  defp read_source!({:binary, bytes}) when is_binary(bytes) do
    {bytes, "certificate.p12"}
  end

  defp read_source!(other) do
    raise ArgumentError,
          "CorvoNfse: certificate source must be {:file, path} or {:binary, bytes}, got: #{inspect(other)}"
  end

  defp sanitize_file_name(file_name) do
    file_name |> to_string() |> String.replace(~r/["\r\n]/, "")
  end

  defp multipart(bytes, file_name, password) do
    boundary = "corvo" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

    body = [
      "--#{boundary}\r\n",
      ~s(content-disposition: form-data; name="file"; filename="#{file_name}"\r\n),
      "content-type: application/x-pkcs12\r\n\r\n",
      bytes,
      "\r\n--#{boundary}\r\n",
      ~s(content-disposition: form-data; name="password"\r\n\r\n),
      password,
      "\r\n--#{boundary}--\r\n"
    ]

    {body, "multipart/form-data; boundary=#{boundary}"}
  end
end
