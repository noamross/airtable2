# Create records in a table

Creates up to 10 records per API call. If more than 10 records are
provided, they are automatically batched.

## Usage

``` r
at_create_records(
  base_id,
  table_id,
  records,
  typecast = FALSE,
  token = NULL,
  progress = NULL
)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`).

- table_id:

  Table name or ID.

- records:

  A list of record objects. Each should be a list with a `fields`
  element (a named list of field values).

- typecast:

  If `TRUE`, Airtable will attempt to cast values to the correct type.
  Defaults to `FALSE` here (low-level, strict); the high-level
  [`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md)
  and
  [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
  default to `TRUE`.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for batch
  operations. If `NULL` (default), uses option `airtable2.progress.bar`
  or env var `AIRTABLE2_PROGRESS_BAR` (both default to `TRUE`).

## Value

A list of created record objects (with assigned IDs).

## Examples

``` r
if (FALSE) { # \dontrun{
records <- list(
  list(fields = list(Name = "Alice", Age = 30)),
  list(fields = list(Name = "Bob",   Age = 25))
)
created <- at_create_records("appXXXXXXXXXXXXXX", "Contacts", records)
vapply(created, function(r) r$id, character(1))
} # }
```
