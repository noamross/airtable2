# Low-level base/workspace wrappers

#' List all accessible bases
#'
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A tibble with columns `id`, `name`, and `permissionLevel`.
#' @examples
#' \dontrun{
#' # List all bases accessible with the current token
#' at_list_bases()
#' }
#' @export
at_list_bases <- function(token = NULL) {
  req <- air_req("meta/bases", token = token)
  records <- air_paginate(
    req,
    page_size = NULL,
    record_accessor = function(body) body$bases
  )

  tibble::tibble(
    id = vapply(records, `[[`, character(1), "id"),
    name = vapply(records, `[[`, character(1), "name"),
    permissionLevel = vapply(records, `[[`, character(1), "permissionLevel")
  )
}

#' Get the schema (tables + fields) for a base
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A list of table objects, each containing `id`, `name`,
#'   `description`, `fields`, and `views`.
#' @examples
#' \dontrun{
#' tables <- at_get_schema("appXXXXXXXXXXXXXX")
#' vapply(tables, function(t) t$name, character(1))
#' }
#' @export
at_get_schema <- function(base_id, token = NULL) {
  check_string(base_id)
  req <- air_req(paste0("meta/bases/", base_id, "/tables"), token = token)
  body <- air_perform(req)
  body$tables
}

#' Get information about a single base
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A list with `id`, `name`, and `permissionLevel`, or `NULL` if not
#'   found.
#' @examples
#' \dontrun{
#' info <- at_get_base("appXXXXXXXXXXXXXX")
#' info$name
#' info$permissionLevel
#' }
#' @export
at_get_base <- function(base_id, token = NULL) {
  check_string(base_id)
  bases <- at_list_bases(token = token)
  match_row <- bases[bases$id == base_id, , drop = FALSE]
  if (nrow(match_row) == 0L) return(NULL)
  list(
    id = match_row$id[[1L]],
    name = match_row$name[[1L]],
    permissionLevel = match_row$permissionLevel[[1L]]
  )
}

#' Get collaborators for a base
#'
#' @inheritParams at_get_schema
#' @return The parsed collaborator response (list).
#' @examples
#' \dontrun{
#' collabs <- at_get_collaborators("appXXXXXXXXXXXXXX")
#' }
#' @export
at_get_collaborators <- function(base_id, token = NULL) {
  check_string(base_id)
  req <- air_req(
    paste0("meta/bases/", base_id, "/collaborators"),
    token = token
  )
  air_perform(req)
}

#' Create a new base
#'
#' @param name Name for the new base.
#' @param tables A list of table configurations. Each should include at minimum
#'   `name` and `fields` (a list of field configs).
#' @param workspace_id Workspace ID to create the base in.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The created base object (list with `id`, `name`, `tables`).
#' @examples
#' \dontrun{
#' new_base <- at_create_base(
#'   name = "My New Base",
#'   workspace_id = "wspXXXXXXXXXXXXXX",
#'   tables = list(list(
#'     name = "Items",
#'     fields = list(list(name = "Name", type = "singleLineText"))
#'   ))
#' )
#' new_base$id
#' }
#' @export
at_create_base <- function(
  name,
  tables = list(list(
    name = "Table 1",
    fields = list(list(name = "id", type = "singleLineText"))
  )),
  workspace_id = NULL,
  token = NULL
) {
  check_string(name)
  workspace_id <- workspace_id %||% default_workspace_id()
  check_string(workspace_id)

  body <- list(
    name = name,
    workspaceId = workspace_id,
    tables = tables
  )

  req <- air_req("meta/bases", token = token) |>
    httr2::req_method("POST") |>
    httr2::req_body_json(body)

  air_perform(req)
}
