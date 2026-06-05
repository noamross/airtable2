# Update table metadata

Update table metadata

## Usage

``` r
at_update_table(
  base_id,
  table_id,
  name = NULL,
  description = NULL,
  token = NULL
)
```

## Arguments

- base_id:

  Base ID.

- table_id:

  Table ID.

- name:

  New table name (or `NULL` to leave unchanged).

- description:

  New description (or `NULL` to leave unchanged).

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

The updated table object.

## Examples

``` r
if (FALSE) { # \dontrun{
at_update_table(
  base_id  = "appXXXXXXXXXXXXXX",
  table_id = "tblXXXXXXXXXXXXXX",
  name     = "Renamed Table"
)
} # }
```
