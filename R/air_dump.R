#' Dump an entire base (schema + data) for backup
#'
#' Exports the full schema and all table data from a base. By default,
#' attachments are downloaded to disk (`attachments = "file"`) since the
#' purpose of a dump is to create a full backup.
#'
#' @inheritParams air_read
#' @param dir Directory to write JSON/attachment files to. When
#'   `format = "json"`, schema and data files are written here. When
#'   `attachments = "file"`, attachment files are saved under
#'
#'   `{dir}/attachments/{table_name}/{record_id}/{filename}`.
#'   If `NULL` and format is `"json"`, uses a temp directory.
#' @param format Either `"list"` (return as R list) or `"json"` (write files).
#' @return For `format = "list"`: a named list with `schema` and a tibble per
#'   table. For `format = "json"`: the directory path (invisibly).
#' @examples
#' \dontrun{
#' # Full backup with attachments
#' air_dump("appXXXXXX", dir = "backup/")
#'
#' # Quick dump without downloading attachments
#' air_dump("appXXXXXX", dir = "backup/", attachments = "meta")
#' }
#' @export
air_dump <- function(
  base_id,
  dir = NULL,
  format = c("list", "json"),
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
        base_id, t$name,
        coerce = FALSE,
        attachments = attachments,
        attachment_dir = tbl_att_dir,
        .token = .token
      )
    }),
    vapply(tables, function(t) t$name, character(1))
  )

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
#' creation.
#'
#' @param dump Either a list (from `air_dump(format = "list")`) or a path to
#'   a dump directory (from `air_dump(format = "json")`).
#' @param base_name Name for the new base. If `NULL`, uses a generated name.
#' @param workspace_id Workspace ID to create the base in.
#' @inheritParams air_read
#' @return The new base ID (invisibly).
#' @examples
#' \dontrun{
#' # Restore from a directory dump
#' air_restore("backup/", workspace_id = "wspXXXXXX")
#' }
#' @export
air_restore <- function(
  dump,
  base_name = NULL,
  workspace_id,
  attachments = c("file", "meta"),
  attachment_dir = NULL,
  .token = NULL
) {
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

  # Build table configs for base creation (first table + field only)
  table_configs <- lapply(schema, function(t) {
    fields <- lapply(t$fields[1], function(f) {
      compact(list(
        name = f$name,
        type = f$type,
        description = f$description,
        options = f$options
      ))
    })
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

  # Insert records
  cli_inform("Inserting records...")
  for (tbl_name in names(table_data)) {
    data <- table_data[[tbl_name]]
    if (is.data.frame(data) && nrow(data) > 0L) {
      data <- data[setdiff(
        names(data),
        c("airtable_id", "airtable_created_time")
      )]

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
          new_base_id,
          tbl_name,
          data,
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

#' Load a dump from path or list
#' @noRd
load_dump <- function(dump) {
  if (is.character(dump) && length(dump) == 1L && dir.exists(dump)) {
    schema <- jsonlite::read_json(file.path(dump, "schema.json"))
    json_files <- list.files(dump, pattern = "\\.json$", full.names = TRUE)
    json_files <- json_files[basename(json_files) != "schema.json"]
    table_data <- stats::setNames(
      lapply(json_files, jsonlite::read_json, simplifyVector = TRUE),
      tools::file_path_sans_ext(basename(json_files))
    )
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

#' Add fields from schema to a newly created base
#' @noRd
restore_fields <- function(schema, new_base_id, .token) {
  for (tbl_schema in schema) {
    new_tables <- at_get_schema(new_base_id, token = .token)
    new_tbl <- Find(function(t) t$name == tbl_schema$name, new_tables)
    if (is.null(new_tbl)) {
      next
    }

    # Skip first field (already created with table)
    if (length(tbl_schema$fields) > 1L) {
      for (f in tbl_schema$fields[-1]) {
        tryCatch(
          at_create_field(
            base_id = new_base_id,
            table_id = new_tbl$id,
            name = f$name,
            type = f$type,
            description = f$description,
            options = f$options,
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
