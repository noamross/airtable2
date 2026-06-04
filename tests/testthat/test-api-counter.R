# Unit tests for the per-workspace API call counter. No network access.

# Isolate counter state: temp data dir, counting enabled.
local_counter <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(R_USER_DATA_DIR = dir, .local_envir = env)
  withr::local_options(airtable2.count_api = TRUE, .local_envir = env)
  dir
}

fake_req <- function(url) {
  list(url = url)
}

test_that("count_api_call increments and persists per workspace", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspTEST1")
  req <- fake_req("https://api.airtable.com/v0/appABC123/Contacts")

  count_api_call(req)
  count_api_call(req)
  count_api_call(req)

  usage <- air_api_usage("wspTEST1")
  expect_s3_class(usage, "air_api_usage")
  expect_equal(usage$count, 3L)
  expect_equal(usage$workspace_id, "wspTEST1")
  expect_false(is.na(usage$last))
})

test_that("attribution uses default workspace, falls back to unknown", {
  local_counter()
  req <- fake_req("https://api.airtable.com/v0/appUNKNOWN/Contacts")

  withr::local_options(airtable2.workspace_id = "wspDEFAULT")
  expect_equal(attribute_workspace(req), "wspDEFAULT")

  withr::local_options(airtable2.workspace_id = NULL)
  withr::local_envvar(AIRTABLE_WORKSPACE_ID = "")
  expect_equal(attribute_workspace(req), "unknown")
})

test_that("monthly reset zeroes a stale count", {
  local_counter()
  stale_since <- iso_utc(utc_month_start(Sys.time()) - 60 * 60 * 24 * 40)
  write_api_counter("wspOLD", list(count = 50L, since = stale_since, last = NA))

  usage <- air_api_usage("wspOLD")
  expect_equal(usage$count, 0L)
  # `since` is reset to the current UTC month start.
  expect_equal(usage$since, iso_utc(utc_month_start(Sys.time())))
})

test_that("a current-month count is preserved on read", {
  local_counter()
  this_since <- iso_utc(utc_month_start(Sys.time()))
  write_api_counter("wspNOW", list(count = 7L, since = this_since, last = NA))
  expect_equal(air_api_usage("wspNOW")$count, 7L)
})

test_that("counting is a no-op when disabled", {
  dir <- withr::local_tempdir()
  withr::local_envvar(R_USER_DATA_DIR = dir)
  withr::local_options(airtable2.count_api = FALSE)
  req <- fake_req("https://api.airtable.com/v0/appABC123/Contacts")
  count_api_call(req)
  expect_false(file.exists(api_counter_file("appABC123")))
  expect_equal(air_api_usage("wspWHATEVER")$count, 0L)
})

test_that("air_api_usage prints a cli summary", {
  local_counter()
  write_api_counter(
    "wspPRINT",
    list(count = 5L, since = iso_utc(utc_month_start(Sys.time())), last = NA)
  )
  usage <- air_api_usage("wspPRINT")
  out <- cli::cli_fmt(print(usage))
  expect_true(any(grepl("API call", out)))
  expect_true(any(grepl("since start of month", out)))
  expect_invisible(print(usage))
})

