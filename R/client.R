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
#' @param endpoint Path appended to the host root
#'   (e.g., `"meta/bases"` or `"appXXX/TableName"`).
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @param host Which Airtable host to target: `"api"` (the default REST API at
#'   `https://api.airtable.com/v0`) or `"content"` (the attachment-upload host
#'   at `https://content.airtable.com/v0`).
#' @return An `httr2_request` object ready for further modification.
#' @export
air_req <- function(endpoint, token = NULL, host = c("api", "content")) {
  host <- match.arg(host)
  token <- air_token(token)
  root <- if (host == "content") content_url() else base_url()

  segments <- strsplit(endpoint, "/", fixed = TRUE)[[1L]]
  encoded  <- vapply(segments, utils::URLencode, character(1L), reserved = TRUE)

  httr2::request(root) |>
    httr2::req_url_path_append(encoded) |>
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
  resp <- tryCatch(httr2::req_perform(req), httr2_http = function(cnd) {
    # A request that reaches the server (even a 4xx/5xx) still consumes quota.
    count_api_call(req)

    status <- httr2::resp_status(cnd$resp)
    status_desc <- httr2::resp_status_desc(cnd$resp)

    # Airtable's error field may be an object {type, message} or a bare string.
    body <- tryCatch(httr2::resp_body_json(cnd$resp), error = function(e) NULL)
    parsed <- parse_airtable_error(body)

    bullets <- c(
      "Airtable API error ({status} {status_desc})."
    )
    if (!is.na(parsed$type)) {
      bullets <- c(bullets, x = "{parsed$type}")
    }
    if (!is.na(parsed$message)) {
      bullets <- c(bullets, x = "{parsed$message}")
    }

    # Name the base/table from the URL (helps spot a wrong table name).
    ids <- tryCatch(airtable_url_ids(cnd$request$url), error = function(e) NULL)
    if (!is.null(ids) && !is.na(ids$table)) {
      bullets <- c(
        bullets,
        i = "Request was for table {.val {ids$table}} in base {.val {ids$base_id}}."
      )
    }

    bullets <- c(
      bullets,
      airtable_error_hint(parsed$type, cnd$request$url)
    )

    cli_abort(bullets, call = call, parent = cnd)
  })
  count_api_call(req)
  httr2::resp_body_json(resp)
}

#' Resolve the progress bar flag for paginate/batch operations.
#' NULL → check option airtable2.progress.bar / env AIRTABLE2_PROGRESS_BAR
#' (default TRUE). Also sets cli.progress_show_after = 5 in the caller's
#' frame when progress is TRUE and the user has not configured it, so bars
#' only appear for operations that take more than 5 seconds.
#' @noRd
resolve_progress <- function(progress, .envir = rlang::caller_env()) {
  result <- if (!is.null(progress)) {
    isTRUE(progress)
  } else {
    opt <- getOption("airtable2.progress.bar", NULL)
    if (!is.null(opt)) {
      isTRUE(opt)
    } else {
      env <- Sys.getenv("AIRTABLE2_PROGRESS_BAR", unset = "")
      if (!nzchar(env)) TRUE else !tolower(trimws(env)) %in% c("false", "0", "no", "off")
    }
  }
  if (result && is.null(getOption("cli.progress_show_after"))) {
    withr::local_options(cli.progress_show_after = 5, .local_envir = .envir)
  }
  result
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
#'   `AIRTABLE2_PROGRESS_BAR` (both default to `TRUE`).
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

  pb <- NULL
  if (progress && !is.null(page_size) && max_records == Inf) {
    pb <- cli::cli_progress_bar(
      name  = "Fetching records",
      total = NA,
      clear = FALSE
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

    if (!is.null(pb)) {
      cli::cli_progress_update(
        id     = pb,
        set    = total_fetched,
        status = paste0(total_fetched, " records")
      )
    }

    offset <- body$offset
    if (is.null(offset) || remaining <= 0) break
  }

  if (!is.null(pb)) {
    cli::cli_progress_done(id = pb)
  }

  collected
}
