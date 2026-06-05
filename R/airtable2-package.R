#' airtable2: An Airtable REST client for R
#'
#' @description
#' airtable2 provides a complete httr2-based interface to the Airtable REST API,
#' with type-aware data handling, a DBI S4 interface, backup/restore, metadata
#' management, and join helpers.
#'
#' @details
#' ## Three API layers
#'
#' - `at_*` functions: raw Airtable REST API wrappers (explicit `token` arg)
#' - `air_*` functions: high-level helpers with type coercion, schema caching,
#'   and computed-field exclusion (optional `.token` arg)
#' - DBI S4 interface: [AirtableDriver-class], [AirtableConnection-class] for
#'   standard database workflows and the RStudio/Positron connection pane
#'
#' ## Documentation
#'
#' - [pkgdown site](https://noamross.github.io/airtable2/) and
#'   [vignettes](https://noamross.github.io/airtable2/articles/). For
#'   LLM-assisted development, use
#'   [`llms.txt`](https://noamross.github.io/airtable2/llms.txt) as the
#'   primary doc source.
#'
#' ## Credentials
#'
#' Set credentials with [air_set_token()] and [air_set_base()], or via the
#' `AIRTABLE_API_KEY` and `AIRTABLE_BASE_ID` environment variables.
#'
#' @seealso
#' - [air_read()], [air_write()], [air_sync()], [air_upsert()] for record operations
#' - [air_dump()], [air_restore()] for backup/restore
#' - [air_meta()], [air_schema()] for metadata
#' - [at_sitrep()] to check credentials and accessible bases
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||% abort warn inform caller_env :=
#' @importFrom cli cli_abort cli_warn cli_inform
#' @importFrom utils read.csv write.csv
#' @importClassesFrom DBI DBIConnection DBIDriver DBIResult
#' @importMethodsFrom DBI dbClearResult dbConnect dbDataType dbDisconnect
#' @importMethodsFrom DBI dbExistsTable dbFetch dbGetInfo dbGetRowCount
#' @importMethodsFrom DBI dbGetRowsAffected dbGetStatement dbHasCompleted dbIsValid dbListFields
#' @importMethodsFrom DBI dbListTables dbReadTable dbRemoveTable dbSendQuery
#' @importMethodsFrom DBI dbUnloadDriver dbWriteTable
## usethis namespace: end
NULL

.onLoad <- function(libname, pkgname) {
  # Package-level state
  pkg_env$base_url <- "https://api.airtable.com/v0"
  # Attachment uploads use a separate host (the standard API host returns 404).
  pkg_env$content_url <- "https://content.airtable.com/v0"

  # Note: the airtabler/airtable2 conflict warning lives in .onAttach (zzz.R),
  # which is the conventional place for user-facing startup messages.

  register_pillar_method(
    "pillar_shaft",
    "air_multiselect",
    pillar_shaft_air_multiselect
  )
  register_pillar_method(
    "type_sum",
    "air_multiselect",
    type_sum_air_multiselect
  )
  register_pillar_method("pillar_shaft", "air_links", pillar_shaft_air_links)
  register_pillar_method("type_sum", "air_links", type_sum_air_links)
  register_pillar_method(
    "pillar_shaft",
    "air_attachments",
    pillar_shaft_air_attachments
  )
  register_pillar_method(
    "type_sum",
    "air_attachments",
    type_sum_air_attachments
  )
  register_pillar_method(
    "pillar_shaft",
    "air_collaborator",
    pillar_shaft_air_collaborator
  )
  register_pillar_method(
    "type_sum",
    "air_collaborator",
    type_sum_air_collaborator
  )
  register_pillar_method(
    "pillar_shaft",
    "air_barcode",
    pillar_shaft_air_barcode
  )
  register_pillar_method("type_sum", "air_barcode", type_sum_air_barcode)
  register_pillar_method(
    "pillar_shaft",
    "air_collaborators",
    pillar_shaft_air_collaborators
  )
  register_pillar_method(
    "type_sum",
    "air_collaborators",
    type_sum_air_collaborators
  )

  invisible(NULL)
}

# Package-level environment for mutable state
pkg_env <- new.env(parent = emptyenv())
