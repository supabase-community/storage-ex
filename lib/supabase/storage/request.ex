defmodule Supabase.Storage.Request do
  @moduledoc "Helper to build the base request builder for Storage services"

  alias Supabase.Client
  alias Supabase.Fetcher.Request

  def base(%Client{} = client, path) when is_binary(path) do
    Request.new(client)
    |> Request.with_storage_url(path)
    |> Request.with_error_parser(Supabase.Storage.Error)
  end
end
