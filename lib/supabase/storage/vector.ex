defmodule Supabase.Storage.Vector do
  @moduledoc """
  API for managing vector buckets in Supabase Storage.

  Vector buckets are specialized storage containers for vector embeddings used in
  similarity search and machine learning applications. This module provides operations
  for creating, retrieving, listing, and deleting vector buckets.

  > #### Public Alpha {: .warning}
  >
  > This API is currently in public alpha. Features and interfaces may change
  > as the API evolves. Use in production environments at your own discretion.

  ## Example

      # Create a vector client
      vector = Supabase.Storage.Vector.from(client)

      # Create a new vector bucket
      {:ok, :created} = Supabase.Storage.Vector.create_bucket(vector, "embeddings")

      # Get bucket metadata
      {:ok, metadata} = Supabase.Storage.Vector.get_bucket(vector, "embeddings")

      # List all buckets
      {:ok, buckets} = Supabase.Storage.Vector.list_buckets(vector)

      # Delete a bucket (must be empty)
      {:ok, :deleted} = Supabase.Storage.Vector.delete_bucket(vector, "embeddings")
  """

  alias Supabase.Client
  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request
  alias Supabase.Storage
  alias Supabase.Storage.BodyDecoder
  alias Supabase.Storage.Vector.Metadata

  @behaviour Supabase.Storage.Vector.Behaviour

  @typedoc """
  Vector client instance containing the Supabase client and optional bucket name.
  """
  @type t :: %__MODULE__{client: Client.t(), vector_bucket_name: String.t() | nil}

  defstruct [:client, :vector_bucket_name]

  @doc """
  Creates a new Vector client instance.

  ## Parameters

    * `client` - A `Supabase.Client` instance
    * `vector_bucket_name` - Optional default bucket name to use for operations (default: `nil`)

  ## Returns

  A `Supabase.Storage.Vector` struct.

  ## Examples

      iex> client = Supabase.init_client(url, key)
      iex> vector = Supabase.Storage.Vector.from(client)
      %Supabase.Storage.Vector{client: client, vector_bucket_name: nil}

      iex> vector = Supabase.Storage.Vector.from(client, "my-bucket")
      %Supabase.Storage.Vector{client: client, vector_bucket_name: "my-bucket"}
  """
  @impl true
  def from(%Client{} = client, vector_bucket_name \\ nil) do
    %__MODULE__{client: client, vector_bucket_name: vector_bucket_name}
  end

  @doc """
  Creates a new vector bucket.

  Vector buckets must have unique names within a project. Once created, buckets can
  contain multiple vector indexes for different embedding dimensions and distance metrics.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance
    * `vector_bucket_name` - Unique name for the new bucket

  ## Returns

    * `{:ok, :created}` - Bucket was successfully created
    * `{:error, reason}` - Creation failed

  ## Examples

      iex> Supabase.Storage.Vector.create_bucket(vector, "embeddings")
      {:ok, :created}

      iex> Supabase.Storage.Vector.create_bucket(vector, "embeddings")
      {:error, %{message: "Bucket already exists"}}
  """
  @impl true
  def create_bucket(%__MODULE__{} = v, vector_bucket_name)
      when is_binary(vector_bucket_name) do
    v.client
    |> Storage.Request.base("/CreateVectorBucket")
    |> Request.with_method(:post)
    |> Request.with_body(%{vector_bucket_name: vector_bucket_name})
    |> Fetcher.request()
    |> then(fn
      {:ok, _} -> {:ok, :created}
      err -> err
    end)
  end

  @doc """
  Retrieves metadata for a specific vector bucket.

  Returns detailed information about a vector bucket including its name, creation time,
  and encryption configuration if available.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance
    * `vector_bucket_name` - Name of the bucket to retrieve

  ## Returns

    * `{:ok, metadata}` - Successfully retrieved bucket metadata
    * `{:error, reason}` - Bucket not found or retrieval failed

  ## Examples

      iex> Supabase.Storage.Vector.get_bucket(vector, "embeddings")
      {:ok, %Supabase.Storage.Vector.Metadata{
        vector_bucket_name: "embeddings",
        creation_time: 1704067200,
        encryption_configuration: %{kms_key_arn: nil, sse_type: nil}
      }}
  """
  @impl true
  def get_bucket(%__MODULE__{} = v, vector_bucket_name)
      when is_binary(vector_bucket_name) do
    v.client
    |> Storage.Request.base("/GetVectorBucket")
    |> Request.with_method(:post)
    |> Request.with_body(%{vector_bucket_name: vector_bucket_name})
    |> Request.with_body_decoder(BodyDecoder, schema: Metadata)
    |> Fetcher.request()
  end

  @doc """
  Lists vector buckets with optional filtering and pagination.

  Supports filtering by name prefix and pagination for large result sets.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance
    * `options` - Optional map with the following keys:
      * `:prefix` - Filter buckets by name prefix (optional)
      * `:max_results` - Maximum number of results to return (default: 100, optional)
      * `:next_token` - Token for pagination from previous response (optional)

  ## Returns

    * `{:ok, response}` - Successfully retrieved bucket list with optional pagination token
    * `{:error, reason}` - List operation failed

  ## Examples

      # List all buckets
      iex> Supabase.Storage.Vector.list_buckets(vector)
      {:ok, %{vector_buckets: [%{vector_bucket_name: "embeddings"}], next_token: nil}}

      # Filter by prefix
      iex> Supabase.Storage.Vector.list_buckets(vector, %{prefix: "prod-"})
      {:ok, %{vector_buckets: [%{vector_bucket_name: "prod-embeddings"}], next_token: nil}}

      # Paginate results
      iex> Supabase.Storage.Vector.list_buckets(vector, %{max_results: 10, next_token: "..."})
      {:ok, %{vector_buckets: [...], next_token: "next_page_token"}}
  """
  @impl true
  def list_buckets(%__MODULE__{} = v, options \\ %{max_results: 100}) do
    v.client
    |> Storage.Request.base("/ListVectorBuckets")
    |> Request.with_method(:post)
    |> Request.with_body(options)
    |> Request.with_body_decoder(BodyDecoder, schema: Metadata)
    |> Fetcher.request()
  end

  @doc """
  Deletes a vector bucket.

  **Important:** The bucket must be empty before it can be deleted. All vector indexes
  and their contents must be removed first.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance
    * `vector_bucket_name` - Name of the bucket to delete

  ## Returns

    * `{:ok, :deleted}` - Bucket was successfully deleted
    * `{:error, reason}` - Deletion failed (e.g., bucket not empty or doesn't exist)

  ## Examples

      iex> Supabase.Storage.Vector.delete_bucket(vector, "old-embeddings")
      {:ok, :deleted}

      iex> Supabase.Storage.Vector.delete_bucket(vector, "embeddings")
      {:error, %{message: "Bucket must be empty before deletion"}}
  """
  @impl true
  def delete_bucket(%__MODULE__{} = v, vector_bucket_name)
      when is_binary(vector_bucket_name) do
    v.client
    |> Storage.Request.base("/DeleteVectorBucket")
    |> Request.with_method(:post)
    |> Request.with_body(%{vector_bucket_name: vector_bucket_name})
    |> Fetcher.request()
    |> then(fn
      {:ok, _} -> {:ok, :deleted}
      err -> err
    end)
  end
end
