defmodule Supabase.StorageTest do
  use ExUnit.Case, async: true

  alias Supabase.Fetcher.Request
  alias Supabase.Storage
  alias Supabase.Storage.Bucket

  import Mox

  setup :verify_on_exit!

  @mock Supabase.Storage.TestHTTPAdapter

  setup_all do
    Application.put_env(:supabase_storage, :http_client, @mock)
    on_exit(fn -> Application.delete_env(:supabase_storage, :http_client) end)
    client = Supabase.init_client!("http://localhost:54321", "test-key")

    {:ok, client: client}
  end

  describe "list_buckets/1" do
    test "it should list and parse correctly empty buckets list", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        {:ok, %Finch.Response{status: 200, headers: [], body: ~s([])}}
      end)

      assert {:ok, []} = Storage.list_buckets(client)

      # with schema parsing too
    end

    test "it should lsit and parse buckets with the body decoder", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        body = """
        [
          {
            "id": "main",
            "name": "main",
            "file_size_limit": 100,
            "allowed_mime_types": ["image/*"],
            "owner": null,
            "public": false,
            "created_at": "2025-01-15T14:00:00Z",
            "updated_at": "2025-01-15T14:00:00Z"
          }
        ]
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: body}}
      end)

      assert {:ok,
              [
                %Bucket{
                  id: "main",
                  name: "main",
                  allowed_mime_types: ["image/*"],
                  owner: nil,
                  public: false,
                  file_size_limit: %{size: 100, unit: :byte},
                  created_at: ~N[2025-01-15 14:00:00],
                  updated_at: ~N[2025-01-15 14:00:00]
                }
              ]} = Storage.list_buckets(client)
    end
  end

  describe "get_bucket/2" do
    test "it should return an error if bucket doesn't exist", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        id = Path.basename(url.path)

        body =
          ~s({"code": "Not Found", "message": "Bucket with id #{id} doesn't exist", "statusCode": 404})

        {:ok, %Finch.Response{status: 404, headers: [], body: body}}
      end)

      assert {:error, %Supabase.Error{} = err} = Storage.get_bucket(client, "some")
      assert err.code == :not_found
      assert err.message == "Bucket with id some doesn't exist"
    end

    test "it should return parsed bucket if bucket exist", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        body = """
          {
            "id": "main",
            "name": "main",
            "file_size_limit": 100,
            "allowed_mime_types": ["image/*"],
            "owner": null,
            "public": false,
            "created_at": "2025-01-15T14:00:00Z",
            "updated_at": "2025-01-15T14:00:00Z"
          }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: body}}
      end)

      assert {:ok, %Bucket{}} = Storage.get_bucket(client, "some")
    end
  end

  describe "create_bucket/3" do
    test "it should return success if a bucket is correctly created, no options", %{
      client: client
    } do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        {:ok, %Finch.Response{status: 201, headers: [], body: ~s({"name": "main"})}}
      end)
      |> expect(:request, fn %Request{}, _opts ->
        body = Supabase.encode_json(%Bucket{id: "some", name: "some"})
        {:ok, %Finch.Response{status: 200, headers: [], body: body}}
      end)

      assert {:ok, :created} = Storage.create_bucket(client, "some")
      assert {:ok, %Bucket{id: "some"}} = Storage.get_bucket(client, "some")
    end
  end
end
