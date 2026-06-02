#' Smart sync: diff-based upsert + delete
#'
#' Compares local data against the current table contents using a hash of
#' specified fields, then creates/updates/deletes as needed.
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param table Table name or ID.
#' @param data A data frame representing the desired state of the table.
#' @param key Column name in `data` that uniquely identifies records (used as
#'   the merge field for upsert). Must be a single field.
#' @param hash_fields Character vector of fields to include in the change-
#'   detection hash. If `NULL` (default), all non-key fields are used.
#' @param delete_missing If `TRUE` (default), records in Airtable that are not
#'   in `data` will be deleted.
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values.
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A list with counts: `created`, `updated`, `deleted`, `unchanged`
#'   (invisibly).
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

  meta_cols <- c("airtable_id", "airtable_created_time")
  data_fields <- setdiff(names(data), meta_cols)

  if (is.null(hash_fields)) {
    hash_fields <- setdiff(data_fields, key)
  }

  # 1. Read existing records
  existing <- air_read(base_id, table, coerce = FALSE, .token = .token)

  # 2. Compute hashes for existing data
  existing_keys <- if (nrow(existing) > 0 && key %in% names(existing)) {
    as.character(existing[[key]])
  } else {
    character()
  }
  existing_hashes <- if (nrow(existing) > 0L && length(hash_fields) > 0L) {
    available_hash_fields <- intersect(hash_fields, names(existing))
    if (length(available_hash_fields) > 0L) {
      apply(existing[available_hash_fields], 1, function(row) {
        digest::digest(row, algo = "xxhash64")
      })
    } else {
      rep(NA_character_, nrow(existing))
    }
  } else {
    rep(NA_character_, nrow(existing))
  }

  # 3. Compute hashes for new data
  new_keys <- as.character(data[[key]])
  new_hashes <- if (length(hash_fields) > 0L) {
    available_hash_fields <- intersect(hash_fields, names(data))
    if (length(available_hash_fields) > 0L) {
      apply(data[available_hash_fields], 1, function(row) {
        digest::digest(row, algo = "xxhash64")
      })
    } else {
      rep(NA_character_, nrow(data))
    }
  } else {
    rep(NA_character_, nrow(data))
  }

  # 4. Determine what changed
  # Records to create: keys in data but not in existing
  to_create_idx <- which(!new_keys %in% existing_keys)

  # Records to potentially update: keys in both
  shared_new_idx <- which(new_keys %in% existing_keys)
  to_update_idx <- integer()
  for (i in shared_new_idx) {
    ex_pos <- match(new_keys[i], existing_keys)
    if (!is.na(ex_pos) && !identical(new_hashes[i], existing_hashes[ex_pos])) {
      to_update_idx <- c(to_update_idx, i)
    }
  }
  n_unchanged <- length(shared_new_idx) - length(to_update_idx)

  # Records to delete: keys in existing but not in data
  to_delete_keys <- setdiff(existing_keys, new_keys)

  # 5. Perform operations
  n_created <- 0L
  n_updated <- 0L
  n_deleted <- 0L

  # Upsert new + changed records together
  upsert_idx <- c(to_create_idx, to_update_idx)
  if (length(upsert_idx) > 0L) {
    upsert_data <- data[upsert_idx, data_fields, drop = FALSE]

    # For records being updated, attach airtable_id from existing data so
    # the upsert can use direct record ID matching (more efficient).
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

  cli_inform(
    "Sync complete: {n_created} created, {n_updated} updated, {n_deleted} deleted, {n_unchanged} unchanged."
  )

  invisible(list(
    created = n_created,
    updated = n_updated,
    deleted = n_deleted,
    unchanged = n_unchanged
  ))
}
