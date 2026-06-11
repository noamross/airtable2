#' Upsert records into an Airtable table
#'
#' Uses Airtable's native upsert (PATCH with `performUpsert`) to create or
#' update records based on merge fields. Supports two matching modes:
#'
#' - If `data` contains an `airtable_id` column, records with non-NA IDs are
#'   updated directly by record ID (more efficient).
#' - Records without an `airtable_id` (or where it is `NA`) are matched using
#'   the `merge_on` field(s) via Airtable's upsert mechanism.
#'
#' Computed fields (formulas, rollups, autoNumber, createdTime,
#' lastModifiedTime, etc.) and attachment fields are automatically excluded
#' from the upload payload. When `attachments` is `"file"` or `"blob"`,
#' attachment content is uploaded separately after record creation/update.
#' Optionally creates missing columns.
#'
#' @param data A data frame of records to upsert. May include an `airtable_id`
#'   column for direct record matching. Computed field columns and attachment
#'   field columns are silently dropped from the record payload.
#' @inheritParams air_read
#' @param merge_on Character vector of 1-3 field names to match on (for records
#'   without an `airtable_id`).
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values.
#' @param add_fields What to do when `data` contains columns not in the table:
#'   - `"error"` (default): error if unknown columns exist.
#'   - `"warn"`: warn and drop unknown columns.
#'   - `"yes"`: create missing fields before upserting. Field types are inferred
#'     from the column class: `numeric` → `number`, `logical` → `checkbox`,
#'     `Date` → `date`, complex/JSON columns → `multilineText`, all others →
#'     `singleLineText`.
#' @inheritParams air_write
#' @param progress Logical or `NULL`. If `TRUE`, shows a cli progress bar for
#'   batch operations. If `NULL` (default), uses option `airtable2.progress.bar`
#'   or env var `AIRTABLE2_PROGRESS_BAR`.
#' @return A list with `created` and `updated` character vectors of record IDs
#'   (invisibly).
#' @examples
#' \dontrun{
#' data <- data.frame(Name = c("Alice", "Bob"), Age = c(31, 26))
#' result <- air_upsert(data, "Contacts", merge_on = "Name", base_id = "appXXXXXX")
#' result$created
#' result$updated
#' }
#' @export
air_upsert <- function(
  data,
  table,
  merge_on,
  base_id = NULL,
  typecast = TRUE,
  add_fields = c("error", "warn", "yes"),
  complex_fields = c("error", "warn", "json"),
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  progress = NULL,
  .token = NULL
) {
  base_id <- resolve_base_id(base_id)
  check_string(base_id)
  check_string(table)
  check_bool(typecast)
  add_fields     <- match.arg(add_fields)
  complex_fields <- match.arg(complex_fields)
  attachments    <- match.arg(attachments)
  progress       <- resolve_progress(progress)

  # Prepare write fields: identify computed/attachment fields, validate unknowns.
  # Uses the session schema cache (same as air_write).
  wf <- prepare_write_fields(base_id, table, data, add_fields, complex_fields, .token,
                             progress = progress)
  computed   <- wf$computed
  att_fields <- wf$att_fields
  exclude    <- if (attachments == "meta") wf$computed else wf$exclude

  if (length(wf$json_cols) > 0L) {
    data <- serialize_json_cols(data, wf$json_cols, wf$field_types)
  }

  # Use airtable_id for direct matching when available, merge_on otherwise.
  records <- tibble_to_records(
    data,
    id_col = "airtable_id",
    exclude = exclude,
    field_types = wf$field_types
  )

  result <- at_update_records(
    base_id = base_id,
    table_id = table,
    records = records,
    method = "PATCH",
    typecast = typecast,
    upsert_fields = merge_on,
    token = .token,
    progress = progress
  )

  n_created <- length(result$createdRecords %||% character())
  n_updated <- length(result$updatedRecords %||% character())
  cli_inform("Upsert complete: {n_created} created, {n_updated} updated.")

  # Upload attachments after upsert
  if (attachments != "meta") {
    data_att_fields <- intersect(att_fields, names(data))
    if (length(data_att_fields) > 0L) {
      # Get all record IDs from the upsert response
      all_records <- result$records %||% list()
      all_ids <- vapply(all_records, function(r) r$id, character(1))
      if (length(all_ids) == nrow(data)) {
        upload_attachments_from_tibble(
          base_id = base_id,
          table = table,
          record_ids = all_ids,
          data = data,
          att_fields = data_att_fields,
          mode = attachments,
          attachment_dir = attachment_dir,
          .token = .token
        )
      }
    }
  }

  invisible(list(
    created = result$createdRecords %||% character(),
    updated = result$updatedRecords %||% character()
  ))
}
