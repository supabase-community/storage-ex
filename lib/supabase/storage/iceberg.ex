defmodule Supabase.Storage.Iceberg do
  @moduledoc """
  Thin client for the Apache Iceberg REST catalog exposed by Supabase Storage
  analytics buckets.

  The bucket name maps to the Iceberg warehouse: every catalog path is
  prefixed with `/iceberg/v1/{bucket}`. Responses are returned as decoded
  maps, following the Iceberg REST spec payloads.

  > #### Public Alpha {: .warning}
  >
  > This API is currently in public alpha. Features and interfaces may change
  > as the API evolves. Use in production environments at your own discretion.

  Covers namespace management (create/list/load/drop/exists) and table
  management (create/register/load/list/drop/exists/rename/commit).

  ## Example

      iceberg = Supabase.Storage.Iceberg.from(analytics, "analytics-data")

      {:ok, _} = Supabase.Storage.Iceberg.create_namespace(iceberg, ["default"])

      {:ok, metadata} =
        Supabase.Storage.Iceberg.create_table(iceberg, ["default"], %{
          name: "events",
          schema: %{
            "type" => "struct",
            "schema-id" => 0,
            "fields" => [
              %{"id" => 1, "name" => "id", "type" => "long", "required" => true}
            ]
          }
        })

      {:ok, %{"identifiers" => tables}} = Supabase.Storage.Iceberg.list_tables(iceberg, ["default"])
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

  @doc """
  Checks the existence of a table (HEAD request).

  ## Examples

      iex> Supabase.Storage.Iceberg.table_exists?(iceberg, ["default"], "events")
      true
  """
  @spec table_exists?(t, namespace, String.t()) :: boolean
  def table_exists?(%__MODULE__{} = i, namespace, table) when is_binary(table) do
    case head(i, tables_path(i, namespace) <> "/" <> URI.encode(table)) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Creates a namespace, optionally with properties.

  ## Examples

      iex> Supabase.Storage.Iceberg.create_namespace(iceberg, ["production"], %{"owner" => "data-team"})
      {:ok, %{"namespace" => ["production"], "properties" => %{"owner" => "data-team"}}}
  """
  @spec create_namespace(t, namespace, map) :: Supabase.result(map)
  def create_namespace(%__MODULE__{} = i, namespace, properties \\ %{})
      when is_map(properties) do
    body = %{namespace: List.wrap(namespace), properties: properties}
    post(i, namespaces_path(i), body)
  end

  @doc """
  Drops a namespace. The namespace must be empty.

  ## Examples

      iex> Supabase.Storage.Iceberg.drop_namespace(iceberg, ["production"])
      {:ok, :dropped}
  """
  @spec drop_namespace(t, namespace) :: Supabase.result(:dropped)
  def drop_namespace(%__MODULE__{} = i, namespace) do
    case delete(i, namespaces_path(i) <> "/" <> encode_namespace(namespace)) do
      {:ok, _} -> {:ok, :dropped}
      err -> err
    end
  end

  @doc """
  Checks the existence of a namespace (HEAD request).

  ## Examples

      iex> Supabase.Storage.Iceberg.namespace_exists?(iceberg, ["default"])
      true
  """
  @spec namespace_exists?(t, namespace) :: boolean
  def namespace_exists?(%__MODULE__{} = i, namespace) do
    case head(i, namespaces_path(i) <> "/" <> encode_namespace(namespace)) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Creates a table within a namespace.

  ## Parameters

    * `i` - A `Supabase.Storage.Iceberg` instance
    * `namespace` - The namespace to create the table in, as a `t:namespace/0`
    * `params` - Map with the following keys:
      * `:name` - Table name (required)
      * `:schema` - Iceberg schema map, as in the REST spec (required)
      * `:partition_spec` - Partition spec map (optional)
      * `:write_order` - Write order map (optional)
      * `:properties` - Table properties map (optional)
      * `:stage_create` - If true, stages the creation without committing (optional)

  ## Examples

      iex> Supabase.Storage.Iceberg.create_table(iceberg, ["default"], %{
      ...>   name: "events",
      ...>   schema: %{
      ...>     "type" => "struct",
      ...>     "schema-id" => 0,
      ...>     "fields" => [
      ...>       %{"id" => 1, "name" => "id", "type" => "long", "required" => true},
      ...>       %{"id" => 2, "name" => "ts", "type" => "timestamp", "required" => true}
      ...>     ]
      ...>   },
      ...>   partition_spec: %{"spec-id" => 0, "fields" => []},
      ...>   write_order: %{"order-id" => 0, "fields" => []},
      ...>   properties: %{"write.format.default" => "parquet"}
      ...> })
      {:ok, %{"metadata-location" => "s3://...", "metadata" => %{...}}}
  """
  @spec create_table(t, namespace, map | keyword) :: Supabase.result(map)
  def create_table(%__MODULE__{} = i, namespace, params) do
    params = Map.new(params)

    body =
      %{name: Map.fetch!(params, :name), schema: Map.fetch!(params, :schema)}
      |> maybe_put_raw(:"partition-spec", params[:partition_spec])
      |> maybe_put_raw(:"write-order", params[:write_order])
      |> maybe_put_raw(:properties, params[:properties])
      |> maybe_put_raw(:"stage-create", params[:stage_create])

    post(i, tables_path(i, namespace), body)
  end

  @doc """
  Registers an existing table by its metadata location, without moving data.

  ## Examples

      iex> Supabase.Storage.Iceberg.register_table(iceberg, ["default"], "events", "s3://bucket/events/metadata/1.json")
      {:ok, %{"metadata-location" => "s3://...", "metadata" => %{...}}}
  """
  @spec register_table(t, namespace, String.t(), String.t()) :: Supabase.result(map)
  def register_table(%__MODULE__{} = i, namespace, name, metadata_location)
      when is_binary(name) and is_binary(metadata_location) do
    body = %{name: name, "metadata-location": metadata_location}
    post(i, tables_path(i, namespace), body)
  end

  @doc """
  Commits updates to a table, following the Iceberg REST `CommitTableRequest`
  payload: a list of `requirements` that must hold for the commit to apply,
  and a list of `updates` describing the changes.

  ## Examples

      iex> Supabase.Storage.Iceberg.commit_table(iceberg, ["default"], "events", %{
      ...>   requirements: [
      ...>     %{"type" => "assert-table-uuid", "uuid" => "..."}
      ...>   ],
      ...>   updates: [
      ...>     %{"action" => "add-schema", "schema" => %{...}}
      ...>   ]
      ...> })
      {:ok, %{"metadata-location" => "s3://...", "metadata" => %{...}}}
  """
  @spec commit_table(t, namespace, String.t(), %{requirements: list, updates: list}) ::
          Supabase.result(map)
  def commit_table(%__MODULE__{} = i, namespace, table, %{requirements: _, updates: _} = commit)
      when is_binary(table) do
    post(i, tables_path(i, namespace) <> "/" <> URI.encode(table), commit)
  end

  @doc """
  Drops a table. With `purge: true`, the table data is permanently deleted;
  without it, the table is dropped from the catalog but data remains.

  ## Examples

      iex> Supabase.Storage.Iceberg.drop_table(iceberg, ["default"], "events", purge: true)
      {:ok, :dropped}
  """
  @spec drop_table(t, namespace, String.t(), keyword) :: Supabase.result(:dropped)
  def drop_table(%__MODULE__{} = i, namespace, table, opts \\ []) when is_binary(table) do
    query = if Keyword.get(opts, :purge, false), do: %{"purgeRequested" => "true"}, else: %{}

    case delete(i, tables_path(i, namespace) <> "/" <> URI.encode(table), query) do
      {:ok, _} -> {:ok, :dropped}
      err -> err
    end
  end

  @doc """
  Renames (or moves) a table from a source identifier to a destination
  identifier.

  ## Parameters

    * `i` - A `Supabase.Storage.Iceberg` instance
    * `from` - Source identifier: `%{namespace: namespace, name: name}`
    * `to` - Destination identifier: `%{namespace: namespace, name: name}`

  ## Examples

      iex> Supabase.Storage.Iceberg.rename_table(
      ...>   iceberg,
      ...>   %{namespace: ["default"], name: "events"},
      ...>   %{namespace: ["archive"], name: "events"}
      ...> )
      {:ok, :renamed}
  """
  @spec rename_table(t, %{namespace: namespace, name: String.t()}, %{
          namespace: namespace,
          name: String.t()
        }) :: Supabase.result(:renamed)
  def rename_table(%__MODULE__{} = i, %{namespace: src_ns, name: src}, %{namespace: dst_ns, name: dst}) do
    body = %{
      source: %{namespace: List.wrap(src_ns), name: src},
      destination: %{namespace: List.wrap(dst_ns), name: dst}
    }

    case post(i, "/iceberg/v1/#{URI.encode(i.bucket)}/tables/rename", body, raw?: true) do
      {:ok, _} -> {:ok, :renamed}
      err -> err
    end
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

  defp post(%__MODULE__{} = i, path, body, opts \\ []) do
    req =
      i.client
      |> Storage.Request.base(path)
      |> Request.with_method(:post)
      |> Request.with_body(body)

    req = if opts[:raw?], do: Request.with_body_decoder(req, nil), else: req

    with {:ok, %{body: body}} <- Fetcher.request(req) do
      {:ok, body}
    end
  end

  defp delete(%__MODULE__{} = i, path, query \\ %{}) do
    i.client
    |> Storage.Request.base(path)
    |> Request.with_method(:delete)
    |> Request.with_query(query)
    |> Request.with_body_decoder(nil)
    |> Fetcher.request()
  end

  defp head(%__MODULE__{} = i, path) do
    i.client
    |> Storage.Request.base(path)
    |> Request.with_method(:head)
    |> Request.with_body_decoder(nil)
    |> Fetcher.request()
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

  defp maybe_put_raw(map, _key, nil), do: map
  defp maybe_put_raw(map, key, value), do: Map.put(map, key, value)
end
