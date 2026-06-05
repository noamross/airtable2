# Update field metadata

Update field metadata

## Usage

``` r
at_update_field(
  base_id,
  table_id,
  field_id,
  name = NULL,
  description = NULL,
  token = NULL
)
```

## Arguments

- base_id:

  Base ID.

- table_id:

  Table ID.

- field_id:

  Field ID.

- name:

  New field name (or `NULL` to leave unchanged).

- description:

  New description (or `NULL` to leave unchanged).

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

The updated field object.

## Examples

``` r
if (FALSE) { # \dontrun{
at_update_field(
  base_id     = "appXXXXXXXXXXXXXX",
  table_id    = "tblXXXXXXXXXXXXXX",
  field_id    = "fldXXXXXXXXXXXXXX",
  name        = "Full Name",
  description = "First and last name"
)
} # }
```
