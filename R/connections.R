#' Connect to Airtable via DBI
#'
#' A convenience wrapper around [DBI::dbConnect()] using the [airtable2()]
#' driver. When `base` is specified, the connection shows that base's tables
#' directly. When `base` is omitted, all accessible bases are shown as schemas
#' in the connection pane.
#'
#' @param base Character. A Base ID (starts with `app`) or a Base Name. If
#'   `NULL`, connects to all accessible bases.
#' @param .token Character. Airtable Personal Access Token (resolved via
#'   [air_token()] if `NULL`).
#' @param include_views Logical. If `TRUE`, views are included in the
#'   connection pane alongside tables. Default `FALSE`.
#' @param .connect_code Character. Optional custom reconnect code for the IDE
#'   connection pane. Defaults to a `DBI::dbConnect()` call. Set by
#'   [air_pane()] to use `airtable2::air_pane()` instead.
#' @return An [AirtableConnection-class] object.
#' @export
#' @examples
#' \dontrun{
#' # Connect to a specific base by name
#' con <- air_connect(base = "Project Tracker")
#'
#' # Connect to all accessible bases
#' con <- air_connect()
#' }
air_connect <- function(base = NULL, .token = NULL, include_views = FALSE,
                        .connect_code = NULL) {
  .token <- .token %||% air_token()

  base_id <- base

  # Resolve base name -> ID when the argument doesn't look like an ID
  if (!is.null(base) && !grepl("^app", base)) {
    cli::cli_inform("Resolving base name {.val {base}}...")
    bases <- at_list_bases(token = .token)
    match <- bases[bases$name == base, ]

    if (nrow(match) == 0) {
      user_info <- tryCatch(
        {
          whoami <- at_whoami(token = .token)
          if (!is.null(whoami$email)) {
            sprintf(" (user: %s)", whoami$email)
          } else if (!is.null(whoami$id)) {
            sprintf(" (user ID: %s)", whoami$id)
          } else {
            ""
          }
        },
        error = function(e) ""
      )

      cli::cli_abort(c(
        "x" = "Could not find an Airtable base named {.val {base}}{user_info}.",
        "i" = "Run {.code at_list_bases()} to see accessible bases.",
        "i" = "Or use the base ID directly (starts with {.val app})."
      ))
    }

    if (nrow(match) > 1) {
      cli::cli_warn(
        "Multiple bases named {.val {base}}; using {.val {match$id[1]}}."
      )
    }

    base_id <- match$id[1]
  }

  DBI::dbConnect(
    airtable2(),
    base_id       = base_id,
    token         = .token,
    include_views = include_views,
    connect_code  = .connect_code
  )
}

#' Open the Airtable Connection Pane
#'
#' Establishes a connection via [air_connect()] and ensures it is registered
#' with the RStudio/Positron connection pane.
#'
#' @inheritParams air_connect
#' @return An [AirtableConnection-class] object (invisibly).
#' @export
air_pane <- function(base = NULL, .token = NULL, include_views = FALSE) {
  # Build the reconnect code before connecting so the pane "Reconnect" button
  # calls air_pane() rather than DBI::dbConnect() directly.
  connect_code <- pane_connect_code(base, include_views)

  con <- air_connect(
    base = base, .token = .token, include_views = include_views,
    .connect_code = connect_code
  )

  if (!DBI::dbIsValid(con)) {
    cli::cli_abort("Failed to establish a valid Airtable connection.")
  }

  cli::cli_inform(
    "Connection to {.val {base %||% 'Airtable'}} opened in pane."
  )

  invisible(con)
}

#' Build reconnect code for air_pane()
#' @noRd
pane_connect_code <- function(base = NULL, include_views = FALSE) {
  if (is.null(base)) {
    if (isTRUE(include_views)) {
      return('airtable2::air_pane(include_views = TRUE)')
    }
    return('airtable2::air_pane()')
  }
  if (isTRUE(include_views)) {
    return(glue::glue('airtable2::air_pane(base = "{base}", include_views = TRUE)'))
  }
  glue::glue('airtable2::air_pane(base = "{base}")')
}
