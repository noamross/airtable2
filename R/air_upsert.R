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
#' @inheritParams air_read
#' @param data A data frame of records to upsert. May include an `airtable_id`
#'   column for direct record matching. Computed field columns and attachment
#'   field columns are silently dropped from the record payload.
#' @param merge_on Character vector of 1-3 field names to match on (for records
#'   without an `airtable_id`).
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values.
#' @param add_fields What to do when `data` contains columns not in the table:
#'   - `"error"` (default): error if unknown columns exist.
#'   - `"warn"`: warn and drop unknown columns.
#'   - `"yes"`: create missing fields before upserting (as `singleLineText`).
#' @return A list with `created` and `updated` character vectors of record IDs
#'   (invisibly).
#' @examples
#' \dontrun{
#' data <- data.frame(Name = c("Alice", "Bob"), Age = c(31, 26))
#' result <- air_upsert("appXXXXXX", "Contacts", data, merge_on = "Name")
#' result$created
#' result$updated
#' }
#' @export
air_upsert <- function(
  base_id,
  table,

  data,
  merge_on,
  typecast = TRUE,
  add_fields = c("error", "warn", "yes"),
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  .token = NULL
) {
  check_string(base_id)
  check_string(table)
  check_bool(typecast)
  add_fields <- match.arg(add_fields)
  attachments <- match.arg(attachments)

  # Fetch schema once for field validation + computed/attachment field detection
  tables <- at_get_schema(base_id, token = .token)
  tbl_schema <- Find(function(t) t$name == table || t$id == table, tables)

  # Identify and drop computed fields
  computed <- if (!is.null(tbl_schema)) {
    computed_fields_from_schema(tbl_schema$fields)
  } else {
    character()
  }
  dropped <- intersect(computed, names(data))
  if (length(dropped) > 0L) {
    cli_inform("Dropping computed field{?s}: {.field {dropped}}.")
  }

  # Identify attachment fields (always excluded from payload)
  att_fields <- if (!is.null(tbl_schema)) {
    vapply(
      Filter(
        function(f) (f$type %||% "") == "multipleAttachments",
        tbl_schema$fields
      ),
      \(f) f$name,
      character(1)
    )
  } else {
    character()
  }

  # Check for unknown columns (excluding computed + attachment + metadata)
  if (!is.null(tbl_schema)) {
    existing_fields <- vapply(
      tbl_schema$fields,
      function(f) f$name,
      character(1)
    )
    meta_cols <- c("airtable_id", "airtable_created_time")
    data_fields <- setdiff(names(data), c(meta_cols, computed, att_fields))
    unknown <- setdiff(data_fields, existing_fields)

    if (length(unknown) > 0L) {
      if (add_fields == "error") {
        n_unknown <- length(unknown)
        cli_abort(c(
          "{n_unknown} column{?s} not found in table {.val {table}}: {.field {unknown}}.",
          i = "Set {.arg add_fields} to {.val warn} or {.val yes} to handle this."
        ))
      } else if (add_fields == "warn") {
        n_unknown <- length(unknown)
        cli_warn("{n_unknown} unknown column{?s} dropped: {.field {unknown}}.")
        computed <- c(computed, unknown)
      } else {
        # add_fields == "yes": create missing fields
        table_id <- tbl_schema$id
        for (field_name in unknown) {
          cli_inform("Creating field {.field {field_name}} in {.val {table}}.")
          at_create_field(
            base_id = base_id,
            table_id = table_id,
            name = field_name,
            type = "singleLineText",
            token = .token
          )
        }
      }
    }
  }

  # Exclude both computed and attachment fields from the record payload
  exclude <- union(computed, intersect(att_fields, names(data)))

  # Use airtable_id for direct matching when available, merge_on otherwise.
  records <- tibble_to_records(data, id_col = "airtable_id", exclude = exclude)

  result <- at_update_records(
    base_id = base_id,
    table_id = table,
    records = records,
    method = "PATCH",
    typecast = typecast,
    upsert_fields = merge_on,
    token = .token
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
