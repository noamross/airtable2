#' Write (create) records in an Airtable table
#'
#' Converts a data frame into records and creates them in the specified table.
#' Automatically batches in groups of 10. Computed fields (formulas, rollups,
#' autoNumber, createdTime, lastModifiedTime, etc.) are automatically excluded
#' from the upload.
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param table Table name or ID.
#' @param data A data frame of records to create. Should not contain
#'   `airtable_id` (those would be ignored). Computed field columns are
#'   silently dropped.
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values
#'   to match field types.
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A character vector of the created record IDs (invisibly).
#' @export
air_write <- function(base_id, table, data, typecast = TRUE, .token = NULL) {
  check_string(base_id)
  check_string(table)
  check_bool(typecast)

  # Fetch schema to identify computed fields
  computed <- get_computed_fields(base_id, table, .token)
  dropped <- intersect(computed, names(data))
  if (length(dropped) > 0L) {
    cli_inform("Dropping computed field{?s}: {.field {dropped}}.")
  }

  records <- tibble_to_records(data, id_col = NULL, exclude = computed)

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
