# Per-workspace API call counter -------------------------------------------
#
# Airtable free/team plans cap each WORKSPACE at ~1000 API calls/month. We
# cannot query the remaining quota, so we keep our own best-effort tally.
#
# Storage: one JSON file per workspace under
#   file.path(tools::R_user_dir("airtable2", "data"), "<workspace_id>.json")
# holding list(workspace_id, count, since, last) where `since` is the start of
# the current UTC month and `last` is the ISO-8601 UTC time of the most recent
# call. The count resets at 00:00 UTC on the first of each month.
#
# Attribution: all calls count against the configured default workspace
# (airtable2.workspace_id option or AIRTABLE_WORKSPACE_ID env var), else "unknown".
#
# Counting is best-effort: all file I/O is wrapped in try() so it can never
# break a real request. Disable with options(airtable2.count_api = FALSE) or
# AIRTABLE2_COUNT_API=false.

#' Report Airtable API usage for a workspace
#'
#' Returns this session's best-effort tally of API calls made against a
#' workspace during the current calendar month (UTC). Airtable free/team plans
#' cap each workspace at roughly 1000 calls per month and provide no way to
#' query the remaining quota, so `airtable2` keeps its own counter on disk.
#'
#' @param workspace Workspace ID (starts with `wsp`). Defaults to the configured
#'   default workspace (`getOption("airtable2.workspace_id")` or
#'   `Sys.getenv("AIRTABLE_WORKSPACE_ID")`).
#' @return A list of class `air_api_usage` with elements `workspace_id`,
#'   `count`, `since`, and `last`. Has a `{cli}` print method.
#' @examples
#' \dontrun{
#' air_api_usage("wspXXXXXXXXXXXXXX")
#' }
#' @export
air_api_usage <- function(workspace = NULL) {
  workspace_id <- workspace %||% default_workspace_id()
  if (!nzchar(workspace_id)) {
    workspace_id <- "unknown"
  }
  data <- read_api_counter(workspace_id)
  structure(
    list(
      workspace_id = workspace_id,
      count = as.integer(data$count %||% 0L),
      since = data$since,
      last = data$last
    ),
    class = "air_api_usage"
  )
}

#' @export
print.air_api_usage <- function(x, ...) {
  limit <- 1000L
  n <- x$count
  ws <- if (identical(x$workspace_id, "unknown")) {
    "unknown workspace"
  } else {
    x$workspace_id
  }
  cli::cli_text("Airtable API usage for {.val {ws}}")
  cli::cli_text("{n} API call{?s} since start of month ({x$since})")
  if (!is.null(x$last) && !is.na(x$last)) {
    cli::cli_text("Most recent call: {x$last}")
  }
  cli::cli_text(
    "Free plan ceiling: ~{limit} calls per workspace per month. 100,000 for team plan."
  )
  invisible(x)
}

# --- Internal helpers ------------------------------------------------------

#' Count one API call, attributing it to a workspace. Best-effort.
#' @noRd
count_api_call <- function(req, n = 1L) {
  if (!api_counter_enabled()) {
    return(invisible(NULL))
  }
  try(
    {
      workspace_id <- attribute_workspace(req)
      now <- Sys.time()
      data <- read_api_counter(workspace_id, now = now)
      data$count <- (data$count %||% 0L) + n
      data$last <- iso_utc(now)
      write_api_counter(workspace_id, data)
    },
    silent = TRUE
  )
  invisible(NULL)
}

#' Is on-disk API counting enabled?
#' @noRd
api_counter_enabled <- function() {
  opt <- getOption("airtable2.count_api", NULL)
  if (!is.null(opt)) {
    return(isTRUE(opt))
  }
  env <- Sys.getenv("AIRTABLE2_COUNT_API", unset = "true")
  !tolower(trimws(env)) %in% c("false", "0", "no", "off")
}

#' Determine the workspace a request should count against (no API calls).
#' @noRd
attribute_workspace <- function(req) {
  ws <- default_workspace_id()
  if (nzchar(ws)) ws else "unknown"
}

#' Default workspace ID from option/env, without any API call.
#' @noRd
default_workspace_id <- function() {
  ws <- getOption("airtable2.workspace_id", "")
  if (is.null(ws) || !nzchar(ws)) {
    ws <- Sys.getenv("AIRTABLE_WORKSPACE_ID", unset = "")
  }
  ws %||% ""
}

#' Directory holding counter files (overridable in tests via R_USER_DATA_DIR).
#' @noRd
api_counter_dir <- function() {
  tools::R_user_dir("airtable2", "data")
}

#' @noRd
api_counter_file <- function(workspace_id) {
  file.path(api_counter_dir(), paste0(workspace_id, ".json"))
}

#' Read a workspace counter, applying the monthly reset. Never errors.
#' @noRd
read_api_counter <- function(workspace_id, now = Sys.time()) {
  month_start <- utc_month_start(now)
  default <- list(
    workspace_id = workspace_id,
    count = 0L,
    since = iso_utc(month_start),
    last = NA_character_
  )
  f <- api_counter_file(workspace_id)
  if (!file.exists(f)) {
    return(default)
  }
  data <- tryCatch(
    jsonlite::read_json(f, simplifyVector = TRUE),
    error = function(e) NULL
  )
  if (is.null(data) || is.null(data$count)) {
    return(default)
  }
  since <- tryCatch(
    as.POSIXct(data$since, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
    error = function(e) NA
  )
  if (length(since) != 1L || is.na(since) || since < month_start) {
    data$count <- 0L
    data$since <- iso_utc(month_start)
  }
  data$workspace_id <- workspace_id
  data
}

#' Write a workspace counter to disk. Never errors (caller wraps in try()).
#' @noRd
write_api_counter <- function(workspace_id, data) {
  dir <- api_counter_dir()
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  jsonlite::write_json(
    list(
      workspace_id = workspace_id,
      count = as.integer(data$count),
      since = data$since,
      last = data$last %||% NA_character_
    ),
    api_counter_file(workspace_id),
    auto_unbox = TRUE,
    null = "null"
  )
  invisible(NULL)
}

#' Start of the current month in UTC, as POSIXct.
#' @noRd
utc_month_start <- function(now = Sys.time()) {
  lt <- as.POSIXlt(now, tz = "UTC")
  lt$mday <- 1L
  lt$hour <- 0L
  lt$min <- 0L
  lt$sec <- 0
  as.POSIXct(lt, tz = "UTC")
}

#' Format a time as ISO-8601 UTC (e.g. "2026-06-01T00:00:00Z").
#' @noRd
iso_utc <- function(t) {
  format(as.POSIXct(t, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}
