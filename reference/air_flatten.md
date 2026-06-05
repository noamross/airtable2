# Flatten a complex Airtable column to a simple atomic vector

Generic that dispatches on the `air_*` S3 class of a column, applying
the appropriate per-type flattener. Plain (already-flat) vectors are
returned unchanged.

## Usage

``` r
air_flatten(x, ...)
```

## Arguments

- x:

  A column, typically an `air_*` list-column from
  [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md).

- ...:

  Passed to the underlying flattener, e.g. `sep`, `field`, `format`.

## Value

A character vector (or `x` unchanged for non-`air_*` input).
