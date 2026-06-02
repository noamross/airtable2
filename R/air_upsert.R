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
#' lastModifiedTime, etc.) are automatically excluded from the upload payload.
#' Optionally creates missing columns.
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param table Table name or ID.
#' @param data A data frame of records to upsert. May include an `airtable_id`
#'   column for direct record matching. Computed field columns are silently
#'   dropped.
#' @param merge_on Character vector of 1-3 field names to match on (for records
#'   without an `airtable_id`).
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values.
#' @param add_fields What to do when `data` contains columns not in the table:
#'   - `"error"` (default): error if unknown columns exist.
#'   - `"warn"`: warn and drop unknown columns.
#'   - `"yes"`: create missing fields before upserting (as `singleLineText`).
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A list with `created` and `updated` character vectors of record IDs
#'   (invisibly).
#' @export
air_upsert <- function(
  base_id,
  table,
  data,
  merge_on,
  typecast = TRUE,
  add_fields = c("error", "warn", "yes"),
  .token = NULL
) {
  check_string(base_id)
  check_string(table)
  check_bool(typecast)
  add_fields <- match.arg(add_fields)

  # Fetch schema once for field validation + computed field detection
  tables <- at_get_schema(base_id, token = .token)
  tbl_schema <- Find(
    function(t) t$name == table || t$id == table,
    tables
  )

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

  # Check for unknown columns (excluding computed + metadata)
  if (!is.null(tbl_schema)) {
    existing_fields <- vapply(
      tbl_schema$fields,
      function(f) f$name,
      character(1)
    )
    meta_cols <- c("airtable_id", "airtable_created_time")
    data_fields <- setdiff(names(data), c(meta_cols, computed))
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

  # Use airtable_id for direct matching when available, merge_on otherwise.
  # Records with airtable_id get their id set on the record body, which tells
  # the API to update that specific record. Records without airtable_id rely on
  # performUpsert.fieldsToMergeOn for matching.
  records <- tibble_to_records(data, id_col = "airtable_id", exclude = computed)

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

  invisible(list(
    created = result$createdRecords %||% character(),
    updated = result$updatedRecords %||% character()
  ))
}
