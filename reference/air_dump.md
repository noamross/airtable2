# Dump an entire base (schema + data) for backup

Exports the full schema and all table data from a base. By default,
attachments are downloaded to disk (`attachments = "file"`) since the
purpose of a dump is to create a full backup.

## Usage

``` r
air_dump(
  base_id,
  dir = NULL,
  format = c("list", "json", "csv"),
  attachments = c("file", "meta", "blob"),
  .token = NULL
)
```

## Arguments

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- dir:

  Directory to write files to. When `format = "json"` or
  `format = "csv"`, schema and data files are written here. When
  `attachments = "file"`, attachment files are saved under

  `{dir}/attachments/{table_name}/{record_id}/{filename}`. If `NULL` and
  format is `"json"` or `"csv"`, uses a temp directory.

- format:

  One of `"list"` (return as R list), `"json"` (write JSON files), or
  `"csv"` (write CSV files with flattened complex types).

- attachments:

  How to handle attachment fields: `"meta"` (default) keeps only
  metadata (filename, url, size, type); `"file"` downloads to
  `attachment_dir`; `"blob"` downloads as in-memory raw vectors.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

For `format = "list"`: a named list with `schema` and a tibble per
table. For `format = "json"` or `"csv"`: the directory path (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
# Full backup with attachments
air_dump("appXXXXXX", dir = "backup/")

# Quick dump without downloading attachments
air_dump("appXXXXXX", dir = "backup/", attachments = "meta")

# CSV dump (flattened for spreadsheet compatibility)
air_dump("appXXXXXX", dir = "backup/", format = "csv")
} # }
```
