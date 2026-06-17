#' Smart sync: diff-based upsert + delete
#'
#' Compares local data against the current table contents using a hash of
#' specified fields, then creates/updates/deletes as needed.
#'
#' Computed fields (formulas, rollups, autoNumber, createdTime,
#' lastModifiedTime, createdBy, lastModifiedBy, etc.) are automatically:
#' - Excluded from the change-detection hash (they change server-side and
#'   would cause spurious "changed" detections on every sync)
#' - Excluded from the upload payload (the API rejects writes to them)
#'
#' Attachment fields (`multipleAttachments`) are always excluded from the
#' change-detection hash because their URLs are volatile (expire hourly).
#' When `attachments` is `"file"` or `"blob"`, attachment content is uploaded
#' for newly created records after the sync completes.
#'
#' Before hashing, both the local data and the existing Airtable records are
#' normalized to a canonical form to prevent false-positive change detection
#' caused by representation differences:
#' - `richText` values have trailing whitespace stripped (Airtable appends `\n`)
#' - Empty strings (`""`) are converted to `NA`
#' - Unchecked checkbox (`FALSE`) is converted to `NA`
#' - `Date` values are formatted as `"YYYY-MM-DD"` strings
#' - `POSIXct` values are formatted as `"YYYY-MM-DDTHH:MM:SS.000Z"` using the
#'   value's own timezone (wall-clock), matching how Airtable round-trips them
#' - `integer` columns are coerced to `double`
#' - List-columns (multipleSelects, multipleRecordLinks, multipleCollaborators)
#'   are collapsed per-element to a `\x01`-separated string
#' - Character `multipleSelects` values (e.g. `"R; Python"`) are expanded to
#'   list form before collapsing, so they hash identically to their list counterpart
#'
#' @param data A data frame representing the desired state of the table.
#'   May contain computed field columns (they are ignored).
#' @inheritParams air_read
#' @param key Column name in `data` that uniquely identifies records (used as
#'   the merge field for upsert). Must be a single field.
#' @param hash_fields Character vector of fields to include in the change-
#'   detection hash. If `NULL` (default), all non-key, non-computed,
#'   non-attachment fields are used. Computed and attachment fields are always
#'   excluded even if explicitly listed.
#' @param delete_missing If `TRUE` (default), records in Airtable that are not
#'   in `data` will be deleted.
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values.
#' @param add_fields What to do when `data` contains columns not in the table.
#'   Passed to [air_upsert()]. Default is `"error"`.
#' @inheritParams air_write
#' @param progress Logical or `NULL`. If `TRUE`, shows a cli progress bar for
#'   read and upsert operations. If `NULL` (default), uses option
#'   `airtable2.progress.bar` or env var `AIRTABLE2_PROGRESS_BAR`.
#' @return A list with counts: `created`, `updated`, `deleted`, `unchanged`
#'   (invisibly).
#' @examples
#' \dontrun{
#' desired <- data.frame(Name = c("Alice", "Bob"), Age = c(30, 26))
#' result <- air_sync(desired, "Contacts", key = "Name", base_id = "appXXXXXX")
#' result$created
#' result$unchanged
#' }
#' @export
air_sync <- function(
  data,
  table,
  key,
  base_id = NULL,
  hash_fields = NULL,
  delete_missing = TRUE,
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
  check_string(key)
  check_bool(delete_missing)
  check_bool(typecast)
  attachments <- match.arg(attachments)
  progress <- resolve_progress(progress)

  if (!key %in% names(data)) {
    cli_abort("Key column {.field {key}} not found in {.arg data}.")
  }

  # Single schema fetch (cached per-session); derive all field metadata from it
  tbl_schema  <- get_table_schema(base_id, table, token = .token)
  computed    <- computed_fields_from_schema(tbl_schema$fields)
  att_fields  <- attachment_fields_from_schema(tbl_schema)
  field_types <- field_types_from_schema(tbl_schema)

  meta_cols <- c("airtable_id", "airtable_created_time")
  data_fields <- setdiff(names(data), c(meta_cols, computed))

  # Determine hash fields (exclude computed AND attachment fields)
  exclude_from_hash <- union(computed, att_fields)
  if (is.null(hash_fields)) {
    hash_fields <- setdiff(data_fields, c(key, att_fields))
  } else {
    removed <- intersect(hash_fields, exclude_from_hash)
    if (length(removed) > 0L) {
      cli_inform(
        "Excluding field{?s} from hash: {.field {removed}}."
      )
    }
    hash_fields <- setdiff(hash_fields, exclude_from_hash)
  }

  # 1. Read existing records (without type coercion for consistent hashing)
  if (progress) cli_inform("Reading {.field {table}}...")
  existing <- air_read(table, base_id, coerce = FALSE, .token = .token, progress = progress)

  # 2. Compute keys and hashes
  existing_keys <- if (nrow(existing) > 0 && key %in% names(existing)) {
    as.character(existing[[key]])
  } else {
    character()
  }
  existing_norm   <- normalize_for_hash(existing, field_types)
  existing_hashes <- compute_row_hashes(existing_norm, hash_fields)

  new_keys <- as.character(data[[key]])
  data_norm    <- normalize_for_hash(data, field_types)
  new_hashes   <- compute_row_hashes(data_norm, hash_fields)

  # 4. Determine what changed
  to_create_idx <- which(!new_keys %in% existing_keys)

  shared_new_idx <- which(new_keys %in% existing_keys)
  to_update_idx <- integer()
  for (i in shared_new_idx) {
    ex_pos <- match(new_keys[i], existing_keys)
    if (!is.na(ex_pos) && !identical(new_hashes[i], existing_hashes[ex_pos])) {
      to_update_idx <- c(to_update_idx, i)
    }
  }
  n_unchanged <- length(shared_new_idx) - length(to_update_idx)

  to_delete_keys <- setdiff(existing_keys, new_keys)

  if (progress) {
    cli_inform(paste0(
      "Diff: {length(to_create_idx)} to create, {length(to_update_idx)} to update, ",
      "{length(to_delete_keys)} to delete, {n_unchanged} unchanged."
    ))
  }

  # 5. Perform operations
  n_created <- 0L
  n_updated <- 0L
  n_deleted <- 0L

  # Upsert new + changed records (computed + attachment fields excluded)
  upsert_idx <- c(to_create_idx, to_update_idx)
  if (length(upsert_idx) > 0L) {
    upsert_data <- data[upsert_idx, data_fields, drop = FALSE]

    # Attach airtable_id from existing data for direct record ID matching
    upsert_ids <- vapply(
      upsert_idx,
      function(i) {
        ex_pos <- match(new_keys[i], existing_keys)
        if (!is.na(ex_pos)) existing$airtable_id[ex_pos] else NA_character_
      },
      character(1)
    )
    upsert_data$airtable_id <- upsert_ids

    result <- air_upsert(
      upsert_data,
      table,
      merge_on = key,
      base_id = base_id,
      typecast = typecast,
      add_fields = add_fields,
      complex_fields = complex_fields,
      # Pass "meta" here; we handle attachment upload ourselves below
      attachments = "meta",
      progress = progress,
      .token = .token
    )
    n_created <- length(result$created)
    n_updated <- length(result$updated)

    # Upload attachments for newly created records
    if (attachments != "meta" && n_created > 0L) {
      data_att_fields <- intersect(att_fields, names(data))
      if (length(data_att_fields) > 0L) {
        created_data <- data[to_create_idx, , drop = FALSE]
        upload_attachments_from_tibble(
          base_id = base_id,
          table = table,
          record_ids = result$created,
          data = created_data,
          att_fields = data_att_fields,
          mode = attachments,
          attachment_dir = attachment_dir,
          .token = .token
        )
      }
    }
  }

  # Delete missing records
  if (delete_missing && length(to_delete_keys) > 0L) {
    delete_ids <- existing$airtable_id[existing_keys %in% to_delete_keys]
    if (length(delete_ids) > 0L) {
      at_delete_records(base_id, table, delete_ids, token = .token, progress = progress)
      n_deleted <- length(delete_ids)
    }
  }

  cli_inform(paste0(
    "Sync complete: {n_created} created, {n_updated} updated, ",
    "{n_deleted} deleted, {n_unchanged} unchanged."
  ))

  invisible(list(
    created = n_created,
    updated = n_updated,
    deleted = n_deleted,
    unchanged = n_unchanged
  ))
}

# --- Internal helpers ---

#' Compute row hashes for change detection
#' @noRd
compute_row_hashes <- function(df, hash_fields) {
  if (nrow(df) == 0L || length(hash_fields) == 0L) {
    return(rep(NA_character_, nrow(df)))
  }
  available <- intersect(hash_fields, names(df))
  if (length(available) == 0L) {
    return(rep(NA_character_, nrow(df)))
  }
  apply(df[available], 1, digest::digest, algo = "xxhash64")
}
