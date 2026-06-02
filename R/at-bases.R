# Low-level base/workspace wrappers

#' List all accessible bases
#'
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A tibble with columns `id`, `name`, and `permissionLevel`.
#' @export
at_list_bases <- function(token = NULL) {
  req <- air_req("meta/bases", token = token)
  records <- air_paginate(
    req,
    page_size = 1000L,
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
#' @export
at_get_schema <- function(base_id, token = NULL) {
  check_string(base_id)
  req <- air_req(paste0("meta/bases/", base_id, "/tables"), token = token)
  body <- air_perform(req)
  body$tables
}

#' Get collaborators for a base
#'
#' @inheritParams at_get_schema
#' @return The parsed collaborator response (list).
#' @export
at_get_collaborators <- function(base_id, token = NULL) {
  check_string(base_id)
  req <- air_req(paste0("meta/bases/", base_id, "/collaborators"), token = token)
  air_perform(req)
}

#' Create a new base
#'
#' @param name Name for the new base.
#' @param workspace_id Workspace ID to create the base in.
#' @param tables A list of table configurations. Each should include at minimum
#'   `name` and `fields` (a list of field configs).
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The created base object (list with `id`, `name`, `tables`).
#' @export
at_create_base <- function(name, workspace_id, tables, token = NULL) {

  check_string(name)
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
