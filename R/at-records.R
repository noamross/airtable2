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
#' @return A list of record objects (each with `id`, `createdTime`, `fields`).
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
                            token = NULL) {
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

  air_paginate(req, page_size = page_size, max_records = max_records)
}

#' Get a single record
#'
#' @inheritParams at_list_records
#' @param record_id Record ID (e.g., `"recXXXXXX"`).
#' @return A single record object (list with `id`, `createdTime`, `fields`).
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
#' @export
at_create_records <- function(base_id, table_id, records,
                              typecast = FALSE, token = NULL) {
  check_string(base_id)
  check_string(table_id)
  check_bool(typecast)

  batches <- chunk(records, 10L)
  results <- list()

  for (batch in batches) {
    body <- compact(list(
      records = unname(batch),
      typecast = if (typecast) TRUE
    ))

    req <- air_req(paste0(base_id, "/", table_id), token = token) |>
      httr2::req_method("POST") |>
      httr2::req_body_json(body)

    resp <- air_perform(req)
    results <- c(results, resp$records)
  }

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
#' @export
at_update_records <- function(base_id, table_id, records,
                              method = c("PATCH", "PUT"),
                              typecast = FALSE,
                              upsert_fields = NULL,
                              token = NULL) {
  check_string(base_id)
  check_string(table_id)
  method <- match.arg(method)
  check_bool(typecast)

  batches <- chunk(records, 10L)
  all_records <- list()
  all_created <- character()
  all_updated <- character()

  for (batch in batches) {
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
  }

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
#' @return A list of delete confirmation objects (each with `id` and
#'   `deleted = TRUE`).
#' @export
at_delete_records <- function(base_id, table_id, record_ids, token = NULL) {
  check_string(base_id)
  check_string(table_id)

  batches <- chunk(record_ids, 10L)
  results <- list()

  for (batch in batches) {
    req <- air_req(paste0(base_id, "/", table_id), token = token) |>
      httr2::req_method("DELETE") |>
      httr2::req_url_query(`records[]` = batch, .multi = "explode")

    resp <- air_perform(req)
    results <- c(results, resp$records)
  }

  results
}
