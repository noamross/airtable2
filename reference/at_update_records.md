# Update multiple records

Updates records using PATCH (partial) or PUT (destructive). Handles
auto-batching in groups of 10. Also supports upsert via the
`upsert_fields` argument.

## Usage

``` r
at_update_records(
  base_id,
  table_id,
  records,
  method = c("PATCH", "PUT"),
  typecast = FALSE,
  upsert_fields = NULL,
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

  A list of record objects. Each should be a list with `id` and `fields`
  elements. For upsert, `id` can be omitted.

- method:

  Either `"PATCH"` (partial update) or `"PUT"` (destructive).

- typecast:

  If `TRUE`, Airtable will attempt to cast values. Defaults to `FALSE`
  here (low-level, strict);
  [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
  defaults to `TRUE`.

- upsert_fields:

  Character vector (1-3 fields) to merge on for upsert. If `NULL`,
  performs a standard update.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for batch
  operations. If `NULL` (default), uses option `airtable2.progress.bar`
  or env var `AIRTABLE2_PROGRESS_BAR` (both default to `TRUE`).

## Value

A list with `records`, and (for upserts) `createdRecords` and
`updatedRecords` character vectors.

## Examples

``` r
if (FALSE) { # \dontrun{
# Patch an existing record
at_update_records(
  "appXXXXXXXXXXXXXX", "Contacts",
  records = list(list(id = "recXXXXXXXXXXXXXX", fields = list(Age = 31)))
)

# Upsert by Name field
at_update_records(
  "appXXXXXXXXXXXXXX", "Contacts",
  records = list(list(fields = list(Name = "Alice", Age = 31))),
  upsert_fields = "Name"
)
} # }
```
