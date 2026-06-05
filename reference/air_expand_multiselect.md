# Expand delimited strings to a multi-select list-column

Inverse of
[`air_flatten_multiselect()`](https://noamross.github.io/airtable2/reference/air_flatten_multiselect.md).

## Usage

``` r
air_expand_multiselect(x, sep = NULL)
```

## Arguments

- x:

  A character vector of delimited values.

- sep:

  Delimiter to split on. Default `"; "` (tolerates optional surrounding
  spaces when the delimiter is a semicolon family), overridable via
  `options(airtable2.delimiter = ...)` or the `AIRTABLE2_DELIMITER`
  environment variable. An explicit `sep` argument always takes
  precedence.

## Value

A list of character vectors.
