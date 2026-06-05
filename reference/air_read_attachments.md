# Read attachments from records

Downloads attachment files from a specified field, returning them as
either in-memory blobs or saved files.

## Usage

``` r
air_read_attachments(
  base_id,
  table,
  field,
  record_ids = NULL,
  dest = c("blob", "file"),
  dir = NULL,
  parallel = NULL,
  .token = NULL
)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- table:

  Table name or ID.

- field:

  Name of the attachment field.

- record_ids:

  Optional character vector of specific record IDs to fetch. If `NULL`,
  fetches all records.

- dest:

  Either `"blob"` (return raw content as list-column) or `"file"` (save
  to disk).

- dir:

  Directory to save files to (required if `dest = "file"`).

- parallel:

  Logical or `NULL`. If `TRUE`, attachment downloads use
  [`httr2::req_perform_parallel()`](https://httr2.r-lib.org/reference/req_perform_parallel.html)
  (up to 5 concurrent). If `NULL`, uses option `airtable2.parallel` or
  env var `AIRTABLE2_PARALLEL` (default `TRUE`).

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A tibble with `airtable_id`, `filename`, `url`, and either `blob` (raw
list-column) or `local_path` (character).
