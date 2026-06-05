# Get base metadata as a flat tibble

Returns one row per field across all tables, useful for inspecting and
editing base structure as a data frame.

## Usage

``` r
air_meta(base_id, .token = NULL)
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

A tibble with columns: `table_name`, `table_id`, `field_name`,
`field_id`, `field_type`, `description`.

## Examples

``` r
if (FALSE) { # \dontrun{
meta <- air_meta("appXXXXXX")
meta
} # }
```
