#' Write (create) records in an Airtable table
#'
#' Converts a data frame into records and creates them in the specified table.
#' Automatically batches in groups of 10. Computed fields (formulas, rollups,
#' autoNumber, createdTime, lastModifiedTime, etc.) and attachment fields are
#' automatically excluded from the upload payload. When `attachments` is
#' `"file"` or `"blob"`, attachment content is uploaded separately after record
#' creation using the dedicated upload endpoint.
#'
#' @inheritParams air_read
#' @param data A data frame of records to create. Should not contain
#'   `airtable_id` (those would be ignored). Computed field columns and
#'   attachment field columns are silently dropped from the record payload.
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values
#'   to match field types.
#' @return A character vector of the created record IDs (invisibly).
#' @examples
#' \dontrun{
#' data <- data.frame(Name = c("Alice", "Bob"), Age = c(30, 25))
#' ids <- air_write("appXXXXXX", "Contacts", data)
#'
#' # Write records and upload attachments from list-column
#' ids <- air_write("appXXXXXX", "Projects", data,
#'   attachments = "file",
#'   attachment_dir = "files/"
#' )
#' }
#' @export
air_write <- function(
  base_id,
  table,
  data,

  typecast = TRUE,
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
 .token = NULL
) {
  check_string(base_id)
  check_string(table)
  check_bool(typecast)
  attachments <- match.arg(attachments)

  # Fetch schema to identify computed and attachment fields
  computed <- get_computed_fields(base_id, table, .token)
  att_fields <- get_attachment_fields(base_id, table, .token)

  dropped <- intersect(computed, names(data))
  if (length(dropped) > 0L) {
    cli_inform("Dropping computed field{?s}: {.field {dropped}}.")
  }

  # Exclude both computed and attachment fields from the record payload

  exclude <- union(computed, intersect(att_fields, names(data)))

  records <- tibble_to_records(data, id_col = NULL, exclude = exclude)

  results <- at_create_records(
    base_id = base_id,
    table_id = table,
    records = records,
    typecast = typecast,
    token = .token
  )

  ids <- vapply(results, function(r) r$id, character(1))
  cli_inform("Created {length(ids)} record{?s}.")

  # Upload attachments after record creation
  if (attachments != "meta") {
    data_att_fields <- intersect(att_fields, names(data))
    if (length(data_att_fields) > 0L) {
      upload_attachments_from_tibble(
        base_id = base_id,
        table = table,
        record_ids = ids,
        data = data,
        att_fields = data_att_fields,
        mode = attachments,
        attachment_dir = attachment_dir,
        .token = .token
      )
    }
  }

  invisible(ids)
}
