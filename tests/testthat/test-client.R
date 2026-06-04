test_that("air_token errors with no token available", {
  withr::local_envvar(AIRTABLE_API_KEY = "")
  withr::local_options(airtable2.token = NULL)
  expect_error(air_token(), "No Airtable token found")
})

test_that("air_token resolves from explicit argument", {
  expect_equal(air_token("pat_test123"), "pat_test123")
})

test_that("air_token resolves from option", {
  withr::local_envvar(AIRTABLE_API_KEY = "")
  withr::local_options(airtable2.token = "pat_from_option")
  expect_equal(air_token(), "pat_from_option")
})

test_that("air_token resolves from env var", {
  withr::local_envvar(AIRTABLE_API_KEY = "pat_from_env")
  withr::local_options(airtable2.token = NULL)
  expect_equal(air_token(), "pat_from_env")
})

test_that("air_token prefers option over env var", {
  withr::local_envvar(AIRTABLE_API_KEY = "pat_from_env")
  withr::local_options(airtable2.token = "pat_from_option")
  expect_equal(air_token(), "pat_from_option")
})

test_that("air_req builds proper request", {
  withr::local_envvar(AIRTABLE_API_KEY = "pat_test_req")
  req <- air_req("appABC123/TableName")
  expect_s3_class(req, "httr2_request")
  expect_true(grepl("api.airtable.com/v0/appABC123/TableName", req$url))
})

# --- parse_airtable_error() ----------------------------------------------

test_that("parse_airtable_error handles error-as-object", {
  body <- list(error = list(
    type = "UNKNOWN_FIELD_NAME",
    message = "Unknown field name: \"Score\""
  ))
  out <- parse_airtable_error(body)
  expect_equal(out$type, "UNKNOWN_FIELD_NAME")
  expect_equal(out$message, "Unknown field name: \"Score\"")
})

test_that("parse_airtable_error handles error-as-bare-string", {
  out <- parse_airtable_error(list(error = "NOT_FOUND"))
  expect_equal(out$type, "NOT_FOUND")
  expect_true(is.na(out$message))
})

test_that("parse_airtable_error handles NULL and missing", {
  out <- parse_airtable_error(NULL)
  expect_true(is.na(out$type))
  expect_true(is.na(out$message))

  out2 <- parse_airtable_error(list(foo = "bar"))
  expect_true(is.na(out2$type))
  expect_true(is.na(out2$message))
})

# --- airtable_url_ids() --------------------------------------------------

test_that("airtable_url_ids parses base and table from a record URL", {
  out <- airtable_url_ids("https://api.airtable.com/v0/appABC123/My%20Table")
  expect_equal(out$base_id, "appABC123")
  expect_equal(out$table, "My Table")
})

test_that("airtable_url_ids returns NULL for meta endpoints", {
  expect_null(airtable_url_ids("https://api.airtable.com/v0/meta/bases"))
})

test_that("airtable_url_ids returns NULL when no path segments", {
  expect_null(airtable_url_ids("https://api.airtable.com/v0/"))
})

# --- airtable_error_hint() -----------------------------------------------

test_that("airtable_error_hint gives hints for known types", {
  expect_match(
    paste(airtable_error_hint("UNKNOWN_FIELD_NAME"), collapse = " "),
    "at_get_schema"
  )
  expect_match(
    paste(
      airtable_error_hint("INVALID_PERMISSIONS_OR_MODEL_NOT_FOUND"),
      collapse = " "
    ),
    "token|exist|access"
  )
  expect_match(
    paste(airtable_error_hint("INVALID_FILTER_BY_FORMULA"), collapse = " "),
    "formula"
  )
  expect_length(airtable_error_hint("SOMETHING_ELSE"), 0L)
  expect_length(airtable_error_hint(NA_character_), 0L)
})

# --- air_perform() error handling (mocked) -------------------------------

# Build a request that air_perform can run against a mocked response.
mock_req <- function(url = "https://api.airtable.com/v0/appABC/Contacts") {
  httr2::request(url) |>
    httr2::req_error(is_error = function(resp) httr2::resp_status(resp) >= 400)
}

# Construct a JSON response with a given status.
json_resp <- function(status, body) {
  httr2::response_json(status = status, body = body)
}

test_that("422 UNKNOWN_FIELD_NAME surfaces message + field-listing hint", {
  resp <- json_resp(422, list(error = list(
    type = "UNKNOWN_FIELD_NAME",
    message = "Unknown field name: \"Score\""
  )))
  err <- tryCatch(
    httr2::with_mocked_responses(function(req) resp, {
      air_perform(mock_req())
    }),
    error = function(e) e
  )
  msg <- cli::ansi_strip(paste(
    conditionMessage(err),
    paste(err$body, collapse = "\n")
  ))
  expect_match(msg, "Unknown field name")
  expect_match(msg, "at_get_schema")
  expect_match(msg, "422")
})

test_that("403 INVALID_PERMISSIONS surfaces permissions/table hint", {
  resp <- json_resp(403, list(error = list(
    type = "INVALID_PERMISSIONS_OR_MODEL_NOT_FOUND",
    message = "Invalid permissions, or the requested model was not found."
  )))
  err <- tryCatch(
    httr2::with_mocked_responses(function(req) resp, {
      air_perform(mock_req())
    }),
    error = function(e) e
  )
  msg <- cli::ansi_strip(paste(
    conditionMessage(err),
    paste(err$body, collapse = "\n")
  ))
  expect_match(msg, "Invalid permissions")
  expect_match(msg, "at_get_schema")
  expect_match(msg, "403")
})

test_that("bare-string error body surfaces the string (not swallowed)", {
  resp <- json_resp(404, list(error = "NOT_FOUND"))
  err <- tryCatch(
    httr2::with_mocked_responses(function(req) resp, {
      air_perform(mock_req())
    }),
    error = function(e) e
  )
  msg <- cli::ansi_strip(paste(
    conditionMessage(err),
    paste(err$body, collapse = "\n")
  ))
  expect_match(msg, "NOT_FOUND")
})

test_that("non-JSON / empty body falls back to HTTP status description", {
  resp <- httr2::response(
    status_code = 500,
    headers = list("Content-Type" = "text/plain"),
    body = charToRaw("not json")
  )
  err <- tryCatch(
    httr2::with_mocked_responses(function(req) resp, {
      air_perform(mock_req())
    }),
    error = function(e) e
  )
  msg <- cli::ansi_strip(paste(
    conditionMessage(err),
    paste(err$body, collapse = "\n")
  ))
  # Should not error inside the handler; should mention the HTTP status.
  expect_s3_class(err, "rlang_error")
  expect_match(msg, "500")
})
