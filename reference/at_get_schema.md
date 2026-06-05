# Get the schema (tables + fields) for a base

Get the schema (tables + fields) for a base

## Usage

``` r
at_get_schema(base_id, token = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`).

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A list of table objects, each containing `id`, `name`, `description`,
`fields`, and `views`.

## Examples

``` r
if (FALSE) { # \dontrun{
tables <- at_get_schema("appXXXXXXXXXXXXXX")
vapply(tables, function(t) t$name, character(1))
} # }
```
