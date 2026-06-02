#' Resolve an Airtable personal access token
#'
#' Looks for a token in this order:
#' 1. Explicit `token` argument
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
      max_tries = 3,
      is_transient = function(resp) httr2::resp_status(resp) == 429L,
      backoff = ~30
    ) |>
    httr2::req_throttle(rate = 5 / 1)
}

#' Perform a request and parse the JSON response
#' @noRd
air_perform <- function(req, call = rlang::caller_env()) {
  resp <- tryCatch(httr2::req_perform(req), httr2_http_error = function(cnd) {
    # Extract Airtable error info if available
    body <- tryCatch(httr2::resp_body_json(cnd$resp), error = function(e) NULL)
    msg <- body$error$message %||% httr2::resp_status_desc(cnd$resp)
    cli_abort(
      c("Airtable API error ({httr2::resp_status(cnd$resp)}).", x = msg),
      call = call,
      parent = cnd
    )
  })
  httr2::resp_body_json(resp)
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
#' @return A list of all collected items.
#' @noRd
air_paginate <- function(
  req,
  page_size = 100L,
  max_records = Inf,
  record_accessor = function(body) body$records
) {
  collected <- list()
  offset <- NULL
  remaining <- max_records

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
    remaining <- remaining - length(records)

    offset <- body$offset
    if (is.null(offset) || remaining <= 0) break
  }

  collected
}
