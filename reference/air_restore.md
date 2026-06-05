# Restore a base from a dump

Recreates a base from output of
[`air_dump()`](https://noamross.github.io/airtable2/reference/air_dump.md).
When `attachments` is `"file"`, uploads attachment files from the dump
directory after record creation. For CSV dumps, automatically detects
and parses the flattened format.

## Usage

``` r
air_restore(
  dump,
  base_name = NULL,
  workspace_id = NULL,
  attachments = c("file", "meta"),
  attachment_dir = NULL,
  restore_linked_fields = TRUE,
  .token = NULL
)
```

## Arguments

- dump:

  Either a list (from `air_dump(format = "list")`) or a path to a dump
  directory (from `air_dump(format = "json")` or
  `air_dump(format = "csv")`).

- base_name:

  Name for the new base. If `NULL`, uses a generated name.

- workspace_id:

  Workspace ID to create the base in.

- attachments:

  How to handle attachment fields: `"meta"` (default) keeps only
  metadata (filename, url, size, type); `"file"` downloads to
  `attachment_dir`; `"blob"` downloads as in-memory raw vectors.

- attachment_dir:

  Directory for downloading attachments (required when
  `attachments = "file"`). Files are saved as
  `{attachment_dir}/{record_id}/{filename}`.

- restore_linked_fields:

  If `TRUE` (the default), after all records are created, linked-record
  fields (`multipleRecordLinks`) and their dependent computed fields
  (`rollup`, `lookup`, `count`) are recreated with remapped table/field
  IDs, and the link cell values (record-to-record connections) are
  repopulated by remapping old record IDs to the newly created record
  IDs. Set to `FALSE` to skip this step (faster, but links will be
  empty).

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

The new base ID (invisibly).

## Linked-record fields

Linked-record fields (`multipleRecordLinks`) and the computed fields
that depend on them (`rollup`, `lookup`, `count`) are skipped during the
initial field-creation pass because their options reference
base-specific IDs. When `restore_linked_fields = TRUE` (the default),
after all records are inserted a two-step pass runs:

1.  **Field definitions**: `multipleRecordLinks` fields are recreated
    with `linkedTableId` remapped to the new base's table IDs.

2.  **Cell values**: the link columns in the dump contain old record
    IDs. These are remapped to the new record IDs (matched by insertion
    order) and written back via
    [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# Restore from a directory dump
air_restore("backup/", workspace_id = "wspXXXXXX")

# Restore from a CSV dump
air_restore("backup/", workspace_id = "wspXXXXXX", format = "csv")
} # }
```
