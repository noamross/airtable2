# List all accessible bases

List all accessible bases

## Usage

``` r
at_list_bases(token = NULL)
```

## Arguments

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A tibble with columns `id`, `name`, and `permissionLevel`.

## Examples

``` r
if (FALSE) { # \dontrun{
# List all bases accessible with the current token
at_list_bases()
} # }
```
