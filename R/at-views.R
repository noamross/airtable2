# Low-level view wrappers

#' List views in a table
#'
#' @param base_id Base ID.
#' @param table_id Table ID.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A tibble with columns `id`, `name`, and `type`.
#' @examples
#' \dontrun{
#' views <- at_list_views("appXXXXXXXXXXXXXX", "tblXXXXXXXXXXXXXX")
#' views$name
#' }
#' @export
at_list_views <- function(base_id, table_id, token = NULL) {
  check_string(base_id)
  check_string(table_id)

  req <- air_req(
    paste0("meta/bases/", base_id, "/tables/", table_id, "/views"),
    token = token
  )
  body <- air_perform(req)

  views <- body$views
  tibble::tibble(
    id = vapply(views, `[[`, character(1), "id"),
    name = vapply(views, `[[`, character(1), "name"),
    type = vapply(views, `[[`, character(1), "type")
  )
}

#' Get a specific view's metadata
#'
#' @param base_id Base ID.
#' @param table_id Table ID.
#' @param view_id View ID.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A list with view metadata (name, type, formula, filterByFormula, etc.).
#' @examples
#' \dontrun{
#' view <- at_get_view(
#'   "appXXXXXXXXXXXXXX",
#'   "tblXXXXXXXXXXXXXX",
#'   "viwXXXXXXXXXXXXXX"
#' )
#' view$name
#' view$type
#' }
#' @export
at_get_view <- function(base_id, table_id, view_id, token = NULL) {
  check_string(base_id)
  check_string(table_id)
  check_string(view_id)

  req <- air_req(
    paste0("meta/bases/", base_id, "/tables/", table_id, "/views/", view_id),
    token = token
  )
  air_perform(req)
}
