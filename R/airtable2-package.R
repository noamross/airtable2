#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||% abort warn inform caller_env :=
#' @importFrom cli cli_abort cli_warn cli_inform
#' @importFrom utils read.csv write.csv
#' @importClassesFrom DBI DBIConnection DBIDriver DBIResult
#' @importMethodsFrom DBI dbClearResult dbConnect dbDataType dbDisconnect
#' @importMethodsFrom DBI dbExistsTable dbFetch dbGetInfo dbGetRowCount
#' @importMethodsFrom DBI dbGetStatement dbHasCompleted dbIsValid dbListFields
#' @importMethodsFrom DBI dbListTables dbReadTable dbRemoveTable dbSendQuery
#' @importMethodsFrom DBI dbUnloadDriver dbWriteTable
## usethis namespace: end
NULL

.onLoad <- function(libname, pkgname) {
  # Package-level state
  pkg_env$base_url <- "https://api.airtable.com/v0"

  # Warn if both airtabler and airtable2 are loaded
  if (isNamespaceLoaded("airtabler")) {
    cli::cli_warn(c(
      "!" = "Both {.pkg airtabler} and {.pkg airtable2} are loaded.",
      "i" = "Many function names overlap between these packages.",
      "i" = "Unload {.pkg airtabler} with {.code detach(\"package:airtabler\")} to avoid conflicts."
    ))
  }

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
