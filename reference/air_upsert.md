# Upsert records into an Airtable table

Uses Airtable's native upsert (PATCH with `performUpsert`) to create or
update records based on merge fields. Supports two matching modes:

## Usage

``` r
air_upsert(
  data,
  table,
  merge_on,
  base_id = NULL,
  typecast = TRUE,
  add_fields = c("error", "warn", "yes"),
  complex_fields = c("error", "warn", "json"),
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  progress = NULL,
  .token = NULL
)
```

## Arguments

- data:

  A data frame of records to upsert. May include an `airtable_id` column
  for direct record matching. Computed field columns and attachment
  field columns are silently dropped from the record payload.

- table:

  Table name or ID.

- merge_on:

  Character vector of 1-3 field names to match on (for records without
  an `airtable_id`).

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- typecast:

  If `TRUE` (default), Airtable will attempt to coerce values.

- add_fields:

  What to do when `data` contains columns not in the table:

  - `"error"` (default): error if unknown columns exist.

  - `"warn"`: warn and drop unknown columns.

  - `"yes"`: create missing fields before upserting. Field types are
    inferred from the column class: `numeric` → `number`, `logical` →
    `checkbox`, `Date` → `date`, complex/JSON columns → `multilineText`,
    all others → `singleLineText`.

- complex_fields:

  What to do when `data` contains list-columns with complex (nested list
  or data-frame) values that Airtable cannot store directly:

  - `"error"` (default): abort with an informative message.

  - `"warn"`: warn and drop those columns.

  - `"json"`: serialize each complex value to a JSON text string and
    write it to a `singleLineText` field (creating the field first when
    `add_fields = "yes"`).

- attachments:

  How to handle attachment fields: `"meta"` (default) keeps only
  metadata (filename, url, size, type); `"file"` downloads to
  `attachment_dir`; `"blob"` downloads as in-memory raw vectors.

- attachment_dir:

  Directory for downloading attachments (required when
  `attachments = "file"`). Files are saved as
  `{attachment_dir}/{record_id}/{filename}`.

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for batch
  operations. If `NULL` (default), uses option `airtable2.progress.bar`
  or env var `AIRTABLE2_PROGRESS_BAR`.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A list with `created` and `updated` character vectors of record IDs
(invisibly).

## Details

- If `data` contains an `airtable_id` column, records with non-NA IDs
  are updated directly by record ID (more efficient).

- Records without an `airtable_id` (or where it is `NA`) are matched
  using the `merge_on` field(s) via Airtable's upsert mechanism.

Computed fields (formulas, rollups, autoNumber, createdTime,
lastModifiedTime, etc.) and attachment fields are automatically excluded
from the upload payload. When `attachments` is `"file"` or `"blob"`,
attachment content is uploaded separately after record creation/update.
Optionally creates missing columns.

## Examples

``` r
if (FALSE) { # \dontrun{
data <- data.frame(Name = c("Alice", "Bob"), Age = c(31, 26))
result <- air_upsert(data, "Contacts", merge_on = "Name", base_id = "appXXXXXX")
result$created
result$updated
} # }
```
