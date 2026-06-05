# Get current user info

Get current user info

## Usage

``` r
at_whoami(token = NULL)
```

## Arguments

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A list with `id` and (if scoped) `email`, `scopes`.

## Examples

``` r
if (FALSE) { # \dontrun{
me <- at_whoami()
me$email
me$id
} # }
```
