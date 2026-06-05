# Push metadata changes back to the base

Compares a modified metadata tibble (from
[`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md))
against the current schema and applies name/description changes via
PATCH. Changes to `table_name` rename the table; changes to `field_name`
or `description` rename or re-describe the field.

## Usage

``` r
air_meta_push(base_id, meta, .token = NULL)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- meta:

  A tibble from
  [`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md)
  with modifications to `table_name`, `field_name`, or `description`.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

Invisible `NULL`. Side effect: updates table and field metadata.
