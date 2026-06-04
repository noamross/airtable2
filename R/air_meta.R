#' Get base metadata as a flat tibble
#'
#' Returns one row per field across all tables, useful for inspecting and
#' editing base structure as a data frame.
#'
#' @inheritParams air_read
#' @return A tibble with columns: `table_name`, `table_id`, `field_name`,
#'   `field_id`, `field_type`, `description`.
#' @examples
#' \dontrun{
#' meta <- air_meta("appXXXXXX")
#' meta
#' }
#' @export
air_meta <- function(base_id, .token = NULL) {
  check_string(base_id)

  tables <- at_get_schema(base_id, token = .token)

  rows <- lapply(tables, function(t) {
    if (length(t$fields) == 0L) {
      return(NULL)
    }
    tibble::tibble(
      table_name = t$name,
      table_id = t$id,
      field_name = vapply(t$fields, \(f) f$name, character(1)),
      field_id = vapply(t$fields, \(f) f$id, character(1)),
      field_type = vapply(
        t$fields,
        \(f) f$type %||% NA_character_,
        character(1)
      ),
      description = vapply(
        t$fields,
        \(f) f$description %||% NA_character_,
        character(1)
      )
    )
  })

  do.call(rbind, compact(rows))
}

#' Push metadata changes back to the base
#'
#' Compares a modified metadata tibble (from [air_meta()]) against the current
#' schema and applies name/description changes via PATCH.
#'
#' @inheritParams air_read
#' @param meta A tibble from [air_meta()] with modifications to `field_name`
#'   or `description`.
#' @return Invisible `NULL`. Side effect: updates field names/descriptions.
#' @export
air_meta_push <- function(base_id, meta, .token = NULL) {
  check_string(base_id)

  # Get current schema for comparison
  current <- air_meta(base_id, .token = .token)

  n_changes <- 0L

  for (i in seq_len(nrow(meta))) {
    field_id <- meta$field_id[i]
    table_id <- meta$table_id[i]

    # Find matching row in current
    cur_row <- current[current$field_id == field_id, ]
    if (nrow(cur_row) == 0L) {
      next
    }

    new_name <- if (!identical(meta$field_name[i], cur_row$field_name[1])) {
      meta$field_name[i]
    }
    new_desc <- if (!identical(meta$description[i], cur_row$description[1])) {
      meta$description[i]
    }

    if (!is.null(new_name) || !is.null(new_desc)) {
      at_update_field(
        base_id = base_id,
        table_id = table_id,
        field_id = field_id,
        name = new_name,
        description = new_desc,
        token = .token
      )
      n_changes <- n_changes + 1L
    }
  }

  cli_inform("Pushed {n_changes} field change{?s}.")
  invisible(NULL)
}

#' Sync a metadata source to patch the base schema
#'
#' The **preferred metadata workflow**: pull field names and descriptions from
#' a source (default: the `"_metadata"` table inside the same base), compare
#' against the live schema, and PATCH any changed fields.
#'
#' # Typical workflow
#'
#' 1. **Seed** – run [air_meta_init()] once to create / populate the
#'    `"_metadata"` table from the live schema.
#' 2. **Edit** – open the `"_metadata"` table in Airtable and change
#'    `field_name` / `description` cells to your liking.
#' 3. **Sync** – call `air_meta_sync()` (no arguments needed) to PATCH the
#'    schema with your edits.
#'
#' # Source precedence
#'
#' `source` is resolved in this order:
#'
#' 1. A `data.frame` → used directly.
#' 2. A length-1 character path to an **existing `.csv`** file → read with
#'    [utils::read.csv()].
#' 3. A length-1 character path to an **existing `.json`** file → read with
#'    [jsonlite::fromJSON()].
#' 4. A length-1 character string that matches neither 2 nor 3 → treated as
#'    a **table name** inside the base and read with [air_read()].
#'
#' The source tibble must contain at least `field_id`, `table_id`,
#' `field_name`, and `description` columns (the shape produced by
#' [air_meta()] and [air_meta_init()]). An extra `meta_key` column (produced
#' by older seed runs) is silently ignored.
#'
#' @inheritParams air_read
#' @param source Where to pull the edited metadata from.  Defaults to
#'   `"_metadata"`, meaning the `_metadata` table inside `base_id`.  Can also
#'   be a `data.frame`, a path to a `.csv` file, or a path to a `.json` file
#'   (see *Source precedence* above).
#' @return Invisible `NULL`. Side-effect: PATCHes changed fields in the base.
#' @examples
#' \dontrun{
#' # 1. Seed the _metadata table from the live schema (run once)
#' air_meta_init("appXXXXXX")
#'
#' # 2. Edit field_name / description cells directly in Airtable ...
#'
#' # 3. Pull edits back and patch the schema
#' air_meta_sync("appXXXXXX")
#'
#' # 4. Alternatively, sync from a local CSV
#' air_meta_sync("appXXXXXX", source = "my_meta.csv")
#' }
#' @export
air_meta_sync <- function(base_id, source = "_metadata", ..., .token = NULL) {
  check_string(base_id)

  meta <- .resolve_meta_source(source, base_id = base_id, .token = .token)

  # Drop bookkeeping columns produced by air_meta_init() before passing on
  meta <- meta[, intersect(
    c("table_name", "table_id", "field_name", "field_id",
      "field_type", "description"),
    names(meta)
  ), drop = FALSE]

  air_meta_push(base_id, meta = meta, .token = .token)
}

#' Seed the _metadata table from the live schema
#'
#' Reads the current base schema via [air_meta()] and upserts it into a
#' designated table within the same base.  Run this **once** to initialise the
#' metadata store, then edit the table in Airtable and call [air_meta_sync()]
#' to push changes back.
#'
#' @inheritParams air_read
#' @param meta_table Name of the table to store metadata in.
#'   Default `"_metadata"`.
#' @return Invisible upsert result.
#' @examples
#' \dontrun{
#' # Initialise the _metadata table
#' air_meta_init("appXXXXXX")
#'
#' # Use a custom table name
#' air_meta_init("appXXXXXX", meta_table = "_docs")
#' }
#' @export
air_meta_init <- function(base_id, meta_table = "_metadata", .token = NULL) {
  check_string(base_id)
  check_string(meta_table)

  meta <- air_meta(base_id, .token = .token)

  # Use table_name + field_name as the merge key (composite via concat)
  meta$meta_key <- paste(meta$table_name, meta$field_name, sep = "||")

  air_upsert(
    data = meta,
    base_id = base_id,
    table = meta_table,
    merge_on = "meta_key",
    typecast = TRUE,
    add_fields = "yes",
    .token = .token
  )
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' Resolve a metadata source to a data.frame
#'
#' @param source data.frame, file path, or table name.
#' @param base_id Airtable base ID.
#' @param .token API token.
#' @return A data.frame with at least field_id, table_id, field_name,
#'   description columns.
#' @noRd
.resolve_meta_source <- function(source, base_id, .token) {
  if (is.data.frame(source)) {
    return(source)
  }

  if (is.character(source) && length(source) == 1L) {
    # Check for existing file path with known extension
    if (file.exists(source)) {
      ext <- tolower(tools::file_ext(source))
      if (ext == "csv") {
        return(utils::read.csv(source, stringsAsFactors = FALSE,
                               check.names = FALSE))
      }
      if (ext == "json") {
        return(jsonlite::fromJSON(source, simplifyDataFrame = TRUE))
      }
      cli_abort(
        "File {.path {source}} has unsupported extension {.val {ext}}.
        Only .csv and .json are supported."
      )
    }

    # Otherwise treat as a table name in the base
    return(air_read(source, base_id = base_id, .token = .token))
  }

  cli_abort(
    "{.arg source} must be a data.frame, a file path (.csv/.json),
     or a table name (character string)."
  )
}
