# Low-level record CRUD wrappers
# These map directly to Airtable API endpoints. Return parsed JSON (lists).

#' List records from a table
#'
#' @param base_id Base ID (e.g., `"appXXXXXX"`).
#' @param table_id Table name or ID.
#' @param fields Character vector of field names to return.
#' @param formula Airtable formula string for filtering.
#' @param sort A named character vector: names are field names, values are
#'   `"asc"` or `"desc"`.
#' @param view View name or ID to filter by.
#' @param max_records Maximum total records to return.
#' @param page_size Records per page (max 100).
#' @param cell_format Either `"json"` (default) or `"string"`.
#' @param time_zone Time zone for date formatting (when `cell_format = "string"`).
#' @param user_locale Locale for date formatting.
#' @param return_fields_by_id If `TRUE`, use field IDs as keys instead of names.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @param progress Logical or `NULL`. If `TRUE`, shows a cli progress bar for
#'   batch operations. If `NULL` (default), uses option `airtable2.progress.bar`
#'   or env var `AIRTABLE2_PROGRESS_BAR` (both default to `FALSE`).
#' @return A list of record objects (each with `id`, `createdTime`, `fields`).
#' @examples
#' \dontrun{
#' # List all records from a table
#' records <- at_list_records("appXXXXXXXXXXXXXX", "Contacts")
#'
#' # Filter records with a formula
#' records <- at_list_records(
#'   "appXXXXXXXXXXXXXX", "Contacts",
#'   formula = "{Active} = TRUE()",
#'   fields  = c("Name", "Email")
#' )
#' }
#' @export
at_list_records <- function(base_id,
                            table_id,
                            fields = NULL,
                            formula = NULL,
                            sort = NULL,
                            view = NULL,
                            max_records = Inf,
                            page_size = 100L,
                            cell_format = NULL,
                            time_zone = NULL,
                            user_locale = NULL,
                            return_fields_by_id = FALSE,
                            token = NULL,
                            progress = NULL) {
  check_string(base_id)
  check_string(table_id)

  req <- air_req(paste0(base_id, "/", table_id), token = token)

  # Add query parameters
  if (!is.null(fields)) {
    for (f in fields) {
      req <- req |> httr2::req_url_query(`fields[]` = f, .multi = "explode")
    }
  }
  if (!is.null(formula)) {
    req <- req |> httr2::req_url_query(filterByFormula = formula)
  }
  if (!is.null(sort)) {
    for (i in seq_along(sort)) {
      req <- req |>
        httr2::req_url_query(
          !!paste0("sort[", i - 1, "][field]") := names(sort)[[i]],
          !!paste0("sort[", i - 1, "][direction]") := unname(sort[[i]])
        )
    }
  }
  if (!is.null(view)) {
    req <- req |> httr2::req_url_query(view = view)
  }
  if (!is.null(cell_format)) {
    req <- req |> httr2::req_url_query(cellFormat = cell_format)
  }
  if (!is.null(time_zone)) {
    req <- req |> httr2::req_url_query(timeZone = time_zone)
  }
  if (!is.null(user_locale)) {
    req <- req |> httr2::req_url_query(userLocale = user_locale)
  }

  if (isTRUE(return_fields_by_id)) {
    req <- req |> httr2::req_url_query(returnFieldsByFieldId = "true")
  }

  air_paginate(req, page_size = page_size, max_records = max_records, progress = progress)
}

#' Get a single record
#'
#' @inheritParams at_list_records
#' @param record_id Record ID (e.g., `"recXXXXXX"`).
#' @return A single record object (list with `id`, `createdTime`, `fields`).
#' @examples
#' \dontrun{
#' rec <- at_get_record(
#'   "appXXXXXXXXXXXXXX",
#'   "Contacts",
#'   "recXXXXXXXXXXXXXX"
#' )
#' rec$fields$Name
#' }
#' @export
at_get_record <- function(base_id, table_id, record_id, token = NULL) {
  check_string(base_id)
  check_string(table_id)
  check_string(record_id)

  req <- air_req(paste0(base_id, "/", table_id, "/", record_id), token = token)
  air_perform(req)
}

#' Create records in a table
#'
#' Creates up to 10 records per API call. If more than 10 records are provided,
#' they are automatically batched.
#'
#' @inheritParams at_list_records
#' @param records A list of record objects. Each should be a list with a
#'   `fields` element (a named list of field values).
#' @param typecast If `TRUE`, Airtable will attempt to cast values to the
#'   correct type.
#' @return A list of created record objects (with assigned IDs).
#' @examples
#' \dontrun{
#' records <- list(
#'   list(fields = list(Name = "Alice", Age = 30)),
#'   list(fields = list(Name = "Bob",   Age = 25))
#' )
#' created <- at_create_records("appXXXXXXXXXXXXXX", "Contacts", records)
#' vapply(created, function(r) r$id, character(1))
#' }
#' @export
at_create_records <- function(base_id, table_id, records,
                              typecast = FALSE, token = NULL,
                              progress = NULL) {
  check_string(base_id)
  check_string(table_id)
  check_bool(typecast)

  progress <- resolve_progress(progress)
  batches <- chunk(records, 10L)
  results <- list()

  pb <- NULL
  if (progress && length(batches) > 1) {
    pb <- cli::cli_progress_bar(
      name  = paste("Creating", length(records), "records"),
      total = length(batches),
      clear = FALSE
    )
  }

  batch_num <- 0L
  for (batch in batches) {
    batch_num <- batch_num + 1L
    body <- compact(list(
      records = unname(batch),
      typecast = if (typecast) TRUE
    ))

    req <- air_req(paste0(base_id, "/", table_id), token = token) |>
      httr2::req_method("POST") |>
      httr2::req_body_json(body)

    resp <- air_perform(req)
    results <- c(results, resp$records)

    if (!is.null(pb)) {
      cli::cli_progress_update(
        id     = pb,
        set    = batch_num,
        status = paste0("batch ", batch_num, "/", length(batches))
      )
    }
  }

  if (!is.null(pb)) cli::cli_progress_done(id = pb)

  results
}

#' Update multiple records
#'
#' Updates records using PATCH (partial) or PUT (destructive). Handles
#' auto-batching in groups of 10. Also supports upsert via the
#' `upsert_fields` argument.
#'
#' @inheritParams at_list_records
#' @param records A list of record objects. Each should be a list with `id` and
#'   `fields` elements. For upsert, `id` can be omitted.
#' @param method Either `"PATCH"` (partial update) or `"PUT"` (destructive).
#' @param typecast If `TRUE`, Airtable will attempt to cast values.
#' @param upsert_fields Character vector (1-3 fields) to merge on for upsert.
#'   If `NULL`, performs a standard update.
#' @return A list with `records`, and (for upserts) `createdRecords` and
#'   `updatedRecords` character vectors.
#' @examples
#' \dontrun{
#' # Patch an existing record
#' at_update_records(
#'   "appXXXXXXXXXXXXXX", "Contacts",
#'   records = list(list(id = "recXXXXXXXXXXXXXX", fields = list(Age = 31)))
#' )
#'
#' # Upsert by Name field
#' at_update_records(
#'   "appXXXXXXXXXXXXXX", "Contacts",
#'   records = list(list(fields = list(Name = "Alice", Age = 31))),
#'   upsert_fields = "Name"
#' )
#' }
#' @export
at_update_records <- function(base_id, table_id, records,
                              method = c("PATCH", "PUT"),
                              typecast = FALSE,
                              upsert_fields = NULL,
                              token = NULL,
                              progress = NULL) {
  check_string(base_id)
  check_string(table_id)
  method <- match.arg(method)
  check_bool(typecast)

  progress <- resolve_progress(progress)

  batches <- chunk(records, 10L)
  all_records <- list()
  all_created <- character()
  all_updated <- character()

  # Set up progress bar if requested
  pb <- NULL
  if (progress && length(batches) > 1) {
    pb <- cli::cli_progress_bar(
      name  = paste("Upserting", length(records), "records"),
      total = length(batches),
      clear = FALSE
    )
  }

  batch_num <- 0L
  for (batch in batches) {
    batch_num <- batch_num + 1L
    body <- compact(list(
      records = unname(batch),
      typecast = if (typecast) TRUE,
      performUpsert = if (!is.null(upsert_fields)) {
        list(fieldsToMergeOn = as.list(upsert_fields))
      }
    ))

    req <- air_req(paste0(base_id, "/", table_id), token = token) |>
      httr2::req_method(method) |>
      httr2::req_body_json(body)

    resp <- air_perform(req)
    all_records <- c(all_records, resp$records)
    if (!is.null(resp$createdRecords)) {
      all_created <- c(all_created, unlist(resp$createdRecords))
    }
    if (!is.null(resp$updatedRecords)) {
      all_updated <- c(all_updated, unlist(resp$updatedRecords))
    }

    if (!is.null(pb)) {
      cli::cli_progress_update(
        id     = pb,
        set    = batch_num,
        status = paste0("batch ", batch_num, "/", length(batches))
      )
    }
  }

  if (!is.null(pb)) cli::cli_progress_done(id = pb)

  compact(list(
    records = all_records,
    createdRecords = if (length(all_created)) all_created,
    updatedRecords = if (length(all_updated)) all_updated
  ))
}

#' Delete records
#'
#' Deletes up to 10 records per API call. Automatically batched.
#'
#' @inheritParams at_list_records
#' @param record_ids Character vector of record IDs to delete.
#' @param progress Logical or `NULL`. If `TRUE`, shows a cli progress bar for
#'   batch operations. If `NULL` (default), uses option `airtable2.progress.bar`
#'   or env var `AIRTABLE2_PROGRESS_BAR`.
#' @return A list of delete confirmation objects (each with `id` and
#'   `deleted = TRUE`).
#' @examples
#' \dontrun{
#' at_delete_records(
#'   "appXXXXXXXXXXXXXX",
#'   "Contacts",
#'   c("recXXXXXXXXXXXXXX", "recYYYYYYYYYYYYYY")
#' )
#' }
#' @export
at_delete_records <- function(base_id, table_id, record_ids, token = NULL,
                              progress = NULL) {
  check_string(base_id)
  check_string(table_id)

  progress <- resolve_progress(progress)
  batches <- chunk(record_ids, 10L)
  results <- list()

  # Set up progress bar if requested
  pb <- NULL
  if (progress && length(batches) > 1) {
    pb <- cli::cli_progress_bar(
      "Deleting records",
      total = length(batches),
      clear = TRUE
    )
  }

  for (i in seq_along(batches)) {
    batch <- batches[[i]]
    req <- air_req(paste0(base_id, "/", table_id), token = token) |>
      httr2::req_method("DELETE") |>
      httr2::req_url_query(`records[]` = batch, .multi = "explode")

    resp <- air_perform(req)
    results <- c(results, resp$records)
    
    # Update progress bar
    if (!is.null(pb)) {
      cli::cli_progress_update(id = pb, set = i)
    }
  }

  if (!is.null(pb)) {
    cli::cli_progress_done(id = pb)
  }

  results
}
