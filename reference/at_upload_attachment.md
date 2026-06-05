# Upload an attachment to a record field

Upload an attachment to a record field

## Usage

``` r
at_upload_attachment(
  base_id,
  table_id,
  record_id,
  field_id,
  file,
  token = NULL
)
```

## Arguments

- base_id:

  Base ID.

- table_id:

  Table ID or name containing the record.

- record_id:

  Record ID.

- field_id:

  Field ID or name.

- file:

  Path to the file to upload (max 5 MB).

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

## Value

The attachment object returned by the API.

## Examples

``` r
if (FALSE) { # \dontrun{
at_upload_attachment(
  base_id   = "appXXXXXXXXXXXXXX",
  table_id  = "Projects",
  record_id = "recXXXXXXXXXXXXXX",
  field_id  = "Files",
  file      = "report.pdf"
)
} # }
```
