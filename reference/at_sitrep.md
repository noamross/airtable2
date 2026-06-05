# Summarize Airtable situation report

Safely probes the current token to determine what workspaces and bases
are accessible. Modelled after `usethis::git_sitrep()` and
`usethis::proj_sitrep()`. Useful for debugging authentication issues and
understanding the scope of the current token.

## Usage

``` r
at_sitrep(token = NULL)
```

## Arguments

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A list with:

- `user`: User info from
  [`at_whoami()`](https://noamross.github.io/airtable2/reference/at_whoami.md)
  (id, and `email`/`scopes` if the token grants them)

- `scopes`: Character vector of token scopes, or `NULL` if not exposed

- `bases`: Tibble of accessible bases (`id`, `name`, `permissionLevel`)

- `error`: `NULL` if successful, otherwise a message string

Note: the non-enterprise Airtable API does not expose workspace names or
the workspace each base belongs to, so workspaces cannot be enumerated
from a token alone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Check what your current token can access
info <- at_sitrep()
print(info$user)
print(info$scopes)
head(info$bases)
} # }
```
