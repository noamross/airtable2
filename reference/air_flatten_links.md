# Flatten a record-links list-column to delimited strings

Flatten a record-links list-column to delimited strings

## Usage

``` r
air_flatten_links(x, sep = NULL)
```

## Arguments

- x:

  A list-column where each element is a character vector of record IDs.

- sep:

  Delimiter. Default `"; "`, overridable via
  `options(airtable2.delimiter = ...)` or the `AIRTABLE2_DELIMITER`
  environment variable. An explicit `sep` argument always takes
  precedence.

## Value

A character vector.
