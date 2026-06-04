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
#' @param base_id Base ID (e.g., `"appXXXXXX"`). If `NULL`, uses the session
#'   default set by [air_set_base()] or the `AIRTABLE_BASE_ID` environment
#'   variable.
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values
#'   to match field types.
#' @param add_fields What to do when `data` contains columns not in the table:
#'   - `"error"` (default): error if unknown columns exist.
#'   - `"warn"`: warn and drop unknown columns.
#'   - `"yes"`: create missing fields before writing (as `singleLineText`).
#' @return A character vector of the created record IDs (invisibly).
#' @examples
#' \dontrun{
#' data <- data.frame(Name = c("Alice", "Bob"), Age = c(30, 25))
#' ids <- air_write(data, "appXXXXXX", "Contacts")
#'
#' # Write records and upload attachments from list-column
#' ids <- air_write(data, "appXXXXXX", "Projects",
#'   attachments = "file",
#'   attachment_dir = "files/"
#' )
#'
#' # Write records and add new columns if they don't exist
#' ids <- air_write(data, "appXXXXXX", "Contacts", add_fields = "yes")
#' }
#' @export
air_write <- function(
  data,
  base_id = NULL,
  table,
  typecast = TRUE,
  add_fields = c("error", "warn", "yes"),
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  progress = NULL,
  .token = NULL
) {
  base_id <- resolve_base_id(base_id)
  check_string(base_id)
  check_string(table)
  check_bool(typecast)
  add_fields <- match.arg(add_fields)
  attachments <- match.arg(attachments)

  # Prepare write fields: identify computed/attachment fields, validate unknowns.
  wf <- prepare_write_fields(base_id, table, data, add_fields, .token)
  computed   <- wf$computed
  att_fields <- wf$att_fields
  exclude    <- wf$exclude

  records <- tibble_to_records(data, id_col = NULL, exclude = exclude)

  results <- at_create_records(
    base_id = base_id,
    table_id = table,
    records = records,
    typecast = typecast,
    token = .token,
    progress = progress
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

# --- Internal helpers ---

#' Prepare data fields for a write operation
#'
#' Identifies computed and attachment fields to exclude from the payload,
#' warns about or drops unknown columns, and optionally creates missing fields.
#' Uses the session schema cache via `get_table_schema()`.
#'
#' @return A list with `computed`, `att_fields`, and `exclude` character vectors.
#' @noRd
prepare_write_fields <- function(base_id, table, data, add_fields, .token,
                                 call = rlang::caller_env()) {
  computed   <- get_computed_fields(base_id, table, .token)
  att_fields <- get_attachment_fields(base_id, table, .token)

  dropped <- intersect(computed, names(data))
  if (length(dropped) > 0L) {
    cli_inform("Dropping computed field{?s}: {.field {dropped}}.")
  }

  tbl_schema <- tryCatch(
    get_table_schema(base_id, table, token = .token),
    error = function(e) NULL
  )

  if (!is.null(tbl_schema)) {
    existing_fields <- vapply(tbl_schema$fields, function(f) f$name, character(1))
    meta_cols <- c("airtable_id", "airtable_created_time")
    data_fields <- setdiff(names(data), c(meta_cols, computed, att_fields))
    unknown <- setdiff(data_fields, existing_fields)

    if (length(unknown) > 0L) {
      n_unknown <- length(unknown)
      if (add_fields == "error") {
        cli_abort(
          c(
            "{n_unknown} column{?s} not found in table {.val {table}}: {.field {unknown}}.",
            i = "Set {.arg add_fields} to {.val warn} or {.val yes} to handle this."
          ),
          call = call
        )
      } else if (add_fields == "warn") {
        cli_warn("{n_unknown} unknown column{?s} dropped: {.field {unknown}}.")
        computed <- c(computed, unknown)
      } else {
        for (field_name in unknown) {
          cli_inform("Creating field {.field {field_name}} in {.val {table}}.")
          at_create_field(
            field_name,
            base_id = base_id,
            table_id = tbl_schema$id,
            type = "singleLineText",
            token = .token
          )
        }
        schema_cache_invalidate(base_id)
        computed   <- get_computed_fields(base_id, table, .token)
        att_fields <- get_attachment_fields(base_id, table, .token)
      }
    }
  }

  list(
    computed   = computed,
    att_fields = att_fields,
    exclude    = union(computed, intersect(att_fields, names(data)))
  )
}
