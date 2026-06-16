#' Write (create) records in an Airtable table
#'
#' Converts a data frame into records and creates them in the specified table.
#' Automatically batches in groups of 10. Computed fields (formulas, rollups,
#' autoNumber, createdTime, lastModifiedTime, etc.) and attachment fields are
#' automatically excluded from the upload payload. When `attachments` is
#' `"file"` or `"blob"`, attachment content is uploaded separately after record
#' creation using the dedicated upload endpoint.
#'
#' @param data A data frame of records to create. Should not contain
#'   `airtable_id` (those would be ignored). Computed field columns and
#'   attachment field columns are silently dropped from the record payload.
#' @inheritParams air_read
#' @param typecast If `TRUE` (default), Airtable will attempt to coerce values
#'   to match field types.
#' @param add_fields What to do when `data` contains columns not in the table:
#'   - `"error"` (default): error if unknown columns exist.
#'   - `"warn"`: warn and drop unknown columns.
#'   - `"yes"`: create missing fields before writing. Field types are inferred
#'     from the column class: `numeric` → `number`, `logical` → `checkbox`,
#'     `Date` → `date`, complex/JSON columns → `multilineText`, all others →
#'     `singleLineText`.
#' @param complex_fields What to do when `data` contains list-columns with
#'   complex (nested list or data-frame) values that Airtable cannot store
#'   directly:
#'   - `"error"` (default): abort with an informative message.
#'   - `"warn"`: warn and drop those columns.
#'   - `"json"`: serialize each complex value to a JSON text string and write
#'     it to a `singleLineText` field (creating the field first when
#'     `add_fields = "yes"`).
#' @param create_table If `TRUE`, creates the table in the base if it does not
#'   already exist. Field types are inferred from the data using the same rules
#'   as `add_fields = "yes"`. Defaults to `FALSE`.
#' @return A character vector of the created record IDs (invisibly).
#' @examples
#' \dontrun{
#' data <- data.frame(Name = c("Alice", "Bob"), Age = c(30, 25))
#' ids <- air_write(data, "Contacts", "appXXXXXX")
#'
#' # Write records and upload attachments from list-column
#' ids <- air_write(data, "Projects", "appXXXXXX",
#'   attachments = "file",
#'   attachment_dir = "files/"
#' )
#'
#' # Write records and add new columns if they don't exist
#' ids <- air_write(data, "Contacts", "appXXXXXX", add_fields = "yes")
#' }
#' @export
air_write <- function(
  data,
  table,
  base_id = NULL,
  typecast = TRUE,
  add_fields = c("error", "warn", "yes"),
  complex_fields = c("error", "warn", "json"),
  create_table = FALSE,
  attachments = c("meta", "file", "blob"),
  attachment_dir = NULL,
  progress = NULL,
  .token = NULL
) {
  base_id <- resolve_base_id(base_id)
  check_string(base_id)
  check_string(table)
  check_bool(typecast)
  check_bool(create_table)
  add_fields <- match.arg(add_fields)
  complex_fields <- match.arg(complex_fields)
  attachments <- match.arg(attachments)

  if (create_table) {
    tbl_schema <- tryCatch(
      get_table_schema(base_id, table, token = .token),
      error = function(e) NULL
    )
    if (is.null(tbl_schema)) {
      fields <- air_infer_fields(data)
      at_create_table(table, fields = fields, base_id = base_id, token = .token)
      schema_cache_invalidate(base_id)
    }
  }

  # Prepare write fields: identify computed/attachment fields, validate unknowns.
  wf <- prepare_write_fields(
    base_id,
    table,
    data,
    add_fields,
    complex_fields,
    .token,
    progress = progress
  )
  computed <- wf$computed
  att_fields <- wf$att_fields
  # With attachments = "meta", URL data is written directly to the API — keep
  # att_fields in the payload. With "file"/"blob", attachment upload happens
  # separately after record creation, so att_fields are excluded here.
  exclude <- if (attachments == "meta") wf$computed else wf$exclude

  if (length(wf$json_cols) > 0L) {
    data <- serialize_json_cols(data, wf$json_cols, wf$field_types)
  }

  records <- tibble_to_records(
    data,
    id_col = NULL,
    exclude = exclude,
    field_types = wf$field_types
  )

  results <- at_create_records(
    base_id = base_id,
    table_id = table,
    records = records,
    typecast = typecast,
    token = .token,
    progress = progress
  )

  ids <- vapply(results, function(r) r$id, character(1))
  cli_inform("Created {length(ids)} record{?s}.")

  # Upload attachments after record creation
  if (attachments != "meta") {
    data_att_fields <- intersect(att_fields, names(data))
    if (length(data_att_fields) > 0L) {
      upload_attachments_from_tibble(
        base_id = base_id,
        table = table,
        record_ids = ids,
        data = data,
        att_fields = data_att_fields,
        mode = attachments,
        attachment_dir = attachment_dir,
        .token = .token
      )
    }
  }

  invisible(ids)
}

# --- Internal helpers ---

#' Prepare data fields for a write operation
#'
#' Identifies computed and attachment fields to exclude from the payload,
#' warns about or drops unknown columns, and optionally creates missing fields.
#' Uses the session schema cache via `get_table_schema()`.
#'
#' @return A list with `computed`, `att_fields`, `exclude`, and `json_cols`
#'   character vectors, plus `field_types` (named field name -> Airtable type,
#'   or `NULL`).
#' @noRd
prepare_write_fields <- function(
  base_id,
  table,
  data,
  add_fields,
  complex_fields,
  .token,
  progress = NULL,
  call = rlang::caller_env()
) {
  progress <- resolve_progress(progress)
  computed <- get_computed_fields(base_id, table, .token)
  att_fields <- get_attachment_fields(base_id, table, .token)

  dropped <- intersect(computed, names(data))
  if (length(dropped) > 0L) {
    cli_inform("Dropping computed field{?s}: {.field {dropped}}.")
  }

  # Detect complex (nested list / data-frame) columns before schema work so
  # we error/warn early and so "json" columns are still treated as
  # singleLineText candidates by the add_fields path.
  meta_cols <- c("airtable_id", "airtable_created_time")
  data_fields <- setdiff(names(data), c(meta_cols, computed, att_fields))
  json_cols <- detect_complex_cols(data, data_fields)
  n_complex <- length(json_cols)

  if (n_complex > 0L) {
    if (complex_fields == "error") {
      cli_abort(
        c(
          "{n_complex} column{?s} contain complex (nested list or data-frame) values that Airtable cannot store directly: {.field {json_cols}}.",
          i = "Set {.arg complex_fields} to {.val warn} to drop these columns, or {.val json} to serialize them as JSON text."
        ),
        call = call
      )
    } else if (complex_fields == "warn") {
      cli_warn("{n_complex} complex column{?s} dropped: {.field {json_cols}}.")
      computed <- c(computed, json_cols)
      json_cols <- character()
    }
    # "json": json_cols returned as-is; caller serializes before tibble_to_records
  }

  tbl_schema <- tryCatch(
    get_table_schema(base_id, table, token = .token),
    error = function(e) NULL
  )

  field_types <- NULL
  if (!is.null(tbl_schema)) {
    field_types <- stats::setNames(
      vapply(tbl_schema$fields, function(f) f$type %||% "", character(1)),
      vapply(tbl_schema$fields, function(f) f$name, character(1))
    )
  }

  if (!is.null(tbl_schema)) {
    existing_fields <- vapply(
      tbl_schema$fields,
      function(f) f$name,
      character(1)
    )
    # Recompute data_fields after any complex-fields exclusion ("warn" path)
    data_fields <- setdiff(names(data), c(meta_cols, computed, att_fields))
    unknown <- setdiff(data_fields, existing_fields)

    if (length(unknown) > 0L) {
      n_unknown <- length(unknown)
      if (add_fields == "error") {
        cli_abort(
          c(
            "{n_unknown} column{?s} not found in table {.val {table}}: {.field {unknown}}.",
            i = "Set {.arg add_fields} to {.val warn} or {.val yes} to handle this."
          ),
          call = call
        )
      } else if (add_fields == "warn") {
        cli_warn("{n_unknown} unknown column{?s} dropped: {.field {unknown}}.")
        computed <- c(computed, unknown)
      } else {
        pb <- NULL
        if (progress && length(unknown) > 1L) {
          pb <- cli::cli_progress_bar(
            name = paste("Creating", length(unknown), "fields in", table),
            total = length(unknown),
            clear = FALSE
          )
        }
        field_num <- 0L
        for (field_name in unknown) {
          field_num <- field_num + 1L
          col <- data[[field_name]]
          field_type <- if (is.numeric(col)) {
            "number"
          } else if (is.logical(col)) {
            "checkbox"
          } else if (inherits(col, "Date")) {
            "date"
          } else if (field_name %in% json_cols) {
            "multilineText"
          } else {
            "singleLineText"
          }
          field_opts <- if (field_type == "number") {
            list(precision = if (is.integer(col)) 0L else 8L)
          } else if (field_type == "date") {
            list(dateFormat = list(name = "iso"))
          } else if (field_type == "checkbox") {
            list(icon = "check", color = "greenBright")
          }
          if (!is.null(pb)) {
            cli::cli_progress_update(
              id = pb,
              set = field_num,
              status = field_name
            )
          } else {
            cli_inform(
              "Creating field {.field {field_name}} in {.val {table}}."
            )
          }
          at_create_field(
            field_name,
            base_id = base_id,
            table_id = tbl_schema$id,
            type = field_type,
            options = field_opts,
            token = .token
          )
        }
        if (!is.null(pb)) {
          cli::cli_progress_done(id = pb)
        }
        schema_cache_invalidate(base_id)
        computed <- get_computed_fields(base_id, table, .token)
        att_fields <- get_attachment_fields(base_id, table, .token)
      }
    }
  }

  list(
    computed = computed,
    att_fields = att_fields,
    exclude = union(computed, intersect(att_fields, names(data))),
    field_types = field_types,
    json_cols = json_cols
  )
}

# Identify list-columns whose elements are themselves lists (data frames,
# nested lists) — values Airtable fields cannot accept directly.
detect_complex_cols <- function(data, data_fields) {
  air_classes <- c(
    "air_multiselect",
    "air_links",
    "air_attachments",
    "air_collaborator",
    "air_collaborators",
    "air_barcode"
  )
  Filter(
    function(nm) {
      col <- data[[nm]]
      is.list(col) &&
        !inherits(col, air_classes) &&
        any(vapply(
          col,
          function(x) {
            !is.null(x) && is.list(x) && !inherits(x, air_classes)
          },
          logical(1L)
        ))
    },
    data_fields
  )
}

# Convert complex list-columns to JSON text strings.
# For columns already typed as singleLineText in the schema (100k char limit),
# values that would exceed the limit are set to NA and a warning is issued.
serialize_json_cols <- function(data, json_cols, field_types = NULL) {
  singleline_limit <- 100000L
  for (nm in json_cols) {
    is_singleline <- !is.null(field_types) &&
      isTRUE(field_types[nm] == "singleLineText")

    serialized <- vapply(
      data[[nm]],
      function(x) {
        if (is.null(x) || (is.atomic(x) && length(x) == 1L && is.na(x))) {
          return(NA_character_)
        }
        as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
      },
      character(1L)
    )

    if (is_singleline) {
      too_long <- which(
        !is.na(serialized) & nchar(serialized) > singleline_limit
      )
      if (length(too_long) > 0L) {
        cli_warn(c(
          "{length(too_long)} value{?s} in {.field {nm}} exceed Airtable's 100,000-character {.val singleLineText} limit and will be set to {.code NA}.",
          i = "Affected rows: {toString(too_long)}.",
          i = "Change the field type to {.val longText} in Airtable to store large JSON values."
        ))
        serialized[too_long] <- NA_character_
      }
    }

    data[[nm]] <- serialized
  }
  data
}
