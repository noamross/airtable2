# Unit tests for the per-workspace API call counter. No network access.

# Isolate counter state: temp data dir, counting enabled.
local_counter <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(R_USER_DATA_DIR = dir, .local_envir = env)
  withr::local_options(airtable2.count_api = TRUE, .local_envir = env)
  dir
}

fake_req <- function(url = "https://api.airtable.com/v0/appABC123/Contacts") {
  httr2::request(url)
}

# ── Basic counting ────────────────────────────────────────────────────────────

test_that("fresh workspace starts at count 0", {
  local_counter()
  usage <- air_api_usage("wspFRESH")
  expect_s3_class(usage, "air_api_usage")
  expect_equal(usage$count, 0L)
  expect_equal(usage$workspace_id, "wspFRESH")
})

test_that("count_api_call increments by 1 each call", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspTEST1")
  req <- fake_req()

  count_api_call(req)
  expect_equal(air_api_usage("wspTEST1")$count, 1L)

  count_api_call(req)
  expect_equal(air_api_usage("wspTEST1")$count, 2L)
})

test_that("count_api_call(req, n = 5) increments by exactly 5", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspBATCH")
  req <- fake_req()

  count_api_call(req, n = 5L)
  expect_equal(air_api_usage("wspBATCH")$count, 5L)
})

test_that("count_api_call increments persist and accumulate", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspTEST2")
  req <- fake_req()

  count_api_call(req)
  count_api_call(req)
  count_api_call(req)
  expect_equal(air_api_usage("wspTEST2")$count, 3L)
  expect_equal(air_api_usage("wspTEST2")$workspace_id, "wspTEST2")
  expect_false(is.na(air_api_usage("wspTEST2")$last))
})

test_that("n = 5 then n = 3 accumulates to 8", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspACCUM")
  req <- fake_req()

  count_api_call(req, n = 5L)
  count_api_call(req, n = 3L)
  expect_equal(air_api_usage("wspACCUM")$count, 8L)
})

# ── On-disk round-trip ────────────────────────────────────────────────────────

test_that("write then read preserves count and last timestamp", {
  local_counter()
  this_since <- iso_utc(utc_month_start(Sys.time()))
  ts <- iso_utc(Sys.time())
  write_api_counter("wspROUND", list(
    count = 42L,
    since = this_since,
    last  = ts
  ))
  data <- read_api_counter("wspROUND")
  expect_equal(data$count, 42L)
  expect_equal(data$since, this_since)
  expect_equal(data$last, ts)
})

test_that("count is stored as integer, not double", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspINT")
  req <- fake_req()

  count_api_call(req, n = 7L)
  usage <- air_api_usage("wspINT")
  expect_type(usage$count, "integer")
  expect_equal(usage$count, 7L)
})

# ── Monthly reset ─────────────────────────────────────────────────────────────

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

# ── Enable/disable ────────────────────────────────────────────────────────────

test_that("counting is a no-op when disabled", {
  dir <- withr::local_tempdir()
  withr::local_envvar(R_USER_DATA_DIR = dir)
  withr::local_options(airtable2.count_api = FALSE)
  req <- fake_req("https://api.airtable.com/v0/appABC123/Contacts")
  count_api_call(req)
  expect_false(file.exists(api_counter_file("appABC123")))
  expect_equal(air_api_usage("wspWHATEVER")$count, 0L)
})

# ── print method ──────────────────────────────────────────────────────────────

test_that("print.air_api_usage output contains API call info", {
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

test_that("print.air_api_usage contains the workspace id as visible text", {
  local_counter()
  write_api_counter(
    "wspLINK",
    list(count = 3L, since = iso_utc(utc_month_start(Sys.time())), last = NA)
  )
  usage <- air_api_usage("wspLINK")
  out <- paste(cli::cli_fmt(print(usage)), collapse = " ")
  # The workspace id must appear as visible text (hyperlink escape wraps it
  # but the id itself remains in the output string).
  expect_true(grepl("wspLINK", out, fixed = TRUE))
})

# ── Parallel download counting ────────────────────────────────────────────────

test_that("parallel blob download increments counter by number of requests", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspPAR")

  # Build a tibble with 3 attachment URLs across 2 records
  tbl <- tibble::tibble(
    airtable_id = c("rec1", "rec2"),
    Photos = list(
      list(
        list(url = "https://example.com/a.jpg", filename = "a.jpg"),
        list(url = "https://example.com/b.jpg", filename = "b.jpg")
      ),
      list(
        list(url = "https://example.com/c.jpg", filename = "c.jpg")
      )
    )
  )

  local_mocked_bindings(
    req_perform_parallel = function(reqs, ...) {
      lapply(reqs, function(r) {
        structure(
          list(status_code = 200L, headers = list(), body = as.raw(1:3)),
          class = "httr2_response"
        )
      })
    },
    resp_body_raw = function(resp) as.raw(1:3),
    .package = "httr2"
  )

  before <- air_api_usage("wspPAR")$count
  download_attachments_in_tibble(tbl, "Photos", mode = "blob", parallel = TRUE)
  after <- air_api_usage("wspPAR")$count

  # 3 attachment URLs → counter must increase by exactly 3
  expect_equal(after - before, 3L)
})

test_that("parallel file download increments counter by number of requests", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspPARFILE")

  tbl <- tibble::tibble(
    airtable_id = c("rec1", "rec2"),
    Photos = list(
      list(list(url = "https://example.com/a.jpg", filename = "a.jpg")),
      list(list(url = "https://example.com/b.jpg", filename = "b.jpg"))
    )
  )

  tmpdir <- withr::local_tempdir()

  local_mocked_bindings(
    req_perform_parallel = function(reqs, paths = NULL, ...) {
      # Write empty files for the paths so the function doesn't error
      if (!is.null(paths)) lapply(paths, function(p) {
        dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
        file.create(p)
      })
      lapply(reqs, function(r) {
        structure(
          list(status_code = 200L, headers = list(), body = raw(0)),
          class = "httr2_response"
        )
      })
    },
    .package = "httr2"
  )

  before <- air_api_usage("wspPARFILE")$count
  download_attachments_in_tibble(tbl, "Photos", mode = "file", dir = tmpdir,
                                  parallel = TRUE)
  after <- air_api_usage("wspPARFILE")$count

  # 2 attachment URLs → counter must increase by exactly 2
  expect_equal(after - before, 2L)
})

test_that("air_read_attachments parallel blob path counts requests", {
  local_counter()
  withr::local_options(airtable2.workspace_id = "wspRAB")

  # Mock at_list_records to return 2 records with 2 attachments each
  att_field <- list(
    list(url = "https://cdn.airtable.com/f1.png", filename = "f1.png",
         size = 100L, type = "image/png"),
    list(url = "https://cdn.airtable.com/f2.png", filename = "f2.png",
         size = 200L, type = "image/png")
  )
  fake_records <- list(
    list(id = "rec1", fields = list(Photos = att_field)),
    list(id = "rec2", fields = list(Photos = att_field))
  )

  local_mocked_bindings(
    at_list_records = function(base_id, table, ...) fake_records,
    air_token       = function(token = NULL) "fake_token",
    .package = "airtable2"
  )
  local_mocked_bindings(
    req_perform_parallel = function(reqs, ...) {
      lapply(reqs, function(r) {
        structure(
          list(status_code = 200L, headers = list(), body = as.raw(1:5)),
          class = "httr2_response"
        )
      })
    },
    resp_body_raw = function(resp) as.raw(1:5),
    .package = "httr2"
  )

  before <- air_api_usage("wspRAB")$count
  result <- air_read_attachments("appX", "T", "Photos",
                                  dest = "blob", parallel = TRUE)
  after <- air_api_usage("wspRAB")$count

  # 4 attachments across 2 records → counter must increase by exactly 4
  expect_equal(after - before, 4L)
  expect_equal(nrow(result), 4L)
})
