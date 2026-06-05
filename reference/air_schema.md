# Get schema for a base as a tidy tibble

Returns table and field metadata in a structured tibble format.

## Usage

``` r
air_schema(base_id, .token = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A tibble with columns `table_id`, `table_name`, and `fields` (a
list-column of tibbles with `id`, `name`, `type`, `description`).

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- air_schema("appXXXXXX")
schema$table_name
schema$fields[[1]]
} # }
```
