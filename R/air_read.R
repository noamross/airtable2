#' Read records from an Airtable table
#'
#' High-level function that auto-paginates, fetches schema for type coercion,
#' and returns a properly typed tibble.
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param table Table name or ID.
#' @param view Optional view name or ID to filter by.
#' @param fields Optional character vector of field names to return.
#' @param formula Optional Airtable formula string for filtering.
#' @param sort Optional named character vector for sorting (names = field names,
#'   values = `"asc"` or `"desc"`).
#' @param max_records Maximum number of records to return. Default `Inf` (all).
#' @param page_size Records per page (max 100).
#' @param coerce If `TRUE` (default), fetches schema and coerces types. If
#'   `FALSE`, returns raw values (faster but untyped).
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A tibble with columns `airtable_id`, `airtable_created_time`, and
#'   one column per field.
#' @examples
#' \dontrun{
#' # Read all records from a table
#' df <- air_read("appXXXXXX", "Contacts")
#'
#' # Read specific fields with a filter
#' df <- air_read("appXXXXXX", "Contacts",
#'   fields = c("Name", "Email"),
#'   formula = "{Age} > 30"
#' )
#' }
#' @export
air_read <- function(
  base_id,
  table,
  view = NULL,
  fields = NULL,
  formula = NULL,
  sort = NULL,
  max_records = Inf,
  page_size = 100L,
  coerce = TRUE,
  .token = NULL
) {
  check_string(base_id)
  check_string(table)
  check_bool(coerce)

  # Fetch schema for type coercion if requested
  schema <- NULL
  if (coerce) {
    tables <- at_get_schema(base_id, token = .token)
    tbl_schema <- Find(function(t) t$name == table || t$id == table, tables)
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
    token = .token
  )

  records_to_tibble(records, schema = schema)
}
