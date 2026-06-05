# Upload attachments to records

Upload attachments to records

## Usage

``` r
air_write_attachments(
  base_id,
  table,
  field,
  data,
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

- data:

  A tibble with `airtable_id` and `file_path` columns.

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

Invisible `NULL`. Side effect: uploads attachments.
