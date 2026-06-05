# Get a single record

Get a single record

## Usage

``` r
at_get_record(base_id, table_id, record_id, token = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`).

- table_id:

  Table name or ID.

- record_id:

  Record ID (e.g., `"recXXXXXX"`).

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A single record object (list with `id`, `createdTime`, `fields`).

## Examples

``` r
if (FALSE) { # \dontrun{
rec <- at_get_record(
  "appXXXXXXXXXXXXXX",
  "Contacts",
  "recXXXXXXXXXXXXXX"
)
rec$fields$Name
} # }
```
