# Build a field template specification

Convenience function for constructing field configurations.

## Usage

``` r
air_field_template(name, type, description = NULL, options = NULL)
```

## Arguments

- name:

  Field name.

- type:

  Field type (e.g., `"singleLineText"`, `"number"`, `"singleSelect"`).

- description:

  Optional field description.

- options:

  Optional field-specific options (list). See Airtable docs for
  available options per type.

## Value

A list suitable for use in
[`air_table_template()`](https://noamross.github.io/airtable2/reference/air_table_template.md)
or
[`at_create_field()`](https://noamross.github.io/airtable2/reference/at_create_field.md).

## Examples

``` r
air_field_template("Status", "singleSelect",
  options = list(choices = list(
    list(name = "Active"), list(name = "Inactive")
  ))
)
#> $name
#> [1] "Status"
#> 
#> $type
#> [1] "singleSelect"
#> 
#> $options
#> $options$choices
#> $options$choices[[1]]
#> $options$choices[[1]]$name
#> [1] "Active"
#> 
#> 
#> $options$choices[[2]]
#> $options$choices[[2]]$name
#> [1] "Inactive"
#> 
#> 
#> 
#> 
```
