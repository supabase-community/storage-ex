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
end
