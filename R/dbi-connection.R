# DBI connection -----------------------------------------------------------

#' Airtable DBI connection
#'
#' Stores Airtable credentials and connection state for DBI methods. Use
#' [airtable2()] with [DBI::dbConnect()] to create connections.
#'
#' @section Capabilities and limitations:
#' \describe{
#'   \item{Reading tables}{[dbReadTable()] works on any accessible table. You
#'     can also pass `"TableName WHERE <formula>"` as the name to filter records
#'     using Airtable's formula syntax.}
#'   \item{Writing tables}{[dbWriteTable()] works on **existing** tables only.
#'     With `append = TRUE` it creates new records; with `overwrite = TRUE` it
#'     syncs (upsert + delete-missing) using the first column as the key.}
#'   \item{No table creation via DBI}{Use [at_create_table()] to create tables.
#'     [dbWriteTable()] errors if the table does not already exist.}
#'   \item{No table removal}{Airtable's API cannot delete tables. Use the
#'     Airtable web UI instead. [dbRemoveTable()] will error with a clear
#'     message.}
#'   \item{No SQL queries}{Arbitrary SQL is not supported. Use the high-level
#'     helpers ([air_read()], [air_write()], [air_upsert()], [air_sync()]) for
#'     more ergonomic access.}
#'   \item{No transactions}{Airtable does not support database transactions.}
#'   \item{Single-base or all-bases}{When a `base_id` is given, the connection
#'     shows that base's tables directly. Without a `base_id`, all accessible
#'     bases appear as schemas in the connection pane.}
#' }
#'
#' For most use cases, the high-level functions like [air_read()], [air_write()],
#' [air_upsert()], and [air_sync()] provide more ergonomic interfaces for
#' Airtable operations.
#'
#' @param conn,dbObj An `AirtableConnection` object.
#' @param name Table name.
#' @param value Data frame to write.
#' @param overwrite,append DBI write mode flags.
#' @param ... Additional arguments passed to Airtable helpers.
#' @exportClass AirtableConnection
methods::setClass(
  "AirtableConnection",
  contains = "DBIConnection",
  slots = list(
    token = "character",
    base_id = "character",
    state = "environment"
  )
)

#' @rdname AirtableConnection-class
#' @noRd
connection_observer_close <- function(conn) {
  observer <- connection_observer()
  if (!is.null(observer)) {
    try(
      observer$connectionClosed(
        type = "Airtable",
        host = conn@base_id %||% "Airtable"
      ),
      silent = TRUE
    )
  }
  invisible(NULL)
}

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbDisconnect",
  signature(conn = "AirtableConnection"),
  function(conn, ...) {
    conn@state$valid <- FALSE
    connection_observer_close(conn)
    TRUE
  }
)

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbIsValid",
  signature(dbObj = "AirtableConnection"),
  function(dbObj, ...) {
    isTRUE(dbObj@state$valid)
  }
)

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbListTables",
  signature(conn = "AirtableConnection"),
  function(conn, ...) {
    check_dbi_connection(conn)

    if (dbi_base_mode(conn)) {
      tables <- get_base_schema(conn@base_id, token = conn@token)
      return(vapply(tables, `[[`, character(1), "name"))
    }

    unlist(
      lapply(dbi_list_bases(conn), function(base) {
        tables <- get_base_schema(base$id, token = conn@token)
        paste(base$name, vapply(tables, `[[`, character(1), "name"), sep = ".")
      }),
      use.names = FALSE
    )
  }
)

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbExistsTable",
  signature(conn = "AirtableConnection", name = "character"),
  function(conn, name, ...) {
    check_dbi_connection(conn)
    isTRUE(dbi_resolve_table(conn, name)$exists)
  }
)

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbListFields",
  signature(conn = "AirtableConnection", name = "character"),
  function(conn, name, ...) {
    check_dbi_connection(conn)
    resolved <- dbi_resolve_table(conn, name)
    if (!resolved$exists) {
      cli_abort("Table {.val {name}} does not exist.")
    }

    fields <- resolved$table$fields
    vapply(fields, `[[`, character(1), "name")
  }
)

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbReadTable",
  signature(conn = "AirtableConnection", name = "character"),
  function(conn, name, ...) {
    check_dbi_connection(conn)
    resolved <- dbi_resolve_table(conn, name)
    if (!resolved$exists) {
      cli_abort("Table {.val {name}} does not exist.")
    }

    air_read(
      base_id = resolved$base_id,
      table = resolved$table$name,
      attachments = "meta",
      .token = conn@token,
      ...
    )
  }
)

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbWriteTable",
  signature(conn = "AirtableConnection", name = "character"),
  function(conn, name, value, overwrite = FALSE, append = FALSE, ...) {
    check_dbi_connection(conn)
    check_bool(overwrite)
    check_bool(append)

    resolved <- dbi_resolve_table(conn, name)
    if (!resolved$exists) {
      cli_abort(
        "Creating tables through {.fn DBI::dbWriteTable} is not supported."
      )
    }

    if (isTRUE(overwrite)) {
      key <- names(value)[[1]]
      air_sync(
        resolved$base_id,
        resolved$table$name,
        value,
        key = key,
        delete_missing = TRUE,
        .token = conn@token,
        ...
      )
    } else {
      if (!isTRUE(append)) {
        cli_abort(
          "{.arg append} must be {.code TRUE} unless {.arg overwrite} is {.code TRUE}."
        )
      }
      air_write(
        resolved$base_id,
        resolved$table$name,
        value,
        .token = conn@token,
        ...
      )
    }

    schema_cache_invalidate(resolved$base_id)
    TRUE
  }
)

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbRemoveTable",
  signature(conn = "AirtableConnection", name = "character"),
  function(conn, name, ...) {
    cli_abort(
      "Airtable's API cannot delete tables; use the Airtable web UI instead."
    )
  }
)

#' @rdname AirtableConnection-class
#' @export
methods::setMethod(
  "dbGetInfo",
  signature(dbObj = "AirtableConnection"),
  function(dbObj, ...) {
    list(
      db.version = utils::packageVersion("airtable2"),
      username = NA_character_,
      host = if (nzchar(dbObj@base_id)) dbObj@base_id else "Airtable",
      port = NA_integer_,
      dbname = dbObj@base_id,
      base_id = dbObj@base_id,
      valid = DBI::dbIsValid(dbObj)
    )
  }
)

methods::setMethod(
  "show",
  signature(object = "AirtableConnection"),
  function(object) {
    valid <- DBI::dbIsValid(object)
    cli::cli_text("<AirtableConnection>")
    if (nzchar(object@base_id)) {
      base_name <- tryCatch(
        {
          base_info <- at_get_base(object@base_id, token = object@token)
          base_info$name %||% object@base_id
        },
        error = function(e) object@base_id
      )
      cli::cli_text("  Base:  {base_name} ({object@base_id})")
      if (valid) {
        cli::cli_text("  URL:   {.url {paste0('https://airtable.com/', object@base_id)}}")
      }
    } else {
      cli::cli_text("  Mode:  all accessible bases")
    }
    cli::cli_text("  Valid: {valid}")
  }
)

#' @noRd
check_dbi_connection <- function(conn) {
  if (!DBI::dbIsValid(conn)) {
    cli_abort("Airtable connection is no longer valid.")
  }
  invisible(conn)
}

#' @noRd
dbi_list_bases <- function(conn, refresh = FALSE) {
  if (!refresh && !is.null(conn@state$bases)) {
    return(conn@state$bases)
  }

  bases <- at_list_bases(token = conn@token)
  if (nzchar(conn@base_id)) {
    bases <- bases[bases$id == conn@base_id, , drop = FALSE]
  }

  conn@state$bases <- lapply(seq_len(nrow(bases)), function(i) {
    list(id = bases$id[[i]], name = bases$name[[i]])
  })
  conn@state$bases
}

#' @noRd
dbi_resolve_table <- function(conn, name) {
  if (inherits(name, "Id")) {
    return(dbi_resolve_id(conn, name))
  }
  dbi_resolve_name(conn, name)
}

#' @noRd
dbi_resolve_id <- function(conn, id) {
  pieces <- as.list(id)
  schema <- pieces$schema %||% NULL
  table_name <- pieces$table %||% pieces$name %||% NULL
  if (is.null(table_name)) {
    cli_abort("Table name is required.")
  }
  dbi_resolve_name(conn, table_name, schema = schema)
}

#' @noRd
dbi_resolve_name <- function(conn, table_name, schema = NULL) {
  if (dbi_base_mode(conn)) {
    table <- get_table_schema(conn@base_id, table_name, token = conn@token)
    return(list(
      exists = !is.null(table),
      base_id = conn@base_id,
      base_name = "",
      table = table
    ))
  }

  if (is.null(schema)) {
    split <- strsplit(table_name, ".", fixed = TRUE)[[1]]
    if (length(split) >= 2L) {
      schema <- split[[1]]
      table_name <- paste(split[-1], collapse = ".")
    }
  }

  if (is.null(schema)) {
    cli_abort(
      "Multi-base connections require a qualified name like {.val Base.Table} or {.code DBI::Id(schema = 'Base', table = 'Table')}."
    )
  }

  base <- Find(
    function(x) identical(x$name, schema) || identical(x$id, schema),
    dbi_list_bases(conn)
  )
  if (is.null(base)) {
    return(list(exists = FALSE, base_id = "", base_name = schema, table = NULL))
  }

  table <- get_table_schema(base$id, table_name, token = conn@token)
  list(
    exists = !is.null(table),
    base_id = base$id,
    base_name = base$name,
    table = table
  )
}
