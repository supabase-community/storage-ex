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
  alias Supabase.Storage.Vector.Index
  alias Supabase.Storage.Vector.Metadata

  @behaviour Supabase.Storage.Vector.Behaviour

  @typedoc """
  Vector client instance containing the Supabase client and optional bucket name.
  """
  @type t :: %__MODULE__{
          client: Client.t(),
          vector_bucket_name: String.t() | nil,
          vector_index_name: String.t() | nil
        }

  defstruct [:client, :vector_bucket_name, :vector_index_name]

  @doc """
  Creates a new Vector client instance.

  ## Parameters

    * `client` - A `Supabase.Client` instance
    * `vector_bucket_name` - Optional default bucket name to use for operations (default: `nil`)
    * `vector_index_name` - Optional default index name to use for operations (default: `nil`)

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
    %__MODULE__{
      client: client,
      vector_bucket_name: vector_bucket_name
    }
  end

  @doc """
  Scopes the vector client to a specific index within the current bucket.

  This convenience method creates a new client instance with both bucket and index
  names set, allowing index-scoped operations like `put_vectors/2`, `query_vector/2`, etc.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with `vector_bucket_name` set
    * `index_name` - Name of the index to scope operations to (optional)

  ## Returns

  A `Supabase.Storage.Vector` struct with `vector_index_name` set.

  ## Examples

      iex> vector = Supabase.Storage.Vector.from(client, "embeddings")
      iex> index = Supabase.Storage.Vector.index(vector, "documents")
      %Supabase.Storage.Vector{
        client: client,
        vector_bucket_name: "embeddings",
        vector_index_name: "documents"
      }

      # Now you can perform vector operations
      iex> Supabase.Storage.Vector.Index.put_vectors(index, %{vectors: [...]})
  """
  def index(%__MODULE__{} = v, index_name \\ nil) do
    %{v | vector_index_name: index_name}
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
    |> Storage.Request.base("/vector/CreateVectorBucket")
    |> Request.with_method(:post)
    |> Request.with_body(%{vectorBucketName: vector_bucket_name})
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
    |> Storage.Request.base("/vector/GetVectorBucket")
    |> Request.with_method(:post)
    |> Request.with_body(%{vectorBucketName: vector_bucket_name})
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
    options = Map.new(options)

    body =
      %{}
      |> maybe_put(:prefix, options[:prefix])
      |> maybe_put(:maxResults, options[:max_results])
      |> maybe_put(:nextToken, options[:next_token])

    v.client
    |> Storage.Request.base("/vector/ListVectorBuckets")
    |> Request.with_method(:post)
    |> Request.with_body(body)
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
    |> Storage.Request.base("/vector/DeleteVectorBucket")
    |> Request.with_method(:post)
    |> Request.with_body(%{vectorBucketName: vector_bucket_name})
    |> Fetcher.request()
    |> then(fn
      {:ok, _} -> {:ok, :deleted}
      err -> err
    end)
  end

  @doc """
  Creates a new vector index within the current bucket.

  Vector indexes define the structure for storing and querying vectors, including
  the dimension, distance metric, and optional metadata configuration.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with `vector_bucket_name` set
    * `params` - Map with index configuration:
      * `:index_name` - Unique name for the index (required)
      * `:data_type` - Data type of vectors, currently only `:float32` (required)
      * `:dimension` - Dimensionality of vectors, e.g., 384, 768, 1536 (required)
      * `:distance_metric` - Similarity metric: `:cosine`, `:euclidean`, or `:dotproduct` (required)
      * `:metadata_configuration` - Optional metadata settings (optional)
        * `:non_filterable_metadata_keys` - List of metadata keys that cannot be used in filters

  ## Returns

    * `{:ok, :created}` - Index was successfully created
    * `{:error, reason}` - Creation failed

  ## Examples

      iex> vector = Supabase.Storage.Vector.from(client, "embeddings")
      iex> Supabase.Storage.Vector.create_index(vector, %{
      ...>   index_name: "documents-openai",
      ...>   data_type: :float32,
      ...>   dimension: 1536,
      ...>   distance_metric: :cosine,
      ...>   metadata_configuration: %{
      ...>     non_filterable_metadata_keys: ["raw_text"]
      ...>   }
      ...> })
      {:ok, :created}
  """
  @impl true
  def create_index(%__MODULE__{} = v, params \\ %{}) when not is_nil(v.vector_bucket_name) do
    params =
      params
      |> Map.new()
      |> Map.put_new(:vector_bucket_name, v.vector_bucket_name)

    changeset = Index.create_changeset(%Index{}, params)

    with {:ok, index} <- Ecto.Changeset.apply_action(changeset, :create) do
      body = %{
        vectorBucketName: index.vector_bucket_name,
        indexName: index.index_name,
        dataType: index.data_type,
        dimension: index.dimension,
        distanceMetric: index.distance_metric
      }

      body =
        case index.metadata_configuration do
          nil ->
            body

          config ->
            metadata_configuration =
              maybe_put(%{}, :nonFilterableMetadataKeys, config.non_filterable_metadata_keys)

            Map.put(body, :metadataConfiguration, metadata_configuration)
        end

      v.client
      |> Storage.Request.base("/vector/CreateIndex")
      |> Request.with_method(:post)
      |> Request.with_body(body)
      |> Fetcher.request()
      |> then(fn
        {:ok, _} -> {:ok, :created}
        err -> err
      end)
    end
  end

  @doc """
  Retrieves metadata for a specific vector index.

  Returns detailed configuration about a vector index including its dimension,
  distance metric, and metadata configuration.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with `vector_bucket_name` set
    * `index_name` - Name of the index to retrieve

  ## Returns

    * `{:ok, response}` - Successfully retrieved index metadata
    * `{:error, reason}` - Index not found or retrieval failed

  ## Examples

      iex> vector = Supabase.Storage.Vector.from(client, "embeddings")
      iex> Supabase.Storage.Vector.get_index(vector, "documents-openai")
      {:ok, %Response{body: %{
        "index" => %{
          "indexName" => "documents-openai",
          "dimension" => 1536,
          "distanceMetric" => "cosine",
          "dataType" => "float32"
        }
      }}}
  """
  @impl true
  def get_index(%__MODULE__{} = v, index_name)
      when not is_nil(v.vector_bucket_name) and is_binary(index_name) do
    v.client
    |> Storage.Request.base("/vector/GetIndex")
    |> Request.with_method(:post)
    |> Request.with_body(%{vectorBucketName: v.vector_bucket_name, indexName: index_name})
    |> Request.with_body_decoder(BodyDecoder, schema: Index)
    |> Fetcher.request()
  end

  @doc """
  Lists vector indexes within the current bucket with optional filtering and pagination.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with `vector_bucket_name` set
    * `options` - Optional map with the following keys:
      * `:prefix` - Filter indexes by name prefix (optional)
      * `:max_results` - Maximum number of results to return (default: 100, optional)
      * `:next_token` - Token for pagination from previous response (optional)

  ## Returns

    * `{:ok, response}` - Successfully retrieved index list with optional pagination token
    * `{:error, reason}` - List operation failed

  ## Examples

      iex> vector = Supabase.Storage.Vector.from(client, "embeddings")
      iex> Supabase.Storage.Vector.list_indexes(vector)
      {:ok, %Response{body: %{
        "indexes" => [%{"indexName" => "documents-openai"}],
        "nextToken" => nil
      }}}

      # Filter by prefix
      iex> Supabase.Storage.Vector.list_indexes(vector, %{prefix: "documents-"})
      {:ok, %Response{body: %{"indexes" => [...]}}}
  """
  @impl true
  def list_indexes(%__MODULE__{} = v, options \\ %{max_results: 100})
      when not is_nil(v.vector_bucket_name) do
    options = Map.new(options)

    body =
      %{vectorBucketName: v.vector_bucket_name}
      |> maybe_put(:prefix, options[:prefix])
      |> maybe_put(:maxResults, options[:max_results])
      |> maybe_put(:nextToken, options[:next_token])

    v.client
    |> Storage.Request.base("/vector/ListIndexes")
    |> Request.with_method(:post)
    |> Request.with_body(body)
    |> Fetcher.request()
  end

  @doc """
  Deletes a vector index and all its data.

  **Important:** This operation permanently deletes the index and all vectors stored in it.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with `vector_bucket_name` set
    * `index_name` - Name of the index to delete

  ## Returns

    * `{:ok, :deleted}` - Index was successfully deleted
    * `{:error, reason}` - Deletion failed

  ## Examples

      iex> vector = Supabase.Storage.Vector.from(client, "embeddings")
      iex> Supabase.Storage.Vector.delete_index(vector, "old-index")
      {:ok, :deleted}
  """
  @impl true
  def delete_index(%__MODULE__{} = v, index_name)
      when not is_nil(v.vector_bucket_name) and is_binary(index_name) do
    v.client
    |> Storage.Request.base("/vector/DeleteIndex")
    |> Request.with_method(:post)
    |> Request.with_body(%{vectorBucketName: v.vector_bucket_name, indexName: index_name})
    |> Fetcher.request()
    |> then(fn
      {:ok, _} -> {:ok, :deleted}
      err -> err
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
