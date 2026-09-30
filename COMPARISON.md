# Comparison: storage-js (official, v2.110.x monorepo) vs storage-ex (Elixir, v0.6.0)

storage-js is the source of truth. Both libraries already share: bucket CRUD,
file upload/update/move/copy/remove/list/listV2, signed URLs (single, bulk,
upload), public URLs, `info`/`exists`, image transform options, cache-control
and metadata upload options, and storage vector buckets (bucket/index/data
APIs). Only deltas are listed below.

## Missing in Elixir

- **Analytics buckets (Iceberg REST catalog)** — `StorageAnalyticsClient`
  (`storage.analytics`): create/list/delete analytics buckets and obtain an
  Iceberg REST catalog client (`iceberg-js`) for table operations.
  - Tip: makes full sense server-side — Elixir backends are the natural place
    to query Iceberg tables. Port as a thin HTTP client over the Iceberg REST
    catalog spec (contract-first, behaviour + Finch); no need to mirror the
    whole `iceberg-js` surface initially.
- **CDN cache purge** — `purgeBucketCache(id, { transformations })` on the
  bucket API and `purgeCache(paths)` on the file API (added in storage-js
  #2429, key url-encoded in #2545).
  - Tip: trivial — one authenticated POST/DELETE per scope. Pure win for
  server-side cache invalidation after re-uploads; add to both handlers.
- **`cacheNonce` query param** — on `createSignedUrl(s)` and `download` to
  bust cached signed/public URLs (#2234).
  - Tip: one extra query param; trivially portable, add to the signed-URL and
    download option structs.
- **In-memory / streaming upload bodies** — JS `upload`/`update` accept
  `ArrayBuffer`/`Blob`/`ReadableStream` (auto `duplex: 'half'` for Node
  streams); Elixir only accepts a `file_path` on disk
  (`Fetcher.upload(file_path)` in `file_handler.ex`).
  - Tip: meaningful server-side — generated files and phoenix upload buffers
    shouldn't require a temp file. Accept `iodata()`/`File.Stream` alongside
    paths; Finch supports streaming request bodies.
- **Request cancellation / timeout control** — JS threads `AbortSignal` and
  `cache` fetch options through download/upload.
  - Tip: maps to Finch `receive_timeout`/caller-controlled cancellation;
    largely covered by OTP process exits, so low priority — only worth adding
    explicit per-request timeout options.

## Not applicable / present in neither

- **Resumable uploads (tus)** — no longer shipped in current storage-js (no
  `tus-js-client` dependency); nothing to port. If wanted for large files
  later, it would be a separate protocol layer, not a parity gap.
- **S3 protocol compatibility** — handled server-side by Supabase (S3
  credentials), not part of either client library.
