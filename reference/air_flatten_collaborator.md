# Flatten a collaborator list-column to strings

Flatten a collaborator list-column to strings

## Usage

``` r
air_flatten_collaborator(x, format = "{name} <{email}>")
```

## Arguments

- x:

  A list-column where each element is a named list with `name` and
  `email` fields.

- format:

  A glue-style template. Available fields: `id`, `email`, `name`.
  Default: `"{name} <{email}>"`.

## Value

A character vector.
