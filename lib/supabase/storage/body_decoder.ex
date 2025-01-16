defmodule Supabase.Storage.BodyDecoder do
  @moduledoc "Custom body decoder, tries to parse to a Storage entity or an Error"

  alias Supabase.Fetcher.JSONDecoder
  alias Supabase.Fetcher.Response

  @behaviour Supabase.Fetcher.BodyDecoder

  @impl true
  def decode(%Response{} = resp, opts) do
    schema = Keyword.fetch!(opts, :schema)

    with {:ok, body} <- JSONDecoder.decode(resp, opts),
         {:error, _} <- schema.parse(body) do
      {:ok, body}
    end
  end
end
