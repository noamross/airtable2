#' Delete records from a table (high-level)
#'
#' A convenience wrapper around [at_delete_records()] with messaging.
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param table Table name or ID.
#' @param record_ids Character vector of record IDs to delete.
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return Invisible `NULL`. Side effect: deletes records.
#' @export
air_delete <- function(base_id, table, record_ids, .token = NULL) {
  check_string(base_id)
  check_string(table)

  if (length(record_ids) == 0L) {
    cli_inform("No records to delete.")
    return(invisible(NULL))
  }

  at_delete_records(base_id, table, record_ids, token = .token)
  cli_inform("Deleted {length(record_ids)} record{?s}.")
  invisible(NULL)
}
