defmodule Supabase.Storage.Vector.Behaviour do
  @moduledoc """
  Defines the behaviour interface for vector bucket operations.

  This behaviour specifies the contract that implementations of vector storage
  management must follow. It includes operations for creating, retrieving, listing,
  and deleting vector buckets.
  """

  alias Supabase.Storage.Vector.Index

  @typedoc "Vector client instance"
  @type bucket :: Supabase.Storage.Vector.t()

  @typedoc "Vector bucket metadata"
  @type metadata :: Supabase.Storage.Vector.Metadata.t()

  @typedoc "Supabase client instance"
  @type client :: Supabase.Client.t()

  @typedoc """
  Options for listing vector buckets.

  ## Options

    * `{:prefix, String.t() | nil}` - Filter buckets by name prefix
    * `{:max_results, integer | nil}` - Maximum number of results to return (default: 100)
    * `{:next_token, String.t() | nil}` - Pagination token from previous response
  """
  @type list_opt ::
          {:prefix, String.t() | nil}
          | {:max_results, integer | nil}
          | {:next_token, String.t() | nil}

  @callback from(client) :: bucket
  @callback from(client, Enumerable.t(opt)) :: bucket
            when opt:
                   {:vector_bucket_name, String.t() | nil}
                   | {:vector_index_name, String.t() | nil}
  @callback create_bucket(bucket, name :: String.t()) :: Supabase.result(:created)
  @callback get_bucket(bucket, name :: String.t()) :: Supabase.result(metadata | nil)
  @callback list_buckets(bucket, Enumerable.t(list_opt)) ::
              Supabase.result(%{
                vector_buckets:
                  list(%{vector_bucket_name: String.t(), next_token: String.t() | nil})
              })
  @callback delete_bucket(bucket, name :: String.t()) :: Supabase.result(:deleted)

  @type create_index_opt ::
          {:vector_bucket_name, String.t()}
          | {:index_name, String.t()}
          | {:data_type, Index.data_type()}
          | {:distance_metric, Index.distance_metric()}
          | {:metadata_configuration, %{non_filterable_metadata_keys: list(String.t())} | nil}

  @callback create_index(bucket, Enumerable.t(create_index_opt)) :: Supabase.result(:created)
  @callback get_index(bucket, name :: String.t()) :: Supabase.result(Index.t())
  @callback list_indexes(bucket, Enumerable.t(list_opt | {:vector_bucket_name, String.t()})) ::
              Supabase.result(%{
                indexes: list(%{index_name: String.t(), next_token: String.t() | nil})
              })
  @callback delete_index(bucket, name :: String.t()) :: Supabase.result(:deleted)
end
