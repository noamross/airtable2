# Flatten a multi-select list-column to delimited strings

Flatten a multi-select list-column to delimited strings

## Usage

``` r
air_flatten_multiselect(x, sep = NULL)
```

## Arguments

- x:

  A list-column where each element is a character vector.

- sep:

  Delimiter to join values. Default `"; "`, overridable via
  `options(airtable2.delimiter = ...)` or the `AIRTABLE2_DELIMITER`
  environment variable. An explicit `sep` argument always takes
  precedence.

## Value

A character vector.
