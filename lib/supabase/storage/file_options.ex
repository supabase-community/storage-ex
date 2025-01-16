defmodule Supabase.Storage.FileOptions do
  @moduledoc """
  Represents the configurable options for an File within Supabase Storage.

  This module encapsulates options that can be set or modified for a storage object. These options help in controlling behavior such as caching, content type, and whether to upsert an object.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @typedoc """
  An `FileOptions` consists of the following attributes:

  - `cache_control`: The number of seconds the asset is cached in the browser and in the Supabase CDN. This is set in the `Cache-Control: max-age=<seconds>` header. Defaults to 3600 seconds.
  - `content_type`: Specifies the media type of the resource or data. Default is `"text/plain;charset=UTF-8"`.
  - `upsert`: When upsert is set to true, the file is overwritten if it exists. When set to false, an error is thrown if the object already exists. Defaults to false.
  - `metadata`: The metadata option is an object that allows you to store additional information about the file. This information can be used to filter and search for files. The metadata object can contain any key-value pairs you want to store.
  - `headers`: Optionally add extra headers to the request.
  """
  @type t :: %__MODULE__{
          cache_control: String.t(),
          content_type: String.t(),
          upsert: boolean(),
          metadata: map,
          headers: map
        }

  @fields ~w(cache_control content_type upsert metadata headers)a

  @primary_key false
  embedded_schema do
    field(:cache_control, :string, default: "3600")
    field(:content_type, :string, default: "text/plain;charset=UTF-8")
    field(:upsert, :boolean, default: false)
    field(:metadata, {:map, :string}, default: %{})
    field(:headers, {:map, :string}, default: %{})
  end

  @spec parse(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def parse(attrs) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> apply_action(:parse)
  end
end
