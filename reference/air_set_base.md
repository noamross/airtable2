# Set the default Airtable base for this session

Validates that `base_id` is accessible with the current token, prints a
`{cli}` confirmation, and sets `options(airtable2.base_id = base_id)`
for the rest of the session. Functions that accept `base_id` will use
this default when `base_id` is `NULL`.

## Usage

``` r
air_set_base(base_id, .token = NULL)
```

## Arguments

- base_id:

  Base ID (starts with `app`).

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

`base_id` (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
air_set_base("appXXXXXXXXXXXXXX")
} # }
```
