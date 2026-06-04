#' Dump an entire base (schema + data) for backup
#'
#' Exports the full schema and all table data from a base. By default,
#' attachments are downloaded to disk (`attachments = "file"`) since the
#' purpose of a dump is to create a full backup.
#'
#' @inheritParams air_read
#' @param dir Directory to write files to. When `format = "json"` or
#'   `format = "csv"`, schema and data files are written here. When
#'   `attachments = "file"`, attachment files are saved under
#'
#'   `{dir}/attachments/{table_name}/{record_id}/{filename}`.
#'   If `NULL` and format is `"json"` or `"csv"`, uses a temp directory.
#' @param format One of `"list"` (return as R list), `"json"` (write JSON files),
#'   or `"csv"` (write CSV files with flattened complex types).
#' @return For `format = "list"`: a named list with `schema` and a tibble per
#'   table. For `format = "json"` or `"csv"`: the directory path (invisibly).
#' @examples
#' \dontrun{
#' # Full backup with attachments
#' air_dump("appXXXXXX", dir = "backup/")
#'
#' # Quick dump without downloading attachments
#' air_dump("appXXXXXX", dir = "backup/", attachments = "meta")
#'
#' # CSV dump (flattened for spreadsheet compatibility)
#' air_dump("appXXXXXX", dir = "backup/", format = "csv")
#' }
#' @export
air_dump <- function(
  base_id,
  dir = NULL,
  format = c("list", "json", "csv"),
  attachments = c("file", "meta", "blob"),
  .token = NULL
) {
  check_string(base_id)
  format <- match.arg(format)
  attachments <- match.arg(attachments)

  if (is.null(dir) && format == "json") {
    dir <- tempfile("air_dump_")
  }
  if (!is.null(dir) && !dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }

  # Determine attachment directory
  att_dir <- if (attachments == "file" && !is.null(dir)) {
    file.path(dir, "attachments")
  } else {
    NULL
  }

  # Get schema
  tables <- at_get_schema(base_id, token = .token)

  cli_inform("Dumping {length(tables)} table{?s} from base {.val {base_id}}...")

  # Read all table data
  table_data <- stats::setNames(
    lapply(tables, function(t) {
      cli_inform("  Reading {.val {t$name}}...")
      # Determine per-table attachment dir
      tbl_att_dir <- if (!is.null(att_dir)) {
        safe_name <- gsub("[^a-zA-Z0-9_-]", "_", tolower(t$name))
        file.path(att_dir, safe_name)
      } else {
        NULL
      }
      air_read(
        base_id,
        t$name,
        coerce = FALSE,
        attachments = attachments,
        attachment_dir = tbl_att_dir,
        .token = .token
      )
    }),
    vapply(tables, function(t) t$name, character(1))
  )

  if (format == "csv") {
    # Flatten all tables and write as CSV
    for (tbl_name in names(table_data)) {
      safe_name <- gsub("[^a-zA-Z0-9_-]", "_", tolower(tbl_name))
      flat_data <- flatten_for_csv(table_data[[tbl_name]])
      write.csv(
        flat_data,
        file.path(dir, paste0(safe_name, ".csv")),
        row.names = FALSE,
        na = ""
      )
    }

    # Write schema as JSON (CSV doesn't support schema metadata well)
    jsonlite::write_json(
      tables,
      file.path(dir, "schema.json"),
      auto_unbox = TRUE,
      pretty = TRUE
    )

    cli_inform("CSV dump written to {.path {dir}}.")
    return(invisible(dir))
  }

  if (format == "list") {
    result <- list(schema = tables)
    result <- c(result, table_data)
    return(result)
  }

  # Write JSON files
  jsonlite::write_json(
    tables,
    file.path(dir, "schema.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )

  for (tbl_name in names(table_data)) {
    safe_name <- gsub("[^a-zA-Z0-9_-]", "_", tolower(tbl_name))
    jsonlite::write_json(
      table_data[[tbl_name]],
      file.path(dir, paste0(safe_name, ".json")),
      auto_unbox = TRUE,
      pretty = TRUE
    )
  }

  cli_inform("Dump written to {.path {dir}}.")
  invisible(dir)
}

#' Restore a base from a dump
#'
#' Recreates a base from output of [air_dump()]. When `attachments` is
#' `"file"`, uploads attachment files from the dump directory after record
#' creation. For CSV dumps, automatically detects and parses the flattened format.
#'
#' @param dump Either a list (from `air_dump(format = "list")`) or a path to
#'   a dump directory (from `air_dump(format = "json")` or `air_dump(format = "csv")`).
#' @param base_name Name for the new base. If `NULL`, uses a generated name.
#' @param workspace_id Workspace ID to create the base in.
#' @inheritParams air_read
#' @return The new base ID (invisibly).
#' @examples
#' \dontrun{
#' # Restore from a directory dump
#' air_restore("backup/", workspace_id = "wspXXXXXX")
#'
#' # Restore from a CSV dump
#' air_restore("backup/", workspace_id = "wspXXXXXX", format = "csv")
#' }
#' @export
air_restore <- function(
  dump,
  base_name = NULL,
  workspace_id = NULL,
  attachments = c("file", "meta"),
  attachment_dir = NULL,
  .token = NULL
) {
  workspace_id <- workspace_id %||% default_workspace_id()
  check_string(workspace_id)
  attachments <- match.arg(attachments)

  loaded <- load_dump(dump)
  schema <- loaded$schema
  table_data <- loaded$table_data

  # If dump is a directory, infer attachment_dir
  if (is.null(attachment_dir) && is.character(dump) && dir.exists(dump)) {
    candidate <- file.path(dump, "attachments")
    if (dir.exists(candidate)) {
      attachment_dir <- candidate
    }
  }

  base_name <- base_name %||%
    paste0("Restored_", format(Sys.time(), "%Y%m%d_%H%M%S"))

  # Build table configs for base creation (first field only per table).
  # Sanitize field options so the API accepts them (strip choice IDs, convert
  # formula references, fall back to singleLineText for unrestorable types).
  table_configs <- lapply(schema, function(t) {
    f <- t$fields[[1]]
    s <- sanitize_field_for_create(f, t$fields) %||%
      list(
        name = f$name,
        type = "singleLineText",
        description = NULL,
        options = NULL
      )
    fields <- list(compact(list(
      name = s$name,
      type = s$type,
      description = s$description,
      options = s$options
    )))
    compact(list(name = t$name, description = t$description, fields = fields))
  })

  # Create the base with minimal schema
  cli_inform("Creating base {.val {base_name}}...")
  new_base <- at_create_base(
    name = base_name,
    workspace_id = workspace_id,
    tables = table_configs,
    token = .token
  )
  new_base_id <- new_base$id

  # Add remaining fields to each table
  cli_inform("Adding fields...")
  restore_fields(schema, new_base_id, .token)

  # Fetch the actual restored schema so we only write fields that exist.
  # restore_fields() warns-and-continues, so some fields may not have been created.
  restored_schema <- tryCatch(
    at_get_schema(new_base_id, token = .token),
    error = function(e) NULL
  )

  # Insert records
  cli_inform("Inserting records...")
  for (tbl_name in names(table_data)) {
    data <- table_data[[tbl_name]]
    if (is.data.frame(data) && nrow(data) > 0L) {
      data <- data[setdiff(
        names(data),
        c("airtable_id", "airtable_created_time")
      )]

      # Drop columns for fields that were not successfully created.
      if (!is.null(restored_schema)) {
        tbl_info <- Find(function(t) t$name == tbl_name, restored_schema)
        if (!is.null(tbl_info)) {
          valid_cols <- vapply(
            tbl_info$fields,
            function(f) f$name,
            character(1L)
          )
          data <- data[intersect(names(data), valid_cols)]
        }
      }

      # Resolve per-table attachment dir
      tbl_att_dir <- NULL
      if (attachments == "file" && !is.null(attachment_dir)) {
        safe_name <- gsub("[^a-zA-Z0-9_-]", "_", tolower(tbl_name))
        candidate <- file.path(attachment_dir, safe_name)
        if (dir.exists(candidate)) {
          tbl_att_dir <- candidate
        }
      }

      tryCatch(
        air_write(
          data,
          new_base_id,
          tbl_name,
          typecast = TRUE,
          attachments = attachments,
          attachment_dir = tbl_att_dir,
          .token = .token
        ),
        error = function(e) {
          cli_warn(
            "Could not write to {.val {tbl_name}}: {conditionMessage(e)}"
          )
        }
      )
    }
  }

  cli_inform("Restore complete. New base ID: {.val {new_base_id}}.")
  invisible(new_base_id)
}

# --- Internal helpers ---

#' Flatten a data frame for CSV export
#'
#' Converts complex Airtable types (list-columns) to character vectors
#' suitable for CSV export.
#'
#' @param df A data frame (possibly with list-columns).
#' @return A data frame with all columns as atomic vectors.
#' @noRd
flatten_for_csv <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }

  for (col in names(df)) {
    if (is.list(df[[col]])) {
      # Convert list-column to character by formatting
      df[[col]] <- vapply(
        df[[col]],
        function(x) {
          if (is.null(x)) {
            return(NA_character_)
          }
          # For air_* types, use format method if available
          if (
            inherits(x, "air_multiselect") ||
              inherits(x, "air_links") ||
              inherits(x, "air_attachments") ||
              inherits(x, "air_collaborator") ||
              inherits(x, "air_collaborators") ||
              inherits(x, "air_barcode")
          ) {
            # Strip class and format
            formatted <- tryCatch(format(unclass(x)), error = function(e) {
              as.character(x)
            })
            if (is.character(formatted) && length(formatted) == 1) {
              return(formatted)
            }
            return(as.character(x))
          }
          # For other lists, convert to JSON string
          jsonlite::toJSON(x, auto_unbox = TRUE, simplifyVector = FALSE)
        },
        character(1)
      )
    }
  }
  df
}

#' Load a dump from path or list
#' @noRd
load_dump <- function(dump) {
  if (is.character(dump) && length(dump) == 1L && dir.exists(dump)) {
    schema <- jsonlite::read_json(file.path(dump, "schema.json"))

    # Check if this is a CSV dump
    csv_files <- list.files(dump, pattern = "\\.csv$", full.names = TRUE)
    json_files <- list.files(dump, pattern = "\\.json$", full.names = TRUE)
    json_files <- json_files[basename(json_files) != "schema.json"]

    if (length(csv_files) > 0) {
      # CSV dump - read CSV files
      table_data <- stats::setNames(
        lapply(csv_files, function(f) {
          df <- read.csv(f, stringsAsFactors = FALSE)
          # Replace empty strings with NA
          df[df == ""] <- NA
          df
        }),
        tools::file_path_sans_ext(basename(csv_files))
      )
    } else if (length(json_files) > 0) {
      # JSON dump - read JSON files
      table_data <- stats::setNames(
        lapply(json_files, jsonlite::read_json, simplifyVector = TRUE),
        tools::file_path_sans_ext(basename(json_files))
      )
    } else {
      table_data <- list()
    }

    list(schema = schema, table_data = table_data)
  } else if (is.list(dump)) {
    list(
      schema = dump$schema,
      table_data = dump[setdiff(names(dump), "schema")]
    )
  } else {
    cli_abort("{.arg dump} must be a list or a path to a dump directory.")
  }
}

# Sanitize a field definition for use with at_create_field() or in
# at_create_base() table configs. Returns a modified field_def ready for the
# API, or NULL if the type cannot be created via the Airtable API.
#
# Two transformations applied to restorable fields:
#   1. singleSelect / multipleSelects: strip `id` from choices - the create
#      API rejects choice objects that include `id`.
#   2. formula: convert {fldXXX} field-ID references to {FieldName} using the
#      original table's field list, then strip read-only keys (isValid,
#      referencedFieldIds, result) from the options.
#
# Returns NULL for field types that the API cannot create:
#   - multipleRecordLinks / rollup / lookup / count: reference table/field IDs
#     that are base-specific and won't be valid in the new base.
#   - Auto-generated / read-only computed fields: lastModifiedTime,
#     lastModifiedBy, createdTime, createdBy, autoNumber, externalSyncSource,
#     aiText, button.
#' @noRd
sanitize_field_for_create <- function(field_def, table_fields) {
  cannot_create <- c(
    "multipleRecordLinks",
    "rollup",
    "lookup",
    "count",
    "lastModifiedTime",
    "lastModifiedBy",
    "createdTime",
    "createdBy",
    "autoNumber",
    "externalSyncSource",
    "aiText",
    "button"
  )
  if (field_def$type %in% cannot_create) {
    return(NULL)
  }

  opts <- field_def$options

  if (field_def$type %in% c("singleSelect", "multipleSelects")) {
    if (!is.null(opts$choices)) {
      opts$choices <- lapply(opts$choices, function(ch) {
        ch[setdiff(names(ch), "id")]
      })
    }
    field_def$options <- opts
  }

  if (field_def$type == "formula") {
    ids <- vapply(table_fields, function(f) f$id %||% "", character(1L))
    nms <- vapply(table_fields, function(f) f$name %||% "", character(1L))
    valid <- nzchar(ids) & nzchar(nms)
    id_to_name <- stats::setNames(nms[valid], ids[valid])

    formula <- opts$formula %||% ""
    for (fld_id in names(id_to_name)) {
      formula <- gsub(
        paste0("{", fld_id, "}"),
        paste0("{", id_to_name[[fld_id]], "}"),
        formula,
        fixed = TRUE
      )
    }
    field_def$options <- list(formula = formula)
  }

  field_def
}

#' Add fields from schema to a newly created base
#' @noRd
restore_fields <- function(schema, new_base_id, .token) {
  for (tbl_schema in schema) {
    new_tables <- at_get_schema(new_base_id, token = .token)
    new_tbl <- Find(function(t) t$name == tbl_schema$name, new_tables)
    if (is.null(new_tbl)) {
      next
    }

    if (length(tbl_schema$fields) > 1L) {
      for (f in tbl_schema$fields[-1]) {
        sanitized <- sanitize_field_for_create(f, tbl_schema$fields)
        if (is.null(sanitized)) {
          cli_warn(
            "Field {.field {f$name}} (type {.val {f$type}}) cannot be \\
            restored via the API - create it manually in the web UI."
          )
          next
        }
        tryCatch(
          at_create_field(
            sanitized$name,
            base_id = new_base_id,
            table_id = new_tbl$id,
            type = sanitized$type,
            description = sanitized$description,
            options = sanitized$options,
            token = .token
          ),
          error = function(e) {
            cli_warn(
              "Could not create field {.field {f$name}}: {conditionMessage(e)}"
            )
          }
        )
      }
    }
  }
}
