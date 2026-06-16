# Type coercion from Airtable JSON to R types
#
# Uses schema info to determine how to coerce each field.
# When schema is unavailable, falls back to best-guess heuristics.
#
# --- S3 classes for list-column Airtable types ---
#
# Each complex Airtable field type becomes a lightweight list-subclass so that:
#   (a) all data is preserved as a list-column
#   (b) pillar/tibble print shows a compact one-line summary per value
#   (c) type_sum() shows the Airtable type abbreviation in column headers
#
# Coercion to plain character/vector is user-initiated via air_flatten_*().
# S3 methods are registered lazily in .onLoad via vctrs::s3_register() so
# pillar and vctrs can remain in Suggests / Imports respectively.

# --------------------------------------------------------------------------- #
#  air_multiselect - list of character vectors
# --------------------------------------------------------------------------- #

#' @keywords internal
new_air_multiselect <- function(x = list()) {
  stopifnot(is.list(x))
  structure(x, class = c("air_multiselect", "list"))
}

#' @export
format.air_multiselect <- function(x, ...) {
  vapply(
    x,
    function(v) {
      if (is.null(v) || length(v) == 0L) {
        NA_character_
      } else {
        paste(v, collapse = ", ")
      }
    },
    character(1)
  )
}

#' @export
print.air_multiselect <- function(x, ...) {
  cat("<air_multiselect[", length(x), "]>\n", sep = "")
  invisible(x)
}

# pillar methods registered via s3_register in zzz.R
pillar_shaft_air_multiselect <- function(x, ...) {
  pillar::new_pillar_shaft_simple(format(x), align = "left", min_width = 8L)
}

type_sum_air_multiselect <- function(x, ...) "sel[]"

# --------------------------------------------------------------------------- #
#  air_links - list of record-ID character vectors
# --------------------------------------------------------------------------- #

#' @keywords internal
new_air_links <- function(x = list()) {
  stopifnot(is.list(x))
  structure(x, class = c("air_links", "list"))
}

#' @export
format.air_links <- function(x, ...) {
  vapply(
    x,
    function(v) {
      if (is.null(v) || length(v) == 0L) {
        NA_character_
      } else if (length(v) == 1L) {
        v[[1L]]
      } else {
        sprintf("[%d records]", length(v))
      }
    },
    character(1)
  )
}

#' @export
print.air_links <- function(x, ...) {
  cat("<air_links[", length(x), "]>\n", sep = "")
  invisible(x)
}

pillar_shaft_air_links <- function(x, ...) {
  pillar::new_pillar_shaft_simple(format(x), align = "left", min_width = 10L)
}

type_sum_air_links <- function(x, ...) "lnk[]"

# --------------------------------------------------------------------------- #
#  air_attachments - list of lists of attachment objects
# --------------------------------------------------------------------------- #

#' @keywords internal
new_air_attachments <- function(x = list()) {
  stopifnot(is.list(x))
  structure(x, class = c("air_attachments", "list"))
}

#' @export
format.air_attachments <- function(x, ...) {
  vapply(
    x,
    function(v) {
      if (is.null(v) || length(v) == 0L) {
        return(NA_character_)
      }
      # v is a list of attachment objects (each has $filename, $url, etc.)
      fnames <- vapply(v, function(a) a$filename %||% "?", character(1))
      n <- length(fnames)
      if (n == 1L) {
        fnames[[1L]]
      } else {
        sprintf("%s +%d", fnames[[1L]], n - 1L)
      }
    },
    character(1)
  )
}

#' @export
print.air_attachments <- function(x, ...) {
  cat("<air_attachments[", length(x), "]>\n", sep = "")
  invisible(x)
}

pillar_shaft_air_attachments <- function(x, ...) {
  pillar::new_pillar_shaft_simple(format(x), align = "left", min_width = 12L)
}

type_sum_air_attachments <- function(x, ...) "att[]"

# --------------------------------------------------------------------------- #
#  air_collaborator - single collaborator (list with id/email/name)
# --------------------------------------------------------------------------- #

#' @keywords internal
new_air_collaborator <- function(x = list()) {
  stopifnot(is.list(x))
  structure(x, class = c("air_collaborator", "list"))
}

#' @export
format.air_collaborator <- function(x, ...) {
  vapply(
    x,
    function(v) {
      if (is.null(v)) {
        return(NA_character_)
      }
      name <- v$name %||% ""
      email <- v$email %||% ""
      if (nzchar(name) && nzchar(email)) {
        sprintf("%s <%s>", name, email)
      } else if (nzchar(name)) {
        name
      } else if (nzchar(email)) {
        email
      } else {
        v$id %||% NA_character_
      }
    },
    character(1)
  )
}

#' @export
print.air_collaborator <- function(x, ...) {
  cat("<air_collaborator[", length(x), "]>\n", sep = "")
  invisible(x)
}

pillar_shaft_air_collaborator <- function(x, ...) {
  pillar::new_pillar_shaft_simple(format(x), align = "left", min_width = 12L)
}

type_sum_air_collaborator <- function(x, ...) "collab"

# --------------------------------------------------------------------------- #
#  air_collaborators - list of lists of collaborator objects
# --------------------------------------------------------------------------- #

#' @keywords internal
new_air_collaborators <- function(x = list()) {
  stopifnot(is.list(x))
  structure(x, class = c("air_collaborators", "list"))
}

#' @export
format.air_collaborators <- function(x, ...) {
  vapply(
    x,
    function(v) {
      if (is.null(v) || length(v) == 0L) {
        return(NA_character_)
      }
      # v is a list of collaborator objects
      summaries <- vapply(
        v,
        function(c) c$name %||% c$email %||% c$id %||% "?",
        character(1)
      )
      n <- length(summaries)
      if (n == 1L) {
        summaries[[1L]]
      } else {
        sprintf("%s +%d", summaries[[1L]], n - 1L)
      }
    },
    character(1)
  )
}

pillar_shaft_air_collaborators <- function(x, ...) {
  pillar::new_pillar_shaft_simple(format(x), align = "left", min_width = 12L)
}

type_sum_air_collaborators <- function(x, ...) "collabs"

# --------------------------------------------------------------------------- #
#  air_barcode - list with $text and $type
# --------------------------------------------------------------------------- #

#' @keywords internal
new_air_barcode <- function(x = list()) {
  stopifnot(is.list(x))
  structure(x, class = c("air_barcode", "list"))
}

#' @export
format.air_barcode <- function(x, ...) {
  vapply(
    x,
    function(v) {
      if (is.null(v)) {
        return(NA_character_)
      }
      text <- v$text %||% ""
      type <- v$type %||% ""
      if (nzchar(type)) sprintf("%s (%s)", text, type) else text
    },
    character(1)
  )
}

#' @export
print.air_barcode <- function(x, ...) {
  cat("<air_barcode[", length(x), "]>\n", sep = "")
  invisible(x)
}

pillar_shaft_air_barcode <- function(x, ...) {
  pillar::new_pillar_shaft_simple(format(x), align = "left", min_width = 10L)
}

type_sum_air_barcode <- function(x, ...) "barcode"

# --------------------------------------------------------------------------- #
#  Constructor dispatch - wrap raw list-column in the right air_* class
# --------------------------------------------------------------------------- #

#' Wrap a raw list-column in the appropriate air_* class
#'
#' @param values List (one element per record). May contain NULLs.
#' @param field_type Airtable field type string.
#' @return A classed list or plain list if no matching class.
#' @noRd
wrap_list_column <- function(values, field_type) {
  switch(
    field_type,
    multipleSelects = new_air_multiselect(values),
    multipleCollaborators = new_air_collaborators(values),
    multipleRecordLinks = new_air_links(values),
    multipleAttachments = new_air_attachments(values),
    collaborator = new_air_collaborator(values),
    createdBy = new_air_collaborator(values),
    lastModifiedBy = new_air_collaborator(values),
    barcode = new_air_barcode(values),
    # lookup, button, formula, rollup - return plain list
    values
  )
}

# --------------------------------------------------------------------------- #
#  Computed / read-only field helpers
# --------------------------------------------------------------------------- #

#' Field types that are computed/read-only and cannot be written
#' @noRd
computed_field_types <- function() {
  c(
    "formula",
    "rollup",
    "count",
    "lookup",
    "autoNumber",
    "createdTime",
    "lastModifiedTime",
    "createdBy",
    "lastModifiedBy",
    "externalSyncSource",
    "aiText",
    "button"
  )
}

#' Identify computed field names from a schema
#'
#' Given a list of field definitions (from [at_get_schema()]), returns the
#' names of fields that are computed/read-only and should not be included in
#' write or upsert operations.
#'
#' @param schema List of field definitions (each with `name` and `type`).
#' @return Character vector of computed field names.
#' @noRd
computed_fields_from_schema <- function(schema) {
  if (is.null(schema)) {
    return(character())
  }
  computed_types <- computed_field_types()
  vapply(
    Filter(function(f) (f$type %||% "") %in% computed_types, schema),
    function(f) f$name,
    character(1)
  )
}

#' Get computed field names for a table (internal helper)
#'
#' Fetches schema and returns names of computed/read-only fields.
#' Used by [air_write()], [air_upsert()], and [air_sync()].
#'
#' @param base_id Base ID.
#' @param table Table name or ID.
#' @param .token Token.
#' @return Character vector of computed field names.
#' @noRd
get_computed_fields <- function(base_id, table, .token = NULL) {
  tbl_schema <- get_table_schema(base_id, table, token = .token)
  if (is.null(tbl_schema)) {
    return(character())
  }
  computed_fields_from_schema(tbl_schema$fields)
}

#' Get attachment field names for a table (internal helper)
#'
#' Fetches schema and returns names of `multipleAttachments` fields.
#' Used to exclude attachment columns from write payloads and hashing.
#'
#' @param base_id Base ID.
#' @param table Table name or ID.
#' @param .token Token.
#' @return Character vector of attachment field names.
#' @noRd
get_attachment_fields <- function(base_id, table, .token = NULL) {
  tbl_schema <- get_table_schema(base_id, table, token = .token)
  if (is.null(tbl_schema)) {
    return(character())
  }
  vapply(
    Filter(
      function(f) (f$type %||% "") == "multipleAttachments",
      tbl_schema$fields
    ),
    \(f) f$name,
    character(1)
  )
}

#' Extract a named type vector from a full table schema object
#'
#' @param schema Full schema object as returned by `get_table_schema()`,
#'   with a `$fields` list.
#' @return Named character vector: `c(field_name = "airtable_type", ...)`.
#' @noRd
field_types_from_schema <- function(schema) {
  if (is.null(schema) || length(schema$fields) == 0L) return(character())
  setNames(
    vapply(schema$fields, function(f) f$type %||% "unknown", character(1)),
    vapply(schema$fields, function(f) f$name,                character(1))
  )
}

#' Extract attachment field names from a full table schema object
#'
#' @param schema Full schema object as returned by `get_table_schema()`.
#' @return Character vector of `multipleAttachments` field names.
#' @noRd
attachment_fields_from_schema <- function(schema) {
  if (is.null(schema) || length(schema$fields) == 0L) return(character())
  vapply(
    Filter(function(f) (f$type %||% "") == "multipleAttachments", schema$fields),
    function(f) f$name,
    character(1)
  )
}

# --------------------------------------------------------------------------- #
#  Type map and coercion helpers
# --------------------------------------------------------------------------- #

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
    # List-column types: identity here; wrap_list_column handles class wrapping
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

# --------------------------------------------------------------------------- #
#  records_to_tibble - main entry point
# --------------------------------------------------------------------------- #

#' Coerce record fields using schema information
#'
#' Takes a list of raw records (from the API) and a schema (list of field
#' definitions) and returns a tibble with proper R types.
#'
#' List-column types are wrapped in `air_*` S3 classes for rich pillar display.
#' All columns receive `label` (= field name) and `comment` (= Airtable type)
#' attributes so they appear nicely in the RStudio/Positron data viewer.
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
      airtable_id = structure(
        character(),
        label = "Record ID",
        comment = "recordId"
      ),
      airtable_created_time = structure(
        as.POSIXct(character(), tz = "UTC"),
        label = "Created Time",
        comment = "createdTime"
      )
    )
    return(tbl)
  }

  ids <- vapply(records, function(r) r$id %||% NA_character_, character(1))
  created <- vapply(
    records,
    function(r) r$createdTime %||% NA_character_,
    character(1)
  )

  all_fields <- unique(unlist(lapply(records, function(r) names(r$fields))))

  # Build schema lookups
  type_lookup <- NULL
  if (!is.null(schema)) {
    type_lookup <- stats::setNames(
      vapply(schema, function(f) f$type %||% "unknown", character(1)),
      vapply(schema, function(f) f$name, character(1))
    )
    all_fields <- union(all_fields, names(type_lookup))
  }

  type_map <- airtable_type_map()
  list_types <- list_column_types()

  cols <- lapply(all_fields, function(field_name) {
    raw_values <- lapply(records, function(r) r$fields[[field_name]])

    field_type <- if (
      !is.null(type_lookup) && field_name %in% names(type_lookup)
    ) {
      type_lookup[[field_name]]
    } else {
      NULL
    }
    coerce_fn <- if (!is.null(field_type)) type_map[[field_type]]

    col <- coerce_column(raw_values, coerce_fn, field_type)

    # Wrap list-column types in air_* S3 classes for pillar display
    if (!is.null(field_type) && field_type %in% list_types) {
      col <- wrap_list_column(col, field_type)
    }

    # Attach label (field description from schema, or field name) and comment (Airtable type) for data viewer
    field_label <- if (!is.null(schema)) {
      field_def <- Find(function(f) f$name == field_name, schema)
      if (
        !is.null(field_def) &&
          !is.null(field_def$description) &&
          nzchar(field_def$description)
      ) {
        field_def$description
      } else {
        field_name
      }
    } else {
      field_name
    }
    attr(col, "label") <- field_label
    attr(col, "comment") <- field_type %||% ""

    col
  })
  names(cols) <- all_fields

  tbl <- tibble::tibble(
    airtable_id = structure(ids, label = "Record ID", comment = "recordId"),
    airtable_created_time = structure(
      coerce_datetime(created),
      label = "Created Time",
      comment = "createdTime"
    )
  )
  tbl[all_fields] <- cols

  # Airtable omits unchecked checkboxes; fill with FALSE
  if (!is.null(type_lookup)) {
    checkbox_fields <- names(type_lookup)[type_lookup == "checkbox"]
    for (f in intersect(checkbox_fields, names(tbl))) {
      tbl[[f]][is.na(tbl[[f]])] <- FALSE
    }
  }

  tbl
}

#' Airtable field types that become list-columns
#' @noRd
list_column_types <- function() {
  c(
    "multipleSelects",
    "multipleCollaborators",
    "multipleRecordLinks",
    "multipleAttachments",
    "lookup",
    "collaborator",
    "barcode",
    "button",
    "createdBy",
    "lastModifiedBy"
  )
}

#' Coerce a single column of values
#' @param values List of raw values (one per record, may contain NULLs).
#' @param coerce_fn Coercion function, or NULL for best-guess.
#' @param field_type Airtable field type string, or NULL.
#' @noRd
coerce_column <- function(values, coerce_fn = NULL, field_type = NULL) {
  is_null <- vapply(values, is.null, logical(1))

  if (!is.null(field_type) && field_type %in% list_column_types()) {
    values[is_null] <- list(NULL)
    return(values)
  }

  if (!is.null(coerce_fn) && !identical(coerce_fn, identity)) {
    values[is_null] <- list(NA)
    scalar <- tryCatch(coerce_fn(unlist(values)), error = function(e) NULL)
    if (!is.null(scalar) && length(scalar) == length(values)) {
      return(scalar)
    }
  }

  scalar_check <- vapply(
    values,
    function(v) is.null(v) || (is.atomic(v) && length(v) == 1L),
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

# --------------------------------------------------------------------------- #
#  tibble_to_records - convert R data frame to API payload
# --------------------------------------------------------------------------- #

#' Prepare an R data frame for upload to Airtable
#'
#' Converts a tibble/data.frame into the list-of-lists format expected
#' by the Airtable API. Handles `airtable_id` as the record ID if present.
#' Automatically excludes computed/read-only columns.
#'
#' @param data A data frame.
#' @param id_col Name of the column containing record IDs (set to `NULL` to
#'   omit IDs, e.g., for creating new records).
#' @param exclude Character vector of column names to exclude from the
#'   `fields` payload (e.g., computed fields). These are silently dropped.
#' @param field_types Optional named character vector mapping field name to
#'   Airtable field type (from the table schema). When supplied, flat character
#'   values are auto-expanded to the structure Airtable expects (e.g. a
#'   `"A; B"` string becomes a JSON array for a `multipleSelects` field). When
#'   `NULL` (default), no expansion is performed (fully back-compatible).
#' @return A list of record objects suitable for [at_create_records()] or
#'   [at_update_records()].
#' @noRd
tibble_to_records <- function(
  data,
  id_col = "airtable_id",
  exclude = character(),
  field_types = NULL
) {
  meta_cols <- c("airtable_id", "airtable_created_time")
  field_cols <- setdiff(names(data), c(meta_cols, exclude))

  has_id <- !is.null(id_col) && id_col %in% names(data)

  lapply(seq_len(nrow(data)), function(i) {
    fields <- lapply(field_cols, function(col) {
      val <- data[[col]][[i]]
      if (is.atomic(val) && length(val) == 1L && is.na(val)) {
        return(NULL)
      }
      # Auto-expand flat values to the API's expected shape, when we know
      # the field type from the schema.
      if (!is.null(field_types) && col %in% names(field_types)) {
        val <- expand_upload_value(val, field_types[[col]])
      }
      # Strip air_* classes - send plain lists/vectors to the API
      unclass_air(val)
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

#' Expand a flat value to the structure Airtable expects, by field type
#'
#' Used on the WRITE path so users can supply flat character columns that are
#' auto-expanded to the JSON shape the API requires, inferred from the table
#' schema. Conservative: only transforms plain length-1 character scalars;
#' lists, objects, and already-classed `air_*` values are returned untouched
#' (left for `unclass_air()` / normal serialization).
#'
#' @param val A single cell value.
#' @param field_type Airtable field type string (or `NULL`).
#' @param sep Delimiter for splitting multi-value strings.
#' @return The (possibly expanded) value.
#' @noRd
expand_upload_value <- function(val, field_type, sep = NULL) {
  if (is.null(field_type)) {
    return(val)
  }
  # Only act on plain character scalars; leave lists / classed columns alone.
  is_plain_scalar <- is.character(val) &&
    length(val) == 1L &&
    is.null(attr(val, "class"))
  if (!is_plain_scalar || is.na(val)) {
    return(val)
  }

  split_vals <- function(x) {
    air_expand_multiselect(x, sep = sep)[[1]]
  }

  switch(
    field_type,
    multipleSelects = split_vals(val),
    multipleRecordLinks = split_vals(val),
    singleCollaborator = collaborator_obj(val),
    collaborator = collaborator_obj(val),
    multipleCollaborators = lapply(split_vals(val), collaborator_obj),
    val
  )
}

#' Wrap a flat collaborator string as the object Airtable expects
#'
#' An `usr...`-looking id becomes `list(id = ...)`; anything else is treated as
#' an email and becomes `list(email = ...)`.
#' @noRd
collaborator_obj <- function(x) {
  if (grepl("^usr[A-Za-z0-9]+$", x)) {
    list(id = x)
  } else {
    list(email = x)
  }
}

#' Strip air_* class attributes before sending to the API
#'
#' The API expects plain lists/vectors, not classed objects.
#' @noRd
unclass_air <- function(x) {
  air_classes <- c(
    "air_multiselect",
    "air_links",
    "air_attachments",
    "air_collaborator",
    "air_barcode"
  )
  if (inherits(x, air_classes)) {
    class(x) <- setdiff(class(x), air_classes)
  }
  x
}

#' Normalize a data frame to canonical form before row hashing
#'
#' Applies type-level normalizations so that values that are semantically
#' identical (but differ in R representation vs Airtable's wire format) hash
#' to the same string.  Normalizations applied:
#'
#' - `air_*` S3 classes stripped (so list dispatch works correctly).
#' - List-columns flattened to SOH-joined character strings (preserves order).
#' - `Date` → `"YYYY-MM-DD"`.
#' - `POSIXct` → `"YYYY-MM-DDTHH:MM:SS.000Z"` UTC.
#' - `integer` → `double` (prevents type-divergence in `as.matrix`).
#' - `logical FALSE` → `NA` (Airtable omits unchecked checkboxes).
#' - Trailing whitespace (including `\n`) stripped from character strings.
#' - `""` → `NA` for character (Airtable omits empty text fields).
#' - Character multipleSelects/multipleRecordLinks/multipleCollaborators
#'   expanded via `air_expand_multiselect()` then NUL-joined.
#'
#' @param df Data frame to normalize.
#' @param field_types Named character vector from `field_types_from_schema()`.
#' @return Normalized data frame (same structure, types may differ).
#' @noRd
normalize_for_hash <- function(df, field_types = character()) {
  list_field_types <- c("multipleSelects", "multipleRecordLinks",
                        "multipleCollaborators")

  for (col in names(df)) {
    x  <- df[[col]]
    ft <- if (col %in% names(field_types)) field_types[[col]] else ""

    # Strip air_* S3 classes before type dispatch, preserving Date/POSIXct etc.
    x <- unclass_air(x)

    if (is.list(x)) {
      x <- vapply(x, function(v) {
        if (is.null(v) || length(v) == 0L) return(NA_character_)
        paste(as.character(unlist(v)), collapse = "\x01")
      }, character(1))

    } else {
      if (inherits(x, "Date")) {
        x <- format(x, "%Y-%m-%d")
      } else if (inherits(x, c("POSIXct", "POSIXt"))) {
        x <- format(x, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
      }

      if (is.integer(x))  x <- as.numeric(x)
      if (is.logical(x))  x[!is.na(x) & !x] <- NA

      if (is.character(x)) {
        x <- trimws(x, which = "right")
        x[!is.na(x) & !nzchar(x)] <- NA_character_
      }

      # Schema-aware: expand character multipleSelects to NUL-joined form
      if (ft %in% list_field_types && is.character(x)) {
        expanded <- air_expand_multiselect(x)
        x <- vapply(expanded, function(v) {
          if (is.null(v) || length(v) == 0L) return(NA_character_)
          paste(as.character(v), collapse = "\x01")
        }, character(1))
      }
    }

    df[[col]] <- x
  }
  df
}
