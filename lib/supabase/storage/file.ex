defmodule Supabase.Storage.File do
  @moduledoc """
  Represents an Object within a Supabase Storage Bucket.

  This module encapsulates the structure and operations related to an object or file stored within a Supabase Storage bucket.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Supabase.Storage
  alias Supabase.Storage.FileHandler
  alias Supabase.Storage.FileOptions
  alias Supabase.Storage.SearchOptions
  alias Supabase.Storage.TransformOptions

  @typedoc """
  An `Object` has the following attributes:

  - `id`: The unique identifier for the object.
  - `path`: The path to the object within its storage bucket.
  - `bucket_id`: The ID of the bucket that houses this object.
  - `name`: The name or title of the object.
  - `owner`: The owner or uploader of the object.
  - `metadata`: A map containing meta-information about the object (e.g., file type, size).
  - `created_at`: Timestamp indicating when the object was first uploaded or created.
  - `updated_at`: Timestamp indicating the last time the object was updated.
  - `last_accessed_at`: Timestamp of when the object was last accessed or retrieved.
  """
  @type t :: %__MODULE__{
          id: String.t(),
          path: Path.t(),
          name: String.t(),
          owner: String.t(),
          metadata: map(),
          created_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t(),
          last_accessed_at: NaiveDateTime.t(),
          bucket_id: String.t() | nil,
          bucket: Storage.Bucket.t() | nil
        }

  @fields ~w(id path bucket_id name owner created_at updated_at metadata last_accessed_at)a

  @primary_key false
  embedded_schema do
    field(:path, :string)
    field(:id, :string)
    field(:name, :string)
    field(:owner, :string)
    field(:metadata, :map)
    field(:created_at, :naive_datetime)
    field(:updated_at, :naive_datetime)
    field(:last_accessed_at, :naive_datetime)

    belongs_to(:bucket, Storage.Bucket)
  end

  @spec parse(map | list(map)) :: {:ok, t | list(t)} | {:error, Ecto.Changeset.t()}
  @doc false
  def parse(attrs) when is_list(attrs) do
    Enum.reduce_while(attrs, [], fn attr, acc ->
      case parse(attr) do
        {:ok, data} -> {:cont, acc ++ [data]}
        {:error, changeset} -> {:halt, changeset}
      end
    end)
    |> then(fn
      data when is_list(data) -> {:ok, data}
      changeset -> {:error, changeset}
    end)
  end

  def parse(attrs) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> validate_required([:id])
    |> apply_action(:parse)
  end

  @doc """
  Uploads a file to an existing bucket.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `file_path`: The **local** filesystem path, to upload from.
  - `object_path`: The file path, including the file name. Should be of the format `folder/subfolder/filename.png`. The bucket must already exist before attempting to upload.
  - `options`: Optional `Enumerable` that represents the `Supabase.Storage.FileOptions`.
  """
  @spec upload(Storage.t(), file_path, object_path, options) :: Supabase.result(map)
        when file_path: Path.t(),
             object_path: Path.t(),
             options: Enumerable.t()
  def upload(%Storage{} = s, file_path, object_path, opts \\ %{})
      when is_binary(file_path) and is_binary(object_path) do
    {:ok, opts} = FileOptions.parse(opts)

    clean_path =
      object_path
      |> String.replace(~r/^\/|\/$/, "")
      |> String.replace(~r/\/+/, "/")

    with {:ok, %{body: body}} <-
           FileHandler.create_file(s.client, s.bucket_id, clean_path, file_path, opts) do
      {:ok, %{path: clean_path, id: body["Id"], key: body["Key"]}}
    end
  end

  @doc """
  Update a file in the storage bucket.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `file_path`: The **local** filesystem path, to upload from.
  - `object_path`: The file path, including the file name. Should be of the format `folder/subfolder/filename.png`. The bucket must already exist before attempting to upload.
  - `options`: Optional `Enumerable` that represents the `Supabase.Storage.FileOptions`.
  """
  @spec update(Storage.t(), file_path, object_path, options) :: Supabase.result(map)
        when file_path: Path.t(),
             object_path: Path.t(),
             options: Enumerable.t()
  def update(%Storage{} = s, file_path, object_path, opts \\ %{}) do
    {:ok, opts} = FileOptions.parse(opts)

    clean_path =
      object_path
      |> String.replace(~r/^\/|\/$/, "")
      |> String.replace(~r/\/+/, "/")

    with {:ok, %{body: body}} <-
           FileHandler.update_file(s.client, s.bucket_id, clean_path, file_path, opts) do
      {:ok, %{path: clean_path, id: body["Id"], key: body["Key"]}}
    end
  end

  @doc """
  Upload a file with a token generated from `create_signed_upload_url/3`.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `token`: token The token generated from `create_signed_upload_url/3`.
  - `file_path`: The **local** filesystem path, to upload from.
  - `object_path`: The file path, including the file name. Should be of the format `folder/subfolder/filename.png`. The bucket must already exist before attempting to upload.
  - `options`: Optional `Enumerable` that represents the `Supabase.Storage.FileOptions`.
  """
  @spec upload_to_signed_url(Storage.t(), token, file_path, object_path, options) ::
          Supabase.result(map)
        when file_path: Path.t(),
             object_path: Path.t(),
             options: Enumerable.t(),
             token: String.t()
  def upload_to_signed_url(%Storage{} = s, token, file_path, object_path, opts \\ %{})
      when is_binary(token) and is_binary(file_path) and is_binary(object_path) do
    {:ok, opts} = FileOptions.parse(opts)

    clean_path =
      object_path
      |> String.replace(~r/^\/|\/$/, "")
      |> String.replace(~r/\/+/, "/")

    with {:ok, %{body: body}} <-
           FileHandler.create_file_to_url(
             s.client,
             s.bucket_id,
             token,
             clean_path,
             file_path,
             opts
           ) do
      {:ok, %{path: clean_path, full_path: body["Key"]}}
    end
  end

  @doc """
  Creates a signed upload URL.

  Signed upload URLs can be used to upload files to the bucket without further authentication.

  They are valid for 2 hours.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `obejct_path`: The file path, including the current file name. For example `folder/image.png`.
  - `options.upsert`: If set to true, allows the file to be overwritten if it already exists.
  """
  @spec create_signed_upload_url(Storage.t(), Path.t(), list({:upsert, boolean})) ::
          Supabase.result(%{signed_url: String.t(), token: String.t(), path: Path.t()})
  def create_signed_upload_url(%Storage{} = s, object_path, opts \\ [])
      when is_binary(object_path) and is_list(opts) do
    clean_path =
      object_path
      |> String.replace(~r/^\/|\/$/, "")
      |> String.replace(~r/\/+/, "/")

    with {:ok, %{body: body}} <-
           FileHandler.create_upload_signed_url(s.client, s.bucket_id, clean_path, opts) do
      uri = URI.parse(Path.join(s.client.storage_url, body["url"]))
      token = URI.decode_query(uri.query)["token"]
      {:ok, %{signed_url: to_string(uri), token: token, path: clean_path}}
    end
  end

  @doc """
  Moves an existing file to a new path in the same bucket.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `options.from`: The original file path, including the current file name. For example `folder/image.png`.
  - `options.to`: The new file path, including the new file name. For example `folder/image-new.png`.
  - `options.destination_bucket`: The destination bucket ID to move the file if the `options.to` param refers to another bucket.
  """
  @spec move(Storage.t(), options) :: Supabase.result(:moved)
        when options:
               list({:from, Path.t()} | {:to, Path.t()} | {:destination_bucket, String.t() | nil})
  def move(%Storage{} = s, opts \\ []) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    dest = Keyword.get(opts, :destination_bucket)

    with {:ok, _} <- FileHandler.move(s.client, s.bucket_id, from, to, dest) do
      {:ok, :moved}
    end
  end

  @doc """
  Copies an existing file to a new path in the same bucket.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `options.from`: The original file path, including the current file name. For example `folder/image.png`.
  - `options.to`: The new file path, including the new file name. For example `folder/image-new.png`.
  - `options.destination_bucket`: The destination bucket ID to move the file if the `options.to` param refers to another bucket.
  """
  @spec copy(Storage.t(), options) :: Supabase.result(:moved)
        when options:
               list({:from, Path.t()} | {:to, Path.t()} | {:destination_bucket, String.t() | nil})
  def copy(%Storage{} = s, opts \\ []) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    dest = Keyword.get(opts, :destination_bucket)

    with {:ok, _} <- FileHandler.copy(s.client, s.bucket_id, from, to, dest) do
      {:ok, :moved}
    end
  end

  @doc """
  Creates a signed URL. Use a signed URL to share a file for a fixed amount of time.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `object_path`:The file path, including the current file name. For example `folder/image.png`.
  - `options.expires_in`: The number of seconds until the signed URL expires. For example, `60` for a URL which is valid for one minute.
  - `options.download`: Triggers the file as a download if set to true. Set this parameter as the name of the file if you want to trigger the download with a different filename.
  - `options.transform`: An `Enumerable` that represents the `Supabase.Storage.TransformOptions` to transform the asset before serving it to the client.
  """
  @spec create_signed_url(Storage.t(), object_path, options) :: Supabase.result(String.t())
        when object_path: Path.t(),
             options:
               list(
                 {:download, boolean | String.t() | nil}
                 | {:transform, Enumerable.t() | nil}
                 | {:expires_in, integer}
               )
  def create_signed_url(%Storage{} = s, path, opts \\ []) do
    _ = Keyword.fetch!(opts, :expires_in)
    download = Keyword.get(opts, :download)

    clean_path =
      path
      |> String.replace(~r/^\/|\/$/, "")
      |> String.replace(~r/\/+/, "/")

    with {:ok, resp} <- FileHandler.create_signed_url(s.client, s.bucket_id, clean_path, opts) do
      uri = URI.parse(Path.join(s.client.storage_url, resp.body["signedURL"]))

      if is_nil(download) do
        {:ok, to_string(uri)}
      else
        query = URI.encode_query(%{"download" => if(download === true, do: "", else: download)})
        uri = URI.append_query(uri, query)
        {:ok, to_string(uri)}
      end
    end
  end

  @spec create_signed_urls(Storage.t(), list(object_path), options) ::
          Supabase.result(%{path: String.t(), signed_url: String.t()})
        when object_path: Path.t(),
             options:
               list(
                 {:download, boolean | String.t() | nil}
                 | {:transform, Enumerable.t() | nil}
                 | {:expires_in, integer}
               )
  def create_signed_urls(%Storage{} = s, paths, opts \\ %{}) do
    {:ok, opts} = SearchOptions.parse(opts)

    with {:ok, resp} <- FileHandler.create_signed_url(s.client, s.bucket_id, paths, opts) do
      {:ok, resp.body}
    end
  end

  @doc """
  Lists all the files within a bucket.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `prefix`: The folder path.
  - `options`: An `Enumerable` that represents the `#{SearchOptions}`.
  """
  @spec list(Storage.t(), Path.t() | nil, options :: Enumerable.t()) ::
          Supabase.result(list(t))
  def list(%Storage{} = s, prefix \\ nil, opts \\ %{}) do
    {:ok, opts} = SearchOptions.parse(opts)

    with {:ok, resp} <- FileHandler.list(s.client, s.bucket_id, prefix, opts) do
      {:ok, resp.body}
    end
  end

  @doc """
  Deletes files within the same bucket

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `paths`: An array of files to delete, including the path and file name. For example `["folder/image.png"]`.
  """
  @spec remove(Storage.t(), to_remove :: list(Path.t()) | Path.t()) ::
          Supabase.result(list(t) | t)
  def remove(%Storage{} = s, to_remove) when is_list(to_remove) do
    with {:ok, resp} <- FileHandler.remove_list(s.client, s.bucket_id, to_remove) do
      {:ok, resp.body}
    end
  end

  def remove(%Storage{} = s, to_remove) do
    remove(s, [to_remove])
  end

  @doc """
  A simple convenience function to get the URL for an asset in a public bucket. If you do not want to use this function, you can construct the public URL by concatenating the bucket URL with the path to the asset.

  This function does not verify if the bucket is public. If a public URL is created for a bucket which is not public, you will not be able to download the asset.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `path`: The path and name of the file to generate the public URL for. For example `folder/image.png`.
  - `options.download`: Triggers the file as a download if set to true. Set this parameter as the name of the file if you want to trigger the download with a different filename.
  - `options.transform`: `Supabase.Storage.TransformOptions` the asset before serving it to the client, as an `Enumerable`.
  """
  @spec get_public_url(Storage.t(), object_path, options) :: Supabase.result(String.t())
        when object_path: Path.t(),
             options:
               list(
                 {:download, boolean | String.t() | nil}
                 | {:transform, Enumerable.t() | nil}
               )
  def get_public_url(%Storage{} = s, path, opts \\ [])
      when is_binary(path) and is_list(opts) do
    download = Keyword.get(opts, :download)
    transform = Keyword.get(opts, :transform)

    {:ok, transform} = if transform, do: TransformOptions.parse(transform), else: {:ok, nil}

    clean_path =
      path
      |> String.replace(~r/^\/|\/$/, "")
      |> String.replace(~r/\/+/, "/")

    render_path = if transform, do: "render/image", else: "object"

    uri =
      [s.client.storage_url, render_path, "public", s.bucket_id, clean_path]
      |> Path.join()
      |> URI.parse()

    transform_query = if is_nil(transform), do: "", else: to_string(transform)

    if is_nil(download) do
      {:ok, to_string(URI.append_query(uri, transform_query))}
    else
      query = URI.encode_query(%{"download" => if(download === true, do: "", else: download)})
      uri = URI.append_query(uri, query) |> URI.append_query(transform_query)
      {:ok, to_string(uri)}
    end
  end

  @doc """
  Checks the existence of a file.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `path`
  """
  @spec exists?(Storage.t(), path :: Path.t()) :: boolean
  def exists?(%Storage{} = s, path) when is_binary(path) do
    case FileHandler.exists(s.client, s.bucket_id, path) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Retrieves the details of an existing file.

  ## Params

  - `storage`: The `Supabase.Storage` instance created with `Supabase.Storage.from/2`.
  - `path`
  """
  @spec info(Storage.t(), path :: Path.t()) :: Supabase.result(t)
  def info(%Storage{} = s, path) when is_binary(path) do
    with {:ok, resp} <- FileHandler.get_info(s.client, s.bucket_id, path) do
      {:ok, resp.body}
    end
  end

  @doc """
  Downloads a file from a private bucket. For public buckets, make a request to the URL returned from `getPublicUrl` instead.

  ## Params
  - `path`: The full path and file name of the file to be downloaded. For example `folder/image.png`.
  - `options.transform`: Transform the asset before serving it to the client.
  """
  @spec download(Storage.t(), path :: Path.t(), options) :: Supabase.result(binary)
        when options: list({:transform, Enumerable.t() | nil})
  def download(%Storage{} = s, path, opts \\ [])
      when is_binary(path) and is_list(opts) do
    transform = Keyword.get(opts, :transform)

    with {:ok, resp} <- FileHandler.get(s.client, s.bucket_id, path, transform) do
      {:ok, resp.body}
    end
  end

  @doc """
  Downloads a file from a private bucket, lazily. For public buckets, make a request to the URL returned from `getPublicUrl` instead.

  ## Params
  - `path`: The full path and file name of the file to be downloaded. For example `folder/image.png`.
  - `options.transform`: Transform the asset before serving it to the client.
  """
  @spec download_lazy(Storage.t(), path :: Path.t(), on_response, options) ::
          Supabase.result(binary)
        when options: list({:transform, Enumerable.t() | nil}),
             on_response: ({Supabase.Fetcher.status(), Supabase.Fetcher.headers(), binary} ->
                             Supabase.result(Supabase.Fetcher.Response.t()))
  def download_lazy(%Storage{} = s, path, on_response, opts \\ [])
      when is_binary(path) and is_list(opts) do
    transform = Keyword.get(opts, :transform)

    with {:ok, resp} <- FileHandler.get_lazy(s.client, s.bucket_id, path, transform, on_response) do
      {:ok, resp.body}
    end
  end
end
