# Session-level defaults for base ID and token ----------------------------
#
# Resolution order (mirrors workspace_id pattern in api-counter.R):
#   base_id:  getOption("airtable2.base_id") → Sys.getenv("AIRTABLE_BASE_ID")
#   token:    getOption("airtable2.token")   → Sys.getenv("AIRTABLE_API_KEY")

#' Default base ID from option or environment variable
#' @noRd
default_base_id <- function() {
  id <- getOption("airtable2.base_id", NULL)
  if (!is.null(id) && nzchar(id)) return(id)
  Sys.getenv("AIRTABLE_BASE_ID", unset = "")
}

#' Set the default Airtable base for this session
#'
#' Validates that `base_id` is accessible with the current token, prints a
#' `{cli}` confirmation, and sets `options(airtable2.base_id = base_id)` for
#' the rest of the session. Functions that accept `base_id` will use this
#' default when `base_id` is `NULL`.
#'
#' @param base_id Base ID (starts with `app`).
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return `base_id` (invisibly).
#' @examples
#' \dontrun{
#' air_set_base("appXXXXXXXXXXXXXX")
#' }
#' @export
air_set_base <- function(base_id, .token = NULL) {
  check_string(base_id)
  base_info <- tryCatch(
    at_get_base(base_id, token = .token),
    error = function(e) {
      cli_abort(
        c(
          "x" = "Could not access base {.val {base_id}}.",
          "i" = conditionMessage(e),
          "i" = "Run {.fn at_sitrep} to see accessible bases."
        )
      )
    }
  )
  if (is.null(base_info)) {
    cli_abort(
      c(
        "x" = "Base {.val {base_id}} not found.",
        "i" = "Run {.fn at_list_bases} to see accessible bases."
      )
    )
  }
  options(airtable2.base_id = base_id)
  cli_inform(
    "Default base set to {.val {base_info$name}} ({.val {base_id}})."
  )
  invisible(base_id)
}

#' Set the default Airtable token for this session
#'
#' Validates the token by calling `at_whoami()`, prints a `{cli}` confirmation
#' with the authenticated user's email, and sets `options(airtable2.token = tok)`.
#'
#' @param tok Personal Access Token (PAT) string.
#' @return `tok` (invisibly).
#' @examples
#' \dontrun{
#' air_set_token(Sys.getenv("AIRTABLE_API_KEY"))
#' }
#' @export
air_set_token <- function(tok) {
  check_string(tok)
  whoami <- tryCatch(
    at_whoami(token = tok),
    error = function(e) {
      cli_abort(
        c(
          "x" = "Token validation failed.",
          "i" = conditionMessage(e),
          "i" = "Create a Personal Access Token at {.url https://airtable.com/create/tokens}."
        )
      )
    }
  )
  options(airtable2.token = tok)
  user <- whoami$email %||% whoami$id %||% "unknown user"
  cli_inform("Token set. Authenticated as {.val {user}}.")
  invisible(tok)
}

#' Check whether parallel HTTP is enabled
#'
#' Resolution: explicit `parallel` arg → `airtable2.parallel` option →
#' `AIRTABLE2_PARALLEL` env var → `TRUE` (default on).
#' @noRd
parallel_enabled <- function(parallel) {
  if (!is.null(parallel)) return(isTRUE(parallel))
  opt <- getOption("airtable2.parallel", NULL)
  if (!is.null(opt)) return(isTRUE(opt))
  env <- Sys.getenv("AIRTABLE2_PARALLEL", unset = "true")
  !tolower(trimws(env)) %in% c("false", "0", "no", "off")
}

#' Resolve base_id, falling back to the session default
#'
#' Used internally by air_read(), air_write(), etc.
#' @noRd
resolve_base_id <- function(base_id) {
  if (!is.null(base_id) && length(base_id) == 1L &&
      !is.na(base_id) && nzchar(base_id)) {
    return(base_id)
  }
  id <- default_base_id()
  if (!nzchar(id)) {
    cli_abort(
      c(
        "x" = "{.arg base_id} is required.",
        "i" = "Set a default with {.fn air_set_base} or {.envvar AIRTABLE_BASE_ID}."
      )
    )
  }
  id
}
