defmodule Supabase.Storage.BucketHandler do
  @moduledoc false

  alias Supabase.Client
  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Supabase.Storage
  alias Supabase.Storage.BodyDecoder
  alias Supabase.Storage.Bucket
  alias Supabase.Storage.Endpoints

  @type bucket_id :: String.t()
  @type bucket_name :: String.t()

  @spec list(Client.t()) :: Supabase.result(Response.t())
  def list(%Client{} = client) do
    client
    |> Storage.Request.base(Endpoints.bucket_path())
    |> Request.with_method(:get)
    |> Request.with_body_decoder(BodyDecoder, schema: Bucket)
    |> Fetcher.request()
  end

  @spec retrieve_info(Client.t(), String.t()) :: Supabase.result(Response.t())
  def retrieve_info(%Client{} = client, bucket_id) do
    uri = Endpoints.bucket_path_with_id(bucket_id)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:get)
    |> Request.with_body_decoder(BodyDecoder, schema: Bucket)
    |> Fetcher.request()
  end

  @spec create(Client.t(), Bucket.t()) :: Supabase.result(Response.t())
  def create(%Client{} = client, %Bucket{} = attrs) do
    client
    |> Storage.Request.base(Endpoints.bucket_path())
    |> Request.with_method(:post)
    |> Request.with_body(attrs)
    |> Fetcher.request()
  end

  @spec update(Client.t(), bucket_id, Bucket.t()) :: Supabase.result(Response.t())
  def update(%Client{} = client, id, attrs) do
    uri = Endpoints.bucket_path_with_id(id)
    attrs = Map.take(attrs, [:public, :file_size_limit, :allowed_mime_types, :type])

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:put)
    |> Request.with_body(attrs)
    |> Fetcher.request()
  end

  @spec empty(Client.t(), bucket_id) :: Supabase.result(Response.t())
  def empty(%Client{} = client, id) do
    uri = Endpoints.bucket_path_to_empty(id)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec delete(Client.t(), bucket_id) :: Supabase.result(Response.t())
  def delete(%Client{} = client, id) do
    uri = Endpoints.bucket_path_with_id(id)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:delete)
    |> Fetcher.request()
  end
end
