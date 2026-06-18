# List records from a table

List records from a table

## Usage

``` r
at_list_records(
  base_id,
  table_id,
  fields = NULL,
  formula = NULL,
  sort = NULL,
  view = NULL,
  max_records = Inf,
  page_size = 100L,
  cell_format = NULL,
  time_zone = NULL,
  user_locale = NULL,
  return_fields_by_id = FALSE,
  token = NULL,
  progress = NULL
)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`).

- table_id:

  Table name or ID.

- fields:

  Character vector of field names to return.

- formula:

  Airtable formula string for filtering.

- sort:

  A named character vector: names are field names, values are `"asc"` or
  `"desc"`.

- view:

  View name or ID to filter by.

- max_records:

  Maximum total records to return.

- page_size:

  Records per page (max 100).

- cell_format:

  Either `"json"` (default) or `"string"`.

- time_zone:

  Time zone for date formatting (when `cell_format = "string"`).

- user_locale:

  Locale for date formatting.

- return_fields_by_id:

  If `TRUE`, use field IDs as keys instead of names.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for batch
  operations. If `NULL` (default), uses option `airtable2.progress.bar`
  or env var `AIRTABLE2_PROGRESS_BAR` (both default to `TRUE`).

## Value

A list of record objects (each with `id`, `createdTime`, `fields`).

## Examples

``` r
if (FALSE) { # \dontrun{
# List all records from a table
records <- at_list_records("appXXXXXXXXXXXXXX", "Contacts")

# Filter records with a formula
records <- at_list_records(
  "appXXXXXXXXXXXXXX", "Contacts",
  formula = "{Active} = TRUE()",
  fields  = c("Name", "Email")
)
} # }
```
