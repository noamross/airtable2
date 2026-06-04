# Low-level table and field CRUD wrappers

#' Create a table in a base
#'
#' @param name Table name.
#' @param fields A list of field configurations. The first field becomes the
#'   primary field.
#' @param base_id Base ID. If `NULL`, uses the session default set by
#'   [air_set_base()] or the `AIRTABLE_BASE_ID` environment variable.
#' @param description Optional table description.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The created table object (list with `id`, `name`, `fields`).
#' @examples
#' \dontrun{
#' tbl <- at_create_table(
#'   name = "Tasks",
#'   fields = list(
#'     list(name = "Title",  type = "singleLineText"),
#'     list(name = "Done",   type = "checkbox",
#'          options = list(icon = "check", color = "greenBright")),
#'     list(name = "Due",    type = "date",
#'          options = list(dateFormat = list(name = "iso")))
#'   ),
#'   base_id = "appXXXXXXXXXXXXXX"
#' )
#' tbl$id
#' }
#' @export
at_create_table <- function(
  name,
  fields,
  base_id = NULL,
  description = NULL,
  token = NULL
) {
  check_string(name)
  base_id <- resolve_base_id(base_id)
  check_string(base_id)

  body <- compact(list(
    name = name,
    description = description,
    fields = fields
  ))

  req <- air_req(paste0("meta/bases/", base_id, "/tables"), token = token) |>
    httr2::req_method("POST") |>
    httr2::req_body_json(body)

  air_perform(req)
}

#' Update table metadata
#'
#' @param base_id Base ID.
#' @param table_id Table ID.
#' @param name New table name (or `NULL` to leave unchanged).
#' @param description New description (or `NULL` to leave unchanged).
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The updated table object.
#' @examples
#' \dontrun{
#' at_update_table(
#'   base_id  = "appXXXXXXXXXXXXXX",
#'   table_id = "tblXXXXXXXXXXXXXX",
#'   name     = "Renamed Table"
#' )
#' }
#' @export
at_update_table <- function(
  base_id,
  table_id,
  name = NULL,
  description = NULL,
  token = NULL
) {
  check_string(base_id)
  check_string(table_id)

  body <- compact(list(name = name, description = description))
  if (length(body) == 0L) {
    cli_abort(
      "At least one of {.arg name} or {.arg description} must be provided."
    )
  }

  req <- air_req(
    paste0("meta/bases/", base_id, "/tables/", table_id),
    token = token
  ) |>
    httr2::req_method("PATCH") |>
    httr2::req_body_json(body)

  air_perform(req)
}

#' Create a field in a table
#'
#' @param name Field name.
#' @param table_id Table ID.
#' @param type Field type (e.g., `"singleLineText"`, `"number"`).
#' @param base_id Base ID. If `NULL`, uses the session default set by
#'   [air_set_base()] or the `AIRTABLE_BASE_ID` environment variable.
#' @param description Optional field description.
#' @param options Field-specific options (list). Depends on field type.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The created field object.
#' @examples
#' \dontrun{
#' # Add a number field
#' at_create_field(
#'   name     = "Score",
#'   table_id = "tblXXXXXXXXXXXXXX",
#'   type     = "number",
#'   base_id  = "appXXXXXXXXXXXXXX",
#'   options  = list(precision = 1L)
#' )
#'
#' # Add a single-select field
#' at_create_field(
#'   name     = "Status",
#'   table_id = "tblXXXXXXXXXXXXXX",
#'   type     = "singleSelect",
#'   base_id  = "appXXXXXXXXXXXXXX",
#'   options  = list(choices = list(list(name = "Open"), list(name = "Closed")))
#' )
#' }
#' @export
at_create_field <- function(
  name,
  table_id,
  type,
  base_id = NULL,
  description = NULL,
  options = NULL,
  token = NULL
) {
  check_string(name)
  base_id <- resolve_base_id(base_id)
  check_string(base_id)
  check_string(table_id)
  check_string(type)

  body <- compact(list(
    name = name,
    type = type,
    description = description,
    options = options
  ))

  req <- air_req(
    paste0("meta/bases/", base_id, "/tables/", table_id, "/fields"),
    token = token
  ) |>
    httr2::req_method("POST") |>
    httr2::req_body_json(body)

  air_perform(req)
}

#' Update field metadata
#'
#' @param base_id Base ID.
#' @param table_id Table ID.
#' @param field_id Field ID.
#' @param name New field name (or `NULL` to leave unchanged).
#' @param description New description (or `NULL` to leave unchanged).
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The updated field object.
#' @examples
#' \dontrun{
#' at_update_field(
#'   base_id     = "appXXXXXXXXXXXXXX",
#'   table_id    = "tblXXXXXXXXXXXXXX",
#'   field_id    = "fldXXXXXXXXXXXXXX",
#'   name        = "Full Name",
#'   description = "First and last name"
#' )
#' }
#' @export
at_update_field <- function(
  base_id,
  table_id,
  field_id,
  name = NULL,
  description = NULL,
  token = NULL
) {
  check_string(base_id)
  check_string(table_id)
  check_string(field_id)

  body <- compact(list(name = name, description = description))
  if (length(body) == 0L) {
    cli_abort(
      "At least one of {.arg name} or {.arg description} must be provided."
    )
  }

  req <- air_req(
    paste0("meta/bases/", base_id, "/tables/", table_id, "/fields/", field_id),
    token = token
  ) |>
    httr2::req_method("PATCH") |>
    httr2::req_body_json(body)

  air_perform(req)
}
