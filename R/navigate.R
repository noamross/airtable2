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

#' Open an Airtable workspace, base, table, or view in the browser
#'
#' Navigates to the Airtable web interface for the given resource.
#' Automatically resolves IDs from connection objects and determines
#' the resource type from the ID prefix.
#'
#' @param id Character or connection. One of:
#'   - A workspace ID (starts with `wsp`)
#'   - A base ID (starts with `app`)
#'   - A table ID (starts with `tbl`)
#'   - A view ID (starts with `viw`)
#'   - A record ID (starts with `rec`)
#'   - A full Airtable URL
#'   - An Airtable connection object (uses its base_id or workspace_id)
#' @param ... Additional arguments passed to [utils::browseURL()].
#' @return The URL that was opened (invisibly).
#' @export
#' @examples
#' \dontrun{
#' # Open a base
#' air_browse("appXXXXXX")
#'
#' # Open a workspace
#' air_browse("wspXXXXXX")
#'
#' # Open a table within a base
#' air_browse("tblXXXXXX", base_id = "appXXXXXX")
#'
#' # Open a view
#' air_browse("viwXXXXXX", base_id = "appXXXXXX", table_id = "tblXXXXXX")
#' }
air_browse <- function(id, ...) {
  resolved <- air_resolve_id(id)

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

  cli::cli_inform("Opening {.url {url}}")
  utils::browseURL(url, ...)
  invisible(url)
}
