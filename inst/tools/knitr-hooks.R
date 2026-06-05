# tools/knitr-hooks.R
# Knitr hooks for vignettes: ID obfuscation and other utilities.
# Source this file at the top of each vignette's setup chunk:
#
#   source(here::here("tools/knitr-hooks.R"))
#   setup_vignette_hooks()

#' Install vignette knitr hooks
#'
#' Installs an output hook that replaces real Airtable IDs with obfuscated
#' forms so that precompiled vignettes shipped with the package do not expose
#' real workspace / base / table / record IDs.
#'
#' ID patterns replaced:
#'   app<5+ alphanum>  ->  app...
#'   wsp<5+ alphanum>  ->  wsp...
#'   tbl<5+ alphanum>  ->  tbl...
#'   rec<5+ alphanum>  ->  rec...
#'   viw<5+ alphanum>  ->  viw...
#'
#' The hook is gated on the chunk option `obfuscate_ids = TRUE` (which this
#' function sets as the package-wide default via `knitr::opts_chunk$set`).
setup_vignette_hooks <- function() {
  knitr::knit_hooks$set(output = function(x, options) {
    if (isTRUE(options$obfuscate_ids)) {
      x <- gsub("(app|wsp|tbl|rec|viw)[A-Za-z0-9]{5,}", "\\1...", x)
    }
    x
  })

  knitr::opts_chunk$set(obfuscate_ids = TRUE)

  invisible(NULL)
}
