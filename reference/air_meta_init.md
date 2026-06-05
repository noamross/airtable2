# Seed the \_metadata table from the live schema

Reads the current base schema via
[`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md)
and upserts it into a designated table within the same base. Run this
**once** to initialise the metadata store, then edit the table in
Airtable and call
[`air_meta_sync()`](https://noamross.github.io/airtable2/reference/air_meta_sync.md)
to push changes back.

## Usage

``` r
air_meta_init(base_id, meta_table = "_metadata", .token = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- meta_table:

  Name of the table to store metadata in. Default `"_metadata"`.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

Invisible upsert result.

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialise the _metadata table
air_meta_init("appXXXXXX")

# Use a custom table name
air_meta_init("appXXXXXX", meta_table = "_docs")
} # }
```
