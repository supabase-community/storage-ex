defmodule Supabase.Storage.Behaviour do
  @moduledoc "Defines Supabase Storage Client callbacks"

  alias Supabase.Storage.Bucket

  @type conn :: Supabase.Client.t()
  @type bucket_id :: String.t()

  @callback from(conn, bucket_id) :: Supabase.Storage.t()
  @callback list_buckets(conn) :: Supabase.result([Bucket.t()])
  @callback get_bucket(conn, bucket_id) :: Supabase.result(Bucket.t())
  @callback create_bucket(conn, bucket_id, map) :: Supabase.result(:created)
  @callback update_bucket(conn, bucket_id, map) :: Supabase.result(:updated)
  @callback empty_bucket(conn, bucket_id) :: Supabase.result(:emptied)
  @callback delete_bucket(conn, bucket_id) :: Supabase.result(:deleted)
end
