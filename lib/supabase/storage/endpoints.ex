defmodule Supabase.Storage.Endpoints do
  @moduledoc "Defines the Endpoints for the Supabase Storage API"

  def bucket_path do
    "/bucket"
  end

  def bucket_path_with_id(id) do
    "/bucket/#{id}"
  end

  def bucket_path_to_empty(id) do
    bucket_path_with_id(id) <> "/empty"
  end

  def file_upload_url(path) do
    "/object/upload/sign/#{path}"
  end

  def file_move do
    "/object/move"
  end

  def file_copy do
    "/object/copy"
  end

  def file_upload(bucket, path) do
    "/object/#{bucket}/#{path}"
  end

  def file_upload_to_url(bucket, path) do
    "/object/upload/sign/#{bucket}/#{path}"
  end

  def file_info(bucket, wildcard) do
    "/object/info/authenticated/#{bucket}/#{wildcard}"
  end

  def file_list(bucket) do
    "/object/list/#{bucket}"
  end

  def file_remove(bucket) do
    "/object/#{bucket}"
  end

  def file_signed_url(bucket, path) do
    "/object/sign/#{bucket}/#{path}"
  end

  def file_upload_signed_url(bucket, path) do
    "/object/upload/sign/#{bucket}/#{path}"
  end

  def file_download(bucket, wildcard) do
    "/object/authenticated/#{bucket}/#{wildcard}"
  end
end
