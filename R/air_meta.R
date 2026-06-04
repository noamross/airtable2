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

#' Sync metadata to a table within the base itself
#'
#' Makes the base self-documenting by upserting the metadata tibble into a
#' designated table within the same base.
#'
#' @inheritParams air_read
#' @param meta_table Name of the table to store metadata in.
#'   Default `"_metadata"`.
#' @return Invisible upsert result.
#' @export
air_meta_sync <- function(base_id, meta_table = "_metadata", .token = NULL) {
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
