defmodule Supabase.Storage.FileTest do
  use ExUnit.Case, async: false

  alias Supabase.Fetcher.Request
  alias Supabase.Storage
  alias Supabase.Storage.File, as: SFile

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
    {:ok, storage: Storage.from(client, "main")}
  end

  defp respond(status, body) do
    {:ok, %Finch.Response{status: status, headers: [], body: body}}
  end

  describe "parse/1" do
    test "parses a valid object map" do
      attrs = %{
        "id" => "obj-id",
        "name" => "image.png",
        "bucket_id" => "main",
        "owner" => "user-id",
        "metadata" => %{"size" => 100},
        "created_at" => "2025-01-15T14:00:00",
        "updated_at" => "2025-01-15T14:00:00",
        "last_accessed_at" => "2025-01-15T14:00:00"
      }

      assert {:ok,
              %SFile{
                id: "obj-id",
                name: "image.png",
                bucket_id: "main",
                owner: "user-id",
                metadata: %{"size" => 100},
                created_at: ~N[2025-01-15 14:00:00],
                updated_at: ~N[2025-01-15 14:00:00],
                last_accessed_at: ~N[2025-01-15 14:00:00]
              }} = SFile.parse(attrs)
    end

    test "parses a list of object maps" do
      attrs = [%{"id" => "a", "name" => "a.png"}, %{"id" => "b", "name" => "b.png"}]

      assert {:ok, [%SFile{id: "a"}, %SFile{id: "b"}]} = SFile.parse(attrs)
    end

    test "returns an error when id is missing" do
      assert {:error, %Ecto.Changeset{} = changeset} = SFile.parse(%{"name" => "x.png"})

      assert %{id: ["can't be blank"]} =
               changeset.errors |> Map.new(fn {k, {m, _}} -> {k, [m]} end)
    end

    test "halts on the first invalid item of a list" do
      attrs = [%{"id" => "a"}, %{"name" => "no-id.png"}, %{"id" => "c"}]

      assert {:error, %Ecto.Changeset{}} = SFile.parse(attrs)
    end
  end

  describe "upload/4" do
    setup do
      path = Path.join(System.tmp_dir!(), "storage-ex-upload-test.txt")
      Elixir.File.write!(path, "hello")
      on_exit(fn -> Elixir.File.rm(path) end)
      {:ok, file_path: path}
    end

    test "uploads and returns path, id and key", %{
      storage: storage,
      file_path: file_path
    } do
      @mock
      |> expect(:upload, fn %Request{url: url} = req, _file, _opts ->
        assert req.method == :post
        assert url.path =~ "/object/main/folder/image.png"
        respond(200, ~s({"Id": "obj-id", "Key": "main/folder/image.png"}))
      end)

      assert {:ok, %{path: "folder/image.png", id: "obj-id", key: "main/folder/image.png"}} =
               SFile.upload(storage, file_path, "/folder//image.png/")
    end

    test "returns an error tuple on failure", %{storage: storage, file_path: file_path} do
      @mock
      |> expect(:upload, fn %Request{}, _file, _opts ->
        respond(400, ~s({"statusCode": "400", "error": "Invalid", "message": "nope"}))
      end)

      assert {:error, %Supabase.Error{}} = SFile.upload(storage, file_path, "x.png")
    end

    test "URL encodes object paths containing spaces", %{
      storage: storage,
      file_path: file_path
    } do
      @mock
      |> expect(:upload, fn %Request{url: url}, _file, _opts ->
        assert url.path =~ "/object/main/imports/Pearl%20Jam.csv"
        respond(200, ~s({"Id": "obj-id", "Key": "main/imports/Pearl Jam.csv"}))
      end)

      assert {:ok, %{path: "imports/Pearl Jam.csv"}} =
               SFile.upload(storage, file_path, "imports/Pearl Jam.csv")
    end
  end

  describe "update/4" do
    setup do
      path = Path.join(System.tmp_dir!(), "storage-ex-update-test.txt")
      Elixir.File.write!(path, "hello")
      on_exit(fn -> Elixir.File.rm(path) end)
      {:ok, file_path: path}
    end

    test "updates with a PUT request", %{storage: storage, file_path: file_path} do
      @mock
      |> expect(:upload, fn %Request{url: url} = req, _file, _opts ->
        assert req.method == :put
        assert url.path =~ "/object/main/folder/image.png"
        respond(200, ~s({"Id": "obj-id", "Key": "main/folder/image.png"}))
      end)

      assert {:ok, %{path: "folder/image.png", id: "obj-id"}} =
               SFile.update(storage, file_path, "folder/image.png")
    end
  end

  describe "upload_to_signed_url/5" do
    setup do
      path = Path.join(System.tmp_dir!(), "storage-ex-signed-upload-test.txt")
      Elixir.File.write!(path, "hello")
      on_exit(fn -> Elixir.File.rm(path) end)
      {:ok, file_path: path}
    end

    test "uploads to a signed url and returns full_path", %{
      storage: storage,
      file_path: file_path
    } do
      @mock
      |> expect(:upload, fn %Request{url: url} = req, _file, _opts ->
        assert url.path =~ "/object/upload/sign/main/folder/image.png"
        assert Request.get_query_param(req, "token") == "token-123"
        respond(200, ~s({"Key": "main/folder/image.png"}))
      end)

      assert {:ok, %{path: "folder/image.png", full_path: "main/folder/image.png"}} =
               SFile.upload_to_signed_url(storage, "token-123", file_path, "folder/image.png")
    end
  end

  describe "create_signed_upload_url/3" do
    test "returns the signed url and extracted token", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert url.path =~ "/object/upload/sign/main/folder/image.png"

        respond(
          200,
          ~s({"url": "/object/upload/sign/main/folder/image.png?token=upload-token"})
        )
      end)

      assert {:ok, %{signed_url: signed_url, token: "upload-token", path: "folder/image.png"}} =
               SFile.create_signed_upload_url(storage, "folder/image.png")

      assert signed_url =~ "token=upload-token"
    end
  end

  describe "move/2" do
    test "moves a file and returns :moved", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :post
        assert url.path =~ "/object/move"
        respond(200, ~s({"message": "Successfully moved"}))
      end)

      assert {:ok, :moved} = SFile.move(storage, from: "a.png", to: "b.png")
    end

    test "supports a destination bucket", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{body: body}, _opts ->
        assert IO.iodata_to_binary(body) =~ ~s("destination_bucket":"other")
        respond(200, ~s({"message": "Successfully moved"}))
      end)

      assert {:ok, :moved} =
               SFile.move(storage, from: "a.png", to: "b.png", destination_bucket: "other")
    end
  end

  describe "copy/2" do
    test "copies a file and returns :moved", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert url.path =~ "/object/copy"
        respond(200, ~s({"Key": "main/b.png"}))
      end)

      assert {:ok, :moved} = SFile.copy(storage, from: "a.png", to: "b.png")
    end
  end

  describe "create_signed_url/3" do
    test "returns the signed url", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(200, ~s({"signedURL": "/object/sign/main/a.png?token=token-123"}))
      end)

      assert {:ok, url} = SFile.create_signed_url(storage, "a.png", expires_in: 60)
      assert url =~ "token=token-123"
    end

    test "appends an empty download param when download is true", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(200, ~s({"signedURL": "/object/sign/main/a.png?token=token-123"}))
      end)

      assert {:ok, url} =
               SFile.create_signed_url(storage, "a.png", expires_in: 60, download: true)

      assert url =~ "download="
    end

    test "appends a filename download param when download is a string", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(200, ~s({"signedURL": "/object/sign/main/a.png?token=token-123"}))
      end)

      assert {:ok, url} =
               SFile.create_signed_url(storage, "a.png", expires_in: 60, download: "custom.png")

      assert url =~ "download=custom.png"
    end
  end

  describe "create_signed_urls/3" do
    test "returns a list of signed urls", %{storage: storage} do
      body = """
      [
        {"path": "a.png", "signedURL": "/object/sign/main/a.png?token=t1", "error": null},
        {"path": "b.png", "signedURL": "/object/sign/main/b.png?token=t2", "error": null}
      ]
      """

      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, body) end)

      assert {:ok, [%{path: "a.png", signed_url: u1}, %{path: "b.png", signed_url: u2}]} =
               SFile.create_signed_urls(storage, ["a.png", "b.png"], expires_in: 60)

      assert u1 =~ "token=t1"
      assert u2 =~ "token=t2"
    end

    test "appends the download param to every url", %{storage: storage} do
      body =
        ~s([{"path": "a.png", "signedURL": "/object/sign/main/a.png?token=t1", "error": null}])

      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, body) end)

      assert {:ok, [%{signed_url: url}]} =
               SFile.create_signed_urls(storage, ["a.png"], expires_in: 60, download: true)

      assert url =~ "download="
    end
  end

  describe "list/3" do
    test "returns the raw body list", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, ~s([{"id": "a"}])) end)

      assert {:ok, [%SFile{id: "a"}]} = SFile.list(storage, "folder")
    end
  end

  describe "list_v2/3" do
    test "parses objects and pagination fields", %{storage: storage} do
      body = """
      {
        "hasNext": true,
        "cursor": "next-cursor",
        "folders": ["sub/"],
        "objects": [{"id": "a", "name": "a.png", "bucket_id": "main"}]
      }
      """

      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, body) end)

      assert {:ok,
              %{
                has_next: true,
                cursor: "next-cursor",
                folders: ["sub/"],
                objects: [%SFile{id: "a", name: "a.png"}]
              }} = SFile.list_v2(storage, "folder")
    end

    test "defaults missing fields", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, ~s({})) end)

      assert {:ok, %{has_next: false, cursor: nil, folders: [], objects: []}} =
               SFile.list_v2(storage)
    end

    test "keeps the raw map when an object fails to parse", %{storage: storage} do
      body = ~s({"objects": [{"name": "no-id.png"}]})

      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, body) end)

      assert {:ok, %{objects: [%{"name" => "no-id.png"}]}} = SFile.list_v2(storage)
    end
  end

  describe "remove/2" do
    test "removes a list of files", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{url: url} = req, _opts ->
        assert req.method == :delete
        assert url.path =~ "/object/main"
        respond(200, ~s([{"id": "a"}, {"id": "b"}]))
      end)

      assert {:ok, [%{"id" => "a"}, %{"id" => "b"}]} = SFile.remove(storage, ["a.png", "b.png"])
    end

    test "accepts a single path", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{body: body}, _opts ->
        assert IO.iodata_to_binary(body) =~ ~s("prefixes":["a.png"])
        respond(200, ~s([{"id": "a"}]))
      end)

      assert {:ok, [%{"id" => "a"}]} = SFile.remove(storage, "a.png")
    end
  end

  describe "get_public_url/3" do
    test "builds the public object url", %{storage: storage} do
      assert {:ok, url} = SFile.get_public_url(storage, "/folder//a.png/")

      assert url == "http://localhost:54321/storage/v1/object/public/main/folder/a.png"
    end

    test "URL encodes paths containing spaces", %{storage: storage} do
      assert {:ok, url} = SFile.get_public_url(storage, "imports/Pearl Jam.csv")
      assert url =~ "/object/public/main/imports/Pearl%20Jam.csv"
    end

    test "appends an empty download param when download is true", %{storage: storage} do
      assert {:ok, url} = SFile.get_public_url(storage, "a.png", download: true)
      assert url =~ "download="
    end

    test "appends a filename download param", %{storage: storage} do
      assert {:ok, url} = SFile.get_public_url(storage, "a.png", download: "custom.png")
      assert url =~ "download=custom.png"
    end

    test "uses the render path and transform query when transform is given", %{
      storage: storage
    } do
      assert {:ok, url} =
               SFile.get_public_url(storage, "a.png", transform: %{width: 100, height: 100})

      assert url =~ "/render/image/public/main/a.png"
      assert url =~ "width=100"
      assert url =~ "height=100"
    end
  end

  describe "exists?/2" do
    test "returns true when the file exists", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, ~s({})) end)

      assert SFile.exists?(storage, "a.png")
    end

    test "returns false when the file does not exist", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        respond(404, ~s({"statusCode": "404", "error": "not_found", "message": "not found"}))
      end)

      refute SFile.exists?(storage, "missing.png")
    end
  end

  describe "info/2" do
    test "returns the file info body", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, ~s({"id": "a", "size": 100})) end)

      assert {:ok, %SFile{id: "a"}} = SFile.info(storage, "a.png")
    end
  end

  describe "download/3" do
    test "returns the raw file body", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{}, _opts -> respond(200, "file-content") end)

      assert {:ok, "file-content"} = SFile.download(storage, "a.png")
    end

    test "appends the transform query", %{storage: storage} do
      @mock
      |> expect(:request, fn %Request{url: url}, _opts ->
        assert url.query =~ "width=100"
        respond(200, "file-content")
      end)

      assert {:ok, "file-content"} =
               SFile.download(storage, "a.png", transform: %{width: 100})
    end
  end

  describe "download_lazy/4" do
    test "returns the body through the on_response callback", %{storage: storage} do
      @mock
      |> expect(:stream, fn %Request{}, on_response, _opts ->
        on_response.({200, [], "streamed"})
      end)

      assert {:ok, _} =
               SFile.download_lazy(storage, "a.png", fn {200, _headers, body} ->
                 {:ok, %Finch.Response{status: 200, headers: [], body: body}}
               end)
    end
  end
end
