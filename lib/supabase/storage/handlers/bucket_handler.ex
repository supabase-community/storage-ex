defmodule Supabase.Storage.BucketHandler do
  @moduledoc """
  Provides low-level API functions for managing Supabase Storage buckets.

  The `BucketHandler` module offers a collection of functions that directly interact with the Supabase Storage API for managing buckets. This module works closely with the `Supabase.Fetcher` for sending HTTP requests.

  ## Features

  - **Bucket Listing**: Fetch a list of all the buckets available in the storage.
  - **Bucket Retrieval**: Retrieve detailed information about a specific bucket.
  - **Bucket Creation**: Create a new bucket with specified attributes.
  - **Bucket Update**: Modify the attributes of an existing bucket.
  - **Bucket Emptying**: Empty the contents of a bucket without deleting the bucket itself.
  - **Bucket Deletion**: Permanently remove a bucket and its contents.

  ## Caution

  This module provides a low-level interface to Supabase Storage buckets and is designed for internal use by the `Supabase.Storage` module. Direct use is discouraged unless you need to perform custom or unsupported actions that are not available through the higher-level API. Incorrect use can lead to unexpected results or data loss.

  ## Implementation Details

  All functions within the module expect a base URL, API key, and access token as their initial arguments, followed by any additional arguments required for the specific operation. Responses are usually in the form of `{:ok, result}` or `{:error, message}` tuples.
  """

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
  @type create_attrs :: %{
          id: String.t(),
          name: String.t(),
          file_size_limit: integer | nil,
          allowed_mime_types: list(String.t()) | nil,
          public: boolean
        }
  @type update_attrs :: %{
          public: boolean | nil,
          file_size_limit: integer | nil,
          allowed_mime_types: list(String.t()) | nil
        }

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

  @spec create(Client.t(), create_attrs) :: Supabase.result(Response.t())
  def create(%Client{} = client, attrs) do
    client
    |> Storage.Request.base(Endpoints.bucket_path())
    |> Request.with_method(:post)
    |> Request.with_body(attrs)
    # |> Request.with_body_decoder(BodyDecoder, schema: Bucket)
    |> Fetcher.request()
  end

  @spec update(Client.t(), bucket_id, update_attrs) :: Supabase.result(Response.t())
  def update(%Client{} = client, id, attrs) do
    uri = Endpoints.bucket_path_with_id(id)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:put)
    |> Request.with_body(attrs)
    # |> Request.with_body_decoder(BodyDecoder, schema: Bucket)
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
