# Delete records from a table (high-level)

A convenience wrapper around
[`at_delete_records()`](https://noamross.github.io/airtable2/reference/at_delete_records.md)
with messaging.

## Usage

``` r
air_delete(record_ids, table, base_id = NULL, .token = NULL, progress = NULL)
```

## Arguments

- record_ids:

  Character vector of record IDs to delete.

- table:

  Table name or ID.

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for paginated
  requests. If `NULL` (default), uses option `airtable2.progress.bar` or
  env var `AIRTABLE2_PROGRESS_BAR`.

## Value

Invisible `NULL`. Side effect: deletes records.

## Examples

``` r
if (FALSE) { # \dontrun{
air_delete(c("recABC", "recDEF"), "Contacts", "appXXXXXX")
} # }
```
