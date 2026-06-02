#' Write (create) records in an Airtable table
#'
#' Converts a data frame into records and creates them in the specified table.
#' Automatically batches in groups of 10.
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param table Table name or ID.
#' @param data A data frame of records to create. Should not contain
#'   `airtable_id` (those would be ignored).
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values
#'   to match field types.
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A character vector of the created record IDs (invisibly).
#' @export
air_write <- function(base_id, table, data, typecast = TRUE, .token = NULL) {
  check_string(base_id)
  check_string(table)
  check_bool(typecast)

  records <- tibble_to_records(data, id_col = NULL)

  results <- at_create_records(
    base_id = base_id,
    table_id = table,
    records = records,
    typecast = typecast,
    token = .token
  )

  ids <- vapply(results, function(r) r$id, character(1))
  cli_inform("Created {length(ids)} record{?s}.")
  invisible(ids)
}
