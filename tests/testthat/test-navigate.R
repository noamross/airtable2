# Tests for air_resolve_id() and air_browse() (R/navigate.R)

# ── air_resolve_id ──────────────────────────────────────────────────────────

test_that("air_resolve_id identifies workspace IDs", {
  r <- air_resolve_id("wspABC123XYZ")
  expect_equal(r$type, "workspace")
  expect_equal(r$id, "wspABC123XYZ")
})

test_that("air_resolve_id identifies base IDs", {
  r <- air_resolve_id("appABC123XYZ")
  expect_equal(r$type, "base")
  expect_equal(r$id, "appABC123XYZ")
})

test_that("air_resolve_id identifies table IDs", {
  r <- air_resolve_id("tblABC123XYZ")
  expect_equal(r$type, "table")
  expect_equal(r$id, "tblABC123XYZ")
})

test_that("air_resolve_id identifies view IDs", {
  r <- air_resolve_id("viwABC123XYZ")
  expect_equal(r$type, "view")
  expect_equal(r$id, "viwABC123XYZ")
})

test_that("air_resolve_id identifies record IDs", {
  r <- air_resolve_id("recABC123XYZ")
  expect_equal(r$type, "record")
  expect_equal(r$id, "recABC123XYZ")
})

test_that("air_resolve_id parses a base URL", {
  r <- air_resolve_id("https://airtable.com/appBASE123")
  expect_equal(r$type, "base")
  expect_equal(r$id, "appBASE123")
})

test_that("air_resolve_id parses a table URL", {
  r <- air_resolve_id("https://airtable.com/appBASE123/tblTABLE123")
  expect_equal(r$type, "table")
  expect_equal(r$id, "tblTABLE123")
  expect_equal(r$base_id, "appBASE123")
})

test_that("air_resolve_id parses a view URL", {
  r <- air_resolve_id("https://airtable.com/appBASE123/tblTABLE123/viwVIEW123")
  expect_equal(r$type, "view")
  expect_equal(r$id, "viwVIEW123")
  expect_equal(r$table_id, "tblTABLE123")
  expect_equal(r$base_id, "appBASE123")
})

test_that("air_resolve_id parses a workspace URL", {
  r <- air_resolve_id("https://airtable.com/workspaces/wspWSP123")
  expect_equal(r$type, "workspace")
  expect_equal(r$id, "wspWSP123")
})

test_that("air_resolve_id parses a record URL", {
  r <- air_resolve_id("https://airtable.com/appBASE123/tblTABLE123/recREC123")
  expect_equal(r$type, "record")
  expect_equal(r$id, "recREC123")
})

test_that("air_resolve_id extracts base_id from an AirtableConnection", {
  local_mocked_bindings(
    dbConnect = function(drv, ...) {
      methods::new(
        "AirtableConnection",
        token = "tok",
        base_id = "appCONN123",
        state = new.env(parent = emptyenv())
      )
    },
    .package = "DBI"
  )
  # Build a minimal connection object directly to avoid hitting API
  con <- methods::new(
    "AirtableConnection",
    token = "tok",
    base_id = "appCONN456",
    state = local({
      e <- new.env(parent = emptyenv())
      e$valid <- TRUE
      e
    })
  )
  r <- air_resolve_id(con)
  expect_equal(r$type, "base")
  expect_equal(r$id, "appCONN456")
})


test_that("air_resolve_id warns on unrecognised strings", {
  expect_warning(
    r <- air_resolve_id("something-unrecognised"),
    "Could not determine"
  )
  expect_true(is.na(r$type))
})

test_that("air_resolve_id errors on non-scalar or non-string inputs", {
  expect_error(air_resolve_id(123), class = "rlang_error")
  expect_error(air_resolve_id(c("appA", "appB")), class = "rlang_error")
})

# ── air_browse ──────────────────────────────────────────────────────────────

test_that("air_browse returns URL invisibly (browse suppressed)", {
  # Suppress the actual browser call
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse("appABC123")
  expect_equal(url, "https://airtable.com/appABC123")
})

test_that("air_browse builds workspace URL", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse("wspWSP123")
  expect_equal(url, "https://airtable.com/workspaces/wspWSP123")
})

test_that("air_browse errors for table without base_id", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  expect_error(air_browse("tblTABLE123"), class = "rlang_error")
})

test_that("air_browse accepts a full URL passthrough", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  full_url <- "https://airtable.com/appBASE123/tblTABLE123/viwVIEW123"
  url <- air_browse(full_url)
  expect_equal(url, full_url)
})
