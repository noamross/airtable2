#' Read records from an Airtable table
#'
#' High-level function that auto-paginates, fetches schema for type coercion,
#' and returns a properly typed tibble.
#'
#' @param table Table name or ID.
#' @param base_id Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session
#'   default set by [air_set_base()] or the `AIRTABLE_BASE_ID` environment
#'   variable.
#' @param view Optional view name or ID to filter by.
#' @param fields Optional character vector of field names to return.
#' @param formula Optional Airtable formula string for filtering.
#' @param sort Optional named character vector for sorting (names = field names,
#'   values = `"asc"` or `"desc"`).
#' @param max_records Maximum number of records to return. Default `Inf` (all).
#' @param page_size Records per page (max 100).
#' @param coerce If `TRUE` (default), fetches schema and coerces types. If
#'   `FALSE`, returns raw values (faster but untyped).
#' @param na Character vector of string values to treat as missing (`NA`),
#'   applied to every field before type coercion (e.g. `na = "NA"` turns the
#'   literal text `"NA"` into a real `NA` instead of a string). Default `NULL`
#'   performs no conversion, preserving raw Airtable values.
#' @param attachments How to handle attachment fields: `"meta"` (default) keeps
#'   only metadata (filename, url, size, type); `"file"` downloads to
#'   `attachment_dir`; `"blob"` downloads as in-memory raw vectors.
#' @param attachment_dir Directory for downloading attachments (required when
#'   `attachments = "file"`). Files are saved as
#'   `{attachment_dir}/{record_id}/{filename}`.
#' @param parallel Logical or `NULL`. If `TRUE`, attachment downloads use
#'   [httr2::req_perform_parallel()] (up to 5 concurrent). If `NULL`, uses
#'   option `airtable2.parallel` or env var `AIRTABLE2_PARALLEL` (default `TRUE`).
#' @param progress Logical or `NULL`. If `TRUE`, shows a cli progress bar for
#'   paginated requests. If `NULL` (default), uses option `airtable2.progress.bar`
#'   or env var `AIRTABLE2_PROGRESS_BAR`.
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A tibble with columns `airtable_id`, `airtable_created_time`, and
#'   one column per field.
#' @examples
#' \dontrun{
#' # Read all records from a table
#' df <- air_read("Contacts", "appXXXXXX")
#'
#' # Read specific fields with a filter
#' df <- air_read("Contacts", "appXXXXXX",
#'   fields = c("Name", "Email"),
#'   formula = "{Age} > 30"
#' )
#'
#' # Download attachments to disk
#' df <- air_read("Projects", "appXXXXXX",
#'   attachments = "file",
#'   attachment_dir = "downloads/"
#' )
#'
#' # Treat the literal text "NA" as a real missing value
#' df <- air_read("Contacts", "appXXXXXX", na = "NA")
#' }
#' @export
air_read <- function(
  table,
  base_id = NULL,
  view = NULL,
  fields = NULL,
  formula = NULL,
  sort = NULL,
  max_records = Inf,
  page_size = 100L,
  coerce = TRUE,
  na = NULL,
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  parallel = NULL,
  progress = NULL,
  .token = NULL
) {
  base_id <- resolve_base_id(base_id)
  check_string(base_id)
  check_string(table)
  check_bool(coerce)
  check_character(na, allow_null = TRUE)
  attachments <- match.arg(attachments)

  # Fetch schema for type coercion if requested (uses session cache)
  schema <- NULL
  if (coerce) {
    tbl_schema <- get_table_schema(base_id, table, token = .token)
    if (!is.null(tbl_schema)) {
      schema <- tbl_schema$fields
    }
  }

  # Fetch records
  records <- at_list_records(
    base_id = base_id,
    table_id = table,
    fields = fields,
    formula = formula,
    sort = sort,
    view = view,
    max_records = max_records,
    page_size = page_size,
    token = .token,
    progress = progress
  )

  tbl <- records_to_tibble(records, schema = schema, na = na)

  # Download attachments if requested
  if (attachments != "meta" && nrow(tbl) > 0L) {
    att_fields <- get_attachment_fields(base_id, table, .token)
    att_fields <- intersect(att_fields, names(tbl))
    if (length(att_fields) > 0L) {
      tbl <- download_attachments_in_tibble(
        tbl,
        att_fields,
        mode = attachments,
        dir = attachment_dir,
        parallel = parallel
      )
    }
  }

  tbl
}
