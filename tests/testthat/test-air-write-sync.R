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
  expect_message(ids <- air_write(data, "Table1", "appX"), "Created 2 record")

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
  expect_message(ids <- air_write(data, "Table1", "appX"), "Dropping computed")
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
    result <- air_upsert(data, "Table1", "Name", "appX"),
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
    air_upsert(data, "Table1", "Name", "appX", add_fields = "error"),
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
      "Table1",
      "Name",
      "appX",
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
    air_upsert = function(data, table, merge_on, base_id = NULL, ...) {
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
      "Table1",
      "Name",
      "appX",
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
      "Table1",
      "Name",
      "appX",
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
      "Table1",
      "Name",
      "appX",
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

test_that("air_write(data, table, base_id) works with data-first signature", {
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(base_id, table_id, records, ...) {
      lapply(seq_along(records), function(i) list(id = paste0("rec", i)))
    }
  )
  data <- tibble::tibble(Name = "Alice")
  # positional base_id
  expect_message(
    ids <- air_write(data, "Table", "appXXX"),
    "Created 1 record"
  )
  expect_equal(ids, "rec1")
  # named base_id
  expect_message(
    ids2 <- air_write(data, "Table", base_id = "appXXX"),
    "Created 1 record"
  )
  expect_equal(ids2, "rec1")
})

test_that("air_upsert(data, table, merge_on, base_id) works with data-first signature", {
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
  # positional base_id
  expect_message(
    result <- air_upsert(data, "Table", "Name", "appXXX"),
    "Upsert complete"
  )
  expect_equal(result$created, "rec1")
  # named base_id, named merge_on
  expect_message(
    result2 <- air_upsert(data, "Table", merge_on = "Name", base_id = "appXXX"),
    "Upsert complete"
  )
  expect_equal(result2$created, "rec1")
})

test_that("air_sync(data, table, key, base_id) works with data-first signature", {
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
    air_upsert = function(data, table, merge_on, base_id = NULL, ...) {
      list(created = "rec1", updated = character())
    },
    at_delete_records = function(...) invisible(NULL)
  )
  data <- tibble::tibble(Name = "Alice", Age = 30L)
  # positional base_id
  expect_message(
    result <- air_sync(data, "Table", "Name", "appXXX"),
    "Sync complete"
  )
  expect_equal(result$created, 1L)
  # named base_id, named key
  expect_message(
    result2 <- air_sync(data, "Table", key = "Name", base_id = "appXXX"),
    "Sync complete"
  )
  expect_equal(result2$created, 1L)
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

# ── Feature 4B: flattened-format upload inference ────────────────────────────

test_that("air_write expands flat multiselect/links strings using schema", {
  captured <- NULL
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    get_table_schema = function(...) {
      list(
        id = "tbl1",
        fields = list(
          list(name = "Name", type = "singleLineText"),
          list(name = "Tags", type = "multipleSelects"),
          list(name = "Refs", type = "multipleRecordLinks")
        )
      )
    },
    at_create_records = function(base_id, table_id, records, ...) {
      captured <<- records
      lapply(seq_along(records), function(i) list(id = paste0("rec", i)))
    }
  )

  data <- tibble::tibble(
    Name = "Alice",
    Tags = "A; B",
    Refs = "recX; recY"
  )
  expect_message(air_write(data, "Table1", "appX"), "Created 1 record")

  expect_equal(captured[[1]]$fields$Tags, c("A", "B"))
  expect_equal(captured[[1]]$fields$Refs, c("recX", "recY"))
  expect_equal(captured[[1]]$fields$Name, "Alice")
})

test_that("air_write expands flat collaborator email string using schema", {
  captured <- NULL
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    get_table_schema = function(...) {
      list(
        id = "tbl1",
        fields = list(
          list(name = "Owner", type = "singleCollaborator"),
          list(name = "Team", type = "multipleCollaborators")
        )
      )
    },
    at_create_records = function(base_id, table_id, records, ...) {
      captured <<- records
      list(list(id = "rec1"))
    }
  )

  data <- tibble::tibble(
    Owner = "alice@example.com",
    Team = "bob@example.com; usr00000000000000"
  )
  expect_message(air_write(data, "Table1", "appX"), "Created 1 record")

  expect_equal(captured[[1]]$fields$Owner, list(email = "alice@example.com"))
  expect_equal(
    captured[[1]]$fields$Team,
    list(list(email = "bob@example.com"), list(id = "usr00000000000000"))
  )
})

test_that("air_write leaves already-classed air_multiselect untouched", {
  captured <- NULL
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    get_table_schema = function(...) {
      list(
        id = "tbl1",
        fields = list(
          list(name = "Tags", type = "multipleSelects")
        )
      )
    },
    at_create_records = function(base_id, table_id, records, ...) {
      captured <<- records
      list(list(id = "rec1"))
    }
  )

  data <- tibble::tibble(Tags = new_air_multiselect(list(c("A", "B"))))
  expect_message(air_write(data, "Table1", "appX"), "Created 1 record")
  # A classed multiselect cell is the bare character vector; expansion is a
  # no-op and unclass_air leaves it as a character vector (serializes to array).
  expect_equal(captured[[1]]$fields$Tags, c("A", "B"))
})

test_that("air_upsert expands flat multiselect strings using schema", {
  captured <- NULL
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    get_table_schema = function(...) {
      list(
        id = "tbl1",
        fields = list(
          list(name = "Name", type = "singleLineText"),
          list(name = "Tags", type = "multipleSelects")
        )
      )
    },
    at_update_records = function(base_id, table_id, records, ...) {
      captured <<- records
      list(records = records, createdRecords = "rec1", updatedRecords = character())
    }
  )

  data <- tibble::tibble(Name = "Alice", Tags = "A; B")
  expect_message(
    air_upsert(data, "Table1", "Name", "appX"),
    "Upsert complete"
  )
  expect_equal(captured[[1]]$fields$Tags, c("A", "B"))
})

test_that("tibble_to_records is byte-for-byte unchanged with field_types=NULL", {
  data <- tibble::tibble(
    airtable_id = c("rec1", "rec2"),
    Name = c("Alice", "Bob"),
    Tags = c("A; B", "C")
  )
  before <- tibble_to_records(data, id_col = "airtable_id")
  after <- tibble_to_records(data, id_col = "airtable_id", field_types = NULL)
  expect_identical(before, after)
  # Without schema, flat strings stay as scalar strings (no expansion)
  expect_equal(before[[1]]$fields$Tags, "A; B")
})

test_that("air_delete with empty IDs gives message and no-ops", {
  expect_message(
    air_delete(character(), "Table1", "appX"),
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
    air_delete(c("rec1", "rec2"), "Table1", "appX"),
    "Deleted 2 record"
  )
  expect_equal(deleted, c("rec1", "rec2"))
})
