defmodule Supabase.Storage.IcebergTest do
  use ExUnit.Case, async: false

  alias Supabase.Fetcher.Request
  alias Supabase.Storage.Analytics
  alias Supabase.Storage.Iceberg

  import Mox

  setup :verify_on_exit!

  @mock Supabase.Storage.TestHTTPAdapter

  setup_all do
    Application.put_env(:supabase_storage, :http_client, @mock)
    on_exit(fn -> Application.delete_env(:supabase_storage, :http_client) end)
    client = Supabase.init_client!("http://localhost:54321", "test-key")

    {:ok, client: client}
  end

  setup %{client: client} do
    analytics = Analytics.from(client)
    {:ok, iceberg: Iceberg.from(analytics, "analytics-data")}
  end

  defp respond(status, body) do
    {:ok, %Finch.Response{status: status, headers: [], body: body}}
  end

  describe "list_namespaces/2" do
    test "lists top-level namespaces", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :get
        assert url.path =~ "/iceberg/v1/analytics-data/namespaces"
        respond(200, ~s({"namespaces": [["default"]]}))
      end)

      assert {:ok, %{"namespaces" => [["default"]]}} = Iceberg.list_namespaces(iceberg)
    end

    test "encodes a nested parent namespace with the unit separator", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{} = req, _opts ->
        assert Request.get_query_param(req, "parent") == "prod" <> <<0x1F>> <> "default"
        respond(200, ~s({"namespaces": []}))
      end)

      assert {:ok, %{"namespaces" => []}} =
               Iceberg.list_namespaces(iceberg, parent: ["prod", "default"])
    end

    test "forwards pagination params", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{} = req, _opts ->
        assert Request.get_query_param(req, "pageToken") == "tok"
        assert Request.get_query_param(req, "pageSize") == "10"
        respond(200, ~s({"namespaces": [], "next-page-token": "tok2"}))
      end)

      assert {:ok, %{"next-page-token" => "tok2"}} =
               Iceberg.list_namespaces(iceberg, page_token: "tok", page_size: 10)
    end
  end

  describe "load_namespace/2" do
    test "loads a single namespace", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert url.path =~ "/iceberg/v1/analytics-data/namespaces/default"
        respond(200, ~s({"namespace": ["default"], "properties": {}}))
      end)

      assert {:ok, %{"namespace" => ["default"]}} = Iceberg.load_namespace(iceberg, "default")
    end

    test "encodes nested namespaces in the path", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert url.path =~ "/namespaces/prod%1Fdefault"
        respond(200, ~s({"namespace": ["prod", "default"], "properties": {}}))
      end)

      assert {:ok, _} = Iceberg.load_namespace(iceberg, ["prod", "default"])
    end
  end

  describe "list_tables/3" do
    test "lists tables in a namespace", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert url.path =~ "/iceberg/v1/analytics-data/namespaces/default/tables"

        respond(
          200,
          ~s({"identifiers": [{"namespace": ["default"], "name": "events"}]})
        )
      end)

      assert {:ok, %{"identifiers" => [%{"name" => "events"}]}} =
               Iceberg.list_tables(iceberg, ["default"])
    end
  end

  describe "load_table/3" do
    test "loads table metadata", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert url.path =~ "/namespaces/default/tables/events"

        respond(
          200,
          ~s({"metadata-location": "s3://bucket/events/metadata/1.json", "metadata": {"format-version": 2}})
        )
      end)

      assert {:ok, %{"metadata" => %{"format-version" => 2}}} =
               Iceberg.load_table(iceberg, ["default"], "events")
    end

    test "returns an error tuple when the table does not exist", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(
          404,
          ~s({"error": {"message": "Table not found", "type": "NoSuchTableException", "code": 404}})
        )
      end)

      assert {:error, %Supabase.Error{}} = Iceberg.load_table(iceberg, ["default"], "missing")
    end
  end

  describe "table_exists?/3" do
    test "returns true when the table exists", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :head
        assert url.path =~ "/namespaces/default/tables/events"
        respond(200, "")
      end)

      assert Iceberg.table_exists?(iceberg, ["default"], "events")
    end

    test "returns false when the table does not exist", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(
          404,
          ~s({"error": {"message": "Table not found", "type": "NoSuchTableException", "code": 404}})
        )
      end)

      refute Iceberg.table_exists?(iceberg, ["default"], "missing")
    end
  end

  describe "create_namespace/3" do
    test "creates a namespace with properties", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :post
        assert url.path =~ "/iceberg/v1/analytics-data/namespaces"
        body = IO.iodata_to_binary(req.body)
        assert body =~ ~s("namespace":["production"])
        assert body =~ ~s("owner":"data-team")

        respond(200, ~s({"namespace": ["production"], "properties": {"owner": "data-team"}}))
      end)

      assert {:ok, %{"namespace" => ["production"]}} =
               Iceberg.create_namespace(iceberg, ["production"], %{"owner" => "data-team"})
    end

    test "wraps a single namespace name in a list", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{} = req, _opts ->
        assert IO.iodata_to_binary(req.body) =~ ~s("namespace":["default"])
        respond(200, ~s({"namespace": ["default"], "properties": {}}))
      end)

      assert {:ok, _} = Iceberg.create_namespace(iceberg, "default")
    end
  end

  describe "drop_namespace/2" do
    test "drops a namespace", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :delete
        assert url.path =~ "/namespaces/prod%1Fdefault"
        respond(204, "")
      end)

      assert {:ok, :dropped} = Iceberg.drop_namespace(iceberg, ["prod", "default"])
    end
  end

  describe "namespace_exists?/2" do
    test "returns true when the namespace exists", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{} = req, _opts ->
        assert req.method == :head
        respond(200, "")
      end)

      assert Iceberg.namespace_exists?(iceberg, ["default"])
    end

    test "returns false when the namespace does not exist", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(
          404,
          ~s({"error": {"message": "Namespace not found", "type": "NoSuchNamespaceException", "code": 404}})
        )
      end)

      refute Iceberg.namespace_exists?(iceberg, ["missing"])
    end
  end

  describe "create_table/3" do
    test "creates a table with spec keys in the body", %{iceberg: iceberg} do
      schema = %{
        "type" => "struct",
        "schema-id" => 0,
        "fields" => [%{"id" => 1, "name" => "id", "type" => "long", "required" => true}]
      }

      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :post
        assert url.path =~ "/namespaces/default/tables"
        body = req.body |> IO.iodata_to_binary() |> Jason.decode!()
        assert body["name"] == "events"
        assert body["partition-spec"] == %{"spec-id" => 0, "fields" => []}
        assert body["write-order"] == %{"order-id" => 0, "fields" => []}
        assert body["properties"] == %{"write.format.default" => "parquet"}

        respond(
          200,
          ~s({"metadata-location": "s3://bucket/events/metadata/0.json", "metadata": {"format-version": 2}})
        )
      end)

      assert {:ok, %{"metadata" => %{"format-version" => 2}}} =
               Iceberg.create_table(iceberg, ["default"], %{
                 name: "events",
                 schema: schema,
                 partition_spec: %{"spec-id" => 0, "fields" => []},
                 write_order: %{"order-id" => 0, "fields" => []},
                 properties: %{"write.format.default" => "parquet"}
               })
    end

    test "supports staging the creation", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{} = req, _opts ->
        assert IO.iodata_to_binary(req.body) =~ ~s("stage-create":true)
        respond(200, ~s({"metadata": {"format-version": 2}}))
      end)

      assert {:ok, _} =
               Iceberg.create_table(iceberg, ["default"],
                 name: "events",
                 schema: %{"type" => "struct", "schema-id" => 0, "fields" => []},
                 stage_create: true
               )
    end
  end

  describe "register_table/4" do
    test "registers a table by metadata location", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :post
        assert url.path =~ "/namespaces/default/tables"
        body = IO.iodata_to_binary(req.body)
        assert body =~ ~s("name":"events")
        assert body =~ ~s("metadata-location":"s3://bucket/events/metadata/1.json")

        respond(200, ~s({"metadata": {"format-version": 2}}))
      end)

      assert {:ok, _} =
               Iceberg.register_table(
                 iceberg,
                 ["default"],
                 "events",
                 "s3://bucket/events/metadata/1.json"
               )
    end
  end

  describe "commit_table/4" do
    test "commits requirements and updates", %{iceberg: iceberg} do
      commit = %{
        requirements: [%{"type" => "assert-table-uuid", "uuid" => "uuid-1"}],
        updates: [%{"action" => "add-schema", "schema" => %{"schema-id" => 1, "fields" => []}}]
      }

      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :post
        assert url.path =~ "/namespaces/default/tables/events"
        body = IO.iodata_to_binary(req.body)
        assert body =~ ~s("assert-table-uuid")
        assert body =~ ~s("add-schema")

        respond(
          200,
          ~s({"metadata-location": "s3://bucket/events/metadata/2.json", "metadata": {"format-version": 2}})
        )
      end)

      assert {:ok, %{"metadata-location" => "s3://bucket/events/metadata/2.json"}} =
               Iceberg.commit_table(iceberg, ["default"], "events", commit)
    end
  end

  describe "drop_table/4" do
    test "drops a table", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :delete
        assert url.path =~ "/namespaces/default/tables/events"
        assert is_nil(Request.get_query_param(req, "purgeRequested"))
        respond(204, "")
      end)

      assert {:ok, :dropped} = Iceberg.drop_table(iceberg, ["default"], "events")
    end

    test "passes the purgeRequested query param when purging", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{} = req, _opts ->
        assert Request.get_query_param(req, "purgeRequested") == "true"
        respond(204, "")
      end)

      assert {:ok, :dropped} = Iceberg.drop_table(iceberg, ["default"], "events", purge: true)
    end
  end

  describe "rename_table/3" do
    test "renames a table from source to destination", %{iceberg: iceberg} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :post
        assert url.path =~ "/iceberg/v1/analytics-data/tables/rename"
        body = IO.iodata_to_binary(req.body)
        assert body =~ ~s("source":{"name":"events","namespace":["default"]})
        assert body =~ ~s("destination":{"name":"events","namespace":["archive"]})
        respond(204, "")
      end)

      assert {:ok, :renamed} =
               Iceberg.rename_table(
                 iceberg,
                 %{namespace: ["default"], name: "events"},
                 %{namespace: ["archive"], name: "events"}
               )
    end
  end
end
