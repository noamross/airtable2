# Get information about a single base

Get information about a single base

## Usage

``` r
at_get_base(base_id, token = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`).

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A list with `id`, `name`, and `permissionLevel`, or `NULL` if not found.

## Examples

``` r
if (FALSE) { # \dontrun{
info <- at_get_base("appXXXXXXXXXXXXXX")
info$name
info$permissionLevel
} # }
```
