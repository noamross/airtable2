# Sync a metadata source to patch the base schema

The **preferred metadata workflow**: pull field names and descriptions
from a source (default: the `"_metadata"` table inside the same base),
compare against the live schema, and PATCH any changed fields.

## Usage

``` r
air_meta_sync(base_id, source = "_metadata", ..., .token = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- source:

  Where to pull the edited metadata from. Defaults to `"_metadata"`,
  meaning the `_metadata` table inside `base_id`. Can also be a
  `data.frame`, a path to a `.csv` file, or a path to a `.json` file
  (see *Source precedence* above).

- ...:

  Ignored; forces `.token` to be named.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

Invisible `NULL`. Side-effect: PATCHes changed fields in the base.

## Typical workflow

1.  **Seed** – run
    [`air_meta_init()`](https://noamross.github.io/airtable2/reference/air_meta_init.md)
    once to create / populate the `"_metadata"` table from the live
    schema.

2.  **Edit** – open the `"_metadata"` table in Airtable and change
    `field_name` / `description` cells to your liking.

3.  **Sync** – call `air_meta_sync()` (no arguments needed) to PATCH the
    schema with your edits.

## Source precedence

`source` is resolved in this order:

1.  A `data.frame` → used directly.

2.  A length-1 character path to an **existing `.csv`** file → read with
    [`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html).

3.  A length-1 character path to an **existing `.json`** file → read
    with
    [`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html).

4.  A length-1 character string that matches neither 2 nor 3 → treated
    as a **table name** inside the base and read with
    [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md).

The source tibble must contain at least `field_id`, `table_id`,
`field_name`, and `description` columns (the shape produced by
[`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md)
and
[`air_meta_init()`](https://noamross.github.io/airtable2/reference/air_meta_init.md)).
An extra `meta_key` column (produced by older seed runs) is silently
ignored.

## Examples

``` r
if (FALSE) { # \dontrun{
# 1. Seed the _metadata table from the live schema (run once)
air_meta_init("appXXXXXX")

# 2. Edit field_name / description cells directly in Airtable ...

# 3. Pull edits back and patch the schema
air_meta_sync("appXXXXXX")

# 4. Alternatively, sync from a local CSV
air_meta_sync("appXXXXXX", source = "my_meta.csv")
} # }
```
