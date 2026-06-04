#' Resolve an Airtable personal access token
#'
#' Looks for a token in this order:
#' 1. Explicit `.token` argument
#' 2. `getOption("airtable2.token")`
#' 3. `Sys.getenv("AIRTABLE_API_KEY")`
#'
#' @param token A personal access token string, or `NULL` to use defaults.
#' @return A string (the token).
#' @examples
#' \dontrun{
#' # Uses AIRTABLE_API_KEY env var by default
#' token <- air_token()
#'
#' # Or pass explicitly
#' token <- air_token("patXXXXXXXX")
#' }
#' @export
air_token <- function(token = NULL) {
  token <- token %||%
    getOption("airtable2.token") %||%
    Sys.getenv("AIRTABLE_API_KEY", unset = "")

  if (!nzchar(token)) {
    cli_abort(c(
      "No Airtable token found.",
      i = "Supply {.arg token}, set {.code options(airtable2.token = ...)} ,
          or set env var {.envvar AIRTABLE_API_KEY}."
    ))
  }
  token
}

#' Build an httr2 request to the Airtable API
#'
#' Constructs a base request with auth, user-agent, retry policy, and throttle.
#'
#' @param endpoint Path appended to `https://api.airtable.com/v0`
#'   (e.g., `"meta/bases"` or `"appXXX/TableName"`).
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return An `httr2_request` object ready for further modification.
#' @export
air_req <- function(endpoint, token = NULL) {
  token <- air_token(token)

  httr2::request(base_url()) |>
    httr2::req_url_path_append(endpoint) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_user_agent(paste0(
      "airtable2/",
      utils::packageVersion("airtable2")
    )) |>
    httr2::req_retry(
      max_seconds = 60,
      is_transient = function(resp) {
        httr2::resp_status(resp) == 429L
      },
    ) |>
    httr2::req_throttle(capacity = 5, fill_time_s = 1)
}

#' Perform a request and parse the JSON response
#' @noRd
air_perform <- function(req, call = rlang::caller_env()) {
  resp <- tryCatch(httr2::req_perform(req), httr2_http_error = function(cnd) {
    # A request that reaches the server (even a 4xx/5xx) still consumes quota.
    count_api_call(req)
    # Extract Airtable error info if available
    body <- tryCatch(httr2::resp_body_json(cnd$resp), error = function(e) NULL)
    msg <- body$error$message %||% httr2::resp_status_desc(cnd$resp)
    cli_abort(
      c("Airtable API error ({httr2::resp_status(cnd$resp)}).", x = msg),
      call = call,
      parent = cnd
    )
  })
  count_api_call(req)
  httr2::resp_body_json(resp)
}

#' Resolve the progress bar flag for paginate/batch operations.
#' NULL → check option airtable2.progress.bar / env AIRTABLE2_PROGRESS_BAR
#' (default FALSE so tests are silent by default).
#' @noRd
resolve_progress <- function(progress) {
  if (!is.null(progress)) return(isTRUE(progress))
  opt <- getOption("airtable2.progress.bar", NULL)
  if (!is.null(opt)) return(isTRUE(opt))
  env <- Sys.getenv("AIRTABLE2_PROGRESS_BAR", unset = "false")
  !tolower(trimws(env)) %in% c("false", "0", "no", "off")
}

#' Paginate through all pages of a list endpoint
#'
#' Repeatedly calls `req`, following the `offset` token until exhausted
#' or `max_records` is reached.
#'
#' @param req An `httr2_request` for a list endpoint.
#' @param page_size Number of records per page (max 100). Set to `NULL` to
#'   omit the `pageSize` query parameter (for endpoints that don't support it).
#' @param max_records Maximum total records to fetch (`Inf` for all).
#' @param record_accessor Function to extract records from the parsed response
#'   body. Defaults to `function(body) body$records`.
#' @param progress Logical or `NULL`. If `TRUE`, shows a cli progress bar.
#'   If `NULL` (default), uses option `airtable2.progress.bar` or env var
#'   `AIRTABLE2_PROGRESS_BAR` (both default to `FALSE`).
#' @return A list of all collected items.
#' @noRd
air_paginate <- function(
  req,
  page_size = 100L,
  max_records = Inf,
  record_accessor = function(body) body$records,
  progress = NULL
) {
  progress <- resolve_progress(progress)

  collected <- list()
  offset <- NULL
  remaining <- max_records
  total_fetched <- 0L

  # Set up progress bar if requested
  pb <- NULL
  if (progress && !is.null(page_size) && max_records == Inf) {
    pb <- cli::cli_progress_bar(
      total = NA,
      clear = FALSE,
      display = "Fetching records..."
    )
  }

  repeat {
    page_req <- req

    if (!is.null(page_size)) {
      this_size <- min(page_size, remaining)
      page_req <- page_req |> httr2::req_url_query(pageSize = this_size)
    }

    if (!is.null(offset)) {
      page_req <- page_req |> httr2::req_url_query(offset = offset)
    }

    body <- air_perform(page_req)
    records <- record_accessor(body)

    if (length(records) == 0L) {
      break
    }

    collected <- c(collected, records)
    total_fetched <- total_fetched + length(records)
    remaining <- remaining - length(records)

    # Update progress bar
    if (!is.null(pb)) {
      pb$set(
        total_fetched,
        message = paste("Fetched", total_fetched, "records")
      )
    }

    offset <- body$offset
    if (is.null(offset) || remaining <= 0) break
  }

  # Clear progress bar
  if (!is.null(pb)) {
    pb$set(
      total_fetched,
      done = TRUE,
      message = paste("Fetched", total_fetched, "records")
    )
  }

  collected
}
