defmodule Supabase.Storage.FileHandler do
  @moduledoc false

  alias Supabase.Client
  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Supabase.Storage
  alias Supabase.Storage.BodyDecoder
  alias Supabase.Storage.Endpoints
  alias Supabase.Storage.File
  alias Supabase.Storage.FileOptions, as: Opts
  alias Supabase.Storage.ListV2Options, as: ListV2
  alias Supabase.Storage.SearchOptions, as: Search
  alias Supabase.Storage.TransformOptions, as: Transform

  @type bucket_id :: String.t()
  @type object_path :: Path.t()
  @type file_path :: Path.t()
  @type opts :: Opts.t()
  @type search_opts :: Search.t()
  @type list_v2_opts :: ListV2.t()
  @type wildcard :: String.t()
  @type prefix :: String.t() | nil
  @type token :: String.t()

  @spec create_file(Client.t(), bucket_id, object_path, file_path, opts) ::
          Supabase.result(Response.t())
  def create_file(%Client{} = client, bucket, object_path, file_path, %Opts{} = opts) do
    uri = Endpoints.file_upload(bucket, object_path)
    metadata = Supabase.encode_json(opts.metadata)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:post)
    |> Request.with_headers(%{
      "cache-control" => "max-age=#{opts.cache_control}",
      "content-type" => opts.content_type,
      "x-upsert" => to_string(opts.upsert),
      "x-metadata" => Base.encode64(metadata)
    })
    |> Request.with_headers(opts.headers)
    |> Fetcher.upload(file_path, upload_http_opts(opts))
  end

  @spec update_file(Client.t(), bucket_id, object_path, file_path, opts) ::
          Supabase.result(Response.t())
  def update_file(%Client{} = client, bucket, object_path, file_path, %Opts{} = opts) do
    uri = Endpoints.file_update(bucket, object_path)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:put)
    |> Request.with_headers(%{
      "cache-control" => "max-age=#{opts.cache_control}",
      "content-type" => opts.content_type,
      "x-upsert" => to_string(opts.upsert),
      "x-metadata" => Base.encode64(Jason.encode!(opts.metadata))
    })
    |> Request.with_headers(opts.headers)
    |> Fetcher.upload(file_path, upload_http_opts(opts))
  end

  @spec create_file_to_url(Client.t(), bucket_id, token, object_path, file_path, opts) ::
          Supabase.result(Response.t())
  def create_file_to_url(
        %Client{} = client,
        bucket,
        token,
        object_path,
        file_path,
        %Opts{} = opts
      ) do
    uri = Endpoints.file_upload_to_url(bucket, object_path)
    metadata = Supabase.encode_json(opts.metadata)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:put)
    |> Request.with_query(%{"token" => token})
    |> Request.with_headers(%{
      "cache-control" => "max-age=#{opts.cache_control}",
      "content-type" => opts.content_type,
      "x-upsert" => to_string(opts.upsert),
      "x-metadata" => Base.encode64(metadata)
    })
    |> Request.with_headers(opts.headers)
    |> Fetcher.upload(file_path, upload_http_opts(opts))
  end

  @spec move(Client.t(), bucket_id, object_path, object_path, String.t() | nil) ::
          Supabase.result(Response.t())
  def move(%Client{} = client, bucket_id, path, to, dest) do
    client
    |> Storage.Request.base(Endpoints.file_move())
    |> Request.with_body(%{
      bucket_id: bucket_id,
      source_key: path,
      destination_key: to,
      destination_bucket: dest
    })
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec copy(Client.t(), bucket_id, object_path, object_path, String.t() | nil) ::
          Supabase.result(Response.t())
  def copy(%Client{} = client, bucket_id, path, to, dest) do
    client
    |> Storage.Request.base(Endpoints.file_copy())
    |> Request.with_body(%{
      bucket_id: bucket_id,
      source_key: path,
      destination_key: to,
      destination_bucket: dest
    })
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec get_info(Client.t(), bucket_id, wildcard) :: Supabase.result(Response.t())
  def get_info(%Client{} = client, bucket_id, wildcard) do
    uri = Endpoints.file_info(bucket_id, wildcard)

    client
    |> Storage.Request.base(uri)
    |> Request.with_body_decoder(BodyDecoder, schema: File)
    |> Fetcher.request()
  end

  @spec list(Client.t(), bucket_id, prefix, search_opts) :: Supabase.result(Response.t())
  def list(%Client{} = client, bucket_id, prefix, %Search{} = opts) do
    uri = Endpoints.file_list(bucket_id)
    body = Map.merge(%{prefix: prefix || ""}, Map.from_struct(opts))

    client
    |> Storage.Request.base(uri)
    |> Request.with_body_decoder(BodyDecoder, schema: File)
    |> Request.with_headers(%{"content-type" => "application/json"})
    |> Request.with_body(body)
    |> Fetcher.request()
  end

  @spec list_v2(Client.t(), bucket_id, prefix, list_v2_opts) :: Supabase.result(Response.t())
  def list_v2(%Client{} = client, bucket_id, prefix, %ListV2{} = opts) do
    uri = Endpoints.file_list_v2(bucket_id)

    body =
      opts
      |> Map.from_struct()
      |> Map.merge(%{prefix: prefix || ""})
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    client
    |> Storage.Request.base(uri)
    |> Request.with_headers(%{"content-type" => "application/json"})
    |> Request.with_body(body)
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec remove_list(Client.t(), bucket_id, list(object_path)) :: Supabase.result(Response.t())
  def remove_list(%Client{} = client, bucket_id, paths) do
    uri = Endpoints.file_remove(bucket_id)

    client
    |> Storage.Request.base(uri)
    |> Request.with_body(%{prefixes: paths})
    |> Request.with_method(:delete)
    |> Fetcher.request()
  end

  @spec create_signed_url(Client.t(), bucket_id, object_path, keyword) ::
          Supabase.result(Response.t())
  def create_signed_url(%Client{} = client, bucket_id, path, opts) do
    expires_in = Keyword.fetch!(opts, :expires_in)
    transform = Keyword.get(opts, :transform)

    uri = Endpoints.file_signed_url(bucket_id, path)

    transform =
      if transform do
        {:ok, parsed} = Transform.parse(transform)
        parsed
      end

    body =
      if transform do
        %{expiresIn: expires_in, transform: transform}
      else
        %{expiresIn: expires_in}
      end

    client
    |> Storage.Request.base(uri)
    |> Request.with_headers(%{"content-type" => "application/json"})
    |> Request.with_body(body)
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec create_signed_urls(Client.t(), bucket_id, list(object_path), keyword) ::
          Supabase.result(Response.t())
  def create_signed_urls(%Client{} = client, bucket_id, paths, opts) when is_list(paths) do
    expires_in = Keyword.fetch!(opts, :expires_in)
    transform = Keyword.get(opts, :transform)

    uri = Endpoints.file_signed_url(bucket_id)

    body =
      if transform do
        %{expiresIn: expires_in, transform: transform, paths: paths}
      else
        %{expiresIn: expires_in, paths: paths}
      end

    client
    |> Storage.Request.base(uri)
    |> Request.with_headers(%{"content-type" => "application/json"})
    |> Request.with_body(body)
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec create_upload_signed_url(Client.t(), bucket_id, object_path, keyword) ::
          Supabase.result(Response.t())
  def create_upload_signed_url(%Client{} = client, bucket_id, path, opts) do
    upsert? = opts[:upsert] || false
    uri = Endpoints.file_upload_signed_url(bucket_id, path)

    client
    |> Storage.Request.base(uri)
    |> Request.with_headers(%{"x-upsert" => to_string(upsert?)})
    |> Request.with_method(:post)
    |> Fetcher.request()
  end

  @spec get(Client.t(), bucket_id, object_path, map | nil, keyword) ::
          Supabase.result(Response.t())
  def get(%Client{} = client, bucket_id, wildcard, transform, opts \\ []) do
    uri = download_uri(bucket_id, wildcard, transform, Keyword.get(opts, :cache_nonce))

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:get)
    |> Request.with_headers(%{"accept" => MIME.from_path(wildcard)})
    |> Request.with_body_decoder(nil)
    |> Fetcher.request(http_opts(opts))
  end

  @spec get_lazy(Client.t(), bucket_id, wildcard, term, keyword) ::
          Supabase.result(Response.t())
  def get_lazy(%Client{} = client, bucket_id, wildcard, transform, opts \\ []) do
    uri = download_uri(bucket_id, wildcard, transform, Keyword.get(opts, :cache_nonce))

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:get)
    |> Request.with_headers(%{"accept" => MIME.from_path(wildcard)})
    |> Request.with_body_decoder(nil)
    |> Fetcher.stream(nil, http_opts(opts))
  end

  @spec get_lazy(Client.t(), bucket_id, wildcard, term, on_response, keyword) ::
          Supabase.result(Response.t())
        when on_response: ({Fetcher.status(), Fetcher.headers(), binary} ->
                             Supabase.result(Response.t()))
  def get_lazy(%Client{} = client, bucket_id, wildcard, transform, on_response, opts) do
    uri = download_uri(bucket_id, wildcard, transform, Keyword.get(opts, :cache_nonce))

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:get)
    |> Request.with_headers(%{"accept" => MIME.from_path(wildcard)})
    |> Request.with_body_decoder(nil)
    |> Fetcher.stream(on_response, http_opts(opts))
  end

  defp download_uri(bucket_id, wildcard, transform, cache_nonce) do
    {:ok, transform} =
      if transform, do: Transform.parse(transform), else: {:ok, nil}

    render_path = if transform, do: "render/image/authenticated", else: "object"
    transform_query = if transform, do: to_string(transform), else: ""

    uri =
      [render_path, bucket_id, wildcard]
      |> Path.join()
      |> URI.parse()
      |> URI.append_query(transform_query)

    uri =
      if cache_nonce,
        do: URI.append_query(uri, URI.encode_query(%{"cacheNonce" => cache_nonce})),
        else: uri

    to_string(uri)
  end

  def exists(%Client{} = client, bucket_id, path) do
    uri = Endpoints.file_upload(bucket_id, path)

    client
    |> Storage.Request.base(uri)
    |> Request.with_method(:head)
    |> Request.with_body_decoder(nil)
    |> Fetcher.request()
  end

  @spec purge_cache(Client.t(), bucket_id, object_path, keyword) :: Supabase.result(Response.t())
  def purge_cache(%Client{} = client, bucket_id, path, opts) do
    query =
      if Keyword.get(opts, :transformations, false), do: %{"transformations" => "true"}, else: %{}

    client
    |> Storage.Request.base(Endpoints.cdn_purge(bucket_id, path))
    |> Request.with_method(:delete)
    |> Request.with_query(query)
    |> Fetcher.request()
  end

  defp http_opts(opts) do
    case Keyword.get(opts, :receive_timeout) do
      nil -> []
      timeout -> [receive_timeout: timeout]
    end
  end

  defp upload_http_opts(%Opts{receive_timeout: nil}), do: []
  defp upload_http_opts(%Opts{receive_timeout: timeout}), do: [receive_timeout: timeout]
end
