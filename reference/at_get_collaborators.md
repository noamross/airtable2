# Get collaborators for a base

Get collaborators for a base

## Usage

``` r
at_get_collaborators(base_id, token = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`).

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

The parsed collaborator response (list).

## Examples

``` r
if (FALSE) { # \dontrun{
collabs <- at_get_collaborators("appXXXXXXXXXXXXXX")
} # }
```
