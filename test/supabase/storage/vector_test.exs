defmodule Supabase.Storage.VectorTest do
  use ExUnit.Case, async: false

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Supabase.Storage.Vector
  alias Supabase.Storage.Vector.Metadata

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
      |> expect(:request, fn %Request{url: url, body: body}, _opts ->
        assert String.ends_with?(url.path, "/vector/CreateVectorBucket")

        body = body |> IO.iodata_to_binary() |> Jason.decode!()

        assert body["vectorBucketName"] == "embeddings"
        refute Map.has_key?(body, "vector_bucket_name")

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
      |> expect(:request, fn %Request{url: url, body: body}, _opts ->
        assert String.ends_with?(url.path, "/vector/GetVectorBucket")

        body = body |> IO.iodata_to_binary() |> Jason.decode!()

        assert body["vectorBucketName"] == "embeddings"
        refute Map.has_key?(body, "vector_bucket_name")

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
        assert String.ends_with?(url.path, "/vector/ListVectorBuckets")

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
      |> expect(:request, fn %Request{body: body}, _opts ->
        body = body |> IO.iodata_to_binary() |> Jason.decode!()

        assert body["maxResults"] == 50
        assert body["nextToken"] == "previous-token"
        refute Map.has_key?(body, "max_results")
        refute Map.has_key?(body, "next_token")

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
        assert String.ends_with?(url.path, "/vector/DeleteVectorBucket")

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

  describe "index/2" do
    test "it should scope vector client to an index", %{client: client} do
      vector = Vector.from(client, "embeddings")
      index = Vector.index(vector, "documents")

      assert %Vector{
               client: ^client,
               vector_bucket_name: "embeddings",
               vector_index_name: "documents"
             } = index
    end
  end

  describe "create_index/2" do
    test "it should create an index successfully", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: body}, _opts ->
        assert String.ends_with?(url.path, "/vector/CreateIndex")

        body = body |> IO.iodata_to_binary() |> Jason.decode!()

        assert body["vectorBucketName"] == "embeddings"
        assert body["indexName"] == "documents-openai"
        assert body["dataType"] == "float32"
        assert body["dimension"] == 1536
        assert body["distanceMetric"] == "cosine"
        refute Map.has_key?(body, "vector_bucket_name")
        refute Map.has_key?(body, "index_name")

        {:ok, %Finch.Response{status: 200, headers: [], body: ~s({})}}
      end)

      vector = Vector.from(client, "embeddings")

      assert {:ok, :created} =
               Vector.create_index(vector, %{
                 index_name: "documents-openai",
                 data_type: :float32,
                 dimension: 1536,
                 distance_metric: :cosine
               })
    end

    test "it should validate required fields", %{client: client} do
      vector = Vector.from(client, "embeddings")

      assert {:error, %Ecto.Changeset{}} =
               Vector.create_index(vector, %{
                 index_name: "documents-openai"
               })
    end
  end

  describe "get_index/2" do
    test "it should return index metadata when index exists", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: body}, _opts ->
        assert String.ends_with?(url.path, "/vector/GetIndex")

        body = body |> IO.iodata_to_binary() |> Jason.decode!()

        assert body["vectorBucketName"] == "embeddings"
        assert body["indexName"] == "documents-openai"
        refute Map.has_key?(body, "vector_bucket_name")

        response_body = """
        {
          "index": {
            "indexName": "documents-openai",
            "vectorBucketName": "embeddings",
            "dataType": "float32",
            "dimension": 1536,
            "distanceMetric": "cosine",
            "creationTime": 1704067200
          }
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client, "embeddings")

      assert {:ok, %Response{body: %{"index" => index}}} =
               Vector.get_index(vector, "documents-openai")

      assert index["indexName"] == "documents-openai"
      assert index["dimension"] == 1536
    end

    test "it should return an error when index doesn't exist", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        body = ~s({"code": "Not Found", "message": "Index not found", "statusCode": 404})

        {:ok, %Finch.Response{status: 404, headers: [], body: body}}
      end)

      vector = Vector.from(client, "embeddings")
      assert {:error, %Supabase.Error{} = err} = Vector.get_index(vector, "nonexistent")
      assert err.code == :not_found
      assert err.message == "Index not found"
    end
  end

  describe "list_indexes/2" do
    test "it should list indexes with empty result", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert String.ends_with?(url.path, "/vector/ListIndexes")

        response_body = """
        {
          "indexes": []
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client, "embeddings")
      assert {:ok, %Response{body: %{"indexes" => []}}} = Vector.list_indexes(vector)
    end

    test "it should list indexes with results", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        response_body = """
        {
          "indexes": [
            {"indexName": "documents-openai"},
            {"indexName": "documents-cohere"}
          ],
          "nextToken": "next-page-token"
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client, "embeddings")

      assert {:ok, %Response{body: %{"indexes" => indexes, "nextToken" => token}}} =
               Vector.list_indexes(vector)

      assert length(indexes) == 2
      assert token == "next-page-token"
    end

    test "it should list indexes with prefix filter", %{client: client} do
      @mock
      |> expect(:request, fn %Request{body: _body}, _opts ->
        response_body = """
        {
          "indexes": [
            {"indexName": "documents-openai"}
          ]
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      vector = Vector.from(client, "embeddings")

      assert {:ok, %Response{body: %{"indexes" => indexes}}} =
               Vector.list_indexes(vector, %{prefix: "documents-"})

      assert length(indexes) == 1
    end
  end

  describe "delete_index/2" do
    test "it should delete an index successfully", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: _body}, _opts ->
        assert String.ends_with?(url.path, "/vector/DeleteIndex")

        {:ok, %Finch.Response{status: 200, headers: [], body: ~s({})}}
      end)

      vector = Vector.from(client, "embeddings")
      assert {:ok, :deleted} = Vector.delete_index(vector, "old-index")
    end

    test "it should return an error if index doesn't exist", %{client: client} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        body = ~s({"code": "Not Found", "message": "Index not found", "statusCode": 404})

        {:ok, %Finch.Response{status: 404, headers: [], body: body}}
      end)

      vector = Vector.from(client, "embeddings")
      assert {:error, %Supabase.Error{} = err} = Vector.delete_index(vector, "nonexistent")
      assert err.code == :not_found
      assert err.message == "Index not found"
    end
  end

  describe "Metadata.parse/1" do
    test "it should parse a camelCase GetVectorBucket response into the struct" do
      attrs = %{
        "vectorBucketName" => "embeddings",
        "creationTime" => 1_704_067_200,
        "encryptionConfiguration" => %{
          "kmsKeyArn" => "arn:aws:kms:us-east-1:123456789012:key/12345678",
          "sseType" => "KMS"
        }
      }

      assert {:ok, %Metadata{} = metadata} = Metadata.parse(attrs)
      assert metadata.vector_bucket_name == "embeddings"
      assert metadata.creation_time == 1_704_067_200

      assert %Metadata.EncryptConfiguration{
               kms_key_arn: "arn:aws:kms:us-east-1:123456789012:key/12345678",
               sse_type: "KMS"
             } = metadata.encryption_configuration
    end
  end
end
