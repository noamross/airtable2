# Package load helpers -----------------------------------------------------

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
