# Low-level utility endpoints

#' Summarize Airtable situation report
#'
#' Safely probes the current token to determine what workspaces and bases
#' are accessible. Modelled after [usethis::git_sitrep()] and [usethis::proj_sitrep()].
#' Useful for debugging authentication issues and understanding the scope of
#' the current token.
#'
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A list with:
#'   - `user`: User info from [at_whoami()] (id, and `email`/`scopes` if the
#'     token grants them)
#'   - `scopes`: Character vector of token scopes, or `NULL` if not exposed
#'   - `bases`: Tibble of accessible bases (`id`, `name`, `permissionLevel`)
#'   - `error`: `NULL` if successful, otherwise a message string
#'
#'   Note: the non-enterprise Airtable API does not expose workspace names or
#'   the workspace each base belongs to, so workspaces cannot be enumerated
#'   from a token alone.
#' @examples
#' \dontrun{
#' # Check what your current token can access
#' info <- at_sitrep()
#' print(info$user)
#' print(info$scopes)
#' head(info$bases)
#' }
#' @export
at_sitrep <- function(token = NULL) {
  errors <- character()

  # User info
  user <- tryCatch(
    at_whoami(token = token),
    error = function(e) {
      errors[[length(errors) + 1L]] <<- paste0(
        "Failed to get user info: ",
        conditionMessage(e)
      )
      NULL
    }
  )

  scopes <- if (!is.null(user) && !is.null(user$scopes)) {
    unlist(user$scopes, use.names = FALSE)
  } else {
    NULL
  }

  # Accessible bases (single shared meta/bases parse via at_list_bases()).
  bases <- tryCatch(
    at_list_bases(token = token),
    error = function(e) {
      errors[[length(errors) + 1L]] <<- paste0(
        "Failed to list bases: ",
        conditionMessage(e)
      )
      NULL
    }
  )

  structure(
    list(
      user = user,
      scopes = scopes,
      bases = bases,
      error = if (length(errors)) paste(errors, collapse = "; ") else NULL
    ),
    class = "at_sitrep"
  )
}

#' @export
print.at_sitrep <- function(x, ...) {
  cli::cli_rule("Airtable situation report")

  if (!is.null(x$user)) {
    user_id <- x$user$id %||% "unknown"
    if (!is.null(x$user$email)) {
      cli::cli_text("User: {x$user$email} ({.val {user_id}})")
    } else {
      cli::cli_text("User ID: {.val {user_id}}")
    }
  } else {
    cli::cli_text("User: {.emph (unavailable)}")
  }

  if (!is.null(x$scopes)) {
    n <- length(x$scopes)
    cli::cli_text("Scopes: {n} granted")
    cli::cli_bullets(stats::setNames(x$scopes, rep("*", n)))
  } else {
    cli::cli_text("Scopes: {.emph (not exposed by this token type)}")
  }

  if (!is.null(x$bases) && nrow(x$bases) > 0L) {
    n <- nrow(x$bases)
    cli::cli_text("Accessible bases: {n}")
    for (i in seq_len(min(n, 15L))) {
      cli::cli_text(
        "  {x$bases$name[i]} ({.val {x$bases$id[i]}}) [{x$bases$permissionLevel[i]}]"
      )
    }
    if (n > 15L) {
      cli::cli_text("  {.emph ... and {n - 15L} more}")
    }
  } else if (is.null(x$bases)) {
    cli::cli_text("Bases: {.emph (unavailable)}")
  } else {
    cli::cli_text("Bases: none accessible")
  }

  usage <- tryCatch(air_api_usage(), error = function(e) NULL)
  if (!is.null(usage) && !identical(usage$workspace_id, "unknown")) {
    cli::cli_text(
      "API usage: {usage$count} call{?s} this month ({.val {usage$workspace_id}})"
    )
  }

  if (!is.null(x$error)) {
    cli::cli_alert_warning("Errors: {x$error}")
  }

  invisible(x)
}

#' Get current user info
#'
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A list with `id` and (if scoped) `email`, `scopes`.
#' @examples
#' \dontrun{
#' me <- at_whoami()
#' me$email
#' me$id
#' }
#' @export
at_whoami <- function(token = NULL) {
  req <- air_req("meta/whoami", token = token)
  air_perform(req)
}

#' Upload an attachment to a record field
#'
#' @param base_id Base ID.
#' @param table_id Table ID or name.
#' @param record_id Record ID.
#' @param field_id Field ID or name.
#' @param file Path to the file to upload.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The attachment object returned by the API.
#' @examples
#' \dontrun{
#' at_upload_attachment(
#'   base_id   = "appXXXXXXXXXXXXXX",
#'   table_id  = "Projects",
#'   record_id = "recXXXXXXXXXXXXXX",
#'   field_id  = "Files",
#'   file      = "report.pdf"
#' )
#' }
#' @export
at_upload_attachment <- function(
  base_id,
  table_id,
  record_id,
  field_id,
  file,
  token = NULL
) {
  check_string(base_id)
  check_string(table_id)
  check_string(record_id)
  check_string(field_id)
  check_string(file)

  if (!file.exists(file)) {
    cli_abort("File {.file {file}} does not exist.")
  }

  endpoint <- paste0(
    base_id,
    "/",
    table_id,
    "/",
    record_id,
    "/",
    field_id,
    "/uploadAttachment"
  )
  token_resolved <- air_token(token)

  ua <- paste0("airtable2/", utils::packageVersion("airtable2"))
  req <- httr2::request(base_url()) |>
    httr2::req_url_path_append(endpoint) |>
    httr2::req_auth_bearer_token(token_resolved) |>
    httr2::req_user_agent(ua) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = function(resp) httr2::resp_status(resp) == 429L,
      backoff = ~30
    ) |>
    httr2::req_method("POST") |>
    httr2::req_body_multipart(file = curl::form_file(file))

  air_perform(req)
}
