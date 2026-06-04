# Type flattening/expansion helpers for complex Airtable columns
#
# These help users work with list-columns in a flat-friendly way.

#' @noRd
resolve_delimiter <- function(sep = NULL) {
  if (!is.null(sep)) return(sep)
  opt <- getOption("airtable2.delimiter", NULL)
  if (!is.null(opt)) return(opt)
  env <- Sys.getenv("AIRTABLE2_DELIMITER", unset = "")
  if (nzchar(env)) env else "; "
}

#' Flatten a multi-select list-column to delimited strings
#'
#' @param x A list-column where each element is a character vector.
#' @param sep Delimiter to join values. Default `"; "`, overridable via
#'   `options(airtable2.delimiter = ...)` or the `AIRTABLE2_DELIMITER`
#'   environment variable. An explicit `sep` argument always takes precedence.
#' @return A character vector.
#' @export
air_flatten_multiselect <- function(x, sep = NULL) {
  sep <- resolve_delimiter(sep)
  vapply(
    x,
    function(val) {
      if (is.null(val) || length(val) == 0L) {
        return(NA_character_)
      }
      paste(val, collapse = sep)
    },
    character(1)
  )
}

#' Expand delimited strings to a multi-select list-column
#'
#' Inverse of [air_flatten_multiselect()].
#'
#' @param x A character vector of delimited values.
#' @param sep Delimiter to split on. Default `"; "` (tolerates optional
#'   surrounding spaces when the delimiter is a semicolon family), overridable
#'   via `options(airtable2.delimiter = ...)` or the `AIRTABLE2_DELIMITER`
#'   environment variable. An explicit `sep` argument always takes precedence.
#' @return A list of character vectors.
#' @export
air_expand_multiselect <- function(x, sep = NULL) {
  sep <- resolve_delimiter(sep)
  # When the delimiter is semicolon-based (default or env/option returning ";")
  # use a regex that tolerates optional surrounding whitespace so that
  # "A; B", "A;B", and "A ; B" all split correctly.
  is_semi <- grepl(";", sep, fixed = TRUE)
  lapply(x, function(val) {
    if (is.na(val)) {
      return(NULL)
    }
    if (is_semi) {
      trimws(strsplit(val, "\\s*;\\s*")[[1]])
    } else {
      trimws(strsplit(val, sep, fixed = TRUE)[[1]])
    }
  })
}

#' Flatten a collaborator list-column to strings
#'
#' @param x A list-column where each element is a named list with `name`
#'   and `email` fields.
#' @param format A glue-style template. Available fields: `id`, `email`, `name`.
#'   Default: `"{name} <{email}>"`.
#' @return A character vector.
#' @export
air_flatten_collaborator <- function(x, format = "{name} <{email}>") {
  vapply(
    x,
    function(val) {
      if (is.null(val)) {
        return(NA_character_)
      }
      glue::glue(format, .envir = as.environment(val))
    },
    character(1)
  )
}

#' Expand collaborator strings to list-column
#'
#' Inverse of [air_flatten_collaborator()].
#'
#' @param x A character vector (e.g., `"Name <email>"`)
#' @param pattern Regex with two capture groups (name, email).
#'   Default: `"(.+) <(.+)>"`.
#' @return A list of named lists with `name` and `email`.
#' @export
air_expand_collaborator <- function(x, pattern = "(.+) <(.+)>") {
  lapply(x, function(val) {
    if (is.na(val)) {
      return(NULL)
    }
    m <- regmatches(val, regexec(pattern, val))[[1]]
    if (length(m) < 3L) {
      return(list(name = val, email = NA_character_))
    }
    list(name = m[[2]], email = m[[3]])
  })
}

#' Flatten a record-links list-column to delimited strings
#'
#' @param x A list-column where each element is a character vector of record IDs.
#' @param sep Delimiter. Default `"; "`, overridable via
#'   `options(airtable2.delimiter = ...)` or the `AIRTABLE2_DELIMITER`
#'   environment variable. An explicit `sep` argument always takes precedence.
#' @return A character vector.
#' @export
air_flatten_links <- function(x, sep = NULL) {
  air_flatten_multiselect(x, sep = resolve_delimiter(sep))
}

#' Flatten an attachments list-column to a summary string
#'
#' @param x A list-column where each element is a data frame or list of
#'   attachment objects.
#' @param field Which attachment field to extract (e.g., `"filename"`, `"url"`).
#'   Default `"filename"`.
#' @param sep Delimiter. Default `"; "`, overridable via
#'   `options(airtable2.delimiter = ...)` or the `AIRTABLE2_DELIMITER`
#'   environment variable. An explicit `sep` argument always takes precedence.
#' @return A character vector.
#' @export
air_flatten_attachments <- function(x, field = "filename", sep = NULL) {
  sep <- resolve_delimiter(sep)
  vapply(
    x,
    function(val) {
      if (is.null(val) || length(val) == 0L) {
        return(NA_character_)
      }
      # val can be a list of lists or a data frame
      if (is.data.frame(val)) {
        vals <- val[[field]]
      } else {
        vals <- vapply(
          val,
          function(a) a[[field]] %||% NA_character_,
          character(1)
        )
      }
      paste(vals[!is.na(vals)], collapse = sep)
    },
    character(1)
  )
}

#' Flatten a complex Airtable column to a simple atomic vector
#'
#' Generic that dispatches on the `air_*` S3 class of a column, applying the
#' appropriate per-type flattener. Plain (already-flat) vectors are returned
#' unchanged.
#'
#' @param x A column, typically an `air_*` list-column from [air_read()].
#' @param ... Passed to the underlying flattener, e.g. `sep`, `field`,
#'   `format`.
#' @return A character vector (or `x` unchanged for non-`air_*` input).
#' @export
air_flatten <- function(x, ...) {
  UseMethod("air_flatten")
}

#' @export
air_flatten.air_multiselect <- function(x, ...) {
  air_flatten_multiselect(unclass(x), ...)
}

#' @export
air_flatten.air_links <- function(x, ...) {
  air_flatten_links(unclass(x), ...)
}

#' @export
air_flatten.air_attachments <- function(x, ...) {
  air_flatten_attachments(unclass(x), ...)
}

#' @export
air_flatten.air_collaborator <- function(x, ...) {
  air_flatten_collaborator(unclass(x), ...)
}

#' @export
air_flatten.default <- function(x, ...) {
  x
}

#' Simplify all complex columns in a tibble for display/export
#'
#' Applies the appropriate flatten function to each list-column based on
#' schema information.
#'
#' @param data A tibble (typically from [air_read()]).
#' @param schema Optional list of field definitions (from [at_get_schema()]).
#'   If `NULL`, uses heuristics.
#' @return A tibble with list-columns replaced by character representations.
#' @export
air_simplify <- function(data, schema = NULL) {
  # Build type lookup from schema
  type_lookup <- NULL
  if (!is.null(schema)) {
    type_lookup <- stats::setNames(
      vapply(schema, function(f) f$type %||% "unknown", character(1)),
      vapply(schema, function(f) f$name, character(1))
    )
  }

  for (col_name in names(data)) {
    col <- data[[col_name]]
    if (!is.list(col)) {
      next
    }

    # Classed air_* columns: route through the air_flatten() generic.
    air_classes <- c(
      "air_multiselect",
      "air_links",
      "air_attachments",
      "air_collaborator"
    )
    if (inherits(col, air_classes)) {
      data[[col_name]] <- air_flatten(col)
      next
    }

    field_type <- type_lookup[[col_name]]

    data[[col_name]] <- if (!is.null(field_type)) {
      switch(
        field_type,
        multipleSelects = air_flatten_multiselect(col),
        multipleRecordLinks = air_flatten_links(col),
        multipleAttachments = air_flatten_attachments(col),
        collaborator = air_flatten_collaborator(col),
        # Default: paste elements together
        vapply(
          col,
          function(v) {
            if (is.null(v)) {
              NA_character_
            } else {
              paste(format(v), collapse = "; ")
            }
          },
          character(1)
        )
      )
    } else {
      # Heuristic: just paste
      vapply(
        col,
        function(v) {
          if (is.null(v)) {
            NA_character_
          } else {
            paste(format(v), collapse = "; ")
          }
        },
        character(1)
      )
    }
  }

  data
}
