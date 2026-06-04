# Navigation and ID utilities

#' Resolve an Airtable ID or URL to its component parts
#'
#' Takes an ID string (e.g., "appXXXXXX", "tblXXXXXX", "wspXXXXXX", "viwXXXXXX")
#' or a full URL and extracts the ID, determining its type.
#'
#' @param x Character string. An ID, a connection object, or a URL.
#' @return A list with components: `type` ("workspace", "base", "table", "view", or "record"),
#'   `id` (the extracted ID), and any other parsed components.
#' @export
#' @examples
#' air_resolve_id("appXXXXXX")
#' air_resolve_id("wspXXXXXX")
#' air_resolve_id("https://airtable.com/appXXXXXX/tblXXXXXX/viwXXXXXX")
#' @seealso [air_browse()] for opening the ID in a browser.
air_resolve_id <- function(x) {
  # If it's a connection object, extract the base ID
  if (inherits(x, "AirtableConnection")) {
    if (!is.null(x@base_id) && nzchar(x@base_id)) {
      return(list(type = "base", id = x@base_id))
    }
  }

  # If it's a character string
  if (!is.character(x) || length(x) != 1) {
    cli::cli_abort("x must be a single string, connection object, or URL")
  }

  x <- trimws(x)

  # Try to extract from URL first
  if (grepl("^https?://", x, ignore.case = TRUE)) {
    # Airtable URL patterns:
    # https://airtable.com/appXXXXXX
    # https://airtable.com/appXXXXXX/tblXXXXXX
    # https://airtable.com/appXXXXXX/tblXXXXXX/viwXXXXXX
    # https://airtable.com/appXXXXXX/tblXXXXXX/recXXXXXX
    # https://airtable.com/workspaces/wspXXXXXX

    # Extract the path after the domain
    path <- sub("^https?://[^/]+/", "", x, ignore.case = TRUE)
    path <- sub("^/+", "", path)

    if (nzchar(path)) {
      parts <- strsplit(path, "/")[[1]]
      parts <- parts[parts != ""]

      if (length(parts) > 0) {
        # Check for workspace URL
        if (parts[1] == "workspaces" && length(parts) >= 2) {
          return(list(type = "workspace", id = parts[2]))
        }

        # Check for app (base) ID - must start with "app" and be at least 3 chars
        if (length(parts) >= 1 && grepl("^app", parts[1], ignore.case = TRUE)) {
          if (length(parts) == 1) {
            return(list(type = "base", id = parts[1]))
          }

          # Check second part for table
          if (
            length(parts) >= 2 && grepl("^tbl", parts[2], ignore.case = TRUE)
          ) {
            if (length(parts) == 2) {
              return(list(type = "table", id = parts[2], base_id = parts[1]))
            }

            # Check third part for view or record
            if (length(parts) >= 3) {
              if (grepl("^viw", parts[3], ignore.case = TRUE)) {
                return(list(
                  type = "view",
                  id = parts[3],
                  table_id = parts[2],
                  base_id = parts[1]
                ))
              }
              if (grepl("^rec", parts[3], ignore.case = TRUE)) {
                return(list(
                  type = "record",
                  id = parts[3],
                  table_id = parts[2],
                  base_id = parts[1]
                ))
              }
            }
          }
        }
      }
    }
  }

  # Try direct ID matching
  if (grepl("^wsp", x, ignore.case = TRUE)) {
    return(list(type = "workspace", id = x))
  }
  if (grepl("^app", x, ignore.case = TRUE)) {
    return(list(type = "base", id = x))
  }
  if (grepl("^tbl", x, ignore.case = TRUE)) {
    return(list(type = "table", id = x))
  }
  if (grepl("^viw", x, ignore.case = TRUE)) {
    return(list(type = "view", id = x))
  }
  if (grepl("^rec", x, ignore.case = TRUE)) {
    return(list(type = "record", id = x))
  }

  # If we can't determine, return as-is
  cli::cli_warn("Could not determine ID type for: {.val {x}}")
  list(type = NA_character_, id = x)
}

#' Create a clickable CLI hyperlink for an Airtable ID
#'
#' Wraps an Airtable ID in a `cli::style_hyperlink()` pointing to the
#' corresponding Airtable URL. The raw ID is always the visible link text so
#' terminals that do not support OSC 8 hyperlinks still display the ID plainly.
#'
#' The URL is inferred from the ID prefix:
#' - `app` → base URL
#' - `wsp` → workspace URL
#' - `tbl` → table URL (requires `base_id`)
#' - `viw` → view URL (requires `base_id` and `table_id`)
#'
#' @param id Character. An Airtable ID string.
#' @param base_id Character or `NULL`. Required for table/view IDs.
#' @param table_id Character or `NULL`. Required for view IDs.
#' @return A character string suitable for embedding in `cli` messages.
#' @noRd
air_id_link <- function(id, base_id = NULL, table_id = NULL) {
  type <- if (grepl("^wsp", id, ignore.case = TRUE)) {
    "workspace"
  } else if (grepl("^app", id, ignore.case = TRUE)) {
    "base"
  } else if (grepl("^tbl", id, ignore.case = TRUE)) {
    "table"
  } else if (grepl("^viw", id, ignore.case = TRUE)) {
    "view"
  } else {
    NA_character_
  }

  url <- id_to_url(id, type, base_id = base_id, table_id = table_id)
  cli::style_hyperlink(id, url)
}

#' Get the reverse URL for an ID (for air_browse)
#'
#' @param id The ID string
#' @param type The type (workspace, base, table, view, record)
#' @param base_id For table/view/record, the base ID
#' @param table_id For view/record, the table ID
#' @return The full URL
#' @noRd
id_to_url <- function(id, type, base_id = NULL, table_id = NULL) {
  base_url <- "https://airtable.com"

  switch(
    type,
    "workspace" = paste0(base_url, "/workspaces/", id),
    "base" = paste0(base_url, "/", id),
    "table" = paste0(base_url, "/", base_id, "/", id),
    "view" = paste0(base_url, "/", base_id, "/", table_id, "/", id),
    "record" = paste0(base_url, "/", base_id, "/", table_id, "/", id),
    paste0(base_url, "/", id)
  )
}

#' Detect if a string looks like a human name (not an ID or URL)
#'
#' Returns TRUE if `x` does not start with app/wsp/tbl/viw/rec and is not a URL.
#' Used to skip `air_resolve_id()` for names, avoiding its cli_warn.
#' @noRd
looks_like_name <- function(x) {
  if (!is.character(x) || length(x) != 1L) return(FALSE)
  x <- trimws(x)
  !grepl("^https?://", x, ignore.case = TRUE) &&
    !grepl("^(wsp|app|tbl|viw|rec)", x, ignore.case = TRUE)
}

#' Open an Airtable workspace, base, table, or view in the browser
#'
#' Navigates to the Airtable web interface for the given resource.
#' Automatically resolves IDs from connection objects, determines the resource
#' type from the ID prefix, or resolves human-readable names to IDs.
#'
#' If `id` is `NULL` (the default), `air_browse()` opens the session default
#' base set via [air_set_base()] or the `airtable2.base_id` option.
#'
#' Name resolution precedence:
#' - If `id` is a human name **and** a `base_id` is available (explicit arg or
#'   session default), `id` is treated as a **table name** and resolved via
#'   [at_get_schema()]. Case-sensitive first; falls back to case-insensitive
#'   with a warning if needed.
#' - If `id` is a human name and **no** base context is available, `id` is
#'   treated as a **base name** and resolved via [at_list_bases()].
#' - If no match is found, `cli_abort()` is called with a helpful message
#'   listing how to view valid names.
#'
#' @param id Character, connection, or `NULL`. One of:
#'   - `NULL` (default): opens the session default base.
#'   - A workspace ID (starts with `wsp`)
#'   - A base ID (starts with `app`)
#'   - A table ID (starts with `tbl`)
#'   - A view ID (starts with `viw`)
#'   - A record ID (starts with `rec`)
#'   - A full Airtable URL
#'   - An Airtable connection object (uses its `base_id`)
#'   - A human-readable base or table name (see Name resolution above)
#' @param base_id Character or `NULL`. The base ID to use when browsing a
#'   table, view, or record, or when resolving a table name. Falls back to the
#'   session default set via [air_set_base()].
#' @param table_id Character or `NULL`. The table ID to use when browsing a
#'   view or record ID.
#' @param ... Additional arguments passed to [utils::browseURL()].
#' @return The URL that was opened (invisibly).
#' @export
#' @examples
#' \dontrun{
#' # Open the session default base (requires air_set_base() or option)
#' air_browse()
#'
#' # Open a base by ID
#' air_browse("appXXXXXX")
#'
#' # Open a workspace
#' air_browse("wspXXXXXX")
#'
#' # Open a table within a base (base_id is a proper formal, not ...)
#' air_browse("tblXXXXXX", base_id = "appXXXXXX")
#'
#' # Open a view
#' air_browse("viwXXXXXX", base_id = "appXXXXXX", table_id = "tblXXXXXX")
#'
#' # Resolve a table by name (requires base context)
#' air_browse("My Table", base_id = "appXXXXXX")
#'
#' # Resolve a base by name (no base context)
#' air_browse("My Base")
#' }
air_browse <- function(id = NULL, base_id = NULL, table_id = NULL, ...) {
  # NULL id → open the session default base, then workspace, then abort
  if (is.null(id)) {
    base_ctx <- tryCatch(resolve_base_id(base_id), error = function(e) NULL)
    if (!is.null(base_ctx)) {
      url <- paste0("https://airtable.com/", base_ctx)
      id_link <- cli::style_hyperlink(base_ctx, url)
      cli::cli_inform("Opening {id_link}")
      utils::browseURL(url, ...)
      return(invisible(url))
    }
    wsp_ctx <- tryCatch(resolve_workspace_id(NULL), error = function(e) NULL)
    if (!is.null(wsp_ctx)) {
      url <- paste0("https://airtable.com/workspaces/", wsp_ctx)
      id_link <- cli::style_hyperlink(wsp_ctx, url)
      cli::cli_inform("Opening {id_link}")
      utils::browseURL(url, ...)
      return(invisible(url))
    }
    cli::cli_abort(c(
      "x" = "No default base or workspace set.",
      "i" = "Use {.fn air_set_base} or set {.envvar AIRTABLE_BASE_ID}.",
      "i" = "Or set {.envvar AIRTABLE_WORKSPACE_ID} for a workspace."
    ))
  }

  # Detect human names *before* calling air_resolve_id (avoids its cli_warn)
  if (looks_like_name(id)) {
    # Try to get a base context (explicit arg or session default, no abort yet)
    base_ctx <- tryCatch(resolve_base_id(base_id), error = function(e) NULL)

    if (!is.null(base_ctx)) {
      # Treat id as a TABLE NAME
      tables <- at_get_schema(base_ctx)
      exact <- Filter(function(t) t$name == id, tables)
      if (length(exact) == 0L) {
        # Try case-insensitive
        ci <- Filter(function(t) tolower(t$name) == tolower(id), tables)
        if (length(ci) == 0L) {
          valid <- paste(vapply(tables, `[[`, character(1), "name"), collapse = ", ")
          cli::cli_abort(
            c(
              "x" = "Table {.val {id}} not found in base {.val {base_ctx}}.",
              "i" = "Valid table names: {valid}.",
              "i" = "Use {.fn at_get_schema} to list tables."
            )
          )
        }
        cli::cli_warn(
          "Table name {.val {id}} matched case-insensitively to {.val {ci[[1]]$name}}."
        )
        exact <- ci
      }
      tbl_id <- exact[[1]]$id
      url <- paste0("https://airtable.com/", base_ctx, "/", tbl_id)
      id_link <- cli::style_hyperlink(tbl_id, url)
      cli::cli_inform("Opening {id_link}")
      utils::browseURL(url, ...)
      return(invisible(url))
    } else {
      # Treat id as a BASE NAME
      bases <- at_list_bases()
      match_row <- bases[bases$name == id, , drop = FALSE]
      if (nrow(match_row) == 0L) {
        valid <- paste(bases$name, collapse = ", ")
        cli::cli_abort(
          c(
            "x" = "Base {.val {id}} not found.",
            "i" = "Valid base names: {valid}.",
            "i" = "Use {.fn at_list_bases} to list bases."
          )
        )
      }
      app_id <- match_row$id[[1L]]
      url <- paste0("https://airtable.com/", app_id)
      id_link <- cli::style_hyperlink(app_id, url)
      cli::cli_inform("Opening {id_link}")
      utils::browseURL(url, ...)
      return(invisible(url))
    }
  }

  # Standard ID / URL path
  resolved <- air_resolve_id(id)

  # Fill missing context from explicit args (falling back to session defaults)
  if (is.null(resolved$base_id) && !is.null(base_id) && nzchar(base_id)) {
    resolved$base_id <- base_id
  }
  if (is.null(resolved$base_id)) {
    resolved$base_id <- tryCatch(resolve_base_id(NULL), error = function(e) NULL)
  }
  if (is.null(resolved$table_id) && !is.null(table_id) && nzchar(table_id)) {
    resolved$table_id <- table_id
  }

  url <- switch(
    resolved$type,
    "workspace" = paste0("https://airtable.com/workspaces/", resolved$id),
    "base" = paste0("https://airtable.com/", resolved$id),
    "table" = {
      if (!is.null(resolved$base_id)) {
        paste0("https://airtable.com/", resolved$base_id, "/", resolved$id)
      } else {
        cli::cli_abort(
          "Cannot browse table without base_id. Provide base_id or use a full URL."
        )
      }
    },
    "view" = {
      if (!is.null(resolved$base_id) && !is.null(resolved$table_id)) {
        paste0(
          "https://airtable.com/",
          resolved$base_id,
          "/",
          resolved$table_id,
          "/",
          resolved$id
        )
      } else {
        cli::cli_abort(
          "Cannot browse view without base_id and table_id. Provide them or use a full URL."
        )
      }
    },
    "record" = {
      if (!is.null(resolved$base_id) && !is.null(resolved$table_id)) {
        paste0(
          "https://airtable.com/",
          resolved$base_id,
          "/",
          resolved$table_id,
          "/",
          resolved$id
        )
      } else {
        cli::cli_abort(
          "Cannot browse record without base_id and table_id. Provide them or use a full URL."
        )
      }
    },
    cli::cli_abort("Unknown ID type: {.val {resolved$type}}")
  )

  id_link <- cli::style_hyperlink(resolved$id, url)
  cli::cli_inform("Opening {id_link}")
  utils::browseURL(url, ...)
  invisible(url)
}
