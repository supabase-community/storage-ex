defmodule Supabase.Storage.ObjectHandler do
  @moduledoc """
  A low-level API interface for managing objects within a Supabase bucket.

  ## Responsibilities

  - **File Management**: Create, move, copy, and get information about files in a bucket.
  - **Object Listing**: List objects based on certain criteria, like a prefix.
  - **Object Removal**: Delete specific objects or a list of objects.
  - **URL Management**: Generate signed URLs for granting temporary access to objects.
  - **Content Access**: Retrieve the content of an object or stream it.

  ## Usage Warning

  This module is meant for internal use or for developers requiring more control over object management in Supabase. In general, users should work with the higher-level Supabase.Storage API when possible, as it may offer better abstractions and safety mechanisms.

  Directly interfacing with this module bypasses any additional logic the main API might provide. Use it with caution and ensure you understand its operations.
  """

  alias Supabase.Client
  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Supabase.Storage
  alias Supabase.Storage.BodyDecoder
  alias Supabase.Storage.Endpoints
  alias Supabase.Storage.Object
  alias Supabase.Storage.ObjectOptions, as: Opts
  alias Supabase.Storage.SearchOptions, as: Search

  @type bucket_name :: String.t()
  @type object_path :: Path.t()
  @type file_path :: Path.t()
  @type opts :: Opts.t()
  @type search_opts :: Search.t()
  @type wildcard :: String.t()
  @type prefix :: String.t()

  @spec create_file(Client.t(), bucket_name, object_path, file_path, opts) ::
          Supabase.result(Response.t())
  def create_file(%Client{} = client, bucket, object_path, file_path, %Opts{} = opts) do
    uri = Endpoints.file_upload(bucket, object_path)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:post)
    |> Request.with_headers(%{
      "cache-control" => "max-age=#{opts.cache_control}",
      "content-type" => opts.content_type,
      "x-upsert" => to_string(opts.upsert)
    })
    |> Fetcher.upload(file_path)
  end

  @spec move(Client.t(), bucket_name, object_path, object_path) :: Supabase.result(Response.t())
  def move(%Client{} = client, bucket_id, path, to) do
    body = %{bucket_id: bucket_id, source_key: path, destination_key: to}

    client
    |> Storage.Request.base(Endpoints.file_move())
    |> Request.with_body(body)
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec copy(Client.t(), bucket_name, object_path, object_path) :: Supabase.result(Response.t())
  def copy(%Client{} = client, bucket_id, path, to) do
    body = %{bucket_id: bucket_id, source_key: path, destination_key: to}

    client
    |> Storage.Request.base(Endpoints.file_copy())
    |> Request.with_body(body)
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec get_info(Client.t(), bucket_name, wildcard) :: Supabase.result(Response.t())
  def get_info(%Client{} = client, bucket_name, wildcard) do
    uri = Endpoints.file_info(bucket_name, wildcard)

    client
    |> Storage.Request.base(uri)
    |> Request.with_body_decoder(BodyDecoder, schema: Object)
    |> Fetcher.request()
  end

  @spec list(Client.t(), bucket_name, prefix, search_opts) :: Supabase.result(Response.t())
  def list(%Client{} = client, bucket_name, prefix, %Search{} = opts) do
    uri = Endpoints.file_list(bucket_name)
    body = Map.merge(%{prefix: prefix}, Map.from_struct(opts))

    client
    |> Storage.Request.base(uri)
    |> Request.with_body_decoder(BodyDecoder, schema: Object)
    |> Request.with_body(body)
    |> Fetcher.request()
  end

  @spec remove(Client.t(), bucket_name, object_path) :: Supabase.result(Response.t())
  def remove(%Client{} = client, bucket_name, path) do
    remove_list(client, bucket_name, [path])
  end

  @spec remove_list(Client.t(), bucket_name, list(object_path)) :: Supabase.result(Response.t())
  def remove_list(%Client{} = client, bucket_name, paths) do
    uri = Endpoints.file_remove(bucket_name)

    client
    |> Storage.Request.base(uri)
    |> Request.with_body(%{prefixes: paths})
    |> Request.with_method(:delete)
    |> Fetcher.request()
  end

  @spec create_signed_url(Client.t(), bucket_name, object_path, integer) ::
          Supabase.result(Response.t())
  def create_signed_url(%Client{} = client, bucket_name, path, expires_in) do
    uri = Endpoints.file_signed_url(bucket_name, path)

    client
    |> Storage.Request.base(uri)
    |> Request.with_body(%{expiresIn: expires_in})
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec get(Client.t(), bucket_name, object_path) :: Supabase.result(Response.t())
  def get(%Client{} = client, bucket_name, wildcard) do
    uri = Endpoints.file_download(bucket_name, wildcard)

    client
    |> Storage.Request.base(uri)
    |> Fetcher.request()
  end

  @spec get_lazy(Client.t(), bucket_name, wildcard) :: Supabase.result(Response.t())
  def get_lazy(%Client{} = client, bucket_name, wildcard) do
    uri = Endpoints.file_download(bucket_name, wildcard)

    client
    |> Storage.Request.base(uri)
    |> Fetcher.stream()
  end

  @spec get_lazy(Client.t(), bucket_name, wildcard, on_response) :: Supabase.result(Response.t())
        when on_response: ({Fetcher.status(), Fetcher.headers(), binary} ->
                             Supabase.result(Response.t()))
  def get_lazy(%Client{} = client, bucket_name, wildcard, on_response) do
    uri = Endpoints.file_download(bucket_name, wildcard)

    client
    |> Storage.Request.base(uri)
    |> Fetcher.stream(on_response)
  end
end
