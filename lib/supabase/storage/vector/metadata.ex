defmodule Supabase.Storage.Vector.Metadata do
  @moduledoc """
  Schema for vector bucket metadata.

  Contains information about a vector bucket including its name, creation timestamp,
  and optional encryption configuration for data at rest.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @typedoc """
  Vector bucket metadata structure.

  ## Fields

    * `:vector_bucket_name` - Unique name identifying the vector bucket
    * `:creation_time` - Unix timestamp (seconds) when the bucket was created
    * `:encryption_configuration` - Optional encryption settings for data at rest
      * `:kms_key_arn` - ARN of the AWS KMS key used for encryption
      * `:sse_type` - Server-side encryption type (e.g., "KMS")
  """
  @type t :: %__MODULE__{
          vector_bucket_name: String.t(),
          creation_time: integer | nil,
          encryption_configuration: %__MODULE__.EncryptConfiguration{
            kms_key_arn: String.t() | nil,
            sse_type: String.t() | nil
          }
        }

  @primary_key false
  embedded_schema do
    field(:vector_bucket_name, :string)
    field(:creation_time, :integer)

    embeds_one :encryption_configuration, EncryptConfiguration, primary_key: false do
      field(:kms_key_arn, :string)
      field(:sse_type, :string)
    end
  end

  @spec parse(map | list(map)) :: {:ok, t | list(t)} | {:error, Ecto.Changeset.t()}
  @doc false
  def parse(attrs) when is_list(attrs) do
    Enum.reduce_while(attrs, [], fn attr, acc ->
      case parse(attr) do
        {:ok, data} -> {:cont, acc ++ [data]}
        {:error, changeset} -> {:halt, changeset}
      end
    end)
    |> then(fn
      data when is_list(data) -> {:ok, data}
      changeset -> {:error, changeset}
    end)
  end

  def parse(attrs) do
    %__MODULE__{}
    |> changeset(normalize_response(attrs))
    |> apply_action(:parse)
  end

  # The vectors API returns camelCase JSON keys; translate the known
  # response keys to the snake_case fields before casting.
  defp normalize_response(attrs) when is_map(attrs) do
    attrs
    |> rename_key("vectorBucketName", "vector_bucket_name")
    |> rename_key("creationTime", "creation_time")
    |> normalize_encryption_configuration()
  end

  defp normalize_encryption_configuration(attrs) do
    case Map.pop(attrs, "encryptionConfiguration") do
      {nil, attrs} ->
        attrs

      {config, attrs} when is_map(config) ->
        config =
          config
          |> rename_key("kmsKeyArn", "kms_key_arn")
          |> rename_key("sseType", "sse_type")

        Map.put(attrs, "encryption_configuration", config)
    end
  end

  defp rename_key(map, from, to) do
    case Map.pop(map, from) do
      {nil, map} -> map
      {value, map} -> Map.put(map, to, value)
    end
  end

  @doc """
      Creates a changeset for validating and casting vector bucket metadata.

  Va    lidates that `vector_bucket_name` is present and casts the optional
  `e    ncryption_configuration` nested struct.

      ## Parameters

        * `meta` - A `Supabase.Storage.Vector.Metadata` struct
        *)
  `attrs` - Map of attributes to cast and validate

  ## Returns

  An `Ecto.Changeset` with validated metadata.
  """
  def changeset(%__MODULE__{} = meta, %{} = attrs) do
    meta
    |> cast(attrs, [:vector_bucket_name, :creation_time])
    |> validate_required([:vector_bucket_name])
    |> cast_embed(:encryption_configuration, with: &encrypt_changeset/2, required: false)
  end

  defp encrypt_changeset(config, attrs) do
    cast(config, attrs, [:kms_key_arn, :sse_type])
  end
end
