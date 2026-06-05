# Read records from an Airtable table

High-level function that auto-paginates, fetches schema for type
coercion, and returns a properly typed tibble.

## Usage

``` r
air_read(
  table,
  base_id = NULL,
  view = NULL,
  fields = NULL,
  formula = NULL,
  sort = NULL,
  max_records = Inf,
  page_size = 100L,
  coerce = TRUE,
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  parallel = NULL,
  progress = NULL,
  .token = NULL
)
```

## Arguments

- table:

  Table name or ID.

- base_id:

  Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session default set
  by
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  or the `AIRTABLE_BASE_ID` environment variable.

- view:

  Optional view name or ID to filter by.

- fields:

  Optional character vector of field names to return.

- formula:

  Optional Airtable formula string for filtering.

- sort:

  Optional named character vector for sorting (names = field names,
  values = `"asc"` or `"desc"`).

- max_records:

  Maximum number of records to return. Default `Inf` (all).

- page_size:

  Records per page (max 100).

- coerce:

  If `TRUE` (default), fetches schema and coerces types. If `FALSE`,
  returns raw values (faster but untyped).

- attachments:

  How to handle attachment fields: `"meta"` (default) keeps only
  metadata (filename, url, size, type); `"file"` downloads to
  `attachment_dir`; `"blob"` downloads as in-memory raw vectors.

- attachment_dir:

  Directory for downloading attachments (required when
  `attachments = "file"`). Files are saved as
  `{attachment_dir}/{record_id}/{filename}`.

- parallel:

  Logical or `NULL`. If `TRUE`, attachment downloads use
  [`httr2::req_perform_parallel()`](https://httr2.r-lib.org/reference/req_perform_parallel.html)
  (up to 5 concurrent). If `NULL`, uses option `airtable2.parallel` or
  env var `AIRTABLE2_PARALLEL` (default `TRUE`).

- progress:

  Logical or `NULL`. If `TRUE`, shows a cli progress bar for paginated
  requests. If `NULL` (default), uses option `airtable2.progress.bar` or
  env var `AIRTABLE2_PROGRESS_BAR`.

- .token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

A tibble with columns `airtable_id`, `airtable_created_time`, and one
column per field.

## Examples

``` r
if (FALSE) { # \dontrun{
# Read all records from a table
df <- air_read("Contacts", "appXXXXXX")

# Read specific fields with a filter
df <- air_read("Contacts", "appXXXXXX",
  fields = c("Name", "Email"),
  formula = "{Age} > 30"
)

# Download attachments to disk
df <- air_read("Projects", "appXXXXXX",
  attachments = "file",
  attachment_dir = "downloads/"
)
} # }
```
