# --------------------------------------------------------------------------- #
#  Schema cache (package-level, session-scoped)
# --------------------------------------------------------------------------- #

# Stores full table lists (from at_get_schema) keyed by base_id.
# Invalidated per-base on writes, or globally via schema_cache_clear().
.schema_cache <- new.env(parent = emptyenv())

#' Fetch and cache the schema for a base
#'
#' Returns the raw list of table definitions from [at_get_schema()], using a
#' package-level cache to avoid redundant API calls within a session. The cache
#' is invalidated per-base by `schema_cache_invalidate()`.
#'
#' @param base_id Base ID.
#' @param token Token (passed to [at_get_schema()]).
#' @param refresh If `TRUE`, bypass the cache and force a fresh API call.
#' @return List of table definitions (raw API format).
#' @noRd
get_base_schema <- function(base_id, token = NULL, refresh = FALSE) {
  if (!refresh && exists(base_id, envir = .schema_cache, inherits = FALSE)) {
    cached <- get(base_id, envir = .schema_cache, inherits = FALSE)
    if (identical(cached$provider, at_get_schema)) {
      return(cached$tables)
    }
  }
  tables <- at_get_schema(base_id, token = token)
  assign(
    base_id,
    list(provider = at_get_schema, tables = tables),
    envir = .schema_cache
  )
  tables
}

#' Fetch and cache the schema for a single table within a base
#'
#' Returns the list of field definitions for the named (or ID-matched) table.
#'
#' @param base_id Base ID.
#' @param table Table name or ID.
#' @param token Token.
#' @param refresh If `TRUE`, force a schema refresh.
#' @return List of field definitions, or `NULL` if the table is not found.
#' @noRd
get_table_schema <- function(base_id, table, token = NULL, refresh = FALSE) {
  tables <- get_base_schema(base_id, token = token, refresh = refresh)
  Find(function(t) t$name == table || t$id == table, tables)
}

#' Invalidate the schema cache for a base
#'
#' Called internally after write operations so subsequent reads re-fetch schema.
#'
#' @param base_id Base ID. If `NULL`, clears the entire cache.
#' @noRd
schema_cache_invalidate <- function(base_id = NULL) {
  if (is.null(base_id)) {
    rm(list = ls(.schema_cache), envir = .schema_cache)
  } else if (exists(base_id, envir = .schema_cache, inherits = FALSE)) {
    rm(list = base_id, envir = .schema_cache)
  }
  invisible(NULL)
}

# --------------------------------------------------------------------------- #
#  air_schema
# --------------------------------------------------------------------------- #

#' Get schema for a base as a tidy tibble
#'
#' Returns table and field metadata in a structured tibble format.
#'
#' @inheritParams air_read
#' @return A tibble with columns `table_id`, `table_name`, and `fields`
#'   (a list-column of tibbles with `id`, `name`, `type`, `description`).
#' @examples
#' \dontrun{
#' schema <- air_schema("appXXXXXX")
#' schema$table_name
#' schema$fields[[1]]
#' }
#' @export
air_schema <- function(base_id, .token = NULL) {
  check_string(base_id)

  tables <- at_get_schema(base_id, token = .token)

  tibble::tibble(
    table_id = vapply(tables, \(t) t$id, character(1)),
    table_name = vapply(tables, \(t) t$name, character(1)),
    table_description = vapply(
      tables,
      \(t) t$description %||% NA_character_,
      character(1)
    ),
    fields = lapply(tables, function(t) {
      if (length(t$fields) == 0L) {
        return(tibble::tibble(
          id = character(),
          name = character(),
          type = character(),
          description = character()
        ))
      }
      tibble::tibble(
        id = vapply(t$fields, \(f) f$id, character(1)),
        name = vapply(t$fields, \(f) f$name, character(1)),
        type = vapply(t$fields, \(f) f$type %||% NA_character_, character(1)),
        description = vapply(
          t$fields,
          \(f) f$description %||% NA_character_,
          character(1)
        )
      )
    })
  )
}
