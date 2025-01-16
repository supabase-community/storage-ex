defmodule Supabase.Storage.SearchOptions do
  @moduledoc """
  Represents the search options for querying objects within Supabase Storage.

  This module encapsulates various options that aid in fetching and sorting storage objects. These options include specifying the limit on the number of results, an offset for pagination, and a sorting directive.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @typedoc """
  An `SearchOptions` consists of the following attributes:

  - `limit`: The number of files you want to be returned.
  - `offset`: The starting position.
  - `sort_by`: The column to sort by. Can be any column inside a `Supabase.Storage.File`.
  - `search`: The search string to filter files by.
  """
  @type t :: %__MODULE__{
          limit: integer(),
          offset: integer(),
          sort_by: %__MODULE__.SortBy{
            column: String.t(),
            order: String.t()
          },
          search: String.t()
        }

  @fields ~w(limit offset sort_by search)a

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field(:limit, :integer, default: 100)
    field(:offset, :integer, default: 0)
    field(:search, :string)

    embeds_one :sort_by, SortBy, primary_key: false, defaults_to_struct: true do
      @derive Jason.Encoder
      field(:column, :string, default: "name")
      field(:order, Ecto.Enum, values: [:asc, :desc], default: :asc)
    end
  end

  @spec parse(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def parse(attrs) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> cast_embed(:search_by, with: &search_by_changeset/2, required: true)
    |> apply_action(:parse)
  end

  defp search_by_changeset(source, attrs) do
    source
    |> cast(attrs, [:column, :order])
    |> validate_required([:column, :order])
  end
end
