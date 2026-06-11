#' Join local data with an Airtable table
#'
#' Fetches a remote Airtable table and joins it with a local data frame.
#' These are convenience wrappers around [air_read()] plus base-R `merge()`.
#' The `...` are forwarded to [air_read()] (e.g. `formula`, `fields`).
#'
#' @param x A local data frame.
#' @inheritParams air_read
#' @param by Character vector of column name(s) to join on. If `NULL`,
#'   uses all column names shared between `x` and the remote table
#'   (excluding `airtable_id` and `airtable_created_time`).
#' @param ... Additional arguments passed to [air_read()].
#' @return A tibble.
#' @examples
#' \dontrun{
#' scores <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90, 85))
#' air_left_join(scores, "Contacts", "appXXXX", by = "Name")
#' }
#' @export
air_left_join <- function(x, table, base_id = NULL, by = NULL, ..., .token = NULL) {
  air_join_impl(x, table = table, base_id = base_id, by = by,
                all.x = TRUE, all.y = FALSE, ..., .token = .token)
}

#' @rdname air_left_join
#' @export
air_inner_join <- function(x, table, base_id = NULL, by = NULL, ..., .token = NULL) {
  air_join_impl(x, table = table, base_id = base_id, by = by,
                all.x = FALSE, all.y = FALSE, ..., .token = .token)
}

#' @rdname air_left_join
#' @export
air_full_join <- function(x, table, base_id = NULL, by = NULL, ..., .token = NULL) {
  air_join_impl(x, table = table, base_id = base_id, by = by,
                all.x = TRUE, all.y = TRUE, ..., .token = .token)
}

#' Upload local data to matched Airtable records
#'
#' `air_left_join_upload()` is the complement of [air_left_join()]. Instead of
#' pulling remote data *into* a local data frame, it pushes the columns that a
#' local data frame `x` carries *onto* matching records that already exist in an
#' Airtable table, matching by a join key. It enriches existing records with
#' new or changed field values.
#'
#' Matching is by `by` (a key present in both `x` and the remote table). For
#' each matched record, only the upload columns whose value is **new** (the
#' field does not yet exist remotely) or **changed** (differs from the current
#' remote value) are sent, minimising API calls. Columns whose value already
#' equals the remote value are not re-sent.
#'
#' This function never inserts new records (unmatched local rows are skipped and
#' counted) and never deletes remote fields. To insert as well as update, use
#' [air_upsert()].
#'
#' The remote table is read minimally: only the key field plus any to-upload
#' fields that already exist are fetched. The actual write is delegated to
#' [air_upsert()] (matching by `airtable_id`), so batching, throttling, API
#' counting, and field creation are reused.
#'
#' @param x A local data frame whose columns should be uploaded.
#' @inheritParams air_read
#' @param by The join key: a column present in both `x` and the remote table
#'   (e.g. `"Name"`), or a named character vector `c(local = "remote")` when
#'   the local and remote key columns differ. If `NULL`, uses common column
#'   names (dplyr-style) and messages which key was chosen.
#' @param fields Optional character vector limiting which of `x`'s columns to
#'   upload. Defaults to all columns of `x` except the key and the Airtable
#'   meta columns (`airtable_id`, `airtable_created_time`).
#' @param add_fields What to do when an upload column does not exist in the
#'   table: `"yes"` (default) creates it, `"warn"` warns and drops it,
#'   `"error"` errors. Passed through to [air_upsert()].
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values
#'   to match field types. Passed through to [air_upsert()].
#' @param complex_fields What to do with complex (nested list or data-frame)
#'   columns: `"error"` (default) aborts, `"warn"` drops them, `"json"`
#'   serialises them as JSON text. Passed through to [air_upsert()].
#' @param progress Logical or `NULL`. If `TRUE`, shows a progress bar.
#'   Passed through to [air_upsert()].
#' @param .token Optional API token.
#' @return Invisibly, a tibble of the records that were updated: their
#'   `airtable_id`, the key, and the changed field values.
#' @examples
#' \dontrun{
#' # Local scores you computed; push them onto existing Contacts by Name.
#' scores <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90, 85))
#' air_left_join_upload(scores, "Contacts", "appXXXX", by = "Name")
#'
#' # Different local/remote key names.
#' air_left_join_upload(scores, "Contacts", "appXXXX", by = c(person = "Name"))
#' }
#' @seealso [air_left_join()] for the read direction, [air_upsert()] to also
#'   insert new records.
#' @export
air_left_join_upload <- function(x, table, base_id = NULL, by = NULL,
                            fields = NULL,
                            add_fields = "yes",
                            typecast = TRUE,
                            complex_fields = c("error", "warn", "json"),
                            progress = NULL,
                            .token = NULL) {
  if (!is.data.frame(x)) {
    cli_abort("{.arg x} must be a data frame.", call = rlang::caller_env())
  }
  base_id <- resolve_base_id(base_id)
  check_string(base_id)
  check_string(table)
  add_fields <- match.arg(add_fields, c("error", "warn", "yes"))
  complex_fields <- match.arg(complex_fields)

  meta_cols <- c("airtable_id", "airtable_created_time")

  # Resolve the join key into local and remote names.
  if (is.null(by)) {
    by_local <- NULL
    by_remote <- NULL
  } else if (is.null(names(by))) {
    by_local <- by
    by_remote <- by
  } else {
    by_local <- names(by)
    by_remote <- unname(by)
  }

  # Determine which of x's columns are candidates to upload.
  upload_cols_all <- setdiff(names(x), meta_cols)

  # Auto-detect the key (dplyr-style) when `by` is NULL. This needs the remote
  # column names, so do a single read of all fields and reuse it below.
  remote_probe <- NULL
  if (is.null(by_local)) {
    remote_probe <- air_read(base_id = base_id, table = table, .token = .token)
    by_local <- setdiff(intersect(names(x), names(remote_probe)), meta_cols)
    if (length(by_local) == 0L) {
      cli_abort(
        c(
          "x" = "No common columns between local data and {.val {table}}.",
          "i" = "Specify {.arg by} explicitly."
        ),
        call = rlang::caller_env()
      )
    }
    by_remote <- by_local
    cli_inform("Joining on {.field {by_local}}.")
  }

  # Columns to upload: x's cols minus the local key, optionally limited by
  # `fields`.
  upload_local <- setdiff(upload_cols_all, by_local)
  if (!is.null(fields)) {
    upload_local <- intersect(upload_local, fields)
  }

  # Learn which upload columns already exist remotely, using the (session-
  # cached) table schema. This lets us read minimally: key + existing targets.
  # New columns (absent from the schema) are not requested.
  remote_field_names <- tryCatch({
    sch <- get_table_schema(base_id, table, token = .token)
    if (is.null(sch)) NULL else vapply(sch$fields, function(f) f$name, character(1))
  }, error = function(e) NULL)

  if (!is.null(remote_field_names)) {
    existing_targets <- intersect(upload_local, remote_field_names)
  } else if (!is.null(remote_probe)) {
    existing_targets <- intersect(upload_local, names(remote_probe))
  } else {
    existing_targets <- upload_local
  }

  # Read remote minimally: key field(s) plus any upload fields that already
  # exist remotely.
  if (!is.null(remote_probe)) {
    remote <- remote_probe
  } else {
    read_fields <- unique(c(by_remote, existing_targets))
    remote <- air_read(base_id = base_id, table = table,
                       fields = read_fields, .token = .token)
  }

  if (!"airtable_id" %in% names(remote)) {
    cli_abort(
      "Remote read did not return {.field airtable_id}.",
      call = rlang::caller_env()
    )
  }

  # Which upload columns actually exist remotely (present in the response).
  existing_remote <- intersect(upload_local, names(remote))
  new_cols <- setdiff(upload_local, existing_remote)

  matched_idx <- match(x[[by_local]], remote[[by_remote]])
  is_matched <- !is.na(matched_idx)
  n_unmatched <- sum(!is_matched)

  if (!any(is_matched)) {
    cli_inform(c(
      "i" = "{nrow(x)} local row{?s}; 0 matched, {n_unmatched} skipped.",
      "i" = "Nothing to upload."
    ))
    return(invisible(empty_upload_summary(by_remote, upload_local)))
  }

  xm <- x[is_matched, , drop = FALSE]
  rid <- remote$airtable_id[matched_idx[is_matched]]

  # Build the payload, keeping only new/changed values per cell.
  payload <- tibble::tibble(airtable_id = rid)
  payload[[by_remote]] <- xm[[by_local]]

  any_change_in_col <- character(0)
  for (col in upload_local) {
    new_vals <- xm[[col]]
    if (col %in% new_cols) {
      # Field absent remotely: every value is new.
      payload[[col]] <- new_vals
      any_change_in_col <- c(any_change_in_col, col)
    } else {
      cur_vals <- remote[[col]][matched_idx[is_matched]]
      changed <- !values_equal(new_vals, cur_vals)
      if (any(changed)) {
        out <- new_vals
        out[!changed] <- NA
        payload[[col]] <- out
        any_change_in_col <- c(any_change_in_col, col)
      }
      # else: column unchanged for all matched rows; omit it entirely.
    }
  }

  # Drop rows that have no changes at all.
  if (length(any_change_in_col) == 0L) {
    n_changed_rows <- 0L
    keep <- logical(nrow(payload))
  } else {
    keep <- vapply(seq_len(nrow(payload)), function(i) {
      any(vapply(any_change_in_col, function(col) !is.na(payload[[col]][i]),
                 logical(1)))
    }, logical(1))
    n_changed_rows <- sum(keep)
  }

  n_fields_created <- if (add_fields == "yes") length(new_cols) else 0L

  if (n_changed_rows == 0L) {
    cli_inform(c(
      "i" = "{sum(is_matched)} matched, {n_unmatched} skipped; no changes to upload."
    ))
    return(invisible(empty_upload_summary(by_remote, upload_local)))
  }

  payload <- payload[keep, , drop = FALSE]

  air_upsert(
    data = payload,
    table = table,
    merge_on = by_remote,
    base_id = base_id,
    add_fields = add_fields,
    typecast = typecast,
    complex_fields = complex_fields,
    progress = progress,
    .token = .token
  )

  cli_inform(c(
    "v" = "{sum(is_matched)} matched, {n_changed_rows} updated, {n_unmatched} skipped.",
    if (n_fields_created > 0L)
      c("v" = "{n_fields_created} field{?s} created: {.field {new_cols}}.")
  ))

  invisible(payload)
}

# --- Internal ---

#' Compare two vectors element-wise treating NA == NA as equal.
#' @noRd
values_equal <- function(a, b) {
  both_na <- is.na(a) & is.na(b)
  eq <- a == b
  eq[is.na(eq)] <- FALSE
  eq | both_na
}

#' Empty payload summary with the right columns.
#' @noRd
empty_upload_summary <- function(by_remote, upload_local) {
  out <- tibble::tibble(airtable_id = character())
  out[[by_remote]] <- character()
  for (col in upload_local) out[[col]] <- logical(0)
  out
}

#' @noRd
air_join_impl <- function(x, table, base_id, by, all.x, all.y, ..., .token) {
  if (!is.data.frame(x)) {
    cli_abort("{.arg x} must be a data frame.", call = rlang::caller_env())
  }
  base_id <- resolve_base_id(base_id)
  check_string(base_id)
  check_string(table)

  remote <- air_read(base_id = base_id, table = table, ..., .token = .token)

  if (is.null(by)) {
    meta_cols <- c("airtable_id", "airtable_created_time")
    by <- intersect(names(x), setdiff(names(remote), meta_cols))
    if (length(by) == 0L) {
      cli_abort(
        c(
          "x" = "No common columns between local data and {.val {table}}.",
          "i" = "Specify {.arg by} explicitly."
        ),
        call = rlang::caller_env()
      )
    }
    cli_inform("Joining on {.field {by}}.")
  }

  result <- merge(x, remote, by = by, all.x = all.x, all.y = all.y,
                  sort = FALSE, suffixes = c(".x", ".y"))
  tibble::as_tibble(result)
}
