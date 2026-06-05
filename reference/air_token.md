# Resolve an Airtable personal access token

Looks for a token in this order:

1.  Explicit `.token` argument

2.  `getOption("airtable2.token")`

3.  `Sys.getenv("AIRTABLE_API_KEY")`

## Usage

``` r
air_token(token = NULL)
```

## Arguments

- token:

  A personal access token string, or `NULL` to use defaults.

## Value

A string (the token).

## Examples

``` r
if (FALSE) { # \dontrun{
# Uses AIRTABLE_API_KEY env var by default
token <- air_token()

# Or pass explicitly
token <- air_token("patXXXXXXXX")
} # }
```
