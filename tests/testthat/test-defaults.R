# Tests for session-level defaults: default_base_id(), air_set_base(), air_set_token()

# ── default_base_id() ─────────────────────────────────────────────────────────

test_that("default_base_id returns option when set", {
  withr::local_options(airtable2.base_id = "appOPTION")
  expect_equal(default_base_id(), "appOPTION")
})

test_that("default_base_id falls back to env var when option is unset", {
  withr::local_options(airtable2.base_id = NULL)
  withr::local_envvar(AIRTABLE_BASE_ID = "appENV")
  expect_equal(default_base_id(), "appENV")
})

test_that("default_base_id returns empty string when nothing configured", {
  withr::local_options(airtable2.base_id = NULL)
  withr::local_envvar(AIRTABLE_BASE_ID = "")
  expect_equal(default_base_id(), "")
})

# ── air_set_base() ────────────────────────────────────────────────────────────

test_that("air_set_base sets the airtable2.base_id option", {
  withr::local_options(airtable2.base_id = NULL)
  local_mocked_bindings(
    at_get_base = function(base_id, token = NULL) {
      list(id = base_id, name = "My Base", permissionLevel = "create")
    }
  )
  air_set_base("appABC123")
  expect_equal(getOption("airtable2.base_id"), "appABC123")
})

test_that("air_set_base prints a cli confirmation", {
  withr::local_options(airtable2.base_id = NULL)
  local_mocked_bindings(
    at_get_base = function(base_id, token = NULL) {
      list(id = base_id, name = "Test Base", permissionLevel = "create")
    }
  )
  expect_message(air_set_base("appABC123"), "Test Base")
})

test_that("air_set_base errors with suggestion when base not found", {
  local_mocked_bindings(
    at_get_base = function(base_id, token = NULL) NULL
  )
  expect_error(air_set_base("appNOTFOUND"), class = "rlang_error")
})

test_that("air_set_base validates base_id is a string", {
  expect_error(air_set_base(123), "must be a single non-NA string")
})

# ── air_set_token() ───────────────────────────────────────────────────────────

test_that("air_set_token sets the airtable2.token option", {
  withr::local_options(airtable2.token = NULL)
  local_mocked_bindings(
    at_whoami = function(token = NULL) list(id = "usrXXX", email = "x@y.com")
  )
  air_set_token("patFAKE")
  expect_equal(getOption("airtable2.token"), "patFAKE")
})

test_that("air_set_token prints a confirmation with user email", {
  withr::local_options(airtable2.token = NULL)
  local_mocked_bindings(
    at_whoami = function(token = NULL) list(id = "usrXXX", email = "alice@example.com")
  )
  expect_message(air_set_token("patFAKE"), "alice@example.com")
})

test_that("air_set_token errors with suggestion when token is invalid", {
  local_mocked_bindings(
    at_whoami = function(token = NULL) rlang::abort("Unauthorized")
  )
  expect_error(air_set_token("patBAD"), class = "rlang_error")
})

test_that("air_set_token validates tok is a string", {
  expect_error(air_set_token(123), "must be a single non-NA string")
})

# ── air_read uses default base ────────────────────────────────────────────────

test_that("air_read uses default_base_id() when base_id is NULL", {
  withr::local_options(airtable2.base_id = "appDEFAULT")
  called_with <- NULL
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      called_with <<- req$url
      list(records = list(), offset = NULL)
    },
    at_get_schema = function(base_id, token = NULL) {
      list(list(id = "tbl1", name = "T", fields = list(), views = list()))
    }
  )
  air_read(table = "T")
  expect_true(grepl("appDEFAULT", called_with))
})

test_that("air_read errors when base_id is NULL and no default is set", {
  withr::local_options(airtable2.base_id = NULL)
  withr::local_envvar(AIRTABLE_BASE_ID = "")
  expect_error(air_read(table = "T"), "base_id")
})
