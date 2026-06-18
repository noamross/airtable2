# Infer Airtable field specifications from a data frame

Maps R column types to Airtable field types. The first column becomes
the primary field. Factors are mapped to `singleSelect` with levels as
choices.

## Usage

``` r
air_infer_fields(data)
```

## Arguments

- data:

  A data frame with at least one column.

## Value

A list of field specification lists suitable for
[`at_create_table()`](https://noamross.github.io/airtable2/reference/at_create_table.md).

## Examples

``` r
df <- data.frame(Name = "Alice", Score = 3.14, Active = TRUE)
air_infer_fields(df)
#> [[1]]
#> [[1]]$name
#> [1] "Name"
#> 
#> [[1]]$type
#> [1] "singleLineText"
#> 
#> 
#> [[2]]
#> [[2]]$name
#> [1] "Score"
#> 
#> [[2]]$type
#> [1] "number"
#> 
#> [[2]]$options
#> [[2]]$options$precision
#> [1] 8
#> 
#> 
#> 
#> [[3]]
#> [[3]]$name
#> [1] "Active"
#> 
#> [[3]]$type
#> [1] "checkbox"
#> 
#> [[3]]$options
#> [[3]]$options$icon
#> [1] "check"
#> 
#> [[3]]$options$color
#> [1] "greenBright"
#> 
#> 
#> 
```
