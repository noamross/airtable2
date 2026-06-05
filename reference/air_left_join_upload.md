# Upload local data to matched Airtable records

`air_left_join_upload()` is the complement of
[`air_left_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md).
Instead of pulling remote data *into* a local data frame, it pushes the
columns that a local data frame `x` carries *onto* matching records that
already exist in an Airtable table, matching by a join key. It enriches
existing records with new or changed field values.

## Usage

``` r
air_left_join_upload(
  x,
  table,
  base_id = NULL,
  by = NULL,
  fields = NULL,
  add_fields = c("yes", "warn", "error"),
  .token = NULL
)
```

## Arguments

- x:

  A local data frame whose columns should be uploaded.

- table:

  Table name or ID.

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- by:

  The join key: a column present in both `x` and the remote table (e.g.
  `"Name"`), or a named character vector `c(local = "remote")` when the
  local and remote key columns differ. If `NULL`, uses common column
  names (dplyr-style) and messages which key was chosen.

- fields:

  Optional character vector limiting which of `x`'s columns to upload.
  Defaults to all columns of `x` except the key and the Airtable meta
  columns (`airtable_id`, `airtable_created_time`).

- add_fields:

  What to do when an upload column does not exist in the table: `"yes"`
  (default) creates it, `"warn"` warns and drops it, `"error"` errors.
  Passed through to
  [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md).

- .token:

  Optional API token.

## Value

Invisibly, a tibble of the records that were updated: their
`airtable_id`, the key, and the changed field values.

## Details

Matching is by `by` (a key present in both `x` and the remote table).
For each matched record, only the upload columns whose value is **new**
(the field does not yet exist remotely) or **changed** (differs from the
current remote value) are sent, minimising API calls. Columns whose
value already equals the remote value are not re-sent.

This function never inserts new records (unmatched local rows are
skipped and counted) and never deletes remote fields. To insert as well
as update, use
[`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md).

The remote table is read minimally: only the key field plus any
to-upload fields that already exist are fetched. The actual write is
delegated to
[`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
(matching by `airtable_id`), so batching, throttling, API counting, and
field creation are reused.

## See also

[`air_left_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md)
for the read direction,
[`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
to also insert new records.

## Examples

``` r
if (FALSE) { # \dontrun{
# Local scores you computed; push them onto existing Contacts by Name.
scores <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90, 85))
air_left_join_upload(scores, "Contacts", "appXXXX", by = "Name")

# Different local/remote key names.
air_left_join_upload(scores, "Contacts", "appXXXX", by = c(person = "Name"))
} # }
```
