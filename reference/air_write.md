# Write (create) records in an Airtable table

Converts a data frame into records and creates them in the specified
table. Automatically batches in groups of 10. Computed fields (formulas,
rollups, autoNumber, createdTime, lastModifiedTime, etc.) and attachment
fields are automatically excluded from the upload payload. When
`attachments` is `"file"` or `"blob"`, attachment content is uploaded
separately after record creation using the dedicated upload endpoint.

## Usage

``` r
air_write(
  data,
  table,
  base_id = NULL,
  typecast = TRUE,
  add_fields = c("error", "warn", "yes"),
  complex_fields = c("error", "warn", "json"),
  create_table = FALSE,
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  progress = NULL,
  .token = NULL
)
```

## Arguments

- data:

  A data frame of records to create. Should not contain `airtable_id`
  (those would be ignored). Computed field columns and attachment field
  columns are silently dropped from the record payload.

- table:

  Table name or ID.

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- typecast:

  If `TRUE` (default), Airtable will attempt to coerce values to match
  field types.

- add_fields:

  What to do when `data` contains columns not in the table:

  - `"error"` (default): error if unknown columns exist.

  - `"warn"`: warn and drop unknown columns.

  - `"yes"`: create missing fields before writing. Field types are
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

- create_table:

  If `TRUE`, creates the table in the base if it does not already exist.
  Field types are inferred from the data using the same rules as
  `add_fields = "yes"`. Defaults to `FALSE`.

- attachments:

  How to handle attachment fields: `"meta"` (default) keeps only
  metadata (filename, url, size, type); `"file"` downloads to
  `attachment_dir`; `"blob"` downloads as in-memory raw vectors.

- attachment_dir:

  Directory for downloading attachments (required when
  `attachments = "file"`). Files are saved as
  `{attachment_dir}/{record_id}/{filename}`.

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for paginated
  requests. If `NULL` (default), uses option `airtable2.progress.bar` or
  env var `AIRTABLE2_PROGRESS_BAR`.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A character vector of the created record IDs (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
data <- data.frame(Name = c("Alice", "Bob"), Age = c(30, 25))
ids <- air_write(data, "Contacts", "appXXXXXX")

# Write records and upload attachments from list-column
ids <- air_write(data, "Projects", "appXXXXXX",
  attachments = "file",
  attachment_dir = "files/"
)

# Write records and add new columns if they don't exist
ids <- air_write(data, "Contacts", "appXXXXXX", add_fields = "yes")
} # }
```
