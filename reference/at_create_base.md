# Create a new base

Create a new base

## Usage

``` r
at_create_base(
  name,
  tables = list(list(name = "Table 1", fields = list(list(name = "id", type =
    "singleLineText")))),
  workspace_id = NULL,
  token = NULL
)
```

## Arguments

- name:

  Name for the new base.

- tables:

  A list of table configurations. Each should include at minimum `name`
  and `fields` (a list of field configs).

- workspace_id:

  Workspace ID to create the base in.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

The created base object (list with `id`, `name`, `tables`).

## Examples

``` r
if (FALSE) { # \dontrun{
new_base <- at_create_base(
  name = "My New Base",
  workspace_id = "wspXXXXXXXXXXXXXX",
  tables = list(list(
    name = "Items",
    fields = list(list(name = "Name", type = "singleLineText"))
  ))
)
new_base$id
} # }
```
