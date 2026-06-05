# Expand collaborator strings to list-column

Inverse of
[`air_flatten_collaborator()`](https://noamross.github.io/airtable2/reference/air_flatten_collaborator.md).

## Usage

``` r
air_expand_collaborator(x, pattern = "(.+) <(.+)>")
```

## Arguments

- x:

  A character vector (e.g., `"Name <email>"`)

- pattern:

  Regex with two capture groups (name, email). Default: `"(.+) <(.+)>"`.

## Value

A list of named lists with `name` and `email`.
