# Create a table in a base

Create a table in a base

## Usage

``` r
at_create_table(
  name,
  fields = list(list(name = "id", type = "singleLineText")),
  base_id = NULL,
  description = NULL,
  token = NULL
)
```

## Arguments

- name:

  Table name.

- fields:

  A list of field configurations. The first field becomes the primary
  field.

- base_id:

  Base ID. If `NULL`, uses the session default set by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- description:

  Optional table description.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

The created table object (list with `id`, `name`, `fields`).

## Examples

``` r
if (FALSE) { # \dontrun{
tbl <- at_create_table(
  name = "Tasks",
  fields = list(
    list(name = "Title",  type = "singleLineText"),
    list(name = "Done",   type = "checkbox",
         options = list(icon = "check", color = "greenBright")),
    list(name = "Due",    type = "date",
         options = list(dateFormat = list(name = "iso")))
  ),
  base_id = "appXXXXXXXXXXXXXX"
)
tbl$id
} # }
```
