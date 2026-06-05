#' Connect to Airtable via DBI
#'
#' A convenience wrapper around [DBI::dbConnect()] using the [airtable2()]
#' driver. When `base` is specified, the connection shows that base's tables
#' directly. When `base` is omitted, all accessible bases are shown as schemas
#' in the connection pane. Use `bases` to restrict the pane to a specific
#' subset of bases.
#'
#' @param base Character. A Base ID (starts with `app`) or a Base Name. If
#'   `NULL`, connects to all accessible bases.
#' @param bases Character vector of Base IDs or names. When supplied, the
#'   connection pane shows only those bases (as schemas). Cannot be combined
#'   with `base`.
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
#'
#' # Show only selected bases in the pane
#' con <- air_connect(bases = c("appXXXXXX", "appYYYYYY"))
#' }
air_connect <- function(base = NULL, bases = NULL, .token = NULL,
                        include_views = FALSE, .connect_code = NULL) {
  .token <- .token %||% air_token()

  if (!is.null(base) && !is.null(bases)) {
    cli::cli_abort("Specify {.arg base} or {.arg bases}, not both.")
  }

  base_id <- base

  # Resolve base name -> ID when the argument doesn't look like an ID
  if (!is.null(base) && !grepl("^app", base)) {
    cli::cli_inform("Resolving base name {.val {base}}...")
    all_bases <- at_list_bases(token = .token)
    match <- all_bases[all_bases$name == base, ]

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

  # Resolve 'bases' vector to a list of {id, name} pairs.
  # Each element may be a base ID (starts with "app") or a base name.
  bases_list <- NULL
  if (!is.null(bases)) {
    all_bases <- at_list_bases(token = .token)
    bases_list <- lapply(bases, function(b) {
      if (grepl("^app", b)) {
        row <- all_bases[all_bases$id == b, , drop = FALSE]
        if (nrow(row) == 0L) cli::cli_abort("Base {.val {b}} not found.")
        list(id = b, name = row$name[[1L]])
      } else {
        row <- all_bases[all_bases$name == b, , drop = FALSE]
        if (nrow(row) == 0L) cli::cli_abort("No base named {.val {b}} found.")
        if (nrow(row) > 1L) {
          cli::cli_warn("Multiple bases named {.val {b}}; using the first.")
        }
        list(id = row$id[[1L]], name = b)
      }
    })
  }

  DBI::dbConnect(
    airtable2(),
    base_id       = base_id,
    token         = .token,
    include_views = include_views,
    connect_code  = .connect_code,
    bases_filter  = bases_list
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
air_pane <- function(base = NULL, bases = NULL, .token = NULL,
                     include_views = FALSE) {
  # Build the reconnect code before connecting so the pane "Reconnect" button
  # calls air_pane() rather than DBI::dbConnect() directly.
  connect_code <- pane_connect_code(base, bases, include_views)

  con <- air_connect(
    base = base, bases = bases, .token = .token,
    include_views = include_views, .connect_code = connect_code
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
pane_connect_code <- function(base = NULL, bases = NULL, include_views = FALSE) {
  args <- character(0)
  if (!is.null(base)) {
    args <- c(args, sprintf('base = "%s"', base))
  }
  if (!is.null(bases) && length(bases) > 0L) {
    quoted <- paste0('"', bases, '"', collapse = ", ")
    args <- c(args, sprintf("bases = c(%s)", quoted))
  }
  if (isTRUE(include_views)) {
    args <- c(args, "include_views = TRUE")
  }
  sprintf("airtable2::air_pane(%s)", paste(args, collapse = ", "))
}
