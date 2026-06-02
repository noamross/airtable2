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
#' @export
air_table_template <- function(name, fields, description = NULL) {
  check_string(name)
  compact(list(
    name = name,
    description = description,
    fields = fields
  ))
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
