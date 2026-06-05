# Build a table template specification

Convenience function for constructing table configurations suitable for
[`at_create_table()`](https://noamross.github.io/airtable2/reference/at_create_table.md)
or
[`at_create_base()`](https://noamross.github.io/airtable2/reference/at_create_base.md).

## Usage

``` r
air_table_template(name, fields, description = NULL)
```

## Arguments

- name:

  Table name.

- fields:

  A list of field specifications (e.g., from
  [`air_field_template()`](https://noamross.github.io/airtable2/reference/air_field_template.md)).

- description:

  Optional table description.

## Value

A list suitable for passing to the Airtable API.

## Examples

``` r
fields <- list(
  air_field_template("Name", "singleLineText"),
  air_field_template("Score", "number", options = list(precision = 2))
)
air_table_template("Results", fields, description = "Exam results")
#> $name
#> [1] "Results"
#> 
#> $description
#> [1] "Exam results"
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
#> [1] 2
#> 
#> 
#> 
#> 
```
