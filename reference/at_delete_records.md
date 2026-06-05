# Delete records

Deletes up to 10 records per API call. Automatically batched.

## Usage

``` r
at_delete_records(base_id, table_id, record_ids, token = NULL, progress = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`).

- table_id:

  Table name or ID.

- record_ids:

  Character vector of record IDs to delete.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for batch
  operations. If `NULL` (default), uses option `airtable2.progress.bar`
  or env var `AIRTABLE2_PROGRESS_BAR`.

## Value

A list of delete confirmation objects (each with `id` and
`deleted = TRUE`).

## Examples

``` r
if (FALSE) { # \dontrun{
at_delete_records(
  "appXXXXXXXXXXXXXX",
  "Contacts",
  c("recXXXXXXXXXXXXXX", "recYYYYYYYYYYYYYY")
)
} # }
```
