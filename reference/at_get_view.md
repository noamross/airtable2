# Get a specific view's metadata

Get a specific view's metadata

## Usage

``` r
at_get_view(base_id, table_id, view_id, token = NULL)
```

## Arguments

- base_id:

  Base ID.

- table_id:

  Table ID.

- view_id:

  View ID.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A list with view metadata (name, type, formula, filterByFormula, etc.).

## Examples

``` r
if (FALSE) { # \dontrun{
view <- at_get_view(
  "appXXXXXXXXXXXXXX",
  "tblXXXXXXXXXXXXXX",
  "viwXXXXXXXXXXXXXX"
)
view$name
view$type
} # }
```
