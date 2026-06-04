# DBI driver ---------------------------------------------------------------

#' Airtable DBI driver
#'
#' Create a DBI driver for Airtable. Use with [DBI::dbConnect()] to create an
#' Airtable DBI connection.
#'
#' @section Usage:
#' Use this driver to create DBI-compliant connections to Airtable for use
#' with RStudio/Positron's connection pane. See [airtable2-package] for
#' package-level documentation and [AirtableConnection-class] for details
#' on available DBI methods.
#'
#' @param drv,dbObj An `AirtableDriver` object.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @param base_id Optional Airtable base ID. If omitted, all accessible bases
#'   are shown as schemas in the connection pane.
#' @param include_views Logical. If `TRUE`, views are listed in the connection
#'   pane as separate objects alongside tables.
#' @param obj An R object to map to an Airtable field type.
#' @param ... Additional arguments passed to DBI methods.
#' @return An `AirtableDriver` object.
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(airtable2(), base_id = "appXXXXXX")
#' DBI::dbListTables(con)
#' DBI::dbDisconnect(con)
#' }
#' @export
airtable2 <- function() {
  methods::new("AirtableDriver")
}

#' @rdname airtable2
#' @export
at <- function() {
  airtable2()
}

#' @rdname airtable2
#' @export
airtable <- function() {
  airtable2()
}

#' Airtable DBI driver class
#'
#' S4 class representing the Airtable DBI driver. Use [airtable2()] to
#' construct an instance and pass it to [DBI::dbConnect()].
#'
#' @aliases AirtableDriver
#' @exportClass AirtableDriver
methods::setClass("AirtableDriver", contains = "DBIDriver")

# Connection observer helpers -----------------------------------------------

#' Connection observer accessor
#' @noRd
connection_observer <- function() {
  getOption("connectionObserver")
}

#' Icon path helper
#' @noRd
icon_path <- function(name) {
  path <- system.file("icons", paste0(name, ".png"), package = "airtable2")
  if (nzchar(path) && file.exists(path)) path else NULL
}

#' Check if connection is in single-base mode (vs all-bases mode)
#' @noRd
dbi_base_mode <- function(conn) {
  nzchar(conn@base_id)
}

#' Connection actions for the RStudio/Positron connection pane
#' @noRd
connection_actions <- function(con) {
  actions <- list()

  # Browse action - open the connected base (or airtable.com) in a browser
  if (dbi_base_mode(con)) {
    actions$Browse <- list(
      icon = icon_path("airtable-icon-32-32"),
      callback = function() {
        utils::browseURL(paste0("https://airtable.com/", con@base_id))
      }
    )
  } else {
    actions$Browse <- list(
      icon = icon_path("airtable-icon-32-32"),
      callback = function() {
        utils::browseURL("https://airtable.com")
      }
    )
  }

  actions
}

#' Notify connection opened
#' @noRd
connection_observer_open <- function(con, connect_code) {
  observer <- connection_observer()
  if (is.null(observer)) {
    return(invisible(NULL))
  }

  display_name <- if (nzchar(con@base_id)) {
    base_info <- tryCatch(
      at_get_base(con@base_id, token = con@token),
      error = function(e) NULL
    )
    if (!is.null(base_info)) {
      paste0(base_info$name, " (", substr(con@base_id, 1, 8), "...)")
    } else {
      paste0("Airtable (", substr(con@base_id, 1, 8), "...)")
    }
  } else {
    "Airtable"
  }

  # Helpers reused by both single-base and multi-base list callbacks
  list_tables_for_base <- function(base_id) {
    tables <- tryCatch(DBI::dbListTables(
      methods::new("AirtableConnection",
        token = con@token, base_id = base_id,
        state = {e <- new.env(parent = emptyenv()); e$valid <- TRUE; e}
      )
    ), error = function(e) character())
    include_views <- con@state$include_views %||% FALSE
    if (include_views) {
      schema <- tryCatch(
        get_base_schema(base_id, token = con@token),
        error = function(e) NULL
      )
      if (!is.null(schema)) {
        for (tbl in schema) {
          for (view in tbl$views %||% list()) {
            tables <- c(tables, paste(tbl$name, view$name, sep = ":"))
          }
        }
      }
    }
    tables
  }

  list_columns_for <- function(base_id, table) {
    schema <- tryCatch(
      get_table_schema(base_id, table, token = con@token),
      error = function(e) NULL
    )
    if (!is.null(schema)) {
      data.frame(
        name = vapply(schema$fields, function(f) f$name, character(1)),
        type = vapply(schema$fields, function(f) f$type %||% "", character(1)),
        stringsAsFactors = FALSE
      )
    } else {
      data.frame(name = character(), type = character(), stringsAsFactors = FALSE)
    }
  }

  # Build the core arguments that every version of rstudioapi supports.
  core_args <- list(
    type        = "Airtable",
    displayName = display_name,
    host        = if (nzchar(con@base_id)) con@base_id else "Airtable",
    connectCode = connect_code,
    disconnect  = function() DBI::dbDisconnect(con),
    listObjectTypes = function() {
      if (dbi_base_mode(con)) {
        list(table = list(contains = "data"))
      } else {
        list(schema = list(contains = list(table = list(contains = "data"))))
      }
    },
    listObjects = function(type = "table", ...) {
      args <- list(...)
      if (dbi_base_mode(con)) {
        tables <- list_tables_for_base(con@base_id)
        data.frame(name = tables, type = rep("table", length(tables)),
                   stringsAsFactors = FALSE)
      } else if (type == "schema") {
        bases <- dbi_list_bases(con)
        data.frame(
          name = vapply(bases, `[[`, character(1), "name"),
          type = rep("schema", length(bases)),
          stringsAsFactors = FALSE
        )
      } else if (type == "table") {
        schema_name <- args$schema %||% NULL
        if (is.null(schema_name)) {
          return(data.frame(name = character(), type = character(),
                            stringsAsFactors = FALSE))
        }
        bases <- dbi_list_bases(con)
        base_info <- Find(function(b) b$name == schema_name, bases)
        if (is.null(base_info)) {
          return(data.frame(name = character(), type = character(),
                            stringsAsFactors = FALSE))
        }
        tables <- list_tables_for_base(base_info$id)
        data.frame(name = tables, type = rep("table", length(tables)),
                   stringsAsFactors = FALSE)
      } else {
        data.frame(name = character(), type = character(), stringsAsFactors = FALSE)
      }
    },
    listColumns = function(table, ...) {
      args <- list(...)
      schema_name <- args$schema %||% NULL
      base_id_to_use <- if (!is.null(schema_name) && !dbi_base_mode(con)) {
        bases <- dbi_list_bases(con)
        base_info <- Find(function(b) b$name == schema_name, bases)
        if (!is.null(base_info)) base_info$id else con@base_id
      } else {
        con@base_id
      }
      list_columns_for(base_id_to_use, table)
    },
    previewObject = function(rowLimit, table, ...) {
      args <- list(...)
      schema_name <- args$schema %||% NULL
      base_id_to_use <- if (!is.null(schema_name) && !dbi_base_mode(con)) {
        bases <- dbi_list_bases(con)
        base_info <- Find(function(b) b$name == schema_name, bases)
        if (!is.null(base_info)) base_info$id else con@base_id
      } else {
        con@base_id
      }
      tryCatch(
        air_read(table, base_id_to_use, .token = con@token),
        error = function(e) NULL
      )
    }
  )

  # Try with extended arguments (actions, connectionObject) supported by newer
  # versions of rstudioapi.  Fall back to core-only if the observer rejects
  # them, so the pane always shows tables rather than silently failing.
  result <- tryCatch(
    do.call(observer$connectionOpened, c(core_args, list(
      actions          = connection_actions(con),
      connectionObject = con
    ))),
    error = function(e) {
      tryCatch(
        do.call(observer$connectionOpened, core_args),
        error = function(e2) NULL
      )
    }
  )

  invisible(result)
}

#' @rdname airtable2
#' @export
methods::setMethod(
  "dbConnect",
  signature(drv = "AirtableDriver"),
  function(
    drv,
    token = NULL,
    base_id = NULL,
    include_views = FALSE,
    connect_code = NULL,
    ...
  ) {
    token <- air_token(token)

    check_string(base_id, allow_null = TRUE)
    check_bool(include_views)

    state <- new.env(parent = emptyenv())
    state$valid <- TRUE
    state$bases <- NULL
    state$include_views <- include_views

    con <- methods::new(
      "AirtableConnection",
      token = token,
      base_id = base_id %||% "",
      state = state
    )

    # Use the caller-supplied connect code if provided (e.g. air_pane() passes
    # an air_pane()-based reconnect code), otherwise generate the default.
    code <- connect_code %||% dbi_connect_code(base_id)
    connection_observer_open(con, code)
    con
  }
)

#' @rdname airtable2
#' @export
methods::setMethod(
  "dbDataType",
  signature(dbObj = "AirtableDriver"),
  function(dbObj, obj, ...) {
    airtable_data_type(obj)
  }
)

#' @rdname airtable2
#' @export
methods::setMethod(
  "dbUnloadDriver",
  signature(drv = "AirtableDriver"),
  function(drv, ...) {
    TRUE
  }
)

#' Map R vectors to Airtable field types
#' @noRd
airtable_data_type <- function(obj) {
  if (inherits(obj, "Date")) {
    return("date")
  }
  if (inherits(obj, "POSIXt")) {
    return("dateTime")
  }
  if (is.logical(obj)) {
    return("checkbox")
  }
  if (is.integer(obj) || is.numeric(obj)) {
    return("number")
  }
  if (is.list(obj)) {
    return("multipleSelects")
  }
  "singleLineText"
}

#' @noRd
dbi_connect_code <- function(base_id = NULL) {
  if (is.null(base_id)) {
    return("DBI::dbConnect(airtable2::airtable2())")
  }
  glue::glue(
    'DBI::dbConnect(airtable2::airtable2(), base_id = "{base_id}")'
  )
}
