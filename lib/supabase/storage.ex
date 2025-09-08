defmodule Supabase.Storage do
  @moduledoc """
  Supabase.Storage Elixir Package

  This module provides integration with the Supabase Storage API, enabling developers
  to perform a multitude of operations related to buckets and objects with ease.

  ## Usage

  You can start by creating or managing buckets:

      {:ok, bucket} = Supabase.Storage.create_bucket(client, "my_new_bucket")

  Once a bucket is set up, objects within the bucket can be managed:

      alias Supabase.Storage
      {:ok, s} = Storage.from(client, "my_bucket")
      {:ok, file_} Storage.File.upload(s, "path/on/local.png", "path/on/storage.png")

  ## Examples

  Here are some basic examples:

      alias Supabase.Storage
      {:ok, s} = Storage.from(client, "my_bucket")

      # Removing an object
      Storage.File.remove(s, "path/on/storage.png")

      # Moving an object
      Storage.File.move(s, from: "path/on/server1.png", to: "path/on/server2.png")

  Ensure to refer to method-specific documentation for detailed examples and explanations.

  ## Permissions

  Do remember to check and set the appropriate permissions in Supabase to make sure that the
  operations can be performed without any hitches.
  """

  alias Supabase.Client
  alias Supabase.Storage.Bucket
  alias Supabase.Storage.BucketHandler

  @behaviour Supabase.Storage.Behaviour

  @typedoc """
  Represent an instance of the Storage service to interact with
  the `Supabase.Storage.File` API.

  - `bucket_id`: The id of the `Supabase.Storage.Bucket` to operate within.
  - `client`: The `Supabase.Client` being hold. (internal)
  """
  @type t :: %__MODULE__{bucket_id: String.t(), client: Client.t()}

  defstruct [:bucket_id, :client]

  @doc """
  Creates an instance of `Supabase.Storage` so you can interact with the
  `Supabase.Storage.File` API.

  ## Params

  - `client`: The `Supabase.Client` to use to interact with the Storage service.
  - `bucket_id`: The unique identifier of the Bucket to operate within
  """
  @impl true
  def from(%Client{} = client, bucket_id) when is_binary(bucket_id) do
    %__MODULE__{client: client, bucket_id: bucket_id}
  end

  @doc """
  Retrieves information about all buckets in the current project.

  ## Params

  - `client`: The `Supabase.Client` to use to interact with the Storage service.

  ## Examples

      iex> Supabase.Storage.list_buckets(client)
      {:ok, [%Supabase.Storage.Bucket{...}, ...]}

      iex> Supabase.Storage.list_buckets(client)
      {:error, %Supabase.Error{}}

  """
  @impl true
  def list_buckets(%Client{} = client) do
    with {:ok, %{body: body}} <- BucketHandler.list(client) do
      {:ok, body}
    end
  end

  @doc """
  Retrieves information about a bucket in the current project.

  ## Params

  - `client`: The `Supabase.Client` to use to interact with the Storage service.
  - `id`: The unique identifier of the bucket you would like to retrieve.

  ## Examples

      iex> Supabase.Storage.retrieve_bucket_info(client, "avatars")
      {:ok, %Supabase.Storage.Bucket{...}}

      iex> Supabase.Storage.retrieve_bucket_info(client, "non-existant")
      {:error, %Supabase.Error{...}}

  """
  @impl true
  def get_bucket(%Client{} = client, id) when is_binary(id) do
    with {:ok, %{body: body}} <- BucketHandler.retrieve_info(client, id) do
      {:ok, body}
    end
  end

  @doc """
  Creates a new bucket in the current project given a map of attributes.

  ## Params

  - `client`: The `Supabase.Client` to use to interact with the Storage service.
  - `id`: A unique identifier for the bucket you are creating.
  - `options.public`: The visibility of the bucket. Public buckets don't require an authorization token to download objects, but still require a valid token for all other operations. By default, buckets are private.
  - `options.file_size_limit`: Specifies the max file size in bytes that can be uploaded to this bucket. The global file size limit takes precedence over this value. The default value is `nil`, which doesn't set a per bucket file size limit.
  - `options.allowed_mime_types`: Specifies the allowed mime types that this bucket can accept during upload. The default value is `nil`, which allows files with all mime types to be uploaded. Each mime type specified can be a wildcard, e.g. image/*, or a specific mime type, e.g. image/png.

  ## Examples

      iex> Supabase.Storage.create_bucket(client, "avatars")
      {:ok, %Supabase.Storage.Bucket{...}}

      iex> Supabase.Storage.create_bucket(client, "avatars", %{file_size_limit: "100mb"})
      {:ok, %Supabase.Storage.Bucket{...}}

      iex> Supabase.Storage.create_bucket(client, "avatars")
      {:error, %Supabase.Error{...}}

  """
  @impl true
  def create_bucket(%Client{} = client, id, %{} = attrs \\ %{}) when is_binary(id) do
    {:ok, bucket} = Bucket.parse(Map.put(attrs, :id, id))

    with {:ok, _} <- BucketHandler.create(client, bucket) do
      {:ok, :created}
    end
  end

  @doc """
  Updates a bucket in the current project given a map of attributes.

  ## Params

  - `client`: The `Supabase.Client` to use to interact with the Storage service.
  - `id`: A unique identifier for the bucket you are creating.
  - `options.public`: The visibility of the bucket. Public buckets don't require an authorization token to download objects, but still require a valid token for all other operations. By default, buckets are private.
  - `options.file_size_limit`: Specifies the max file size in bytes that can be uploaded to this bucket. The global file size limit takes precedence over this value. The default value is `nil`, which doesn't set a per bucket file size limit.
  - `options.allowed_mime_types`: Specifies the allowed mime types that this bucket can accept during upload. The default value is `nil`, which allows files with all mime types to be uploaded. Each mime type specified can be a wildcard, e.g. image/*, or a specific mime type, e.g. image/png.

  ## Examples

      iex> Supabase.Storage.update_bucket(client, "avatars", %{public: true})
      {:ok, %Supabase.Storage.Bucket{...}}

      iex> Supabase.Storage.update_bucket(client, "avatars", %{public: true})
      {:error, %Supabase.Error{...}}

  """
  @impl true
  def update_bucket(%Client{} = client, id, %{} = attrs) when is_binary(id) do
    with {:ok, bucket} <- Bucket.parse(Map.put(attrs, :id, id)),
         {:ok, _} <- BucketHandler.update(client, id, bucket) do
      {:ok, :updated}
    end
  end

  @doc """
  Empties a bucket in the current project. This action deletes all objects in the bucket.

  ## Params

  - `client`: The `Supabase.Client` to use to interact with the Storage service.
  - `id`: The unique identifier of the bucket you would like to empty.

  ## Examples

      iex> Supabase.Storage.empty_bucket(client, "avatars")
      {:ok, :emptied}

      iex> Supabase.Storage.empty_bucket(client, "avatars")
      {:error, %Supabase.Error{...}}

  """
  @impl true
  def empty_bucket(%Client{} = client, id) when is_binary(id) do
    with {:ok, _} <- BucketHandler.empty(client, id) do
      {:ok, :emptied}
    end
  end

  @doc """
  Deletes a bucket in the current project. Notice that this also deletes all objects in the bucket.

  ## Params

  - `client`: The `Supabase.Client` to use to interact with the Storage service.
  - `id`: The unique identifier of the bucket you would like to empty.

  ## Examples

      iex> Supabase.Storage.delete_bucket(client, "avatars")
      {:ok, :deleted}

      iex> Supabase.Storage.delete_bucket(client, "avatars")
      {:error, %Supabase.Error{...}}

  """
  @impl true
  def delete_bucket(%Client{} = client, id) when is_binary(id) do
    with {:ok, _} <- BucketHandler.delete(client, id) do
      {:ok, :deleted}
    end
  end
end
