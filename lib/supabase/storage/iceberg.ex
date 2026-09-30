defmodule Supabase.Storage.Iceberg do
  @moduledoc """
  Thin read-only client for the Apache Iceberg REST catalog exposed by
  Supabase Storage analytics buckets.

  The bucket name maps to the Iceberg warehouse: every catalog path is
  prefixed with `/iceberg/v1/{bucket}`. Responses are returned as decoded
  maps, following the Iceberg REST spec payloads.

  > #### Public Alpha {: .warning}
  >
  > This API is currently in public alpha. Features and interfaces may change
  > as the API evolves. Use in production environments at your own discretion.

  Only read operations are covered for now (list/load namespaces and tables).
  Write operations such as `createTable` and commit may be added later.

  ## Example

      iceberg = Supabase.Storage.Iceberg.from(analytics, "analytics-data")

      {:ok, %{"namespaces" => namespaces}} = Supabase.Storage.Iceberg.list_namespaces(iceberg)

      {:ok, %{"identifiers" => tables}} = Supabase.Storage.Iceberg.list_tables(iceberg, ["default"])

      {:ok, metadata} = Supabase.Storage.Iceberg.load_table(iceberg, ["default"], "events")
  """

  alias Supabase.Client
  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request
  alias Supabase.Storage
  alias Supabase.Storage.Analytics

  @typedoc """
  Iceberg catalog client instance scoped to an analytics bucket (warehouse).
  """
  @type t :: %__MODULE__{client: Client.t(), bucket: String.t()}

  @typedoc """
  An Iceberg namespace, given either as a single name or a list of names for
  nested namespaces (e.g. `["prod", "default"]`).
  """
  @type namespace :: String.t() | list(String.t())

  defstruct [:client, :bucket]

  @doc """
  Creates an Iceberg catalog client for the given analytics bucket.

  ## Parameters

    * `analytics` - A `Supabase.Storage.Analytics` instance
    * `bucket` - The name of the analytics bucket (the Iceberg warehouse)

  ## Examples

      iex> analytics = Supabase.Storage.Analytics.from(client)
      iex> Supabase.Storage.Iceberg.from(analytics, "analytics-data")
      %Supabase.Storage.Iceberg{client: client, bucket: "analytics-data"}
  """
  @spec from(Analytics.t(), String.t()) :: t
  def from(%Analytics{client: %Client{} = client}, bucket) when is_binary(bucket) do
    %__MODULE__{client: client, bucket: bucket}
  end

  @doc """
  Lists namespaces in the catalog.

  ## Parameters

    * `i` - A `Supabase.Storage.Iceberg` instance
    * `options` - Optional keyword list with the following keys:
      * `:parent` - Parent namespace to list under, as a `t:namespace/0`
      * `:page_token` - Pagination token from a previous response
      * `:page_size` - Maximum number of namespaces to return

  ## Examples

      iex> Supabase.Storage.Iceberg.list_namespaces(iceberg)
      {:ok, %{"namespaces" => [["default"]]}}

      iex> Supabase.Storage.Iceberg.list_namespaces(iceberg, parent: ["prod"])
      {:ok, %{"namespaces" => [["prod", "default"]]}}
  """
  @spec list_namespaces(t, keyword) :: Supabase.result(map)
  def list_namespaces(%__MODULE__{} = i, opts \\ []) do
    query =
      %{}
      |> maybe_put("parent", parent_query(Keyword.get(opts, :parent)))
      |> maybe_put("pageToken", Keyword.get(opts, :page_token))
      |> maybe_put("pageSize", Keyword.get(opts, :page_size))

    get(i, namespaces_path(i), query)
  end

  @doc """
  Loads metadata for a namespace.

  ## Examples

      iex> Supabase.Storage.Iceberg.load_namespace(iceberg, ["default"])
      {:ok, %{"namespace" => ["default"], "properties" => %{}}}
  """
  @spec load_namespace(t, namespace) :: Supabase.result(map)
  def load_namespace(%__MODULE__{} = i, namespace) do
    get(i, namespaces_path(i) <> "/" <> encode_namespace(namespace))
  end

  @doc """
  Lists tables within a namespace.

  ## Parameters

    * `i` - A `Supabase.Storage.Iceberg` instance
    * `namespace` - The namespace to list tables from, as a `t:namespace/0`
    * `options` - Optional keyword list with the following keys:
      * `:page_token` - Pagination token from a previous response
      * `:page_size` - Maximum number of tables to return

  ## Examples

      iex> Supabase.Storage.Iceberg.list_tables(iceberg, ["default"])
      {:ok, %{"identifiers" => [%{"namespace" => ["default"], "name" => "events"}]}}
  """
  @spec list_tables(t, namespace, keyword) :: Supabase.result(map)
  def list_tables(%__MODULE__{} = i, namespace, opts \\ []) do
    query =
      %{}
      |> maybe_put("pageToken", Keyword.get(opts, :page_token))
      |> maybe_put("pageSize", Keyword.get(opts, :page_size))

    get(i, tables_path(i, namespace), query)
  end

  @doc """
  Loads metadata for a table, including its schema, partition spec and
  location, following the Iceberg REST `LoadTableResponse` payload.

  ## Examples

      iex> Supabase.Storage.Iceberg.load_table(iceberg, ["default"], "events")
      {:ok, %{"metadata-location" => "s3://...", "metadata" => %{...}}}
  """
  @spec load_table(t, namespace, String.t()) :: Supabase.result(map)
  def load_table(%__MODULE__{} = i, namespace, table) when is_binary(table) do
    get(i, tables_path(i, namespace) <> "/" <> URI.encode(table))
  end

  defp get(%__MODULE__{} = i, path, query \\ %{}) do
    with {:ok, %{body: body}} <-
           i.client
           |> Storage.Request.base(path)
           |> Request.with_method(:get)
           |> Request.with_query(query)
           |> Fetcher.request() do
      {:ok, body}
    end
  end

  defp namespaces_path(%__MODULE__{bucket: bucket}) do
    "/iceberg/v1/#{URI.encode(bucket)}/namespaces"
  end

  defp tables_path(%__MODULE__{} = i, namespace) do
    namespaces_path(i) <> "/" <> encode_namespace(namespace) <> "/tables"
  end

  # The Iceberg REST spec encodes multi-level namespaces with the 0x1F
  # (unit separator) character.
  defp encode_namespace(namespace) when is_binary(namespace), do: URI.encode(namespace)

  defp encode_namespace(namespace) when is_list(namespace) do
    namespace |> Enum.join(<<0x1F>>) |> URI.encode()
  end

  defp parent_query(nil), do: nil
  defp parent_query(parent) when is_binary(parent), do: parent
  defp parent_query(parent) when is_list(parent), do: Enum.join(parent, <<0x1F>>)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, to_string(value))
end
