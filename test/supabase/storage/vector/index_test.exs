defmodule Supabase.Storage.Vector.IndexTest do
  use ExUnit.Case, async: true

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Supabase.Storage.Vector
  alias Supabase.Storage.Vector.Index

  import Mox

  setup :verify_on_exit!

  @mock Supabase.Storage.TestHTTPAdapter

  setup_all do
    Application.put_env(:supabase_storage, :http_client, @mock)
    on_exit(fn -> Application.delete_env(:supabase_storage, :http_client) end)
    client = Supabase.init_client!("http://localhost:54321", "test-key")

    {:ok, client: client}
  end

  describe "put_vectors/2" do
    test "it should insert vectors successfully", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: _body}, _opts ->
        assert String.ends_with?(url.path, "/PutVectors")

        {:ok, %Finch.Response{status: 200, headers: [], body: ~s({})}}
      end)

      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:ok, :put} =
               Index.put_vectors(index, %{
                 vectors: [
                   %{
                     key: "doc-1",
                     data: %{float32: [0.1, 0.2, 0.3]},
                     metadata: %{title: "Intro"}
                   }
                 ]
               })
    end

    test "it should reject batch size less than 1", %{client: client} do
      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:error, %Ecto.Changeset{}} = Index.put_vectors(index, %{vectors: []})
    end

    test "it should reject batch size greater than 500", %{client: client} do
      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      vectors = Enum.map(1..501, fn i -> %{key: "doc-#{i}", data: %{float32: [0.1]}} end)

      assert {:error, %Ecto.Changeset{}} = Index.put_vectors(index, %{vectors: vectors})
    end
  end

  describe "get_vectors/2" do
    test "it should retrieve vectors by keys", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: _body}, _opts ->
        assert String.ends_with?(url.path, "/GetVectors")

        response_body = """
        {
          "vectors": [
            {
              "key": "doc-1",
              "data": {"float32": [0.1, 0.2, 0.3]},
              "metadata": {"title": "Intro"}
            }
          ]
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:ok, %Response{body: %{"vectors" => vectors}}} =
               Index.get_vectors(index, %{
                 keys: ["doc-1"],
                 return_data: true,
                 return_metadata: true
               })

      assert length(vectors) == 1
    end
  end

  describe "list_vectors/2" do
    test "it should list vectors with pagination", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert String.ends_with?(url.path, "/ListVectors")

        response_body = """
        {
          "vectors": [
            {"key": "doc-1"},
            {"key": "doc-2"}
          ],
          "nextToken": "next-page"
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:ok, %Response{body: %{"vectors" => vectors, "nextToken" => token}}} =
               Index.list_vectors(index, %{max_results: 100})

      assert length(vectors) == 2
      assert token == "next-page"
    end

    test "it should validate segment_count range", %{client: client} do
      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:error, %Ecto.Changeset{}} =
               Index.list_vectors(index, %{segment_count: 0})

      assert {:error, %Ecto.Changeset{}} =
               Index.list_vectors(index, %{segment_count: 17})
    end

    test "it should validate segment_index relative to segment_count", %{client: client} do
      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:error, %Ecto.Changeset{}} =
               Index.list_vectors(index, %{segment_count: 4, segment_index: 4})

      assert {:error, %Ecto.Changeset{}} =
               Index.list_vectors(index, %{segment_count: 4, segment_index: 5})
    end
  end

  describe "query_vector/2" do
    test "it should query similar vectors", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: _body}, _opts ->
        assert String.ends_with?(url.path, "/QueryVectors")

        response_body = """
        {
          "vectors": [
            {
              "key": "doc-1",
              "distance": 0.95,
              "metadata": {"title": "Similar doc"}
            }
          ],
          "distanceMetric": "cosine"
        }
        """

        {:ok, %Finch.Response{status: 200, headers: [], body: response_body}}
      end)

      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:ok, %Response{body: %{"vectors" => vectors, "distanceMetric" => metric}}} =
               Index.query_vector(index, %{
                 query_vector: %{float32: [0.1, 0.2, 0.3]},
                 topK: 5,
                 return_distance: true,
                 return_metadata: true
               })

      assert length(vectors) == 1
      assert metric == "cosine"
    end
  end

  describe "delete_vectors/2" do
    test "it should delete vectors by keys", %{client: client} do
      @mock
      |> expect(:request, fn %Request{url: url, body: _body}, _opts ->
        assert String.ends_with?(url.path, "/DeleteVectors")

        {:ok, %Finch.Response{status: 200, headers: [], body: ~s({})}}
      end)

      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:ok, :deleted} = Index.delete_vectors(index, ["doc-1", "doc-2"])
    end

    test "it should reject batch size less than 1", %{client: client} do
      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      assert {:error, %Ecto.Changeset{}} = Index.delete_vectors(index, [])
    end

    test "it should reject batch size greater than 500", %{client: client} do
      index =
        Vector.from(client, "embeddings")
        |> Vector.index("documents")

      keys = Enum.map(1..501, fn i -> "doc-#{i}" end)

      assert {:error, %Ecto.Changeset{}} = Index.delete_vectors(index, keys)
    end
  end
end
