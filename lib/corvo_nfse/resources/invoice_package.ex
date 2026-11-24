defmodule CorvoNfse.Resources.InvoicePackage do
  @moduledoc """
  Monthly invoice package of a company: a ZIP with `xml/`, `pdf/` and
  `resumo.csv` (`/v1/companies/:companyId/invoice-package`).

      {:ok, summary} = CorvoNfse.Resources.InvoicePackage.summary(client, company_id, "2026-10")
      {:ok, %{body: zip}} = CorvoNfse.Resources.InvoicePackage.download(client, company_id, "2026-10")
  """

  alias CorvoNfse.{Client, Error, Transport}
  alias CorvoNfse.Types.Invoice

  @doc "Count and total of the month package, without building it. `total` is a decimal string such as `\"1234.50\"`."
  @spec summary(Client.t(), String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def summary(client, company_id, month) do
    Transport.request(client, :get, base(company_id) <> "/summary", query: [month: month])
  end

  @doc """
  Downloads the month package as raw ZIP bytes.

  `include:` is `"xml"`, `"pdf"` or `"xml,pdf"` (default: both). A list such as
  `["xml", "pdf"]` is joined with commas.
  """
  @spec download(Client.t(), String.t(), String.t(), [{:include, String.t() | [String.t()]}]) ::
          {:ok, Invoice.download()} | {:error, Error.t()}
  def download(client, company_id, month, opts \\ []) do
    include =
      case Keyword.get(opts, :include) do
        parts when is_list(parts) -> Enum.join(parts, ",")
        other -> other
      end

    Transport.request_raw(client, :get, base(company_id), query: [month: month, include: include])
  end

  defp base(company_id), do: "/companies/#{Transport.segment(company_id)}/invoice-package"
end
