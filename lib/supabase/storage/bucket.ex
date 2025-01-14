defmodule Supabase.Storage.Bucket do
  @moduledoc """
  Represents a Bucket on Supabase Storage.

  This module defines the structure and operations related to a storage bucket on Supabase.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @typedoc """
  A `Bucket` consists of:

  - `id`: The unique identifier for the bucket.
  - `name`: The display name of the bucket.
  - `owner`: The owner of the bucket.
  - `file_size_limit`: The maximum file size allowed in the bucket. Can be `nil` for no limit.
  - `allowed_mime_types`: List of MIME types permitted in this bucket. Can be `nil` for no restrictions.
  - `created_at`: Timestamp indicating when the bucket was created.
  - `updated_at`: Timestamp indicating the last update to the bucket.
  - `public`: Boolean flag determining if the bucket is publicly accessible or not.

  """
  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          owner: String.t() | nil,
          file_size_limit: file_size_limit_t | nil,
          allowed_mime_types: list(String.t()) | nil,
          created_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil,
          public: boolean
        }

  @typedoc """
  A `FileSizeLimit` consists of:

  - `size`: The maximum file size limit itself as an integer.
  - `unit` The unit of the file size limit, can be: `:byte`, `:megabyte`, `:gigabyte` or `:terabyte`, defaults to `:byte`.
  """
  @type file_size_limit_t :: %__MODULE__.FileSizeLimit{
          size: integer,
          unit: :byte | :megabyte | :gigabyte | :terabyte
        }

  @fields ~w(id name created_at updated_at  allowed_mime_types public owner)a

  @primary_key {:id, :string, autogenerate: false}
  embedded_schema do
    field(:name, :string)
    field(:owner, :string)
    field(:allowed_mime_types, {:array, :string})
    field(:created_at, :naive_datetime)
    field(:updated_at, :naive_datetime)
    field(:public, :boolean, default: false)

    embeds_one :file_size_limit, FileSizeLimit, primary_key: false do
      @units [:byte, :megabyte, :gigabyte, :terabyte]

      field(:size, :integer)
      field(:unit, Ecto.Enum, values: @units, default: :byte)
    end
  end

  @spec parse(list(map)) :: {:ok, list(t)} | {:error, Ecto.Changeset.t()}
  @spec parse(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def parse(attrs) when is_list(attrs) do
    Enum.reduce_while(attrs, [], fn attr, acc ->
      case parse(attr) do
        {:ok, data} -> {:cont, [data | acc]}
        {:error, err} -> {:halt, err}
      end
    end)
    |> then(fn
      %Ecto.Changeset{} = changeset -> {:error, changeset}
      data when is_list(data) -> {:ok, Enum.reverse(data)}
    end)
  end

  def parse(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:parse)
  end

  @spec changeset(t, map) :: {:ok, map} | {:error, Ecto.Changeset.t()}
  def changeset(%__MODULE__{} = source, %{} = attrs) do
    source
    |> cast(attrs, @fields)
    |> maybe_put_name()
    |> cast_embed(:file_size_limit, with: &file_size_limit_changeset/2)
    |> validate_required([:id, :name, :public])
  end

  defp maybe_put_name(%{valid?: true} = changeset), do: changeset

  defp maybe_put_name(changeset) do
    name = get_field(changeset, :name)
    id = get_field(changeset, :id)

    if name, do: changeset, else: put_change(changeset, :name, id)
  end

  defp file_size_limit_changeset(source, attrs) do
    source
    |> cast(attrs, [:size, :unit])
    |> validate_required([:unit])
  end

  defimpl Jason.Encoder, for: __MODULE__ do
    alias Supabase.Storage.Bucket

    def encode(%Bucket{} = bucket, opts) do
      bucket
      |> Map.take([:id, :name, :public, :allowed_mime_types])
      |> Map.put_new_lazy(:file_size_limit, fn ->
        cond do
          is_nil(bucket.file_size_limit) -> nil
          is_nil(bucket.file_size_limit.size) -> nil
          bucket.file_size_limit.unit == :byte -> bucket.file_size_limit.size
          true -> to_string(bucket.file_size_limit)
        end
      end)
      |> Jason.Encode.map(opts)
    end
  end

  defimpl String.Chars, for: __MODULE__.FileSizeLimit do
    alias Supabase.Storage.Bucket.FileSizeLimit

    def to_string(%FileSizeLimit{size: size} = file_size_limit) do
      Kernel.to_string(size) <>
        case file_size_limit.unit do
          :byte -> "B"
          :megabyte -> "MB"
          :gigabyte -> "GB"
          :terabyte -> "TB"
        end
    end
  end
end
