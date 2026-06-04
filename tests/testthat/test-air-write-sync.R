# Mocked unit tests for air_write, air_upsert, air_sync
# These use local_mocked_bindings to avoid hitting the API while covering
# the logic in these functions.

test_that("air_write creates records and returns IDs", {
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(base_id, table_id, records, ...) {
      lapply(seq_along(records), function(i) {
        list(id = paste0("rec", i), fields = records[[i]]$fields)
      })
    }
  )

  data <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(30L, 25L))
  expect_message(ids <- air_write(data, "appX", "Table1"), "Created 2 record")

  expect_equal(ids, c("rec1", "rec2"))
})

test_that("air_write drops computed fields with message", {
  local_mocked_bindings(
    get_computed_fields = function(...) c("Formula", "AutoNum"),
    get_attachment_fields = function(...) character(),
    at_create_records = function(base_id, table_id, records, ...) {
      # Verify computed fields were excluded
      field_names <- names(records[[1]]$fields)
      if ("Formula" %in% field_names || "AutoNum" %in% field_names) {
        stop("Computed fields not excluded!")
      }
      list(list(id = "rec1", fields = records[[1]]$fields))
    }
  )

  data <- tibble::tibble(Name = "Alice", Formula = "COMPUTED", AutoNum = 1L)
  expect_message(ids <- air_write(data, "appX", "Table1"), "Dropping computed")
  expect_equal(ids, "rec1")
})

test_that("air_upsert creates and updates records", {
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    at_get_schema = function(...) {
      list(list(
        name = "Table1",
        id = "tbl1",
        fields = list(
          list(name = "Name", type = "singleLineText"),
          list(name = "Age", type = "number")
        )
      ))
    },
    at_update_records = function(base_id, table_id, records, ...) {
      list(
        records = records,
        createdRecords = c("rec3"),
        updatedRecords = c("rec1")
      )
    }
  )

  data <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(31L, 25L))
  expect_message(
    result <- air_upsert(data, "appX", "Table1", merge_on = "Name"),
    "Upsert complete"
  )
  expect_type(result, "list")
  expect_true("created" %in% names(result))
  expect_true("updated" %in% names(result))
})

test_that("air_upsert errors on unknown columns with add_fields='error'", {
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    at_get_schema = function(...) {
      list(list(
        name = "Table1",
        id = "tbl1",
        fields = list(list(name = "Name", type = "singleLineText"))
      ))
    }
  )

  data <- tibble::tibble(Name = "Alice", Fake = "nope")
  expect_error(
    air_upsert(data, "appX", "Table1", merge_on = "Name", add_fields = "error"),
    "not found in table"
  )
})

test_that("air_upsert warns on unknown columns with add_fields='warn'", {
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    at_get_schema = function(...) {
      list(list(
        name = "Table1",
        id = "tbl1",
        fields = list(list(name = "Name", type = "singleLineText"))
      ))
    },
    at_update_records = function(base_id, table_id, records, ...) {
      list(
        records = records,
        createdRecords = c("rec1"),
        updatedRecords = character()
      )
    }
  )

  data <- tibble::tibble(Name = "Alice", Fake = "nope")
  expect_warning(
    result <- air_upsert(
      data,
      "appX",
      "Table1",
      merge_on = "Name",
      add_fields = "warn"
    ),
    "unknown column"
  )
  expect_length(result$created, 1L)
})

test_that("air_sync detects creates, updates, deletes, unchanged", {
  # Mock existing records in Airtable
  existing <- tibble::tibble(
    airtable_id = c("recA", "recB", "recC"),
    airtable_created_time = as.POSIXct(rep("2024-01-01", 3)),
    Name = c("Alice", "Bob", "Charlie"),
    Age = c(30L, 25L, 35L)
  )

  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    air_read = function(...) existing,
    air_upsert = function(data, base_id = NULL, table, ...) {
      list(created = "recD", updated = "recB")
    },
    at_delete_records = function(...) invisible(NULL)
  )

  # Desired: keep Alice (unchanged), update Bob, add Dana, remove Charlie
  desired <- tibble::tibble(
    Name = c("Alice", "Bob", "Dana"),
    Age = c(30L, 26L, 28L)
  )

  expect_message(
    result <- air_sync(
      desired,
      "appX",
      "Table1",
      key = "Name",
      hash_fields = "Age",
      delete_missing = TRUE
    ),
    "Sync complete"
  )

  expect_equal(result$created, 1L)
  expect_equal(result$updated, 1L)
  expect_equal(result$deleted, 1L)
  expect_equal(result$unchanged, 1L)
})

test_that("air_sync with delete_missing=FALSE preserves extras", {
  existing <- tibble::tibble(
    airtable_id = c("recA", "recB"),
    airtable_created_time = as.POSIXct(rep("2024-01-01", 2)),
    Name = c("Alice", "Bob"),
    Age = c(30L, 25L)
  )

  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    air_read = function(...) existing
  )

  # Only Alice in desired - Bob should NOT be deleted
  desired <- tibble::tibble(Name = "Alice", Age = 30L)

  expect_message(
    result <- air_sync(
      desired,
      "appX",
      "Table1",
      key = "Name",
      hash_fields = "Age",
      delete_missing = FALSE
    ),
    "Sync complete"
  )

  expect_equal(result$deleted, 0L)
  expect_equal(result$unchanged, 1L)
})

test_that("air_sync is idempotent (no changes needed)", {
  existing <- tibble::tibble(
    airtable_id = c("recA", "recB"),
    airtable_created_time = as.POSIXct(rep("2024-01-01", 2)),
    Name = c("Alice", "Bob"),
    Age = c(30L, 25L)
  )

  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    air_read = function(...) existing
  )

  desired <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(30L, 25L))

  expect_message(
    result <- air_sync(
      desired,
      "appX",
      "Table1",
      key = "Name",
      hash_fields = "Age",
      delete_missing = TRUE
    ),
    "Sync complete"
  )

  expect_equal(result$created, 0L)
  expect_equal(result$updated, 0L)
  expect_equal(result$deleted, 0L)
  expect_equal(result$unchanged, 2L)
})

# ── Feature 3: new signature assertions ───────────────────────────────────────

test_that("air_write(data, base_id, table) works with data-first signature", {
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(base_id, table_id, records, ...) {
      lapply(seq_along(records), function(i) list(id = paste0("rec", i)))
    }
  )
  data <- tibble::tibble(Name = "Alice")
  expect_message(
    ids <- air_write(data, "appXXX", "Table"),
    "Created 1 record"
  )
  expect_equal(ids, "rec1")
})

test_that("air_upsert(data, base_id, table, merge_on) works with data-first signature", {
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    at_get_schema = function(...) {
      list(list(
        id = "tbl1", name = "Table",
        fields = list(list(name = "Name", type = "singleLineText"))
      ))
    },
    at_update_records = function(...) {
      list(records = list(), createdRecords = "rec1", updatedRecords = character())
    }
  )
  data <- tibble::tibble(Name = "Alice")
  expect_message(
    result <- air_upsert(data, "appXXX", "Table", merge_on = "Name"),
    "Upsert complete"
  )
  expect_equal(result$created, "rec1")
})

test_that("air_sync(data, base_id, table, key) works with data-first signature", {
  existing <- tibble::tibble(
    airtable_id = character(),
    airtable_created_time = as.POSIXct(character()),
    Name = character(),
    Age = integer()
  )
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    air_read = function(...) existing,
    air_upsert = function(data, base_id = NULL, table, ...) {
      list(created = "rec1", updated = character())
    },
    at_delete_records = function(...) invisible(NULL)
  )
  data <- tibble::tibble(Name = "Alice", Age = 30L)
  expect_message(
    result <- air_sync(data, "appXXX", "Table", key = "Name"),
    "Sync complete"
  )
  expect_equal(result$created, 1L)
})

test_that("at_create_table(name, fields, base_id) works with name-first signature", {
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) list(id = "tblNEW", name = "MyTable")
  )
  result <- at_create_table(
    "MyTable",
    fields = list(list(name = "Name", type = "singleLineText")),
    base_id = "appXXX"
  )
  expect_equal(result$name, "MyTable")
})

test_that("air_delete with empty IDs gives message and no-ops", {
  expect_message(
    air_delete("appX", "Table1", character()),
    "No records to delete"
  )
})

test_that("air_delete calls at_delete_records", {
  deleted <- NULL
  local_mocked_bindings(at_delete_records = function(base_id, table, ids, ...) {
    deleted <<- ids
    invisible(NULL)
  })

  expect_message(
    air_delete("appX", "Table1", c("rec1", "rec2")),
    "Deleted 2 record"
  )
  expect_equal(deleted, c("rec1", "rec2"))
})
