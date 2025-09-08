defmodule Supabase.Storage.Request do
  @moduledoc false

  alias Supabase.Client
  alias Supabase.Fetcher.Request

  def base(%Client{} = client, path) when is_binary(path) do
    Request.new(client)
    |> Request.with_storage_url(path)
    |> Request.with_error_parser(Supabase.Storage.Error)
    |> Request.with_http_client(http_client())
    |> Request.with_headers(%{"content-type" => "application/json"})
  end

  defp http_client do
    alias Supabase.Fetcher.Adapter.Finch
    Application.get_env(:supabase_storage, :http_client, Finch)
  end
end
