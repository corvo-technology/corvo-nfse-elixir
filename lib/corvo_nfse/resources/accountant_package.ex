defmodule CorvoNfse.Resources.AccountantPackage do
  @moduledoc """
  Monthly package (XML, PDF and summary) sent to the company's accountant
  (`/v1/companies/:companyId/accountant-package`).

      CorvoNfse.Resources.AccountantPackage.update(client, company_id, %{
        "accountantEmail" => "contador@example.com"
      })
      CorvoNfse.Resources.AccountantPackage.send(client, company_id, "2026-10")
  """

  alias CorvoNfse.{Client, Error, Transport}

  @doc "Reads the accountant e-mail and the last month sent."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, company_id) do
    Transport.request(client, :get, base(company_id))
  end

  @doc """
  Sets the accountant e-mail (`"accountantEmail" => nil` turns the monthly
  send off) (`PUT`).
  """
  @spec update(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, company_id, params) when is_map(params) do
    Transport.request(client, :put, base(company_id), json: params)
  end

  @doc "Sends the package of `month` (`\"YYYY-MM\"`) to the accountant now."
  @spec send(Client.t(), String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def send(client, company_id, month) when is_binary(month) do
    Transport.request(client, :post, base(company_id) <> "/send", json: %{"month" => month})
  end

  @doc "Lists the last 12 attempts to send the package."
  @spec list_sends(Client.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_sends(client, company_id) do
    Transport.request(client, :get, base(company_id) <> "/sends")
  end

  defp base(company_id), do: "/companies/#{Transport.segment(company_id)}/accountant-package"
end
