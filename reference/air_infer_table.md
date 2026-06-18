# Infer an Airtable table specification from a data frame

Wraps
[`air_infer_fields()`](https://noamross.github.io/airtable2/reference/air_infer_fields.md)
to produce a complete table spec suitable for
[`at_create_table()`](https://noamross.github.io/airtable2/reference/at_create_table.md)
or
[`at_create_base()`](https://noamross.github.io/airtable2/reference/at_create_base.md).

## Usage

``` r
air_infer_table(data, name, description = NULL)
```

## Arguments

- data:

  A data frame with at least one column.

- name:

  Table name.

- description:

  Optional table description.

## Value

A list with `name`, `fields`, and optionally `description`.

## Examples

``` r
df <- data.frame(Name = "Alice", Score = 3.14)
air_infer_table(df, "Results")
#> $name
#> [1] "Results"
#> 
#> $fields
#> $fields[[1]]
#> $fields[[1]]$name
#> [1] "Name"
#> 
#> $fields[[1]]$type
#> [1] "singleLineText"
#> 
#> 
#> $fields[[2]]
#> $fields[[2]]$name
#> [1] "Score"
#> 
#> $fields[[2]]$type
#> [1] "number"
#> 
#> $fields[[2]]$options
#> $fields[[2]]$options$precision
#> [1] 8
#> 
#> 
#> 
#> 
```
