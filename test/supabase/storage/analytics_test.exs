defmodule Supabase.Storage.AnalyticsTest do
  use ExUnit.Case, async: false

  alias Supabase.Fetcher.Request
  alias Supabase.Storage.Analytics
  alias Supabase.Storage.AnalyticsBucket

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
    {:ok, analytics: Analytics.from(client)}
  end

  defp respond(status, body) do
    {:ok, %Finch.Response{status: status, headers: [], body: body}}
  end

  describe "create_bucket/2" do
    test "creates an analytics bucket", %{analytics: analytics} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :post
        assert url.path =~ "/iceberg/bucket"
        assert IO.iodata_to_binary(req.body) =~ ~s("name":"analytics-data")

        respond(
          200,
          ~s({"name": "analytics-data", "type": "ANALYTICS", "format": "iceberg", "created_at": "2024-05-22T22:26:05.100Z", "updated_at": "2024-05-22T22:26:05.100Z"})
        )
      end)

      assert {:ok, %AnalyticsBucket{name: "analytics-data", type: :analytics, format: "iceberg"}} =
               Analytics.create_bucket(analytics, "analytics-data")
    end

    test "returns an error tuple on failure", %{analytics: analytics} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(400, ~s({"statusCode": "400", "error": "Invalid", "message": "nope"}))
      end)

      assert {:error, %Supabase.Error{}} = Analytics.create_bucket(analytics, "analytics-data")
    end
  end

  describe "list_buckets/2" do
    test "lists analytics buckets", %{analytics: analytics} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :get
        assert url.path =~ "/iceberg/bucket"

        respond(
          200,
          ~s([{"name": "analytics-data", "type": "ANALYTICS", "format": "iceberg", "created_at": "2024-05-22T22:26:05.100Z", "updated_at": "2024-05-22T22:26:05.100Z"}])
        )
      end)

      assert {:ok, [%AnalyticsBucket{name: "analytics-data"}]} =
               Analytics.list_buckets(analytics)
    end

    test "forwards pagination, sorting and search query params", %{analytics: analytics} do
      @mock
      |> expect(:request, fn %Request{} = req, _opts ->
        assert Request.get_query_param(req, "limit") == "10"
        assert Request.get_query_param(req, "offset") == "5"
        assert Request.get_query_param(req, "sortColumn") == "created_at"
        assert Request.get_query_param(req, "sortOrder") == "desc"
        assert Request.get_query_param(req, "search") == "prod"

        respond(200, ~s([]))
      end)

      assert {:ok, []} =
               Analytics.list_buckets(analytics,
                 limit: 10,
                 offset: 5,
                 sort_column: :created_at,
                 sort_order: :desc,
                 search: "prod"
               )
    end
  end

  describe "delete_bucket/2" do
    test "deletes an analytics bucket", %{analytics: analytics} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :delete
        assert url.path =~ "/iceberg/bucket/analytics-data"
        respond(200, ~s({"message": "Successfully deleted"}))
      end)

      assert {:ok, :deleted} = Analytics.delete_bucket(analytics, "analytics-data")
    end

    test "returns an error tuple on failure", %{analytics: analytics} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(404, ~s({"statusCode": "404", "error": "not_found", "message": "not found"}))
      end)

      assert {:error, %Supabase.Error{}} = Analytics.delete_bucket(analytics, "missing")
    end
  end
end
