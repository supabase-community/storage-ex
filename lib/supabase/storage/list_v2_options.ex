defmodule Supabase.Storage.ListV2Options do
  @moduledoc """
  Represents the options for cursor-based pagination when querying objects within Supabase Storage.

  This module encapsulates the v2 list options that provide efficient cursor-based pagination
  for large datasets. Unlike offset-based pagination, cursor pagination has O(1) complexity
  regardless of the position in the dataset.

  ## Experimental Feature

  This is marked as experimental and corresponds to the `listV2()` method in the JavaScript SDK.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @typedoc """
  A `ListV2Options` consists of the following attributes:

  - `limit`: The number of files you want to be returned. Defaults to 100.
  - `cursor`: The pagination cursor from a previous response. Use this to get the next page.
  - `with_delimiter`: Enable folder hierarchy grouping when set to true.
  """
  @type t :: %__MODULE__{
          limit: integer(),
          cursor: String.t() | nil,
          with_delimiter: boolean()
        }

  @fields ~w(limit cursor with_delimiter)a

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field(:limit, :integer, default: 100)
    field(:cursor, :string)
    field(:with_delimiter, :boolean, default: false)
  end

  @spec parse(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def parse(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> apply_action(:parse)
  end
end
