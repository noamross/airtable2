# Type flattening/expansion helpers for complex Airtable columns
#
# These help users work with list-columns in a flat-friendly way.

#' Flatten a multi-select list-column to delimited strings
#'
#' @param x A list-column where each element is a character vector.
#' @param sep Delimiter to join values. Default `", "`.
#' @return A character vector.
#' @export
air_flatten_multiselect <- function(x, sep = ", ") {
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
#' @param sep Delimiter to split on. Default `", "`.
#' @return A list of character vectors.
#' @export
air_expand_multiselect <- function(x, sep = ", ") {
  lapply(x, function(val) {
    if (is.na(val)) {
      return(NULL)
    }
    trimws(strsplit(val, sep, fixed = TRUE)[[1]])
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
#' @param sep Delimiter. Default `", "`.
#' @return A character vector.
#' @export
air_flatten_links <- function(x, sep = ", ") {
  air_flatten_multiselect(x, sep = sep)
}

#' Flatten an attachments list-column to a summary string
#'
#' @param x A list-column where each element is a data frame or list of
#'   attachment objects.
#' @param field Which attachment field to extract (e.g., `"filename"`, `"url"`).
#'   Default `"filename"`.
#' @param sep Delimiter. Default `", "`.
#' @return A character vector.
#' @export
air_flatten_attachments <- function(x, field = "filename", sep = ", ") {
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
              paste(format(v), collapse = ", ")
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
            paste(format(v), collapse = ", ")
          }
        },
        character(1)
      )
    }
  }

  data
}
