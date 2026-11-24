defmodule CorvoNfse.Multipart do
  @moduledoc """
  Minimal `multipart/form-data` body builder used by the upload operations
  (`Certificates.upload/5`, `Imports.start/3`).

  Parts are `{:file, name, file_name, content_type, bytes}` or
  `{:field, name, value}`.
  """

  @type part ::
          {:file, String.t(), String.t(), String.t(), binary()}
          | {:field, String.t(), String.t()}

  @doc "Builds `{iodata, content_type}` for the given parts."
  @spec build([part()]) :: {iodata(), String.t()}
  def build(parts) when is_list(parts) do
    boundary = "corvo" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

    body = [Enum.map(parts, &part(boundary, &1)), "--#{boundary}--\r\n"]

    {body, "multipart/form-data; boundary=#{boundary}"}
  end

  @doc """
  Reads an upload source: `{:file, path}` (read from disk) or `{:binary, bytes}`.

  Returns `{bytes, default_file_name}`; raises `ArgumentError` for anything else
  (a programming error, like a missing API key).
  """
  @spec read_source!(term(), String.t()) :: {binary(), String.t()}
  def read_source!({:file, path}, _default_name), do: {File.read!(path), Path.basename(path)}

  def read_source!({:binary, bytes}, default_name) when is_binary(bytes),
    do: {bytes, default_name}

  def read_source!(other, _default_name) do
    raise ArgumentError,
          "CorvoNfse: file source must be {:file, path} or {:binary, bytes}, got: #{inspect(other)}"
  end

  @doc "Strips characters that would break a quoted header value."
  @spec sanitize(term()) :: String.t()
  def sanitize(value), do: value |> to_string() |> String.replace(~r/["\r\n]/, "")

  defp part(boundary, {:file, name, file_name, content_type, bytes}) do
    [
      "--#{boundary}\r\n",
      ~s(content-disposition: form-data; name="#{name}"; filename="#{sanitize(file_name)}"\r\n),
      "content-type: #{content_type}\r\n\r\n",
      bytes,
      "\r\n"
    ]
  end

  defp part(boundary, {:field, name, value}) do
    [
      "--#{boundary}\r\n",
      ~s(content-disposition: form-data; name="#{name}"\r\n\r\n),
      value,
      "\r\n"
    ]
  end
end
