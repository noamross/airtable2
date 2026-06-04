#' Join local data with an Airtable table
#'
#' Fetches a remote Airtable table and joins it with a local data frame.
#' These are convenience wrappers around [air_read()] plus base-R `merge()`.
#' The `...` are forwarded to [air_read()] (e.g. `formula`, `fields`).
#'
#' @param x A local data frame.
#' @inheritParams air_read
#' @param by Character vector of column name(s) to join on. If `NULL`,
#'   uses all column names shared between `x` and the remote table
#'   (excluding `airtable_id` and `airtable_created_time`).
#' @param ... Additional arguments passed to [air_read()].
#' @return A tibble.
#' @examples
#' \dontrun{
#' scores <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90, 85))
#' air_left_join(scores, "appXXXX", "Contacts", by = "Name")
#' }
#' @export
air_left_join <- function(x, base_id = NULL, table, by = NULL, ..., .token = NULL) {
  air_join_impl(x, base_id = base_id, table = table, by = by,
                all.x = TRUE, all.y = FALSE, ..., .token = .token)
}

#' @rdname air_left_join
#' @export
air_inner_join <- function(x, base_id = NULL, table, by = NULL, ..., .token = NULL) {
  air_join_impl(x, base_id = base_id, table = table, by = by,
                all.x = FALSE, all.y = FALSE, ..., .token = .token)
}

#' @rdname air_left_join
#' @export
air_full_join <- function(x, base_id = NULL, table, by = NULL, ..., .token = NULL) {
  air_join_impl(x, base_id = base_id, table = table, by = by,
                all.x = TRUE, all.y = TRUE, ..., .token = .token)
}

# --- Internal ---

#' @noRd
air_join_impl <- function(x, base_id, table, by, all.x, all.y, ..., .token) {
  if (!is.data.frame(x)) {
    cli_abort("{.arg x} must be a data frame.", call = rlang::caller_env())
  }
  base_id <- resolve_base_id(base_id)
  check_string(base_id)
  check_string(table)

  remote <- air_read(base_id = base_id, table = table, ..., .token = .token)

  if (is.null(by)) {
    meta_cols <- c("airtable_id", "airtable_created_time")
    by <- intersect(names(x), setdiff(names(remote), meta_cols))
    if (length(by) == 0L) {
      cli_abort(
        c(
          "x" = "No common columns between local data and {.val {table}}.",
          "i" = "Specify {.arg by} explicitly."
        ),
        call = rlang::caller_env()
      )
    }
    cli_inform("Joining on {.field {by}}.")
  }

  result <- merge(x, remote, by = by, all.x = all.x, all.y = all.y,
                  sort = FALSE, suffixes = c(".x", ".y"))
  tibble::as_tibble(result)
}
