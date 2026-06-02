#' Get schema for a base as a tidy tibble
#'
#' Returns table and field metadata in a structured tibble format.
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A tibble with columns `table_id`, `table_name`, and `fields`
#'   (a list-column of tibbles with `id`, `name`, `type`, `description`).
#' @export
air_schema <- function(base_id, .token = NULL) {
  check_string(base_id)

  tables <- at_get_schema(base_id, token = .token)

  tibble::tibble(
    table_id = vapply(tables, function(t) t$id, character(1)),
    table_name = vapply(tables, function(t) t$name, character(1)),
    table_description = vapply(tables, function(t) t$description %||% NA_character_, character(1)),
    fields = lapply(tables, function(t) {
      if (length(t$fields) == 0L) {
        return(tibble::tibble(
          id = character(), name = character(),
          type = character(), description = character()
        ))
      }
      tibble::tibble(
        id = vapply(t$fields, function(f) f$id, character(1)),
        name = vapply(t$fields, function(f) f$name, character(1)),
        type = vapply(t$fields, function(f) f$type %||% NA_character_, character(1)),
        description = vapply(t$fields, function(f) f$description %||% NA_character_, character(1))
      )
    })
  )
}
