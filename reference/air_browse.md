# Open an Airtable workspace, base, table, or view in the browser

Navigates to the Airtable web interface for the given resource.
Automatically resolves IDs from connection objects, determines the
resource type from the ID prefix, or resolves human-readable names to
IDs.

## Usage

``` r
air_browse(id = NULL, base_id = NULL, table_id = NULL, ...)
```

## Arguments

- id:

  Character, connection, or `NULL`. One of:

  - `NULL` (default): opens the session default base.

  - A workspace ID (starts with `wsp`)

  - A base ID (starts with `app`)

  - A table ID (starts with `tbl`)

  - A view ID (starts with `viw`)

  - A record ID (starts with `rec`)

  - A full Airtable URL

  - An Airtable connection object (uses its `base_id`)

  - A human-readable base or table name (see Name resolution above)

- base_id:

  Character or `NULL`. The base ID to use when browsing a table, view,
  or record, or when resolving a table name. Falls back to the session
  default set via
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md).

- table_id:

  Character or `NULL`. The table ID to use when browsing a view or
  record ID.

- ...:

  Additional arguments passed to
  [`utils::browseURL()`](https://rdrr.io/r/utils/browseURL.html).

## Value

The URL that was opened (invisibly).

## Details

If `id` is `NULL` (the default), `air_browse()` opens the session
default base set via
[`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
or the `airtable2.base_id` option.

Name resolution precedence:

- If `id` is a human name **and** a `base_id` is available (explicit arg
  or session default), `id` is treated as a **table name** and resolved
  via
  [`at_get_schema()`](https://noamross.github.io/airtable2/reference/at_get_schema.md).
  Case-sensitive first; falls back to case-insensitive with a warning if
  needed.

- If `id` is a human name and **no** base context is available, `id` is
  treated as a **base name** and resolved via
  [`at_list_bases()`](https://noamross.github.io/airtable2/reference/at_list_bases.md).

- If no match is found, `cli_abort()` is called with a helpful message
  listing how to view valid names.

## Examples

``` r
if (FALSE) { # \dontrun{
# Open the session default base (requires air_set_base() or option)
air_browse()

# Open a base by ID
air_browse("appXXXXXX")

# Open a workspace
air_browse("wspXXXXXX")

# Open a table within a base (base_id is a proper formal, not ...)
air_browse("tblXXXXXX", base_id = "appXXXXXX")

# Open a view
air_browse("viwXXXXXX", base_id = "appXXXXXX", table_id = "tblXXXXXX")

# Resolve a table by name (requires base context)
air_browse("My Table", base_id = "appXXXXXX")

# Resolve a base by name (no base context)
air_browse("My Base")
} # }
```
