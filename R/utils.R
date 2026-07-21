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

#' Assert a character vector (or NULL)
#' @noRd
check_character <- function(
  x,
  allow_null = FALSE,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (allow_null && is.null(x)) {
    return(invisible(NULL))
  }
  if (!is.character(x)) {
    cli_abort("{.arg {arg}} must be a character vector.", call = call)
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

#' Airtable attachment-upload host URL
#'
#' Attachment uploads are served from a different host
#' (`content.airtable.com`) than the rest of the REST API.
#' @noRd
content_url <- function() {
  pkg_env$content_url
}

#' Normalize an Airtable error body into `list(type, message)`
#'
#' Airtable's `error` field is sometimes an object `{"type","message"}` and
#' sometimes a bare string (e.g. `{"error":"NOT_FOUND"}`). This returns a
#' normalized list with character-or-`NA` `type` and `message`.
#'
#' @param body Parsed JSON body (a list) or `NULL`.
#' @return `list(type = <chr or NA>, message = <chr or NA>)`.
#' @noRd
parse_airtable_error <- function(body) {
  out <- list(type = NA_character_, message = NA_character_)
  if (is.null(body) || is.null(body$error)) {
    return(out)
  }
  err <- body$error
  if (is.character(err) && length(err) == 1L) {
    # Bare string form: use it as the type.
    out$type <- err
  } else if (is.list(err)) {
    if (!is.null(err$type) && length(err$type) == 1L) {
      out$type <- as.character(err$type)
    }
    if (!is.null(err$message) && length(err$message) == 1L) {
      out$message <- as.character(err$message)
    }
  }
  out
}

#' Actionable cli hint lines for known Airtable error types
#'
#' @param type The Airtable error `type` (character or `NA`).
#' @param request_url Optional request URL (currently unused for hint text,
#'   accepted for forward compatibility).
#' @return A (possibly named) character vector of cli hint lines, or
#'   `character(0)` when there is no special hint.
#' @noRd
airtable_error_hint <- function(type, request_url = NULL) {
  if (length(type) != 1L || is.na(type)) {
    return(character(0))
  }
  switch(
    type,
    INVALID_PERMISSIONS_OR_MODEL_NOT_FOUND = c(
      i = paste(
        "The table or base may not exist, the name/ID may be misspelled,",
        "or your token may lack access. Check the table name",
        "(run {.run airtable2::at_get_schema()} / {.code at_list_tables()})",
        "and your token scopes."
      )
    ),
    UNKNOWN_FIELD_NAME = c(
      i = paste(
        "One or more field names don't exist in this table. List valid",
        "fields with {.code at_get_schema(base_id)} (or read the table once",
        "and inspect its columns). Field names are case-sensitive."
      )
    ),
    INVALID_FILTER_BY_FORMULA = c(
      i = paste(
        "The {.arg formula} is invalid. Field names in formulas are",
        "case-sensitive and wrapped in {.code {{...}}}; string values use",
        "single quotes."
      )
    ),
    character(0)
  )
}

#' Best-effort parse of base / table IDs from an Airtable request URL
#'
#' Inspects the path after `/v0/`. Meta endpoints (`meta/...`) return `NULL`.
#' Otherwise returns the first path segment as `base_id` and the second
#' (URL-decoded) as `table`. Used only to enrich error messages; makes no
#' API call.
#'
#' @param url A request URL string.
#' @return `list(base_id, table)` or `NULL`.
#' @noRd
airtable_url_ids <- function(url) {
  if (length(url) != 1L || is.na(url) || !nzchar(url)) {
    return(NULL)
  }
  path <- tryCatch(httr2::url_parse(url)$path, error = function(e) NULL)
  if (is.null(path)) {
    return(NULL)
  }
  m <- regmatches(path, regexpr("/v0/(.*)$", path))
  if (length(m) == 0L) {
    return(NULL)
  }
  rest <- sub("^/v0/", "", m)
  segments <- strsplit(rest, "/", fixed = TRUE)[[1]]
  segments <- segments[nzchar(segments)]
  if (length(segments) == 0L) {
    return(NULL)
  }
  if (identical(segments[1], "meta")) {
    return(NULL)
  }
  base_id <- segments[1]
  table <- if (length(segments) >= 2L) {
    utils::URLdecode(segments[2])
  } else {
    NA_character_
  }
  list(base_id = base_id, table = table)
}
