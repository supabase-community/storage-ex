defmodule Supabase.Storage.Vector.Index do
  @moduledoc """
  Operations for managing vector data within indexes.

  This module provides functions for inserting, retrieving, listing, querying,
  and deleting vectors within a specific index. All operations require a
  `Supabase.Storage.Vector` instance with both `vector_bucket_name` and
  `vector_index_name` set.

  ## Usage

      # Scope to bucket and index
      index = Supabase.Storage.Vector.from(client, "embeddings")
              |> Supabase.Storage.Vector.index("documents")

      # Insert vectors
      Supabase.Storage.Vector.Index.put_vectors(index, %{
        vectors: [
          %{key: "doc-1", data: %{float32: [0.1, 0.2, ...]}, metadata: %{title: "Intro"}}
        ]
      })

      # Query similar vectors
      Supabase.Storage.Vector.Index.query_vector(index, %{
        query_vector: %{float32: [0.1, 0.2, ...]},
        topK: 5,
        return_distance: true
      })
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request
  alias Supabase.Storage
  alias Supabase.Storage.Vector

  @behaviour Supabase.Storage.Vector.Index.Behaviour

  @distance_metrics ~w(cosine euclidean dotproduct)a

  @typedoc "Data type for vector components, currently only float32 is supported"
  @type data_type :: :float32

  @typedoc "Distance metrics for similarity calculations"
  @type distance_metric :: :cosine | :euclidean | :dotproduct

  @typedoc """
  Vector index metadata structure.

  ## Fields

    * `:index_name` - Unique name of the index within the bucket
    * `:vector_bucket_name` - Name of the parent vector bucket
    * `:dimension` - Dimensionality of vectors (e.g., 384, 768, 1536)
    * `:data_type` - Data type of vector components (currently only `:float32`)
    * `:distance_metric` - Similarity metric used for queries
    * `:creation_time` - Unix timestamp when the index was created
    * `:metadata_configuration` - Configuration for metadata filtering
      * `:non_filterable_metadata_keys` - Keys that cannot be used in filters
  """
  @type t :: %__MODULE__{
          index_name: String.t(),
          vector_bucket_name: String.t(),
          dimension: integer,
          data_type: data_type,
          distance_metric: distance_metric,
          creation_time: integer | nil,
          metadata_configuration:
            nil
            | %__MODULE__.MetadataConfiguration{
                non_filterable_metadata_keys: list(String.t()) | nil
              }
        }

  @fields ~w(index_name vector_bucket_name dimension data_type distance_metric creation_time)a
  @required_fields @fields -- [:creation_time]

  @derive Code.ensure_loaded!(Supabase) && Module.concat(Supabase.json_library(), Encoder)

  @primary_key false
  embedded_schema do
    field(:index_name, :string)
    field(:vector_bucket_name, :string)
    field(:dimension, :integer)
    field(:data_type, Ecto.Enum, values: [:float32])
    field(:distance_metric, Ecto.Enum, values: @distance_metrics)
    field(:creation_time, :integer)

    embeds_one :metadata_configuration, MetadataConfiguration, primary_key: false do
      field(:non_filterable_metadata_keys, {:array, :string})
    end
  end

  @doc """
  Inserts or updates vectors in batch (1-500 vectors per request).

  Vectors are upserted by their key - if a key already exists, it will be updated.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with both bucket and index names set
    * `params` - Map with:
      * `:vectors` - List of vector objects (1-500 items, required):
        * `:key` - Unique identifier for the vector
        * `:data` - Vector embedding data: `%{float32: [...]}`
        * `:metadata` - Optional arbitrary JSON metadata

  ## Returns

    * `{:ok, :put}` - Vectors were successfully inserted/updated
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> index = Supabase.Storage.Vector.from(client, "embeddings")
      ...>         |> Supabase.Storage.Vector.index("documents")
      iex> Supabase.Storage.Vector.Index.put_vectors(index, %{
      ...>   vectors: [
      ...>     %{
      ...>       key: "doc-1",
      ...>       data: %{float32: [0.1, 0.2, 0.3]},
      ...>       metadata: %{title: "Introduction", page: 1}
      ...>     }
      ...>   ]
      ...> })
      {:ok, :put}
  """
  @impl true
  def put_vectors(%Vector{} = v, params \\ %{})
      when not (is_nil(v.vector_bucket_name) or is_nil(v.vector_index_name)) do
    with {:ok, %{vectors: vectors}} <- validate_put_vectors(Map.new(params)) do
      body = %{
        vectorBucketName: v.vector_bucket_name,
        indexName: v.vector_index_name,
        vectors: vectors
      }

      v.client
      |> Storage.Request.base("/vector/PutVectors")
      |> Request.with_method(:post)
      |> Request.with_body(body)
      |> Fetcher.request()
      |> then(fn
        {:ok, _} -> {:ok, :put}
        err -> err
      end)
    end
  end

  @doc """
  Retrieves vectors by their keys in batch.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with both bucket and index names set
    * `opts` - Map with:
      * `:keys` - List of vector keys to retrieve (required)
      * `:return_data` - Whether to include vector data in response (optional, default: false)
      * `:return_metadata` - Whether to include metadata in response (optional, default: false)

  ## Returns

    * `{:ok, response}` - Successfully retrieved vectors
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> index = Supabase.Storage.Vector.from(client, "embeddings")
      ...>         |> Supabase.Storage.Vector.index("documents")
      iex> Supabase.Storage.Vector.Index.get_vectors(index, %{
      ...>   keys: ["doc-1", "doc-2"],
      ...>   return_data: true,
      ...>   return_metadata: true
      ...> })
      {:ok, %Response{body: %{"vectors" => [...]}}}
  """
  @impl true
  def get_vectors(%Vector{} = v, opts \\ %{})
      when not (is_nil(v.vector_bucket_name) or is_nil(v.vector_index_name)) do
    opts = Map.new(opts)

    body =
      %{vectorBucketName: v.vector_bucket_name, indexName: v.vector_index_name}
      |> maybe_put(:keys, opts[:keys])
      |> maybe_put(:returnData, opts[:return_data])
      |> maybe_put(:returnMetadata, opts[:return_metadata])

    v.client
    |> Storage.Request.base("/vector/GetVectors")
    |> Request.with_method(:post)
    |> Request.with_body(body)
    |> Fetcher.request()
  end

  @doc """
  Lists vectors in the index with pagination.

  Supports parallel scanning via segment configuration for faster iteration over large datasets.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with both bucket and index names set
    * `opts` - Map with:
      * `:max_results` - Maximum number of results to return (optional, default: 500, max: 1000)
      * `:next_token` - Token for pagination from previous response (optional)
      * `:return_data` - Whether to include vector data in response (optional, default: false)
      * `:return_metadata` - Whether to include metadata in response (optional, default: false)
      * `:segment_count` - Total number of parallel segments for scanning (optional, 1-16)
      * `:segment_index` - Zero-based index of this segment (optional, 0 to segment_count-1)

  ## Returns

    * `{:ok, response}` - Successfully retrieved vectors with pagination token
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> index = Supabase.Storage.Vector.from(client, "embeddings")
      ...>         |> Supabase.Storage.Vector.index("documents")
      iex> Supabase.Storage.Vector.Index.list_vectors(index, %{
      ...>   max_results: 100,
      ...>   return_metadata: true
      ...> })
      {:ok, %Response{body: %{"vectors" => [...], "nextToken" => "..."}}}
  """
  @impl true
  def list_vectors(%Vector{} = v, opts \\ %{}) do
    opts = Map.new(opts)

    with {:ok, opts} <- validate_list_vectors(opts) do
      body =
        %{vectorBucketName: v.vector_bucket_name, indexName: v.vector_index_name}
        |> maybe_put(:maxResults, opts[:max_results])
        |> maybe_put(:nextToken, opts[:next_token])
        |> maybe_put(:returnData, opts[:return_data])
        |> maybe_put(:returnMetadata, opts[:return_metadata])
        |> maybe_put(:segmentCount, opts[:segment_count])
        |> maybe_put(:segmentIndex, opts[:segment_index])

      v.client
      |> Storage.Request.base("/vector/ListVectors")
      |> Request.with_method(:post)
      |> Request.with_body(body)
      |> Fetcher.request()
    end
  end

  @doc """
  Queries for similar vectors using approximate nearest neighbor (ANN) search.

  Finds the most similar vectors to the query vector based on the index's distance metric.

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with both bucket and index names set
    * `query` - Map with:
      * `:query_vector` - Query vector to find similar vectors: `%{float32: [...]}` (required)
      * `:topK` - Number of nearest neighbors to return (optional, default: 10)
      * `:filter` - Optional JSON filter for metadata (optional)
      * `:return_distance` - Whether to include distance scores (optional, default: false)
      * `:return_metadata` - Whether to include metadata in results (optional, default: false)

  ## Returns

    * `{:ok, response}` - Successfully retrieved similar vectors ordered by distance
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> index = Supabase.Storage.Vector.from(client, "embeddings")
      ...>         |> Supabase.Storage.Vector.index("documents")
      iex> Supabase.Storage.Vector.Index.query_vector(index, %{
      ...>   query_vector: %{float32: [0.1, 0.2, 0.3]},
      ...>   topK: 5,
      ...>   filter: %{category: "technical"},
      ...>   return_distance: true,
      ...>   return_metadata: true
      ...> })
      {:ok, %Response{body: %{
        "vectors" => [%{"key" => "doc-1", "distance" => 0.95, ...}],
        "distanceMetric" => "cosine"
      }}}
  """
  @impl true
  def query_vector(%Vector{} = v, query \\ %{})
      when not (is_nil(v.vector_bucket_name) or is_nil(v.vector_index_name)) do
    query = Map.new(query)

    body =
      %{vectorBucketName: v.vector_bucket_name, indexName: v.vector_index_name}
      |> maybe_put(:queryVector, query[:query_vector])
      |> maybe_put(:topK, query[:topK])
      |> maybe_put(:filter, query[:filter])
      |> maybe_put(:returnDistance, query[:return_distance])
      |> maybe_put(:returnMetadata, query[:return_metadata])

    v.client
    |> Storage.Request.base("/vector/QueryVectors")
    |> Request.with_method(:post)
    |> Request.with_body(body)
    |> Fetcher.request()
  end

  @doc """
  Deletes vectors by their keys in batch (1-500 keys per request).

  ## Parameters

    * `v` - A `Supabase.Storage.Vector` instance with both bucket and index names set
    * `keys` - List of vector keys to delete (1-500 items, required)

  ## Returns

    * `{:ok, :deleted}` - Vectors were successfully deleted
    * `{:error, reason}` - Operation failed

  ## Examples

      iex> index = Supabase.Storage.Vector.from(client, "embeddings")
      ...>         |> Supabase.Storage.Vector.index("documents")
      iex> Supabase.Storage.Vector.Index.delete_vectors(index, ["doc-1", "doc-2", "doc-3"])
      {:ok, :deleted}
  """
  @impl true
  def delete_vectors(%Vector{} = v, keys)
      when not (is_nil(v.vector_bucket_name) or is_nil(v.vector_index_name)) and is_list(keys) do
    with {:ok, _} <- validate_delete_vectors(keys) do
      v.client
      |> Storage.Request.base("/vector/DeleteVectors")
      |> Request.with_method(:post)
      |> Request.with_body(%{
        vectorBucketName: v.vector_bucket_name,
        indexName: v.vector_index_name,
        keys: keys
      })
      |> Fetcher.request()
      |> then(fn
        {:ok, _} -> {:ok, :deleted}
        err -> err
      end)
    end
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
    |> changeset(normalize_response(attrs))
    |> apply_action(:parse)
  end

  # The vectors API returns camelCase JSON keys; translate the known
  # response keys to the snake_case fields before casting.
  defp normalize_response(attrs) when is_map(attrs) do
    attrs
    |> rename_key("indexName", "index_name")
    |> rename_key("vectorBucketName", "vector_bucket_name")
    |> rename_key("dataType", "data_type")
    |> rename_key("distanceMetric", "distance_metric")
    |> rename_key("creationTime", "creation_time")
    |> normalize_metadata_configuration()
  end

  defp normalize_metadata_configuration(attrs) do
    case Map.pop(attrs, "metadataConfiguration") do
      {nil, attrs} ->
        attrs

      {config, attrs} when is_map(config) ->
        config = rename_key(config, "nonFilterableMetadataKeys", "non_filterable_metadata_keys")

        Map.put(attrs, "metadata_configuration", config)
    end
  end

  defp rename_key(map, from, to) do
    case Map.pop(map, from) do
      {nil, map} -> map
      {value, map} -> Map.put(map, to, value)
    end
  end

  def changeset(%__MODULE__{} = i, %{} = attrs) do
    i
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> cast_embed(:metadata_configuration, with: &metadata_changeset/2, required: false)
  end

  def create_changeset(%__MODULE__{} = i, %{} = attrs) do
    i
    |> cast(attrs, @fields -- [:creation_time])
    |> validate_required(@required_fields)
    |> cast_embed(:metadata_configuration, with: &metadata_changeset/2, required: false)
  end

  defp metadata_changeset(meta, attrs) do
    cast(meta, attrs, [:non_filterable_metadata_keys])
  end

  defp validate_put_vectors(params) do
    types = %{vectors: {:array, :map}}

    {%{}, types}
    |> cast(params, [:vectors])
    |> validate_required([:vectors])
    |> validate_length(:vectors, min: 1, max: 500, message: "must be between 1 and 500 items")
    |> apply_action(:validate)
  end

  defp validate_delete_vectors(keys) do
    types = %{keys: {:array, :string}}

    {%{}, types}
    |> cast(%{keys: keys}, [:keys])
    |> validate_required([:keys])
    |> validate_length(:keys, min: 1, max: 500, message: "must be between 1 and 500 items")
    |> apply_action(:validate)
    |> case do
      {:ok, _} -> {:ok, keys}
      error -> error
    end
  end

  defp validate_list_vectors(opts) do
    types = %{
      segment_count: :integer,
      segment_index: :integer,
      max_results: :integer,
      next_token: :string,
      return_data: :boolean,
      return_metadata: :boolean
    }

    {%{}, types}
    |> cast(opts, Map.keys(types))
    |> validate_number(:segment_count,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 16
    )
    |> validate_number(:segment_index, greater_than_or_equal_to: 0)
    |> validate_segment_index()
    |> apply_action(:validate)
    |> case do
      {:ok, validated} -> {:ok, Map.merge(opts, Map.new(validated))}
      error -> error
    end
  end

  defp validate_segment_index(changeset) do
    segment_count = get_field(changeset, :segment_count)
    segment_index = get_field(changeset, :segment_index)

    if segment_count && segment_index && segment_index >= segment_count do
      add_error(
        changeset,
        :segment_index,
        "must be between 0 and #{segment_count - 1}"
      )
    else
      changeset
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
