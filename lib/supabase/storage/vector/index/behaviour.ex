defmodule Supabase.Storage.Vector.Index.Behaviour do
  @moduledoc """
  Defines the behaviour interface for vector data operations.

  This behaviour specifies the contract for managing vectors within indexes,
  including insertion, retrieval, listing, querying, and deletion operations.
  """

  alias Supabase.Storage.Vector.Behaviour, as: Vector
  alias Supabase.Storage.Vector.Index

  @typedoc """
  Options for inserting/updating a single vector.

  ## Options

    * `{:key, String.t()}` - Unique identifier for the vector
    * `{:data, %{float32: list(float)}}` - Vector embedding data as float32 array
    * `{:metadata, map | nil}` - Optional arbitrary JSON metadata
  """
  @type put_vector_opt ::
          {:key, String.t()} | {:data, %{float32: list(float)}} | {:metadata, map | nil}

  @typedoc """
  Options for retrieving vectors.

  ## Options

    * `{:keys, list(String.t())}` - List of vector keys to retrieve
    * `{:return_data, boolean | nil}` - Whether to include vector data in response
    * `{:return_metadata, boolean | nil}` - Whether to include metadata in response
  """
  @type get_vector_opt ::
          {:keys, list(String.t())}
          | {:return_data, boolean | nil}
          | {:return_metadata, boolean | nil}

  @typedoc """
  Vector match result with optional data, metadata, and distance.

  ## Fields

    * `:key` - Unique identifier for the vector
    * `:data` - Vector embedding data (if requested)
    * `:metadata` - Arbitrary metadata (if requested)
    * `:distance` - Similarity distance from query vector (if requested)
  """
  @type vector_match :: %{
          key: String.t(),
          data: nil | %{float32: list(float)},
          metadata: map | nil,
          distance: number | nil
        }

  @typedoc """
  Options for listing vectors with pagination.

  ## Options

    * `{:max_results, integer | nil}` - Maximum results (default: 500, max: 1000)
    * `{:next_token, String.t() | nil}` - Pagination token from previous response
    * `{:return_data, boolean | nil}` - Whether to include vector data
    * `{:return_metadata, boolean | nil}` - Whether to include metadata
    * `{:segment_count, integer | nil}` - Total parallel segments (1-16)
    * `{:segment_index, integer | nil}` - Zero-based segment index (0 to segment_count-1)
  """
  @type list_vector_opt ::
          {:max_results, integer | nil}
          | {:next_token, String.t() | nil}
          | {:return_data, boolean | nil}
          | {:return_metadata, boolean | nil}
          | {:segment_count, integer | nil}
          | {:segment_index, integer | nil}

  @typedoc """
  Options for querying similar vectors.

  ## Options

    * `{:query_vector, %{float32: list(float)}}` - Query vector for similarity search
    * `{:topK, integer | nil}` - Number of nearest neighbors to return (default: 10)
    * `{:filter, map | nil}` - Optional JSON filter for metadata
    * `{:return_distance, boolean | nil}` - Whether to include distance scores
    * `{:return_metadata, boolean | nil}` - Whether to include metadata in results
  """
  @type query_vector_opt ::
          {:query_vector, %{float32: list(float)}}
          | {:topK, integer | nil}
          | {:filter, map | nil}
          | {:return_distance, boolean | nil}
          | {:return_metadata, boolean | nil}

  @callback put_vectors(Vector.bucket(), Enumerable.t(put_vector_opt)) :: Supabase.result(:put)
  @callback get_vectors(Vector.bucket(), Enumerable.t(get_vector_opt)) ::
              Supabase.result(vector_match)
  @callback list_vectors(Vector.bucket(), Enumerable.t(list_vector_opt)) ::
              Supabase.result(%{vectors: list(vector_match), next_token: String.t() | nil})
  @callback query_vector(Vector.bucket(), Enumerable.t(query_vector_opt)) ::
              Supabase.result(%{
                vectors: list(vector_match),
                distance_metric: Index.distance_metric() | nil
              })

  @callback delete_vectors(Vector.bucket(), keys :: list(String.t())) :: Supabase.result(:deleted)
end
