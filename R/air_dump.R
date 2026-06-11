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
        t$name,
        base_id,
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
#' @param restore_linked_fields If `TRUE` (the default), after all records are
#'   created, linked-record fields (`multipleRecordLinks`) and their dependent
#'   computed fields (`rollup`, `lookup`, `count`) are recreated with remapped
#'   table/field IDs, and the link cell values (record-to-record connections)
#'   are repopulated by remapping old record IDs to the newly created record
#'   IDs. Set to `FALSE` to skip this step (faster, but links will be empty).
#' @section Linked-record fields:
#' Linked-record fields (`multipleRecordLinks`) and the computed fields that
#' depend on them (`rollup`, `lookup`, `count`) are skipped during the initial
#' field-creation pass because their options reference base-specific IDs.
#' When `restore_linked_fields = TRUE` (the default), after all records are
#' inserted a two-step pass runs:
#'
#' 1. **Field definitions**: `multipleRecordLinks` fields are recreated with
#'    `linkedTableId` remapped to the new base's table IDs.
#' 2. **Cell values**: the link columns in the dump contain old record IDs.
#'    These are remapped to the new record IDs (matched by insertion order) and
#'    written back via `air_upsert()`.
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
  restore_linked_fields = TRUE,
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
  restore_fields(schema, new_base_id, .token, warn_links = !restore_linked_fields)

  # Fetch the actual restored schema so we only write fields that exist.
  # restore_fields() warns-and-continues, so some fields may not have been created.
  restored_schema <- tryCatch(
    at_get_schema(new_base_id, token = .token),
    error = function(e) NULL
  )

  # Identify link-column names per table (must be excluded from initial write
  # since they contain old record IDs that don't exist in the new base yet).
  link_cols_by_table <- stats::setNames(
    lapply(schema, function(t) {
      vapply(
        Filter(function(f) identical(f$type, "multipleRecordLinks"), t$fields),
        function(f) f$name %||% "", character(1L)
      )
    }),
    vapply(schema, function(t) t$name %||% "", character(1L))
  )

  # Insert records, tracking old->new record ID mapping for link restoration.
  cli_inform("Inserting records...")
  record_id_maps <- list()

  for (tbl_name in names(table_data)) {
    data <- table_data[[tbl_name]]
    if (is.data.frame(data) && nrow(data) > 0L) {
      old_ids <- data$airtable_id   # save before stripping

      data <- data[setdiff(
        names(data),
        c("airtable_id", "airtable_created_time")
      )]

      # Drop link columns (contain old record IDs; restored in a second pass).
      lf <- link_cols_by_table[[tbl_name]] %||% character(0)
      if (length(lf) > 0L) {
        data <- data[setdiff(names(data), lf)]
      }

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

      # Rewrap list-type columns using the dump schema so that air_write's
      # detect_complex_cols does not flag valid multiselect/etc. columns.
      # air_dump uses coerce=FALSE, so these columns are plain lists without
      # the air_multiselect / air_attachments / etc. class.
      tbl_orig_schema <- Find(function(t) t$name == tbl_name, schema)
      if (!is.null(tbl_orig_schema)) {
        data <- rewrap_dump_columns(data, tbl_orig_schema$fields)
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

      new_ids <- tryCatch(
        air_write(
          data,
          tbl_name,
          new_base_id,
          typecast = TRUE,
          attachments = attachments,
          attachment_dir = tbl_att_dir,
          .token = .token
        ),
        error = function(e) {
          cli_warn(
            "Could not write to {.val {tbl_name}}: {conditionMessage(e)}"
          )
          character(0)
        }
      )

      # Map old record IDs to new ones (matched by insertion order).
      if (!is.null(old_ids) && length(new_ids) > 0L &&
          length(new_ids) == length(old_ids)) {
        record_id_maps[[tbl_name]] <- stats::setNames(new_ids, old_ids)
      }
    }
  }

  # Global old->new record ID map across all tables (used to re-link values).
  # unname() prevents do.call(c, ...) from prefixing keys with table names.
  global_id_map <- if (length(record_id_maps) > 0L) {
    do.call(c, unname(record_id_maps))
  } else {
    character(0)
  }

  # Recreate linked-record field definitions and re-populate link cell values.
  # Skipped when restore_linked_fields = FALSE.
  new_schema <- tryCatch(
    at_get_schema(new_base_id, token = .token),
    error = function(e) NULL
  )
  if (restore_linked_fields && !is.null(new_schema)) {
    table_id_map <- build_table_id_map(schema, new_schema)
    restore_linked_fields(schema, new_base_id, table_id_map, .token = .token)
    if (length(global_id_map) > 0L) {
      restore_linked_records(
        table_data, new_base_id, global_id_map, schema, .token = .token
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
restore_fields <- function(schema, new_base_id, .token, warn_links = TRUE) {
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
          if (warn_links || !identical(f$type, "multipleRecordLinks")) {
            cli_warn(
              "Field {.field {f$name}} (type {.val {f$type}}) cannot be \\
              restored via the API - create it manually in the web UI."
            )
          }
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

#' Build an old -> new table id map by matching table names
#'
#' Returns a named character vector whose names are old table IDs and whose
#' values are the new base's table IDs, matched on table name. Tables whose
#' name has no counterpart in the new schema are omitted.
#'
#' @param old_schema Schema list from the dump.
#' @param new_schema Schema list freshly fetched from the new base.
#' @return Named character vector (`old_table_id -> new_table_id`).
#' @noRd
build_table_id_map <- function(old_schema, new_schema) {
  new_ids_by_name <- stats::setNames(
    vapply(new_schema, function(t) t$id %||% NA_character_, character(1L)),
    vapply(new_schema, function(t) t$name %||% NA_character_, character(1L))
  )

  map <- character(0)
  for (t in old_schema) {
    old_id <- t$id %||% NA_character_
    nm <- t$name %||% NA_character_
    if (!is.na(nm) && nm %in% names(new_ids_by_name) && !is.na(old_id)) {
      map[[old_id]] <- new_ids_by_name[[nm]]
    }
  }
  map
}

#' Recreate linked-record fields and their dependent computed fields
#'
#' Recreates `multipleRecordLinks` fields (skipped during [air_restore()]'s
#' initial field pass because they reference base-specific IDs) and, once those
#' exist, the dependent `rollup`/`lookup`/`count` fields.
#'
#' For each link field: `options$linkedTableId` is remapped to the new base's
#' table id (via `table_id_map`), and `options$inverseLinkFieldId` and
#' `options$viewIdForRecordSelection` are dropped (they don't exist yet;
#' Airtable auto-creates the inverse link). For each dependent field:
#' `options$recordLinkFieldId` is remapped to the newly created link field's id
#' (looked up by name in a freshly fetched schema).
#'
#' Link CELL VALUES are not repopulated: the dump's old record IDs do not
#' correspond to the new records' IDs. Only the link FIELDS are recreated.
#'
#' Failures are warned-and-continued (like `restore_fields()`); a link whose
#' target table name is missing from the map is warned and skipped.
#'
#' @param schema The original (dump) schema list.
#' @param new_base_id The ID of the newly created base.
#' @param table_id_map Named character vector mapping old table IDs to new
#'   table IDs (see `build_table_id_map()`).
#' @param .token Personal access token (resolved via [air_token()] if `NULL`).
#' @return Invisibly, `NULL`.
#' @noRd
restore_linked_fields <- function(
  schema,
  new_base_id,
  table_id_map,
  .token = NULL
) {
  # Fetch current new schema to learn new table ids by name.
  new_schema <- at_get_schema(new_base_id, token = .token)
  new_tbl_id_by_name <- stats::setNames(
    vapply(new_schema, function(t) t$id %||% NA_character_, character(1L)),
    vapply(new_schema, function(t) t$name %||% NA_character_, character(1L))
  )

  # Safe lookup into a named vector: returns NULL when the key is absent
  # (named-vector `[[` errors on a missing key).
  lookup <- function(vec, key) {
    if (is.null(key) || is.na(key) || !key %in% names(vec)) {
      return(NULL)
    }
    vec[[key]]
  }

  n_links <- 0L
  n_deps <- 0L

  # Build a lookup: old field id -> the name of the table that contains it.
  # Used to identify auto-created reverse links by name heuristic below.
  old_tbl_name_by_field_id <- character(0L)
  old_tbl_name_by_id <- character(0L)
  for (tbl_schema in schema) {
    tbl_name <- tbl_schema$name %||% NA_character_
    tbl_id <- tbl_schema$id %||% NA_character_
    if (!is.na(tbl_id)) old_tbl_name_by_id[[tbl_id]] <- tbl_name
    for (f in tbl_schema$fields) {
      fld_id <- f$id %||% NA_character_
      if (!is.na(fld_id)) old_tbl_name_by_field_id[[fld_id]] <- tbl_name
    }
  }

  # --- Pass 1: create multipleRecordLinks fields ---
  for (tbl_schema in schema) {
    new_tbl_id <- lookup(new_tbl_id_by_name, tbl_schema$name %||% "")
    if (is.null(new_tbl_id) || is.na(new_tbl_id)) {
      next
    }

    for (f in tbl_schema$fields) {
      if (!identical(f$type, "multipleRecordLinks")) {
        next
      }

      opts <- f$options %||% list()

      # Skip the auto-created reverse side of each symmetric pair.
      # Two heuristics (either triggers a skip):
      # 1. isReversed = TRUE  (old Airtable API behaviour, may still appear)
      # 2. Field name equals the name of the linked TABLE  (new behaviour:
      #    Airtable names the auto-created reverse link after the source table,
      #    so e.g. a link "Owner" in Projects auto-creates "Projects" in Contacts)
      # Creating one side always auto-creates the other, so one per pair is enough.
      if (isTRUE(opts$isReversed)) {
        next
      }
      old_linked_tbl_id <- opts$linkedTableId %||% NA_character_
      linked_tbl_name <- lookup(old_tbl_name_by_id, old_linked_tbl_id)
      if (!is.null(linked_tbl_name) &&
          !is.na(linked_tbl_name) &&
          identical(f$name, linked_tbl_name)) {
        next
      }

      new_linked <- lookup(table_id_map, old_linked_tbl_id)

      if (is.null(new_linked) || is.na(new_linked)) {
        cli_warn(
          "Link field {.field {f$name}} targets a table that could not be \\
          remapped (linked table not found in the restored base) - skipping."
        )
        next
      }

      # Only linkedTableId is accepted by the create-field API;
      # isReversed, prefersSingleRecordLink, inverseLinkFieldId, and
      # viewIdForRecordSelection are read-only or auto-set by Airtable.
      create_opts <- list(linkedTableId = new_linked)

      tryCatch(
        {
          at_create_field(
            f$name,
            base_id = new_base_id,
            table_id = new_tbl_id,
            type = "multipleRecordLinks",
            description = f$description,
            options = create_opts,
            token = .token
          )
          n_links <- n_links + 1L
        },
        error = function(e) {
          cli_warn(
            "Could not create link field {.field {f$name}}: \\
            {conditionMessage(e)}"
          )
        }
      )
    }
  }

  # --- Pass 2: create dependent rollup/lookup/count fields ---
  # Re-fetch schema so we can map old link-field ids to the new link-field ids
  # (looked up by name within each table).
  refreshed <- tryCatch(
    at_get_schema(new_base_id, token = .token),
    error = function(e) NULL
  )

  for (tbl_schema in schema) {
    new_tbl_id <- lookup(new_tbl_id_by_name, tbl_schema$name %||% "")
    if (is.null(new_tbl_id) || is.na(new_tbl_id)) {
      next
    }

    # Build old-link-field-id -> new-link-field-id map for this table by name.
    new_tbl <- if (!is.null(refreshed)) {
      Find(function(t) identical(t$name, tbl_schema$name), refreshed)
    } else {
      NULL
    }
    new_link_id_by_name <- if (!is.null(new_tbl)) {
      stats::setNames(
        vapply(new_tbl$fields, function(g) g$id %||% NA_character_, character(1L)),
        vapply(new_tbl$fields, function(g) g$name %||% NA_character_, character(1L))
      )
    } else {
      character(0)
    }
    # old link field id -> its name, for this table.
    old_link_name_by_id <- stats::setNames(
      vapply(tbl_schema$fields, function(g) g$name %||% NA_character_, character(1L)),
      vapply(tbl_schema$fields, function(g) g$id %||% NA_character_, character(1L))
    )

    for (f in tbl_schema$fields) {
      if (!f$type %in% c("rollup", "lookup", "count")) {
        next
      }

      opts <- f$options %||% list()
      old_link_id <- opts$recordLinkFieldId %||% NA_character_
      link_name <- lookup(old_link_name_by_id, old_link_id)
      new_link_id <- if (!is.null(link_name)) {
        lookup(new_link_id_by_name, link_name)
      } else {
        NULL
      }

      if (is.null(new_link_id) || is.na(new_link_id)) {
        cli_warn(
          "Dependent field {.field {f$name}} (type {.val {f$type}}) references \\
          a link field that could not be remapped - skipping."
        )
        next
      }

      # Patch options: remap recordLinkFieldId, drop read-only keys.
      opts$recordLinkFieldId <- new_link_id
      opts <- opts[setdiff(
        names(opts),
        c("isValid", "referencedFieldIds", "result")
      )]

      tryCatch(
        {
          at_create_field(
            f$name,
            base_id = new_base_id,
            table_id = new_tbl_id,
            type = f$type,
            description = f$description,
            options = opts,
            token = .token
          )
          n_deps <- n_deps + 1L
        },
        error = function(e) {
          cli_warn(
            "Could not create dependent field {.field {f$name}}: \\
            {conditionMessage(e)}"
          )
        }
      )
    }
  }

  cli_inform(
    "Recreated {n_links} link field{?s} and {n_deps} dependent \\
    field{?s}."
  )
  invisible(NULL)
}

#' Re-link records after a restore by remapping old record IDs to new ones
#'
#' After [air_restore()] inserts records into the new base, any
#' `multipleRecordLinks` columns in the dump still contain the original record
#' IDs, which are no longer valid. This function remaps them to the new record
#' IDs (collected during the write phase) and writes the corrected link values
#' back via [air_upsert()].
#'
#' @param table_data Named list of tibbles from the dump (including
#'   `airtable_id` and link columns).
#' @param new_base_id ID of the newly created base.
#' @param id_map Named character vector: names are old record IDs, values are
#'   new record IDs.
#' @param schema The original dump schema list.
#' @param .token API token.
#' @return Invisibly `NULL`.
#' @noRd
restore_linked_records <- function(
  table_data,
  new_base_id,
  id_map,
  schema,
  .token = NULL
) {
  n_tables <- 0L

  for (tbl_name in names(table_data)) {
    data <- table_data[[tbl_name]]
    if (!is.data.frame(data) || nrow(data) == 0L) next
    if (!"airtable_id" %in% names(data)) next

    tbl_schema <- Find(function(t) t$name == tbl_name, schema)
    if (is.null(tbl_schema)) next

    link_fields <- vapply(
      Filter(function(f) identical(f$type, "multipleRecordLinks"), tbl_schema$fields),
      function(f) f$name %||% "", character(1L)
    )
    link_fields <- intersect(link_fields, names(data))
    if (length(link_fields) == 0L) next

    old_ids <- data$airtable_id
    new_ids <- id_map[old_ids]
    if (any(is.na(new_ids))) {
      cli_warn(
        "Some records in {.val {tbl_name}} are not in the ID map; \\
        skipping link-value restore for this table."
      )
      next
    }

    update_df <- tibble::tibble(airtable_id = unname(new_ids))
    for (field in link_fields) {
      update_df[[field]] <- lapply(data[[field]], function(old_link_ids) {
        if (is.null(old_link_ids) || length(old_link_ids) == 0L) return(NULL)
        remapped <- id_map[as.character(unlist(old_link_ids))]
        remapped <- remapped[!is.na(remapped)]
        if (length(remapped) == 0L) NULL else as.list(unname(remapped))
      })
    }

    tryCatch(
      air_upsert(
        update_df, tbl_name,
        merge_on = "airtable_id",
        base_id = new_base_id,
        .token = .token
      ),
      error = function(e) {
        cli_warn(
          "Could not restore link values for {.val {tbl_name}}: \\
          {conditionMessage(e)}"
        )
      }
    )
    n_tables <- n_tables + 1L
  }

  cli_inform("Re-linked records in {n_tables} table{?s}.")
  invisible(NULL)
}

#' Rewrap list-type columns in a dump data frame using air_* classes
#'
#' air_dump uses coerce=FALSE, so multipleSelects etc. come back as plain
#' lists (no air_multiselect class). air_write's detect_complex_cols would
#' then flag them as unwritable. This function re-applies wrap_list_column
#' so the classes are present before writing.
#'
#' @param data Data frame from the dump.
#' @param fields Field list from the dump schema for this table.
#' @return data with list-column types re-wrapped in their air_* classes.
#' @noRd
rewrap_dump_columns <- function(data, fields) {
  type_lookup <- stats::setNames(
    vapply(fields, function(f) f$type %||% "", character(1L)),
    vapply(fields, function(f) f$name %||% "", character(1L))
  )
  list_types <- list_column_types()
  for (col_name in names(data)) {
    col <- data[[col_name]]
    ftype <- type_lookup[[col_name]]
    if (!is.null(ftype) && !is.na(ftype) && ftype %in% list_types &&
        is.list(col) && !inherits(col, c(
          "air_multiselect", "air_links", "air_attachments",
          "air_collaborator", "air_collaborators", "air_barcode"
        ))) {
      data[[col_name]] <- wrap_list_column(col, ftype)
    }
  }
  data
}
