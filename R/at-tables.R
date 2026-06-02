# Low-level table and field CRUD wrappers

#' Create a table in a base
#'
#' @param base_id Base ID.
#' @param name Table name.
#' @param fields A list of field configurations. The first field becomes the
#'   primary field.
#' @param description Optional table description.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The created table object (list with `id`, `name`, `fields`).
#' @export
at_create_table <- function(
  base_id,
  name,
  fields,
  description = NULL,
  token = NULL
) {
  check_string(base_id)
  check_string(name)

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
#' @param base_id Base ID.
#' @param table_id Table ID.
#' @param name Field name.
#' @param type Field type (e.g., `"singleLineText"`, `"number"`).
#' @param description Optional field description.
#' @param options Field-specific options (list). Depends on field type.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The created field object.
#' @export
at_create_field <- function(
  base_id,
  table_id,
  name,
  type,
  description = NULL,
  options = NULL,
  token = NULL
) {
  check_string(base_id)
  check_string(table_id)
  check_string(name)
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
