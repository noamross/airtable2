# List views in a table

List views in a table

## Usage

``` r
at_list_views(base_id, table_id, token = NULL)
```

## Arguments

- base_id:

  Base ID.

- table_id:

  Table ID.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A tibble with columns `id`, `name`, and `type`.

## Examples

``` r
if (FALSE) { # \dontrun{
views <- at_list_views("appXXXXXXXXXXXXXX", "tblXXXXXXXXXXXXXX")
views$name
} # }
```
