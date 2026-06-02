#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||% abort warn inform caller_env :=
#' @importFrom cli cli_abort cli_warn cli_inform
## usethis namespace: end
NULL

.onLoad <- function(libname, pkgname) {
  # Package-level state
  pkg_env$base_url <- "https://api.airtable.com/v0"
}

# Package-level environment for mutable state
pkg_env <- new.env(parent = emptyenv())
