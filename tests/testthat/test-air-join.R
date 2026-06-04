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
  list(air_read = function(table, base_id = NULL, ...) tbl)
}

# ── air_left_join ────────────────────────────────────────────────────────────

test_that("air_left_join keeps all rows from x, adds matching remote cols", {
  x <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90L, 85L))
  local_mocked_bindings(air_read = function(table, base_id = NULL, ...) fake_remote())

  result <- air_left_join(x, "Contacts", "appXXX", by = "Name")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
  expect_true("Email" %in% names(result))
  expect_equal(sort(result$Email), c("alice@x.com", "bob@x.com"))
})

test_that("air_left_join preserves unmatched x rows with NA remote cols", {
  x <- tibble::tibble(Name = c("Alice", "Zzz"), Score = c(90L, 99L))
  local_mocked_bindings(air_read = function(table, base_id = NULL, ...) fake_remote())

  result <- air_left_join(x, "Contacts", "appXXX", by = "Name")

  expect_equal(nrow(result), 2L)
  expect_true(is.na(result$Email[result$Name == "Zzz"]))
})

# ── air_inner_join ───────────────────────────────────────────────────────────

test_that("air_inner_join returns only matched rows", {
  x <- tibble::tibble(Name = c("Alice", "Zzz"), Score = c(90L, 99L))
  local_mocked_bindings(air_read = function(table, base_id = NULL, ...) fake_remote())

  result <- air_inner_join(x, "Contacts", "appXXX", by = "Name")

  expect_equal(nrow(result), 1L)
  expect_equal(result$Name, "Alice")
})

# ── air_full_join ────────────────────────────────────────────────────────────

test_that("air_full_join returns rows from both sides with NA fills", {
  x <- tibble::tibble(Name = c("Alice", "Zzz"), Score = c(90L, 99L))
  local_mocked_bindings(air_read = function(table, base_id = NULL, ...) fake_remote())

  result <- air_full_join(x, "Contacts", "appXXX", by = "Name")

  # Alice (match), Zzz (x-only), Bob and Charlie (remote-only)
  expect_equal(nrow(result), 4L)
})

# ── by auto-detection ────────────────────────────────────────────────────────

test_that("air_left_join auto-detects by from shared column names", {
  x <- tibble::tibble(Name = c("Alice", "Bob"), Score = c(90L, 85L))
  local_mocked_bindings(air_read = function(table, base_id = NULL, ...) fake_remote())

  expect_message(
    result <- air_left_join(x, "Contacts", "appXXX"),
    "Joining on"
  )
  expect_equal(nrow(result), 2L)
})

test_that("air_left_join errors when no common columns and by is NULL", {
  x <- tibble::tibble(City = c("NY", "LA"), Pop = c(8L, 4L))
  local_mocked_bindings(air_read = function(table, base_id = NULL, ...) fake_remote())

  expect_error(
    air_left_join(x, "Contacts", "appXXX"),
    "No common columns"
  )
})

# ── default base ─────────────────────────────────────────────────────────────

test_that("air_left_join uses default base when base_id is NULL", {
  withr::local_options(airtable2.base_id = "appDEFAULT")
  called_base <- NULL
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) {
      called_base <<- base_id
      fake_remote()
    }
  )

  x <- tibble::tibble(Name = "Alice")
  air_left_join(x, table = "Contacts", by = "Name")
  expect_equal(called_base, "appDEFAULT")
})

test_that("air_left_join validates inputs", {
  expect_error(air_left_join("notadf", "T", "appX", by = "x"), class = "rlang_error")
})

# ── air_left_join_upload ─────────────────────────────────────────────────────
#
# Upload direction join: match local rows to existing remote records by key
# and upload x's columns onto them. Mocks the read boundary (air_read) and the
# write boundary (air_upsert) to capture payloads. No live calls.

# Remote table that already has an "Email" field but no "Score" field.
upl_remote <- function() {
  tibble::tibble(
    airtable_id = c("recA", "recB", "recC"),
    Name        = c("Alice", "Bob", "Charlie"),
    Email       = c("alice@x.com", "bob@x.com", "charlie@x.com")
  )
}

test_that("air_left_join_upload uploads matched rows and skips unmatched", {
  x <- tibble::tibble(
    Name  = c("Alice", "Bob", "Zzz"),
    Score = c(90L, 85L, 99L)
  )
  captured <- NULL
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, ...) {
      captured <<- data
      invisible(list(created = character(), updated = data$airtable_id))
    }
  )

  result <- air_left_join_upload(x, "Contacts", "appXXX", by = "Name")

  # Only Alice + Bob matched; Zzz unmatched and skipped.
  expect_equal(nrow(captured), 2L)
  expect_setequal(captured$Name, c("Alice", "Bob"))
  expect_true(all(captured$airtable_id %in% c("recA", "recB")))
  expect_true("Score" %in% names(captured))

  # Returned summary reflects matched/updated rows.
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
})

test_that("air_left_join_upload only sends new/changed columns", {
  # Email matches remote exactly for Alice (unchanged) but differs for Bob.
  # Score is brand new for both.
  x <- tibble::tibble(
    Name  = c("Alice", "Bob"),
    Email = c("alice@x.com", "bob-NEW@x.com"),
    Score = c(90L, 85L)
  )
  captured <- NULL
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, ...) {
      captured <<- data
      invisible(list(created = character(), updated = data$airtable_id))
    }
  )

  air_left_join_upload(x, "Contacts", "appXXX", by = "Name", add_fields = "yes")

  # Score (new field) always sent.
  expect_true("Score" %in% names(captured))
  # Email is sent (some rows changed) but Alice's unchanged Email is NA-blanked,
  # only Bob's changed value present.
  expect_true("Email" %in% names(captured))
  alice <- captured[captured$Name == "Alice", ]
  bob   <- captured[captured$Name == "Bob", ]
  expect_true(is.na(alice$Email))
  expect_equal(bob$Email, "bob-NEW@x.com")
})

test_that("air_left_join_upload drops rows/columns with no changes", {
  # Everything already matches remote: nothing to upload.
  x <- tibble::tibble(
    Name  = c("Alice", "Bob"),
    Email = c("alice@x.com", "bob@x.com")
  )
  upsert_called <- FALSE
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, ...) {
      upsert_called <<- TRUE
      invisible(list(created = character(), updated = data$airtable_id))
    }
  )

  result <- air_left_join_upload(x, "Contacts", "appXXX", by = "Name")

  expect_false(upsert_called)
  expect_equal(nrow(result), 0L)
})

test_that("air_left_join_upload passes add_fields through to the writer", {
  x <- tibble::tibble(Name = c("Alice"), Score = c(90L))
  captured_add <- NULL
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, add_fields, ...) {
      captured_add <<- add_fields
      invisible(list(created = character(), updated = data$airtable_id))
    }
  )

  air_left_join_upload(x, "Contacts", "appXXX", by = "Name", add_fields = "yes")
  expect_equal(captured_add, "yes")
})

test_that("air_left_join_upload reads only the key + existing target fields", {
  x <- tibble::tibble(Name = c("Alice"), Score = c(90L), Email = c("a@x.com"))
  read_fields <- NULL
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, fields = NULL, ...) {
      read_fields <<- fields
      upl_remote()
    },
    air_upsert = function(data, table, merge_on, ...) {
      invisible(list(created = character(), updated = data$airtable_id))
    },
    # Remote schema has Name + Email but no Score.
    get_table_schema = function(base_id, table, token = NULL, refresh = FALSE) {
      list(
        id = "tblX",
        fields = list(list(name = "Name"), list(name = "Email"))
      )
    }
  )

  air_left_join_upload(x, "Contacts", "appXXX", by = "Name", add_fields = "yes")
  # Key + existing target field (Email); Score does not exist remotely so is
  # not requested.
  expect_setequal(read_fields, c("Name", "Email"))
})

test_that("air_left_join_upload does not duplicate or mangle the key column", {
  x <- tibble::tibble(Name = c("Alice"), Score = c(90L))
  captured <- NULL
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, ...) {
      captured <<- data
      invisible(list(created = character(), updated = data$airtable_id))
    }
  )

  air_left_join_upload(x, "Contacts", "appXXX", by = "Name")
  expect_equal(sum(names(captured) == "Name"), 1L)
  expect_false(any(grepl("\\.(x|y)$", names(captured))))
  expect_equal(captured$Name, "Alice")
})

test_that("air_left_join_upload supports named-vector by (local != remote)", {
  # Local key column is "contact" but remote key is "Name".
  x <- tibble::tibble(contact = c("Alice", "Bob"), Score = c(90L, 85L))
  captured <- NULL
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, ...) {
      captured <<- data
      invisible(list(created = character(), updated = data$airtable_id))
    }
  )

  air_left_join_upload(x, "Contacts", "appXXX", by = c(contact = "Name"))
  expect_equal(nrow(captured), 2L)
  # Payload is keyed for the remote table, so it carries the remote key name.
  expect_true("Name" %in% names(captured))
  expect_false("contact" %in% names(captured))
})

test_that("air_left_join_upload handles empty x", {
  x <- tibble::tibble(Name = character(), Score = integer())
  upsert_called <- FALSE
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, ...) {
      upsert_called <<- TRUE
      invisible(list(created = character(), updated = character()))
    }
  )

  result <- air_left_join_upload(x, "Contacts", "appXXX", by = "Name")
  expect_false(upsert_called)
  expect_equal(nrow(result), 0L)
})

test_that("air_left_join_upload handles zero matches", {
  x <- tibble::tibble(Name = c("Nobody"), Score = c(1L))
  upsert_called <- FALSE
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, ...) {
      upsert_called <<- TRUE
      invisible(list(created = character(), updated = character()))
    }
  )

  result <- air_left_join_upload(x, "Contacts", "appXXX", by = "Name")
  expect_false(upsert_called)
  expect_equal(nrow(result), 0L)
})

test_that("air_left_join_upload auto-detects by from shared columns", {
  x <- tibble::tibble(Name = c("Alice"), Score = c(90L))
  local_mocked_bindings(
    air_read = function(table, base_id = NULL, ...) upl_remote(),
    air_upsert = function(data, table, merge_on, ...) {
      invisible(list(created = character(), updated = data$airtable_id))
    }
  )
  expect_message(
    air_left_join_upload(x, "Contacts", "appXXX"),
    "Joining on"
  )
})

test_that("air_left_join_upload validates inputs", {
  expect_error(
    air_left_join_upload("notadf", "Contacts", "appX", by = "Name"),
    class = "rlang_error"
  )
})
