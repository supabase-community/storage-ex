defmodule Supabase.Storage.TransformOptions do
  @moduledoc """
  Represents the transform options for querying objects within Supabase Storage.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @typedoc """
  An `TransformOptions` consists of the following attributes:

  - `width`: The width of the image in pixels.
  - `height`: The height of the image in pixels.
  - `resize`: The resize mode can be cover, contain or fill. Defaults to cover. Cover resizes the image to maintain it's aspect ratio while filling the entire width and height. Contain resizes the image to maintain it's aspect ratio while fitting the entire image within the width and height. Fill resizes the image to fill the entire width and height. If the object's aspect ratio does not match the width and height, the image will be stretched to fit.
  - `quality`: Set the quality of the returned image. A number from 20 to 100, with 100 being the highest quality. Defaults to 80
  - `format`: Specify the format of the image requested. When using 'origin' we force the format to be the same as the original image. When this option is not passed in, images are optimized to modern image formats like Webp.
  """
  @type t :: %__MODULE__{
          width: integer(),
          height: integer(),
          resize: :cover | :contain | :fill,
          quality: integer(),
          format: String.t()
        }

  @fields ~w(width height resize quality format)a

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field(:width, :integer)
    field(:height, :integer)
    field(:resize, Ecto.Enum, values: [:cover, :contain, :fill], default: :cover)
    field(:quality, :integer, default: 80)
    field(:format, :string, default: "origin")
  end

  @spec parse(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def parse(attrs) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> validate_inclusion(:quality, 20..100)
    |> apply_action(:parse)
  end

  defimpl String.Chars, for: __MODULE__ do
    alias Supabase.Storage.TransformOptions, as: Transform

    def to_string(%Transform{} = t) do
      Map.from_struct(t)
      |> Map.delete(:__schema__)
      |> Map.filter(fn {_, v} -> v end)
      |> URI.encode_query()
    end
  end
end
