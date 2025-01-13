defmodule Supabase.Storage.Error do
  @moduledoc "Represents an error response from Storage service"

  alias Supabase.HTTPErrorParser

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response

  @behaviour Supabase.Error

  def from(%Response{body: %{"message" => msg}} = resp, %Request{} = ctx) do
    err = HTTPErrorParser.from(resp, ctx)
    %{err | message: msg}
  end

  def from(resp, ctx), do: HTTPErrorParser.from(resp, ctx)
end
