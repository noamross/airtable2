#' Delete records from a table (high-level)
#'
#' A convenience wrapper around [at_delete_records()] with messaging.
#'
#' @param record_ids Character vector of record IDs to delete.
#' @inheritParams air_read
#' @return Invisible `NULL`. Side effect: deletes records.
#' @examples
#' \dontrun{
#' air_delete(c("recABC", "recDEF"), "Contacts", "appXXXXXX")
#' }
#' @export
air_delete <- function(record_ids, table, base_id = NULL, .token = NULL,
                       progress = NULL) {
  check_string(table)
  base_id <- resolve_base_id(base_id)
  check_string(base_id)

  if (length(record_ids) == 0L) {
    cli_inform("No records to delete.")
    return(invisible(NULL))
  }

  at_delete_records(base_id, table, record_ids, token = .token, progress = progress)
  cli_inform("Deleted {length(record_ids)} record{?s}.")
  invisible(NULL)
}
