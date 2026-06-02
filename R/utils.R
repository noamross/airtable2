# Internal utilities -- not exported

#' Remove NULL elements from a list
#' @noRd
compact <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}

#' Assert a scalar character
#' @noRd
check_string <- function(
  x,
  allow_null = FALSE,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (allow_null && is.null(x)) {
    return(invisible(NULL))
  }
  if (!is.character(x) || length(x) != 1 || is.na(x)) {
    cli_abort("{.arg {arg}} must be a single non-NA string.", call = call)
  }
  invisible(x)
}

#' Assert a scalar logical
#' @noRd
check_bool <- function(
  x,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (!is.logical(x) || length(x) != 1 || is.na(x)) {
    cli_abort(
      "{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
      call = call
    )
  }
  invisible(x)
}

#' Assert a positive integer scalar
#' @noRd
check_count <- function(
  x,
  allow_inf = FALSE,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (allow_inf && identical(x, Inf)) {
    return(invisible(x))
  }
  if (
    !is.numeric(x) ||
      length(x) != 1 ||
      is.na(x) ||
      !is.finite(x) ||
      x < 1 ||
      x != trunc(x)
  ) {
    cli_abort("{.arg {arg}} must be a positive integer.", call = call)
  }
  invisible(x)
}

#' Chunk a vector into groups of size n
#' @noRd
chunk <- function(x, n) {
  split(x, ceiling(seq_along(x) / n))
}

#' Airtable API base URL
#' @noRd
base_url <- function() {
  pkg_env$base_url
}
