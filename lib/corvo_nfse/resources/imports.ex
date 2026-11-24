defmodule CorvoNfse.Resources.Imports do
  @moduledoc """
  Bulk invoice import from a `.csv` or `.xlsx` spreadsheet (`/v1/imports`).
  Imports are answered in `snake_case`.

      {:ok, template} = CorvoNfse.Resources.Imports.download_template(client)
      {:ok, job} = CorvoNfse.Resources.Imports.start(client, {:file, "notas.csv"})
      {:ok, job} = CorvoNfse.Resources.Imports.emit(client, job["id"])

  The flow: `start/3` parses the file in the background (`"status"` goes from
  `"processing"` to `"ready"`), `list_rows/3` and `update_row/4` fix the rows,
  `emit/3` issues every valid row, `download_errors/2` returns the rows that
  need attention as CSV.
  """

  alias CorvoNfse.{Client, Error, Multipart, Transport}
  alias CorvoNfse.Types.{Common, Invoice}

  @type source :: {:file, Path.t()} | {:binary, binary()}
  @type start_option :: {:company_id, String.t()} | {:file_name, String.t()}
  @type rows_option ::
          {:status, String.t()} | {:limit, pos_integer()} | {:cursor, String.t()}

  @doc """
  Uploads a spreadsheet as `multipart/form-data` (`POST /v1/imports`, answers `202`).

  The source is `{:file, path}` or `{:binary, bytes}` (then pass `file_name:`,
  default `import.csv`). `company_id:` is the company that issues every row
  without a CNPJ column value.
  """
  @spec start(Client.t(), source(), [start_option()]) :: {:ok, map()} | {:error, Error.t()}
  def start(client, source, opts \\ []) do
    {bytes, default_name} = Multipart.read_source!(source, "import.csv")
    file_name = Keyword.get(opts, :file_name, default_name)

    parts =
      case Keyword.get(opts, :company_id) do
        nil -> []
        company_id -> [{:field, "companyId", company_id}]
      end

    {body, content_type} =
      Multipart.build(parts ++ [{:file, "file", file_name, mime_for(file_name), bytes}])

    Transport.request(client, :post, "/imports", raw_body: body, content_type: content_type)
  end

  @doc "Recent imports with their counters, newest first, at most 20 (`limit:` up to 20)."
  @spec list(Client.t(), [{:limit, pos_integer()}]) :: {:ok, [map()]} | {:error, Error.t()}
  def list(client, opts \\ []) do
    Transport.request(client, :get, "/imports", query: [limit: Keyword.get(opts, :limit)])
  end

  @doc "Status and counters of an import."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, id), do: Transport.request(client, :get, path(id))

  @doc """
  Emits every valid row (`POST /v1/imports/:id/emit`, answers `202`).

  `send_email:` (boolean) sends the invoice e-mail to each customer.
  """
  @spec emit(Client.t(), String.t(), [{:send_email, boolean()}]) ::
          {:ok, map()} | {:error, Error.t()}
  def emit(client, id, opts \\ []) do
    body =
      case Keyword.get(opts, :send_email) do
        nil -> %{}
        send_email -> %{"sendEmail" => send_email}
      end

    Transport.request(client, :post, path(id) <> "/emit", json: body)
  end

  @doc "Rows of an import, one page at a time (default 50, at most 200); `status:` filters."
  @spec list_rows(Client.t(), String.t(), [rows_option()]) ::
          {:ok, Common.page()} | {:error, Error.t()}
  def list_rows(client, id, opts \\ []) do
    Transport.list(client, path(id) <> "/rows", rows_query(opts), :raw)
  end

  @doc "Lazily iterates every row of an import."
  @spec iterate_rows(Client.t(), String.t(), [rows_option()]) ::
          {:ok, Enumerable.t()} | {:error, Error.t()}
  def iterate_rows(client, id, opts \\ []) do
    Transport.paginate(client, path(id) <> "/rows", rows_query(opts), :raw)
  end

  @doc """
  Corrects one row and checks it again, only while the import is `"ready"`
  (`PATCH /v1/imports/:id/rows/:line`). Params: `%{"item" => %{...}}`.
  """
  @spec update_row(Client.t(), String.t(), integer() | String.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def update_row(client, id, line, params) when is_map(params) do
    Transport.request(client, :patch, path(id) <> "/rows/#{Transport.segment(line)}",
      json: params
    )
  end

  @doc "Discards an import that has not been emitted; 204 yields `{:ok, nil}`."
  @spec discard(Client.t(), String.t()) :: {:ok, nil} | {:error, Error.t()}
  def discard(client, id), do: Transport.request(client, :delete, path(id))

  @doc "Downloads the spreadsheet template (CSV) as raw bytes."
  @spec download_template(Client.t()) :: {:ok, Invoice.download()} | {:error, Error.t()}
  def download_template(client), do: Transport.request_raw(client, :get, "/imports/template")

  @doc "Downloads the CSV with the rows that need attention as raw bytes."
  @spec download_errors(Client.t(), String.t()) :: {:ok, Invoice.download()} | {:error, Error.t()}
  def download_errors(client, id),
    do: Transport.request_raw(client, :get, path(id) <> "/errors.csv")

  defp path(id), do: "/imports/#{Transport.segment(id)}"

  defp rows_query(opts) do
    [
      status: Keyword.get(opts, :status),
      limit: Keyword.get(opts, :limit),
      cursor: Keyword.get(opts, :cursor)
    ]
  end

  defp mime_for(file_name) do
    if String.ends_with?(String.downcase(file_name), ".xlsx") do
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    else
      "text/csv"
    end
  end
end
