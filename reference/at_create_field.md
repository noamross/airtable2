# Create a field in a table

Create a field in a table

## Usage

``` r
at_create_field(
  name,
  table_id,
  type,
  base_id = NULL,
  description = NULL,
  options = NULL,
  token = NULL
)
```

## Arguments

- name:

  Field name.

- table_id:

  Table ID.

- type:

  Field type (e.g., `"singleLineText"`, `"number"`).

- base_id:

  Base ID. If `NULL`, uses the session default set by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- description:

  Optional field description.

- options:

  Field-specific options (list). Depends on field type.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

The created field object.

## Examples

``` r
if (FALSE) { # \dontrun{
# Add a number field
at_create_field(
  name     = "Score",
  table_id = "tblXXXXXXXXXXXXXX",
  type     = "number",
  base_id  = "appXXXXXXXXXXXXXX",
  options  = list(precision = 1L)
)

# Add a single-select field
at_create_field(
  name     = "Status",
  table_id = "tblXXXXXXXXXXXXXX",
  type     = "singleSelect",
  base_id  = "appXXXXXXXXXXXXXX",
  options  = list(choices = list(list(name = "Open"), list(name = "Closed")))
)
} # }
```
