# Set the default Airtable token for this session

Validates the token by calling
[`at_whoami()`](https://noamross.github.io/airtable2/reference/at_whoami.md),
prints a `{cli}` confirmation with the authenticated user's email, and
sets `options(airtable2.token = tok)`.

## Usage

``` r
air_set_token(tok)
```

## Arguments

- tok:

  Personal Access Token (PAT) string.

## Value

`tok` (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
air_set_token(Sys.getenv("AIRTABLE_API_KEY"))
} # }
```
