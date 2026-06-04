#' Read attachments from records
#'
#' Downloads attachment files from a specified field, returning them as either
#' in-memory blobs or saved files.
#'
#' @inheritParams air_read
#' @param field Name of the attachment field.
#' @param record_ids Optional character vector of specific record IDs to fetch.
#'   If `NULL`, fetches all records.
#' @param dest Either `"blob"` (return raw content as list-column) or `"file"`
#'   (save to disk).
#' @param dir Directory to save files to (required if `dest = "file"`).
#' @return A tibble with `airtable_id`, `filename`, `url`, and either `blob`
#'   (raw list-column) or `local_path` (character).
#' @export
air_read_attachments <- function(
  base_id,
  table,
  field,
  record_ids = NULL,
  dest = c("blob", "file"),
  dir = NULL,
  parallel = NULL,
  .token = NULL
) {
  check_string(base_id)
  check_string(table)
  check_string(field)
  dest <- match.arg(dest)

  if (dest == "file" && is.null(dir)) {
    cli_abort("{.arg dir} is required when {.code dest = \"file\"}.")
  }

  # Fetch records with the attachment field
  if (!is.null(record_ids)) {
    records <- lapply(record_ids, function(rid) {
      at_get_record(base_id, table, rid, token = .token)
    })
  } else {
    records <- at_list_records(base_id, table, fields = field, token = .token)
  }

  # Extract attachment info
  rows <- list()
  for (rec in records) {
    attachments <- rec$fields[[field]]
    if (is.null(attachments) || length(attachments) == 0L) {
      next
    }
    for (att in attachments) {
      rows[[length(rows) + 1L]] <- list(
        airtable_id = rec$id,
        filename = att$filename %||% NA_character_,
        url = att$url %||% NA_character_,
        size = att$size %||% NA_integer_,
        type = att$type %||% NA_character_
      )
    }
  }

  if (length(rows) == 0L) {
    tbl <- tibble::tibble(
      airtable_id = character(),
      filename = character(),
      url = character(),
      size = integer(),
      type = character()
    )
    if (dest == "blob") {
      tbl$blob <- list()
    } else {
      tbl$local_path <- character()
    }
    return(tbl)
  }

  tbl <- tibble::tibble(
    airtable_id = vapply(rows, `[[`, character(1), "airtable_id"),
    filename = vapply(rows, `[[`, character(1), "filename"),
    url = vapply(rows, `[[`, character(1), "url"),
    size = vapply(rows, function(r) as.integer(r$size), integer(1)),
    type = vapply(rows, `[[`, character(1), "type")
  )

  # Download content — parallel when enabled, sequential otherwise
  valid <- !is.na(tbl$url)
  reqs <- lapply(tbl$url[valid], httr2::request)

  if (dest == "blob") {
    if (parallel_enabled(parallel) && sum(valid) > 1L) {
      resps <- httr2::req_perform_parallel(reqs, on_error = "continue",
                                           max_active = 5L)
      blobs <- vector("list", nrow(tbl))
      blobs[!valid] <- list(raw())
      blobs[valid] <- lapply(resps, function(r) {
        if (inherits(r, "error")) raw() else httr2::resp_body_raw(r)
      })
      tbl$blob <- blobs
    } else {
      tbl$blob <- lapply(tbl$url, function(u) {
        if (is.na(u)) return(raw())
        resp <- httr2::request(u) |> httr2::req_perform()
        httr2::resp_body_raw(resp)
      })
    }
  } else {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
    }
    dest_paths <- ifelse(
      valid,
      file.path(dir, tbl$filename),
      NA_character_
    )
    if (parallel_enabled(parallel) && sum(valid) > 1L) {
      httr2::req_perform_parallel(reqs, paths = dest_paths[valid],
                                  on_error = "continue", max_active = 5L)
    } else {
      mapply(
        function(u, p) { httr2::request(u) |> httr2::req_perform(path = p) },
        tbl$url[valid], dest_paths[valid]
      )
    }
    tbl$local_path <- dest_paths
  }

  cli_inform("Downloaded {nrow(tbl)} attachment{?s}.")
  tbl
}

#' Upload attachments to records
#'
#' @inheritParams air_read
#' @param field Name of the attachment field.
#' @param data A tibble with `airtable_id` and `file_path` columns.
#' @return Invisible `NULL`. Side effect: uploads attachments.
#' @export
air_write_attachments <- function(base_id, table, field, data,
                                   parallel = NULL, .token = NULL) {
  check_string(base_id)
  check_string(table)
  check_string(field)

  if (!"airtable_id" %in% names(data) || !"file_path" %in% names(data)) {
    cli_abort(
      "{.arg data} must contain {.field airtable_id} and {.field file_path} columns."
    )
  }

  n <- nrow(data)
  cli_inform("Uploading {n} attachment{?s}...")

  for (i in seq_len(n)) {
    at_upload_attachment(
      base_id = base_id,
      table_id = table,
      record_id = data$airtable_id[i],
      field_id = field,
      file = data$file_path[i],
      token = .token
    )
  }

  cli_inform("Upload complete.")
  invisible(NULL)
}

#' Smart sync attachments
#'
#' Compares filenames between local data and remote records, uploads
#' new/changed files, skips unchanged.
#'
#' @inheritParams air_read
#' @param field Name of the attachment field.
#' @param data A tibble with a key column and `file_path` column.
#' @param key Column name that identifies which record to attach to.
#' @return A list with counts: `uploaded`, `skipped` (invisibly).
#' @export
air_sync_attachments <- function(
  base_id,
  table,
  field,
  data,
  key,
  parallel = NULL,
  .token = NULL
) {
  check_string(base_id)
  check_string(table)
  check_string(field)
  check_string(key)

  # Read existing attachments
  existing <- air_read(
    base_id,
    table,
    fields = c(key, field),
    coerce = FALSE,
    .token = .token
  )

  # Build lookup: key value → existing filenames
  existing_files <- stats::setNames(
    lapply(seq_len(nrow(existing)), function(i) {
      atts <- existing[[field]][[i]]
      if (is.null(atts)) {
        return(character())
      }
      vapply(atts, function(a) a$filename %||% "", character(1))
    }),
    as.character(existing[[key]])
  )

  # Map key values to record IDs
  key_to_id <- stats::setNames(
    existing$airtable_id,
    as.character(existing[[key]])
  )

  n_uploaded <- 0L
  n_skipped <- 0L

  for (i in seq_len(nrow(data))) {
    key_val <- as.character(data[[key]][i])
    file_path <- data$file_path[i]
    filename <- basename(file_path)

    record_id <- key_to_id[[key_val]]
    if (is.null(record_id) || is.na(record_id)) {
      cli_warn("No record found for key {.val {key_val}}. Skipping.")
      n_skipped <- n_skipped + 1L
      next
    }

    # Check if filename already exists
    if (filename %in% (existing_files[[key_val]] %||% character())) {
      n_skipped <- n_skipped + 1L
      next
    }

    at_upload_attachment(
      base_id = base_id,
      table_id = table,
      record_id = record_id,
      field_id = field,
      file = file_path,
      token = .token
    )
    n_uploaded <- n_uploaded + 1L
  }

  cli_inform("Attachment sync: {n_uploaded} uploaded, {n_skipped} skipped.")
  invisible(list(uploaded = n_uploaded, skipped = n_skipped))
}

# --- Internal helpers for broad attachment strategy ---

#' Download attachment content for attachment list-columns in a tibble
#'
#' Modifies attachment list-columns in place to add downloaded content.
#' Used by `air_read(..., attachments = "file"|"blob")`.
#'
#' @param tbl Tibble from `records_to_tibble()`.
#' @param att_fields Character vector of attachment field names.
#' @param mode `"file"` or `"blob"`.
#' @param dir Directory for file downloads (required for `"file"` mode).
#' @return Modified tibble with downloaded content added to attachment objects.
#' @noRd
download_attachments_in_tibble <- function(tbl, att_fields, mode, dir = NULL,
                                            parallel = NULL) {
  if (mode == "file" && (is.null(dir) || !nzchar(dir))) {
    cli_abort(
      "{.arg attachment_dir} is required when {.code attachments = \"file\"}."
    )
  }
  if (mode == "file" && !dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }

  do_parallel <- parallel_enabled(parallel)

  for (field in att_fields) {
    if (!field %in% names(tbl)) next

    # Flatten all (row_idx, att_idx, url, dest_path) for parallel dispatch
    att_meta <- list()
    for (i in seq_len(nrow(tbl))) {
      atts <- tbl[[field]][[i]]
      if (is.null(atts) || length(atts) == 0L) next
      record_id <- tbl$airtable_id[i]
      for (j in seq_along(atts)) {
        url <- atts[[j]]$url
        if (is.null(url) || is.na(url)) next
        dest_path <- if (mode == "file") {
          rec_dir <- file.path(dir, record_id)
          if (!dir.exists(rec_dir)) dir.create(rec_dir, recursive = TRUE)
          file.path(rec_dir, atts[[j]]$filename %||% "unnamed")
        } else {
          NA_character_
        }
        att_meta[[length(att_meta) + 1L]] <- list(
          row = i, att = j, url = url, dest_path = dest_path
        )
      }
    }

    if (length(att_meta) == 0L) next

    reqs <- lapply(att_meta, function(m) httr2::request(m$url))

    if (do_parallel && length(reqs) > 1L) {
      paths <- vapply(att_meta, `[[`, character(1), "dest_path")
      if (mode == "file") {
        httr2::req_perform_parallel(reqs, paths = paths,
                                    on_error = "continue", max_active = 5L)
        for (m in att_meta) {
          tbl[[field]][[m$row]][[m$att]]$local_path <- m$dest_path
        }
      } else {
        resps <- httr2::req_perform_parallel(reqs, on_error = "continue",
                                             max_active = 5L)
        for (k in seq_along(att_meta)) {
          m <- att_meta[[k]]
          if (!inherits(resps[[k]], "error")) {
            tbl[[field]][[m$row]][[m$att]]$content <-
              httr2::resp_body_raw(resps[[k]])
          }
        }
      }
    } else {
      # Sequential fallback
      for (m in att_meta) {
        if (mode == "blob") {
          resp <- httr2::request(m$url) |> httr2::req_perform()
          tbl[[field]][[m$row]][[m$att]]$content <- httr2::resp_body_raw(resp)
        } else {
          httr2::request(m$url) |> httr2::req_perform(path = m$dest_path)
          tbl[[field]][[m$row]][[m$att]]$local_path <- m$dest_path
        }
      }
    }
  }
  tbl
}

#' Upload attachments from tibble list-columns after record creation
#'
#' For each record that has attachment data, upload files using
#' `at_upload_attachment()`. Handles both "file" mode (local_path in
#' attachment objects) and "blob" mode (content raw vectors).
#'
#' @param base_id Base ID.
#' @param table Table name or ID.
#' @param record_ids Character vector of created/updated record IDs.
#' @param data Original data frame with attachment list-columns.
#' @param att_fields Character vector of attachment field names.
#' @param mode `"file"` or `"blob"`.
#' @param attachment_dir Optional directory to resolve filenames from.
#' @param .token Token.
#' @return Invisible NULL.
#' @noRd
upload_attachments_from_tibble <- function(
  base_id,
  table,
  record_ids,
  data,

  att_fields,
  mode,
  attachment_dir = NULL,
  .token = NULL
) {
  n_uploaded <- 0L
  for (field in att_fields) {
    if (!field %in% names(data)) {
      next
    }
    for (i in seq_along(record_ids)) {
      atts <- data[[field]][[i]]
      if (is.null(atts) || length(atts) == 0L) {
        next
      }
      for (att in atts) {
        file_path <- resolve_attachment_file(att, mode, attachment_dir)
        if (is.null(file_path)) {
          next
        }
        at_upload_attachment(
          base_id = base_id,
          table_id = table,
          record_id = record_ids[i],
          field_id = field,
          file = file_path,
          token = .token
        )
        # Clean up temp file from blob mode
        if (mode == "blob" && grepl("^.*/airtable2_blob_", file_path)) {
          unlink(file_path)
        }
        n_uploaded <- n_uploaded + 1L
      }
    }
  }
  if (n_uploaded > 0L) {
    cli_inform("Uploaded {n_uploaded} attachment{?s}.")
  }
  invisible(NULL)
}

#' Resolve a file path from an attachment object
#'
#' Given an attachment list element and mode, return the local file path
#' to upload. For "blob" mode, writes content to a temp file.
#'
#' @param att Attachment list (with `local_path`, `content`, or `filename`).
#' @param mode `"file"` or `"blob"`.
#' @param attachment_dir Directory to resolve filenames from (file mode).
#' @return File path string, or NULL if no uploadable content.
#' @noRd
resolve_attachment_file <- function(att, mode, attachment_dir = NULL) {
  if (mode == "blob") {
    content <- att$content
    if (is.null(content) || !is.raw(content)) {
      return(NULL)
    }
    filename <- att$filename %||% "unnamed"
    tmp <- tempfile(
      pattern = "airtable2_blob_",
      fileext = paste0(".", tools::file_ext(filename))
    )
    writeBin(content, tmp)
    return(tmp)
  }

  # File mode: try local_path, then attachment_dir/filename

  if (!is.null(att$local_path) && file.exists(att$local_path)) {
    return(att$local_path)
  }
  if (!is.null(attachment_dir) && !is.null(att$filename)) {
    candidate <- file.path(attachment_dir, att$filename)
    if (file.exists(candidate)) return(candidate)
  }
  NULL
}
