# Package load helpers -----------------------------------------------------

#' Build the airtabler conflict warning message, or NULL if no conflict.
#'
#' A pure, side-effect-free helper so the conflict-detection logic can be unit
#' tested without actually attaching any package.
#'
#' @param loaded Logical scalar: is the `airtabler` namespace currently loaded?
#'   Defaults to the real runtime check via [isNamespaceLoaded()].
#' @return A character vector suitable for passing to [packageStartupMessage()],
#'   or `NULL` when no conflict is detected.
#' @noRd
airtabler_conflict_msg <- function(
  loaded = isNamespaceLoaded("airtabler")
) {
  if (!loaded) {
    return(NULL)
  }
  c(
    "!" = "Both 'airtabler' and 'airtable2' are loaded in the same session.",
    "i" = "These packages have overlapping function names that will mask each other.",
    "i" = "Detach 'airtabler' with: detach(\"package:airtabler\", unload = TRUE)"
  )
}

.onAttach <- function(libname, pkgname) {
  msg <- airtabler_conflict_msg()
  if (!is.null(msg)) {
    packageStartupMessage(paste(names(msg), msg, sep = " ", collapse = "\n"))
  }
}

#' @noRd
register_pillar_method <- function(generic, class, method) {
  if (!requireNamespace("vctrs", quietly = TRUE)) {
    return(invisible(NULL))
  }

  vctrs::s3_register(
    glue::glue("pillar::{generic}"),
    class,
    method = method
  )
  invisible(NULL)
}
