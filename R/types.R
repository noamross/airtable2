# Type coercion from Airtable JSON to R types
#
# Uses schema info to determine how to coerce each field.
# When schema is unavailable, falls back to best-guess heuristics.

#' Map Airtable field types to R coercion functions
#' @noRd
airtable_type_map <- function() {
  list(
    singleLineText = as.character,
    multilineText = as.character,
    richText = as.character,
    email = as.character,
    url = as.character,
    phoneNumber = as.character,
    singleSelect = as.character,
    externalSyncSource = as.character,
    aiText = as.character,
    number = as.numeric,
    percent = as.numeric,
    currency = as.numeric,
    duration = as.numeric,
    rating = as.integer,
    count = as.integer,
    autoNumber = as.integer,
    checkbox = as.logical,
    date = coerce_date,
    dateTime = coerce_datetime,
    createdTime = coerce_datetime,
    lastModifiedTime = coerce_datetime,
    # List-column types return identity (already lists from JSON)
    multipleSelects = identity,
    multipleRecordLinks = identity,
    multipleAttachments = identity,
    lookup = identity,
    collaborator = identity,
    barcode = identity,
    button = identity,
    createdBy = identity,
    lastModifiedBy = identity,
    # Computed types depend on result; keep as-is
    formula = identity,
    rollup = identity
  )
}

#' Coerce a value to Date
#' @noRd
coerce_date <- function(x) {
  as.Date(x, format = "%Y-%m-%d")
}

#' Coerce a value to POSIXct
#' @noRd
coerce_datetime <- function(x) {
  as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
}

#' Coerce record fields using schema information
#'
#' Takes a list of raw records (from the API) and a schema (list of field
#' definitions) and returns a tibble with proper R types.
#'
#' @param records List of record objects (each with `id`, `createdTime`,
#'   `fields`).
#' @param schema List of field definitions (each with `name`, `type`). If
#'   `NULL`, no type coercion is performed beyond assembling into a tibble.
#' @return A tibble with `airtable_id`, `airtable_created_time`, and one
#'   column per field.
#' @noRd
records_to_tibble <- function(records, schema = NULL) {
  if (length(records) == 0L) {
    tbl <- tibble::tibble(
      airtable_id = character(),
      airtable_created_time = as.POSIXct(character(), tz = "UTC")
    )
    return(tbl)
  }

  # Extract metadata
  ids <- vapply(records, function(r) r$id %||% NA_character_, character(1))
  created <- vapply(
    records,
    function(r) r$createdTime %||% NA_character_,
    character(1)
  )

  # Collect all field names across records
  all_fields <- unique(unlist(lapply(records, function(r) names(r$fields))))

  # Build schema lookup
  type_lookup <- NULL
  if (!is.null(schema)) {
    type_lookup <- stats::setNames(
      vapply(schema, function(f) f$type %||% "unknown", character(1)),
      vapply(schema, function(f) f$name, character(1))
    )
    # Ensure all schema fields are represented even if absent from records
    all_fields <- union(all_fields, names(type_lookup))
  }

  # Build columns
  type_map <- airtable_type_map()

  cols <- lapply(all_fields, function(field_name) {
    raw_values <- lapply(records, function(r) r$fields[[field_name]])

    field_type <- if (!is.null(type_lookup)) type_lookup[[field_name]]
    coerce_fn <- if (!is.null(field_type)) type_map[[field_type]]

    coerce_column(raw_values, coerce_fn, field_type)
  })
  names(cols) <- all_fields

  # Assemble tibble
  tbl <- tibble::tibble(
    airtable_id = ids,
    airtable_created_time = coerce_datetime(created)
  )
  tbl[all_fields] <- cols

  # Post-process: Airtable omits unchecked checkboxes; fill with FALSE
  if (!is.null(type_lookup)) {
    checkbox_fields <- names(type_lookup)[type_lookup == "checkbox"]
    for (f in intersect(checkbox_fields, names(tbl))) {
      tbl[[f]][is.na(tbl[[f]])] <- FALSE
    }
  }

  tbl
}

#' Coerce a single column of values
#' @param values List of raw values (one per record, may contain NULLs).
#' @param coerce_fn Coercion function, or NULL for best-guess.
#' @param field_type Airtable field type string, or NULL.
#' @noRd
coerce_column <- function(values, coerce_fn = NULL, field_type = NULL) {
  # Replace NULLs with NA
  is_null <- vapply(values, is.null, logical(1))

  # Determine if this is a list-column type
  list_types <- c(
    "multipleSelects",
    "multipleRecordLinks",
    "multipleAttachments",
    "lookup",
    "collaborator",
    "barcode",
    "button",
    "createdBy",
    "lastModifiedBy"
  )

  if (!is.null(field_type) && field_type %in% list_types) {
    # Keep as list-column; replace NULLs with typed NAs
    values[is_null] <- list(NULL)
    return(values)
  }

  # For scalar types, try to simplify
  if (!is.null(coerce_fn) && !identical(coerce_fn, identity)) {
    # Replace NULLs with NA before coercion
    values[is_null] <- list(NA)
    scalar <- tryCatch(
      coerce_fn(unlist(values)),
      error = function(e) NULL
    )
    if (!is.null(scalar) && length(scalar) == length(values)) {
      return(scalar)
    }
  }

  # Fallback: attempt to unlist if all scalars, otherwise keep as list
  scalar_check <- vapply(
    values,
    function(v) {
      is.null(v) || (is.atomic(v) && length(v) == 1L)
    },
    logical(1)
  )

  if (all(scalar_check)) {
    values[is_null] <- list(NA)
    unlist(values)
  } else {
    values[is_null] <- list(NULL)
    values
  }
}

#' Prepare an R data frame for upload to Airtable
#'
#' Converts a tibble/data.frame into the list-of-lists format expected
#' by the Airtable API. Handles `airtable_id` as the record ID if present.
#'
#' @param data A data frame.
#' @param id_col Name of the column containing record IDs (set to `NULL` to
#'   omit IDs, e.g., for creating new records).
#' @return A list of record objects suitable for [at_create_records()] or
#'   [at_update_records()].
#' @noRd
tibble_to_records <- function(data, id_col = "airtable_id") {
  # Identify which columns are fields vs metadata
  meta_cols <- c("airtable_id", "airtable_created_time")
  field_cols <- setdiff(names(data), meta_cols)

  has_id <- !is.null(id_col) && id_col %in% names(data)

  lapply(seq_len(nrow(data)), function(i) {
    fields <- lapply(field_cols, function(col) {
      val <- data[[col]][[i]]
      # Convert NA to NULL for JSON (Airtable ignores null fields)
      if (is.atomic(val) && length(val) == 1L && is.na(val)) {
        return(NULL)
      }
      val
    })
    names(fields) <- field_cols
    fields <- compact(fields)

    rec <- list(fields = fields)
    if (has_id) {
      id_val <- data[[id_col]][[i]]
      if (!is.na(id_val)) rec$id <- id_val
    }
    rec
  })
}
