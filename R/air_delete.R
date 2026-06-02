#' Delete records from a table (high-level)
#'
#' A convenience wrapper around [at_delete_records()] with messaging.
#'
#' @inheritParams air_read
#' @param record_ids Character vector of record IDs to delete.
#' @return Invisible `NULL`. Side effect: deletes records.
#' @examples
#' \dontrun{
#' air_delete("appXXXXXX", "Contacts", c("recABC", "recDEF"))
#' }
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
