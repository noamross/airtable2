# Simplify all complex columns in a tibble for display/export

Applies the appropriate flatten function to each list-column based on
schema information.

## Usage

``` r
air_simplify(data, schema = NULL)
```

## Arguments

- data:

  A tibble (typically from
  [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)).

- schema:

  Optional list of field definitions (from
  [`at_get_schema()`](https://noamross.github.io/airtable2/reference/at_get_schema.md)).
  If `NULL`, uses heuristics.

## Value

A tibble with list-columns replaced by character representations.
