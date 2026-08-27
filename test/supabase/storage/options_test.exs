defmodule Supabase.Storage.OptionsTest do
  use ExUnit.Case, async: true

  alias Supabase.Storage.FileOptions
  alias Supabase.Storage.ListV2Options
  alias Supabase.Storage.SearchOptions
  alias Supabase.Storage.TransformOptions

  describe "FileOptions.parse/1" do
    test "applies defaults on empty input" do
      assert {:ok,
              %FileOptions{
                cache_control: "3600",
                content_type: "text/plain;charset=UTF-8",
                upsert: false,
                metadata: %{},
                headers: %{}
              }} = FileOptions.parse(%{})
    end

    test "casts custom values" do
      attrs = %{
        cache_control: "60",
        content_type: "image/png",
        upsert: true,
        metadata: %{"alt" => "pic"},
        headers: %{"x-custom" => "1"}
      }

      assert {:ok,
              %FileOptions{
                cache_control: "60",
                content_type: "image/png",
                upsert: true,
                metadata: %{"alt" => "pic"},
                headers: %{"x-custom" => "1"}
              }} = FileOptions.parse(attrs)
    end

    test "returns an error for invalid types" do
      assert {:error, %Ecto.Changeset{} = changeset} = FileOptions.parse(%{upsert: "yes"})
      assert %{upsert: ["is invalid"]} = errors_on(changeset)
    end

    test "ignores unknown keys" do
      assert {:ok, %FileOptions{}} = FileOptions.parse(%{unknown: "key"})
    end
  end

  describe "SearchOptions.parse/1" do
    test "applies defaults on empty input" do
      assert {:ok,
              %SearchOptions{
                limit: 100,
                offset: 0,
                search: nil,
                sort_by: %SearchOptions.SortBy{column: "name", order: :asc}
              }} = SearchOptions.parse(%{})
    end

    test "casts custom values including sort_by" do
      attrs = %{
        limit: 10,
        offset: 5,
        search: "png",
        sort_by: %{column: "created_at", order: "desc"}
      }

      assert {:ok,
              %SearchOptions{
                limit: 10,
                offset: 5,
                search: "png",
                sort_by: %SearchOptions.SortBy{column: "created_at", order: :desc}
              }} = SearchOptions.parse(attrs)
    end

    test "returns an error for an invalid sort order" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               SearchOptions.parse(%{sort_by: %{column: "name", order: "sideways"}})

      assert %{sort_by: %{order: ["is invalid"]}} = errors_on(changeset)
    end

    test "returns an error for invalid scalar types" do
      assert {:error, %Ecto.Changeset{} = changeset} = SearchOptions.parse(%{limit: "many"})
      assert %{limit: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "ListV2Options.parse/1" do
    test "applies defaults on empty input" do
      assert {:ok, %ListV2Options{limit: 100, cursor: nil, with_delimiter: false}} =
               ListV2Options.parse(%{})
    end

    test "casts custom values" do
      attrs = %{limit: 50, cursor: "abc", with_delimiter: true}

      assert {:ok, %ListV2Options{limit: 50, cursor: "abc", with_delimiter: true}} =
               ListV2Options.parse(attrs)
    end

    test "returns an error for invalid types" do
      assert {:error, %Ecto.Changeset{} = changeset} = ListV2Options.parse(%{limit: "many"})
      assert %{limit: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "TransformOptions.parse/1" do
    test "applies defaults on empty input" do
      assert {:ok,
              %TransformOptions{
                width: nil,
                height: nil,
                resize: :cover,
                quality: 80,
                format: "origin"
              }} = TransformOptions.parse(%{})
    end

    test "casts custom values" do
      attrs = %{width: 100, height: 50, resize: "contain", quality: 60, format: "origin"}

      assert {:ok, %TransformOptions{width: 100, height: 50, resize: :contain, quality: 60}} =
               TransformOptions.parse(attrs)
    end

    test "returns an error when quality is out of range" do
      assert {:error, %Ecto.Changeset{} = changeset} = TransformOptions.parse(%{quality: 19})
      assert %{quality: [_]} = errors_on(changeset)

      assert {:error, %Ecto.Changeset{} = changeset} = TransformOptions.parse(%{quality: 101})
      assert %{quality: [_]} = errors_on(changeset)
    end

    test "returns an error for an invalid resize mode" do
      assert {:error, %Ecto.Changeset{} = changeset} = TransformOptions.parse(%{resize: "squish"})
      assert %{resize: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "TransformOptions String.Chars" do
    test "encodes only set fields as a query string" do
      {:ok, opts} = TransformOptions.parse(%{width: 100})

      query = to_string(opts)
      assert query =~ "width=100"
      refute query =~ "height="
    end

    test "encodes all defaults when everything is set" do
      {:ok, opts} = TransformOptions.parse(%{width: 100, height: 50, quality: 90})

      query = to_string(opts)
      assert query =~ "resize=cover"
      assert query =~ "quality=90"
      assert query =~ "format=origin"
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
