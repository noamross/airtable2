# Tests for resolve_progress() and staged progress in air_sync()

# --- resolve_progress() -------------------------------------------------------

test_that("resolve_progress(TRUE) returns TRUE", {
  expect_true(resolve_progress(TRUE))
})

test_that("resolve_progress(FALSE) returns FALSE", {
  expect_false(resolve_progress(FALSE))
})

test_that("resolve_progress(NULL) reads from airtable2.progress.bar option", {
  withr::with_options(list(airtable2.progress.bar = TRUE), {
    expect_true(resolve_progress(NULL))
  })
  withr::with_options(list(airtable2.progress.bar = FALSE), {
    expect_false(resolve_progress(NULL))
  })
})

test_that("resolve_progress(NULL) reads from AIRTABLE2_PROGRESS_BAR env var", {
  withr::with_options(list(airtable2.progress.bar = NULL), {
    withr::with_envvar(c(AIRTABLE2_PROGRESS_BAR = "true"), {
      expect_true(resolve_progress(NULL))
    })
    withr::with_envvar(c(AIRTABLE2_PROGRESS_BAR = "false"), {
      expect_false(resolve_progress(NULL))
    })
    withr::with_envvar(c(AIRTABLE2_PROGRESS_BAR = "1"), {
      expect_true(resolve_progress(NULL))
    })
    withr::with_envvar(c(AIRTABLE2_PROGRESS_BAR = "0"), {
      expect_false(resolve_progress(NULL))
    })
  })
})

test_that("resolve_progress(NULL) defaults to TRUE when nothing configured", {
  withr::with_options(list(airtable2.progress.bar = NULL, cli.progress_show_after = 0), {
    withr::with_envvar(c(AIRTABLE2_PROGRESS_BAR = ""), {
      expect_true(resolve_progress(NULL))
    })
  })
})

# --- air_sync() propagates progress to at_delete_records ---------------------

# Helper: existing Airtable state with one record "Alice"
existing_one_record <- function() {
  tibble::tibble(
    airtable_id          = "recALICE1",
    airtable_created_time = as.POSIXct("2024-01-01", tz = "UTC"),
    Name                 = "Alice"
  )
}

test_that("air_sync passes progress=TRUE to at_delete_records", {
  delete_calls <- list()
  local_mocked_bindings(
    get_computed_fields   = function(base_id, table, ...) character(),
    get_attachment_fields = function(base_id, table, ...) character(),
    air_read              = function(table, base_id, ...) existing_one_record(),
    at_delete_records     = function(base_id, table_id, record_ids,
                                     token = NULL, progress = NULL) {
      delete_calls[[length(delete_calls) + 1L]] <<- list(progress = progress)
      list()
    },
    .package = "airtable2"
  )

  suppressMessages(
    air_sync(
      data.frame(Name = character(0)),  # empty local → Alice will be deleted
      "Contacts",
      key = "Name", base_id = "appFAKE",
      delete_missing = TRUE, progress = TRUE
    )
  )

  expect_length(delete_calls, 1L)
  expect_true(delete_calls[[1L]]$progress)
})

test_that("air_sync passes progress=FALSE to at_delete_records", {
  delete_calls <- list()
  local_mocked_bindings(
    get_computed_fields   = function(base_id, table, ...) character(),
    get_attachment_fields = function(base_id, table, ...) character(),
    air_read              = function(table, base_id, ...) existing_one_record(),
    at_delete_records     = function(base_id, table_id, record_ids,
                                     token = NULL, progress = NULL) {
      delete_calls[[length(delete_calls) + 1L]] <<- list(progress = progress)
      list()
    },
    .package = "airtable2"
  )

  suppressMessages(
    air_sync(
      data.frame(Name = character(0)),
      "Contacts",
      key = "Name", base_id = "appFAKE",
      delete_missing = TRUE, progress = FALSE
    )
  )

  expect_length(delete_calls, 1L)
  expect_false(delete_calls[[1L]]$progress)
})

# --- air_sync() staged cli step messages -------------------------------------

# Helper: empty Airtable state
empty_existing <- function() {
  tibble::tibble(
    airtable_id           = character(0),
    airtable_created_time = as.POSIXct(character(0)),
    Name                  = character(0)
  )
}

test_that("air_sync emits a 'Reading' step message when progress=TRUE", {
  local_mocked_bindings(
    get_computed_fields   = function(base_id, table, ...) character(),
    get_attachment_fields = function(base_id, table, ...) character(),
    air_read              = function(table, base_id, ...) empty_existing(),
    .package = "airtable2"
  )

  msgs <- capture_messages(
    air_sync(
      data.frame(Name = character(0)),
      "Contacts",
      key = "Name", base_id = "appFAKE",
      delete_missing = FALSE, progress = TRUE
    )
  )

  expect_true(any(grepl("[Rr]eading", msgs)))
})

test_that("air_sync does not emit 'Reading' message when progress=FALSE", {
  local_mocked_bindings(
    get_computed_fields   = function(base_id, table, ...) character(),
    get_attachment_fields = function(base_id, table, ...) character(),
    air_read              = function(table, base_id, ...) empty_existing(),
    .package = "airtable2"
  )

  msgs <- capture_messages(
    air_sync(
      data.frame(Name = character(0)),
      "Contacts",
      key = "Name", base_id = "appFAKE",
      delete_missing = FALSE, progress = FALSE
    )
  )

  expect_false(any(grepl("[Rr]eading", msgs)))
})

# --- resolve_progress() cli.progress_show_after side-effect ------------------

test_that("resolve_progress sets cli.progress_show_after = 5 when not configured", {
  withr::local_options(cli.progress_show_after = NULL)
  resolve_progress(TRUE)
  expect_equal(getOption("cli.progress_show_after"), 5)
})

test_that("resolve_progress does not override existing cli.progress_show_after", {
  withr::local_options(cli.progress_show_after = 0)
  resolve_progress(TRUE)
  expect_equal(getOption("cli.progress_show_after"), 0)
})

test_that("resolve_progress does not set cli.progress_show_after when progress=FALSE", {
  withr::local_options(cli.progress_show_after = NULL)
  resolve_progress(FALSE)
  expect_null(getOption("cli.progress_show_after"))
})

test_that("resolve_progress cleans up cli.progress_show_after after caller exits", {
  withr::local_options(cli.progress_show_after = NULL)
  f <- function() resolve_progress(TRUE)
  f()
  # After f() exits its cli.progress_show_after registration is scoped to f's
  # frame; the current frame had no registration, so the option is back to NULL.
  expect_null(getOption("cli.progress_show_after"))
})
