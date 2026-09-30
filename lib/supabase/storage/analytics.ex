defmodule Supabase.Storage.Analytics do
  @moduledoc """
  API for managing analytics buckets in Supabase Storage.

  Analytics buckets are optimized for analytical queries and data processing,
  exposing their data through an Iceberg REST catalog. Use `from/2` to obtain
  an `Supabase.Storage.Iceberg` catalog client scoped to a bucket.

  > #### Public Alpha {: .warning}
  >
  > This API is currently in public alpha. Features and interfaces may change
  > as the API evolves. Use in production environments at your own discretion.

  ## Example

      # Create an analytics client
      analytics = Supabase.Storage.Analytics.from(client)

      # Create a new analytics bucket
      {:ok, bucket} = Supabase.Storage.Analytics.create_bucket(analytics, "analytics-data")

      # List all analytics buckets
      {:ok, buckets} = Supabase.Storage.Analytics.list_buckets(analytics)

      # Delete a bucket (must be empty)
      {:ok, :deleted} = Supabase.Storage.Analytics.delete_bucket(analytics, "analytics-data")
  """

  alias Supabase.Client
  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request
  alias Supabase.Storage
  alias Supabase.Storage.AnalyticsBucket
  alias Supabase.Storage.BodyDecoder

  @typedoc """
  Analytics client instance holding the Supabase client.
  """
  @type t :: %__MODULE__{client: Client.t()}

  defstruct [:client]

  @doc """
  Creates a new Analytics client instance.

  ## Parameters

    * `client` - A `Supabase.Client` instance

  ## Examples

      iex> analytics = Supabase.Storage.Analytics.from(client)
      %Supabase.Storage.Analytics{client: client}
  """
  @spec from(Client.t()) :: t
  def from(%Client{} = client), do: %__MODULE__{client: client}

  @doc """
  Creates a new analytics bucket.

  ## Parameters

    * `a` - A `Supabase.Storage.Analytics` instance
    * `name` - A unique name for the bucket

  ## Examples

      iex> Supabase.Storage.Analytics.create_bucket(analytics, "analytics-data")
      {:ok, %Supabase.Storage.AnalyticsBucket{name: "analytics-data", format: "iceberg"}}
  """
  @spec create_bucket(t, String.t()) :: Supabase.result(AnalyticsBucket.t())
  def create_bucket(%__MODULE__{} = a, name) when is_binary(name) do
    with {:ok, %{body: body}} <-
           a.client
           |> Storage.Request.base("/iceberg/bucket")
           |> Request.with_method(:post)
           |> Request.with_body(%{name: name})
           |> Request.with_body_decoder(BodyDecoder, schema: AnalyticsBucket)
           |> Fetcher.request() do
      {:ok, body}
    end
  end

  @doc """
  Lists all analytics buckets in the current project, with optional pagination,
  sorting and search.

  ## Parameters

    * `a` - A `Supabase.Storage.Analytics` instance
    * `options` - Optional map or keyword list with the following keys:
      * `:limit` - Maximum number of buckets to return
      * `:offset` - Number of buckets to skip
      * `:sort_column` - Column to sort by: `:name`, `:created_at` or `:updated_at`
      * `:sort_order` - Sort order: `:asc` or `:desc`
      * `:search` - Search term to filter bucket names

  ## Examples

      iex> Supabase.Storage.Analytics.list_buckets(analytics)
      {:ok, [%Supabase.Storage.AnalyticsBucket{name: "analytics-data"}]}

      iex> Supabase.Storage.Analytics.list_buckets(analytics, limit: 10, sort_order: :desc)
      {:ok, [%Supabase.Storage.AnalyticsBucket{...}]}
  """
  @spec list_buckets(t, Enumerable.t()) :: Supabase.result(list(AnalyticsBucket.t()))
  def list_buckets(%__MODULE__{} = a, options \\ []) do
    options = Map.new(options)

    query =
      %{}
      |> maybe_put("limit", options[:limit])
      |> maybe_put("offset", options[:offset])
      |> maybe_put("sortColumn", options[:sort_column])
      |> maybe_put("sortOrder", options[:sort_order])
      |> maybe_put("search", options[:search])

    with {:ok, %{body: body}} <-
           a.client
           |> Storage.Request.base("/iceberg/bucket")
           |> Request.with_method(:get)
           |> Request.with_query(query)
           |> Request.with_body_decoder(BodyDecoder, schema: AnalyticsBucket)
           |> Fetcher.request() do
      {:ok, body}
    end
  end

  @doc """
  Deletes an analytics bucket. The bucket must be empty before it can be deleted.

  ## Parameters

    * `a` - A `Supabase.Storage.Analytics` instance
    * `name` - The unique name of the bucket to delete

  ## Examples

      iex> Supabase.Storage.Analytics.delete_bucket(analytics, "analytics-data")
      {:ok, :deleted}
  """
  @spec delete_bucket(t, String.t()) :: Supabase.result(:deleted)
  def delete_bucket(%__MODULE__{} = a, name) when is_binary(name) do
    with {:ok, _} <-
           a.client
           |> Storage.Request.base("/iceberg/bucket/#{URI.encode(name)}")
           |> Request.with_method(:delete)
           |> Fetcher.request() do
      {:ok, :deleted}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, to_string(value))
end
