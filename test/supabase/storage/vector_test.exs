defmodule Supabase.Storage.VectorTest do
  use ExUnit.Case, async: true

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Supabase.Storage.Vector

  import Mox

  setup :verify_on_exit!

  @mock Supabase.Storage.TestHTTPAdapter

  setup_all do
    Application.put_env(:supabase_storage, :http_client, @mock)
    on_exit(fn -> Application.delete_env(:supabase_storage, :http_client) end)
    client = Supabase.init_client!("http://localhost:54321", "test-key")

    {:ok, client: client}
  end

  describe "from/2" do
    test "it should create a vector client instance", %{client: client} do
      vector = Vector.from(client)

      assert %Vector{client: ^client, vector_bucket_name: nil} = vector
    end

    test "it should create a vector client with a default bucket name", %{client: client} do
      vector = Vector.from(client, "embeddings")

      assert %Vector{client: ^client, vector_bucket_name: "embeddings"} = vector
    end
  end

  describe "create_bucket/2" do
    test "it should create a vector bucket successfully", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: _body}, _opts ->
        assert String.ends_with?(url.path, "/CreateVectorBucket")

        {:ok, %Finch.Response{status: 200, headers: [], body: ~s({})}}
      end)

      vector = Vector.from(client)
      assert {:ok, :created} = Vector.create_bucket(vector, "embeddings")
    end

    test "it should return an error if bucket already exists", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        body = ~s({"code": "Conflict", "message": "Bucket already exists", "statusCode": 409})
        {:ok, %Finch.Response{status: 409, headers: [], body: body}}
      end)

      vector = Vector.from(client)
      assert {:error, %Supabase.Error{} = err} = Vector.create_bucket(vector, "embeddings")
      assert err.code == :resource_already_exists
      assert err.message == "Bucket already exists"
    end
  end

  describe "get_bucket/2" do
    test "it should return bucket metadata when bucket exists", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: _body}, _opts ->
        assert String.ends_with?(url.path, "/GetVectorBucket")

        response_body = """
        {
          "vectorBucket": {
            "vectorBucketName": "embeddings",
            "creationTime": 1704067200,
            "encryptionConfiguration": {
              "kmsKeyArn": "arn:aws:kms:us-east-1:123456789012:key/12345678",
              "sseType": "KMS"
            }
          }
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client)

      assert {:ok, %Response{body: %{"vectorBucket" => bucket}}} =
               Vector.get_bucket(vector, "embeddings")

      assert bucket["vectorBucketName"] == "embeddings"
      assert bucket["creationTime"] == 1_704_067_200
    end

    test "it should return an error when bucket doesn't exist", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        body =
          ~s({"code": "Not Found", "message": "Vector bucket not found", "statusCode": 404})

        {:ok, %Finch.Response{status: 404, headers: [], body: body}}
      end)

      vector = Vector.from(client)
      assert {:error, %Supabase.Error{} = err} = Vector.get_bucket(vector, "nonexistent")
      assert err.code == :not_found
      assert err.message == "Vector bucket not found"
    end
  end

  describe "list_buckets/2" do
    test "it should list vector buckets with empty result", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert String.ends_with?(url.path, "/ListVectorBuckets")

        response_body = """
        {
          "vectorBuckets": []
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client)
      assert {:ok, %Response{body: %{"vectorBuckets" => []}}} = Vector.list_buckets(vector)
    end

    test "it should list vector buckets with results", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        response_body = """
        {
          "vectorBuckets": [
            {"vectorBucketName": "embeddings"},
            {"vectorBucketName": "vectors"}
          ],
          "nextToken": "next-page-token"
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client)

      assert {:ok, %Response{body: %{"vectorBuckets" => buckets, "nextToken" => token}}} =
               Vector.list_buckets(vector)

      assert length(buckets) == 2
      assert token == "next-page-token"
    end

    test "it should list vector buckets with prefix filter", %{client: client} do
      @mock
      |> expect(:request, fn %Request{body: _body}, _opts ->
        response_body = """
        {
          "vectorBuckets": [
            {"vectorBucketName": "prod-embeddings"}
          ]
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client)

      assert {:ok, %Response{body: %{"vectorBuckets" => buckets}}} =
               Vector.list_buckets(vector, %{prefix: "prod-"})

      assert length(buckets) == 1
      assert hd(buckets)["vectorBucketName"] == "prod-embeddings"
    end

    test "it should list vector buckets with pagination", %{client: client} do
      @mock
      |> expect(:request, fn %Request{body: _body}, _opts ->
        response_body = """
        {
          "vectorBuckets": [
            {"vectorBucketName": "bucket1"}
          ],
          "nextToken": "next-token"
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client)

      assert {:ok, %Response{body: %{"vectorBuckets" => buckets, "nextToken" => token}}} =
               Vector.list_buckets(vector, %{max_results: 50, next_token: "previous-token"})

      assert length(buckets) == 1
      assert token == "next-token"
    end
  end

  describe "delete_bucket/2" do
    test "it should delete a vector bucket successfully", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: _body}, _opts ->
        assert String.ends_with?(url.path, "/DeleteVectorBucket")

        {:ok, %Finch.Response{status: 200, headers: [], body: ~s({})}}
      end)

      vector = Vector.from(client)
      assert {:ok, :deleted} = Vector.delete_bucket(vector, "old-embeddings")
    end

    test "it should return an error if bucket is not empty", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        body =
          ~s({"code": "Conflict", "message": "Bucket must be empty before deletion", "statusCode": 409})

        {:ok, %Finch.Response{status: 409, headers: [], body: body}}
      end)

      vector = Vector.from(client)
      assert {:error, %Supabase.Error{} = err} = Vector.delete_bucket(vector, "embeddings")
      assert err.code == :resource_already_exists
      assert err.message == "Bucket must be empty before deletion"
    end

    test "it should return an error if bucket doesn't exist", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        body =
          ~s({"code": "Not Found", "message": "Vector bucket not found", "statusCode": 404})

        {:ok, %Finch.Response{status: 404, headers: [], body: body}}
      end)

      vector = Vector.from(client)
      assert {:error, %Supabase.Error{} = err} = Vector.delete_bucket(vector, "nonexistent")
      assert err.code == :not_found
      assert err.message == "Vector bucket not found"
    end
  end
end
