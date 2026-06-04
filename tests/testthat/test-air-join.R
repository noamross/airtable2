# Mocked tests for air_left_join, air_inner_join, air_full_join (R/air_join.R)

fake_remote <- function() {
  tibble::tibble(
    airtable_id          = c("recA", "recB", "recC"),
    airtable_created_time = as.POSIXct(c("2024-01-01","2024-01-02","2024-01-03"), tz="UTC"),
    Name  = c("Alice", "Bob", "Charlie"),
    Email = c("alice@x.com", "bob@x.com", "charlie@x.com")
  )
}

mock_air_read <- function(tbl = fake_remote()) {
  list(air_read = function(base_id = NULL, table, ...) tbl)
}

# ── air_left_join ────────────────────────────────────────────────────────────

test_that("air_left_join keeps all rows from x, adds matching remote cols", {
  x <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90L, 85L))
  local_mocked_bindings(air_read = function(base_id = NULL, table, ...) fake_remote())

  result <- air_left_join(x, "appXXX", "Contacts", by = "Name")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
  expect_true("Email" %in% names(result))
  expect_equal(sort(result$Email), c("alice@x.com", "bob@x.com"))
})

test_that("air_left_join preserves unmatched x rows with NA remote cols", {
  x <- tibble::tibble(Name = c("Alice", "Zzz"), Score = c(90L, 99L))
  local_mocked_bindings(air_read = function(base_id = NULL, table, ...) fake_remote())

  result <- air_left_join(x, "appXXX", "Contacts", by = "Name")

  expect_equal(nrow(result), 2L)
  expect_true(is.na(result$Email[result$Name == "Zzz"]))
})

# ── air_inner_join ───────────────────────────────────────────────────────────

test_that("air_inner_join returns only matched rows", {
  x <- tibble::tibble(Name = c("Alice", "Zzz"), Score = c(90L, 99L))
  local_mocked_bindings(air_read = function(base_id = NULL, table, ...) fake_remote())

  result <- air_inner_join(x, "appXXX", "Contacts", by = "Name")

  expect_equal(nrow(result), 1L)
  expect_equal(result$Name, "Alice")
})

# ── air_full_join ────────────────────────────────────────────────────────────

test_that("air_full_join returns rows from both sides with NA fills", {
  x <- tibble::tibble(Name = c("Alice", "Zzz"), Score = c(90L, 99L))
  local_mocked_bindings(air_read = function(base_id = NULL, table, ...) fake_remote())

  result <- air_full_join(x, "appXXX", "Contacts", by = "Name")

  # Alice (match), Zzz (x-only), Bob and Charlie (remote-only)
  expect_equal(nrow(result), 4L)
})

# ── by auto-detection ────────────────────────────────────────────────────────

test_that("air_left_join auto-detects by from shared column names", {
  x <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90L, 85L))
  local_mocked_bindings(air_read = function(base_id = NULL, table, ...) fake_remote())

  expect_message(
    result <- air_left_join(x, "appXXX", "Contacts"),
    "Joining on"
  )
  expect_equal(nrow(result), 2L)
})

test_that("air_left_join errors when no common columns and by is NULL", {
  x <- tibble::tibble(City = c("NY", "LA"), Pop = c(8L, 4L))
  local_mocked_bindings(air_read = function(base_id = NULL, table, ...) fake_remote())

  expect_error(
    air_left_join(x, "appXXX", "Contacts"),
    "No common columns"
  )
})

# ── default base ─────────────────────────────────────────────────────────────

test_that("air_left_join uses default base when base_id is NULL", {
  withr::local_options(airtable2.base_id = "appDEFAULT")
  called_base <- NULL
  local_mocked_bindings(
    air_read = function(base_id = NULL, table, ...) {
      called_base <<- base_id
      fake_remote()
    }
  )

  x <- tibble::tibble(Name = "Alice")
  air_left_join(x, table = "Contacts", by = "Name")
  expect_equal(called_base, "appDEFAULT")
})

test_that("air_left_join validates inputs", {
  expect_error(air_left_join("notadf", "appX", "T", by = "x"), class = "rlang_error")
})
