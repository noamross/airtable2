# DBI result ---------------------------------------------------------------

#' Airtable DBI result
#'
#' Eagerly materialized DBI result object used by [DBI::dbSendQuery()].
#' Unlike traditional DBI results which may be cursor-based, AirtableResult
#' objects fetch all matching records immediately (due to Airtable API
#' limitations).
#'
#' @section Limitations:
#' \describe{
#'   \item{Eager evaluation}{All data is fetched when the result is created.
#'     There is no cursor-based iteration.}
#'   \item{Read-only}{AirtableResult objects are for reading data only.}
#'   \item{Formula filtering}{The `statement` parameter supports Airtable
#'     formula syntax after the table name (e.g., `"Contacts WHERE Age > 30"`).
#'     This is not SQL.}
#' }
#'
#' @param conn An `AirtableConnection` object.
#' @param statement Table name, optionally followed by `WHERE <formula>`.
#' @param res,dbObj An `AirtableResult` object.
#' @param n Number of rows to fetch. Use a negative value to fetch all rows.
#'   Note: Due to eager evaluation, this parameter is primarily for compatibility.
#' @param ... Additional arguments passed to Airtable helpers.
#' @exportClass AirtableResult
methods::setClass(
  "AirtableResult",
  contains = "DBIResult",
  slots = list(
    conn = "AirtableConnection",
    statement = "character",
    data = "data.frame",
    state = "environment"
  )
)

#' @rdname AirtableResult-class
#' @export
methods::setMethod(
  "dbSendQuery",
  signature(conn = "AirtableConnection", statement = "character"),
  function(conn, statement, ...) {
    check_dbi_connection(conn)
    parsed <- dbi_parse_statement(statement)
    resolved <- dbi_resolve_table(conn, parsed$table)
    if (!resolved$exists) {
      cli_abort("Table {.val {parsed$table}} does not exist.")
    }

    data <- air_read(
      base_id = resolved$base_id,
      table = resolved$table$name,
      formula = parsed$formula,
      attachments = "meta",
      .token = conn@token,
      ...
    )

    state <- new.env(parent = emptyenv())
    state$cursor <- 0L
    state$cleared <- FALSE

    methods::new(
      "AirtableResult",
      conn = conn,
      statement = statement,
      data = as.data.frame(data),
      state = state
    )
  }
)

#' @rdname AirtableResult-class
#' @export
methods::setMethod(
  "dbFetch",
  signature(res = "AirtableResult", n = "numeric"),
  function(res, n = -1, ...) {
    check_dbi_result(res)

    total <- nrow(res@data)
    start <- res@state$cursor + 1L
    if (start > total) {
      return(res@data[0, , drop = FALSE])
    }

    if (is.null(n) || n < 0L) {
      end <- total
    } else {
      end <- min(total, res@state$cursor + as.integer(n))
    }

    out <- res@data[start:end, , drop = FALSE]
    res@state$cursor <- end
    out
  }
)

#' @rdname AirtableResult-class
#' @export
methods::setMethod(
  "dbClearResult",
  signature(res = "AirtableResult"),
  function(res, ...) {
    res@state$cursor <- 0L
    res@state$cleared <- TRUE
    TRUE
  }
)

#' @rdname AirtableResult-class
#' @export
methods::setMethod(
  "dbHasCompleted",
  signature(res = "AirtableResult"),
  function(res, ...) {
    check_dbi_result(res)
    res@state$cursor >= nrow(res@data)
  }
)

#' @rdname AirtableResult-class
#' @export
methods::setMethod(
  "dbGetRowCount",
  signature(res = "AirtableResult"),
  function(res, ...) {
    check_dbi_result(res)
    nrow(res@data)
  }
)

#' @rdname AirtableResult-class
#' @export
methods::setMethod(
  "dbGetStatement",
  signature(res = "AirtableResult"),
  function(res, ...) {
    res@statement
  }
)

#' @rdname AirtableResult-class
#' @export
methods::setMethod(
  "dbIsValid",
  signature(dbObj = "AirtableResult"),
  function(dbObj, ...) {
    !isTRUE(dbObj@state$cleared) && DBI::dbIsValid(dbObj@conn)
  }
)

#' @noRd
dbi_parse_statement <- function(statement) {
  check_string(statement)
  statement <- trimws(statement)

  where <- regexpr("\\s+WHERE\\s+", statement, ignore.case = TRUE, perl = TRUE)
  if (where[[1]] < 0L) {
    return(list(table = statement, formula = NULL))
  }

  table <- substr(statement, 1L, where[[1]] - 1L)
  formula <- substr(
    statement,
    where[[1]] + attr(where, "match.length"),
    nchar(statement)
  )
  list(table = trimws(table), formula = trimws(formula))
}

#' @noRd
check_dbi_result <- function(res) {
  if (!DBI::dbIsValid(res)) {
    cli_abort("Airtable result is no longer valid.")
  }
  invisible(res)
}
