defmodule Supabase.Storage.AnalyticsBucket do
  @moduledoc """
  Represents an Analytics Bucket on Supabase Storage.

  Analytics buckets are optimized for analytical workloads and expose their
  data through an Iceberg REST catalog. See `Supabase.Storage.Analytics`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @typedoc """
  An `AnalyticsBucket` consists of:

  - `name`: The unique name of the bucket.
  - `type`: The bucket type, always `:analytics`.
  - `format`: The underlying table format, currently always `"iceberg"`.
  - `created_at`: Timestamp indicating when the bucket was created.
  - `updated_at`: Timestamp indicating the last update to the bucket.
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          type: :analytics,
          format: String.t() | nil,
          created_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @fields ~w(name type format created_at updated_at)a

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:type, Ecto.Enum, values: [:analytics], default: :analytics)
    field(:format, :string)
    field(:created_at, :naive_datetime)
    field(:updated_at, :naive_datetime)
  end

  @spec parse(map | list(map)) :: {:ok, t | list(t)} | {:error, Ecto.Changeset.t()}
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

  def parse(%{} = attrs) do
    attrs =
      Map.new(attrs, fn
        {:type, v} -> {"type", v}
        {"type", v} when is_binary(v) -> {"type", String.downcase(v)}
        {k, v} -> {to_string(k), v}
      end)

    %__MODULE__{}
    |> cast(attrs, @fields)
    |> validate_required([:name])
    |> apply_action(:parse)
  end
end
