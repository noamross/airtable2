# Smart sync: diff-based upsert + delete

Compares local data against the current table contents using a hash of
specified fields, then creates/updates/deletes as needed.

## Usage

``` r
air_sync(
  data,
  table,
  key,
  base_id = NULL,
  hash_fields = NULL,
  delete_missing = TRUE,
  typecast = TRUE,
  add_fields = c("error", "warn", "yes"),
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  progress = NULL,
  .token = NULL
)
```

## Arguments

- data:

  A data frame representing the desired state of the table. May contain
  computed field columns (they are ignored).

- table:

  Table name or ID.

- key:

  Column name in `data` that uniquely identifies records (used as the
  merge field for upsert). Must be a single field.

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- hash_fields:

  Character vector of fields to include in the change- detection hash.
  If `NULL` (default), all non-key, non-computed, non-attachment fields
  are used. Computed and attachment fields are always excluded even if
  explicitly listed.

- delete_missing:

  If `TRUE` (default), records in Airtable that are not in `data` will
  be deleted.

- typecast:

  If `TRUE` (default), Airtable will attempt to coerce values.

- add_fields:

  What to do when `data` contains columns not in the table. Passed to
  [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md).
  Default is `"error"`.

- attachments:

  How to handle attachment fields: `"meta"` (default) keeps only
  metadata (filename, url, size, type); `"file"` downloads to
  `attachment_dir`; `"blob"` downloads as in-memory raw vectors.

- attachment_dir:

  Directory for downloading attachments (required when
  `attachments = "file"`). Files are saved as
  `{attachment_dir}/{record_id}/{filename}`.

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for read and
  upsert operations. If `NULL` (default), uses option
  `airtable2.progress.bar` or env var `AIRTABLE2_PROGRESS_BAR`.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A list with counts: `created`, `updated`, `deleted`, `unchanged`
(invisibly).

## Details

Computed fields (formulas, rollups, autoNumber, createdTime,
lastModifiedTime, createdBy, lastModifiedBy, etc.) are automatically:

- Excluded from the change-detection hash (they change server-side and
  would cause spurious "changed" detections on every sync)

- Excluded from the upload payload (the API rejects writes to them)

Attachment fields (`multipleAttachments`) are always excluded from the
change-detection hash because their URLs are volatile (expire hourly).
When `attachments` is `"file"` or `"blob"`, attachment content is
uploaded for newly created records after the sync completes.

## Examples

``` r
if (FALSE) { # \dontrun{
desired <- data.frame(Name = c("Alice", "Bob"), Age = c(30, 26))
result <- air_sync(desired, "Contacts", key = "Name", base_id = "appXXXXXX")
result$created
result$unchanged
} # }
```
