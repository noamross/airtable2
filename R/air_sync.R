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
#' @inheritParams air_read
#' @param data A data frame representing the desired state of the table.
#'   May contain computed field columns (they are ignored).
#' @param key Column name in `data` that uniquely identifies records (used as
#'   the merge field for upsert). Must be a single field.
#' @param hash_fields Character vector of fields to include in the change-
#'   detection hash. If `NULL` (default), all non-key, non-computed fields are
#'   used. Computed fields are always excluded even if explicitly listed.
#' @param delete_missing If `TRUE` (default), records in Airtable that are not
#'   in `data` will be deleted.
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values.
#' @return A list with counts: `created`, `updated`, `deleted`, `unchanged`
#'   (invisibly).
#' @examples
#' \dontrun{
#' desired <- data.frame(Name = c("Alice", "Bob"), Age = c(30, 26))
#' result <- air_sync("appXXXXXX", "Contacts", desired, key = "Name")
#' result$created
#' result$unchanged
#' }
#' @export
air_sync <- function(
  base_id,
  table,
  data,
  key,
  hash_fields = NULL,
  delete_missing = TRUE,
  typecast = TRUE,
  .token = NULL
) {
  check_string(base_id)
  check_string(table)
  check_string(key)
  check_bool(delete_missing)
  check_bool(typecast)

  if (!key %in% names(data)) {
    cli_abort("Key column {.field {key}} not found in {.arg data}.")
  }

  # Identify computed fields from schema
  computed <- get_computed_fields(base_id, table, .token)

  meta_cols <- c("airtable_id", "airtable_created_time")
  data_fields <- setdiff(names(data), c(meta_cols, computed))

  # Determine hash fields (exclude computed fields even if user listed them)
  if (is.null(hash_fields)) {
    hash_fields <- setdiff(data_fields, key)
  } else {
    removed <- intersect(hash_fields, computed)
    if (length(removed) > 0L) {
      cli_inform("Excluding computed field{?s} from hash: {.field {removed}}.")
    }
    hash_fields <- setdiff(hash_fields, computed)
  }

  # 1. Read existing records (without type coercion for consistent hashing)
  existing <- air_read(base_id, table, coerce = FALSE, .token = .token)

  # 2. Compute keys and hashes
  existing_keys <- if (nrow(existing) > 0 && key %in% names(existing)) {
    as.character(existing[[key]])
  } else {
    character()
  }
  existing_hashes <- compute_row_hashes(existing, hash_fields)

  new_keys <- as.character(data[[key]])
  new_hashes <- compute_row_hashes(data, hash_fields)

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

  # 5. Perform operations
  n_created <- 0L
  n_updated <- 0L
  n_deleted <- 0L

  # Upsert new + changed records (computed fields excluded by air_upsert)
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
      base_id,
      table,
      upsert_data,
      merge_on = key,
      typecast = typecast,
      add_fields = "error",
      .token = .token
    )
    n_created <- length(result$created)
    n_updated <- length(result$updated)
  }

  # Delete missing records
  if (delete_missing && length(to_delete_keys) > 0L) {
    delete_ids <- existing$airtable_id[existing_keys %in% to_delete_keys]
    if (length(delete_ids) > 0L) {
      at_delete_records(base_id, table, delete_ids, token = .token)
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
