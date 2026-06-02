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

  # Download content
  if (dest == "blob") {
    tbl$blob <- lapply(tbl$url, function(u) {
      if (is.na(u)) {
        return(raw())
      }
      resp <- httr2::request(u) |> httr2::req_perform()
      httr2::resp_body_raw(resp)
    })
  } else {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
    }
    tbl$local_path <- vapply(
      seq_len(nrow(tbl)),
      function(i) {
        if (is.na(tbl$url[i])) {
          return(NA_character_)
        }
        dest_path <- file.path(dir, tbl$filename[i])
        resp <- httr2::request(tbl$url[i]) |>
          httr2::req_perform(path = dest_path)
        dest_path
      },
      character(1)
    )
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
air_write_attachments <- function(base_id, table, field, data, .token = NULL) {
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
