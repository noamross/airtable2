#' Build a table template specification
#'
#' Convenience function for constructing table configurations suitable for
#' [at_create_table()] or [at_create_base()].
#'
#' @param name Table name.
#' @param fields A list of field specifications (e.g., from
#'   [air_field_template()]).
#' @param description Optional table description.
#' @return A list suitable for passing to the Airtable API.
#' @examples
#' fields <- list(
#'   air_field_template("Name", "singleLineText"),
#'   air_field_template("Score", "number", options = list(precision = 2))
#' )
#' air_table_template("Results", fields, description = "Exam results")
#' @export
air_table_template <- function(name, fields, description = NULL) {
  check_string(name)
  compact(list(name = name, description = description, fields = fields))
}

#' Build a field template specification
#'
#' Convenience function for constructing field configurations.
#'
#' @param name Field name.
#' @param type Field type (e.g., `"singleLineText"`, `"number"`,
#'   `"singleSelect"`).
#' @param description Optional field description.
#' @param options Optional field-specific options (list). See Airtable docs
#'   for available options per type.
#' @return A list suitable for use in [air_table_template()] or
#'   [at_create_field()].
#' @examples
#' air_field_template("Status", "singleSelect",
#'   options = list(choices = list(
#'     list(name = "Active"), list(name = "Inactive")
#'   ))
#' )
#' @export
air_field_template <- function(name, type, description = NULL, options = NULL) {
  check_string(name)
  check_string(type)
  compact(list(
    name = name,
    type = type,
    description = description,
    options = options
  ))
}

#' Infer Airtable field specifications from a data frame
#'
#' Maps R column types to Airtable field types. The first column becomes the
#' primary field. Factors are mapped to `singleSelect` with levels as choices.
#'
#' @param data A data frame with at least one column.
#' @return A list of field specification lists suitable for [at_create_table()].
#' @examples
#' df <- data.frame(Name = "Alice", Score = 3.14, Active = TRUE)
#' air_infer_fields(df)
#' @export
air_infer_fields <- function(data) {
  if (ncol(data) == 0L) {
    cli_abort("Data frame must have at least one column.")
  }
  lapply(names(data), function(nm) {
    col <- data[[nm]]
    if (inherits(col, "Date")) {
      list(name = nm, type = "date",
           options = list(dateFormat = list(name = "iso")))
    } else if (is.factor(col)) {
      choices <- lapply(levels(col), function(lvl) list(name = lvl))
      list(name = nm, type = "singleSelect",
           options = list(choices = choices))
    } else if (is.integer(col) && !is.object(col)) {
      list(name = nm, type = "number", options = list(precision = 0L))
    } else if (is.double(col) && !is.object(col)) {
      list(name = nm, type = "number", options = list(precision = 8L))
    } else if (is.logical(col) && !is.object(col)) {
      list(name = nm, type = "checkbox",
           options = list(icon = "check", color = "greenBright"))
    } else {
      list(name = nm, type = "singleLineText")
    }
  })
}

#' Infer an Airtable table specification from a data frame
#'
#' Wraps [air_infer_fields()] to produce a complete table spec suitable for
#' [at_create_table()] or [at_create_base()].
#'
#' @param data A data frame with at least one column.
#' @param name Table name.
#' @param description Optional table description.
#' @return A list with `name`, `fields`, and optionally `description`.
#' @examples
#' df <- data.frame(Name = "Alice", Score = 3.14)
#' air_infer_table(df, "Results")
#' @export
air_infer_table <- function(data, name, description = NULL) {
  check_string(name)
  fields <- air_infer_fields(data)
  spec <- list(name = name, fields = fields)
  if (!is.null(description)) spec$description <- description
  spec
}
