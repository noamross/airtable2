# Join local data with an Airtable table

Fetches a remote Airtable table and joins it with a local data frame.
These are convenience wrappers around
[`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)
plus base-R [`merge()`](https://rdrr.io/r/base/merge.html). The `...`
are forwarded to
[`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)
(e.g. `formula`, `fields`).

## Usage

``` r
air_left_join(x, table, base_id = NULL, by = NULL, ..., .token = NULL)

air_inner_join(x, table, base_id = NULL, by = NULL, ..., .token = NULL)

air_full_join(x, table, base_id = NULL, by = NULL, ..., .token = NULL)
```

## Arguments

- x:

  A local data frame.

- table:

  Table name or ID.

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- by:

  Character vector of column name(s) to join on. If `NULL`, uses all
  column names shared between `x` and the remote table (excluding
  `airtable_id` and `airtable_created_time`).

- ...:

  Additional arguments passed to
  [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md).

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A tibble.

## Examples

``` r
if (FALSE) { # \dontrun{
scores <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90, 85))
air_left_join(scores, "Contacts", "appXXXX", by = "Name")
} # }
```
