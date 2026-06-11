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

# ── detect_complex_cols() ─────────────────────────────────────────────────────

test_that("detect_complex_cols finds list-columns whose elements are lists", {
  data <- tibble::tibble(
    name   = "Alice",
    nested = list(list(a = 1, b = 2))
  )
  expect_equal(detect_complex_cols(data, c("name", "nested")), "nested")
})

test_that("detect_complex_cols finds data-frame elements", {
  data <- tibble::tibble(
    df_col = list(data.frame(x = 1:3, y = letters[1:3]))
  )
  expect_equal(detect_complex_cols(data, "df_col"), "df_col")
})

test_that("detect_complex_cols ignores non-list columns", {
  data <- tibble::tibble(name = "Alice", age = 30L, flag = TRUE)
  expect_equal(detect_complex_cols(data, c("name", "age", "flag")), character())
})

test_that("detect_complex_cols ignores list-columns of plain character vectors", {
  # These are valid multiselect payloads — not complex
  data <- tibble::tibble(tags = list(c("a", "b"), c("c")))
  expect_equal(detect_complex_cols(data, "tags"), character())
})

test_that("detect_complex_cols ignores NULL elements (all-NULL list col)", {
  data <- tibble::tibble(col = list(NULL, NULL))
  expect_equal(detect_complex_cols(data, "col"), character())
})

test_that("detect_complex_cols ignores air_*-classed columns", {
  air_classes <- c("air_links", "air_multiselect", "air_attachments",
                   "air_collaborator", "air_collaborators", "air_barcode")
  for (cls in air_classes) {
    col <- structure(list(list(a = 1)), class = c(cls, "list"))
    data <- tibble::tibble(x = col)
    expect_equal(
      detect_complex_cols(data, "x"),
      character(),
      label = paste("should ignore column-level class", cls)
    )
  }
})

test_that("detect_complex_cols ignores plain list-columns whose elements have air_* classes", {
  # This is the case produced by lapply(..., new_air_links) — each *element*
  # is an air_* object even though the column itself has no air_* class.
  all_classes <- c("air_links", "air_multiselect", "air_attachments",
                   "air_collaborator", "air_collaborators", "air_barcode")
  for (cls in all_classes) {
    elem <- structure(list(id = "recXXX"), class = c(cls, "list"))
    # plain list column — no class at the column level
    data <- tibble::tibble(x = list(elem, elem))
    expect_equal(
      detect_complex_cols(data, "x"),
      character(),
      label = paste("should ignore element-level class", cls)
    )
  }
})

test_that("air_upsert does not error when a linked-records column uses new_air_links per-element", {
  # Regression: air_demo constructs Lead Artist as lapply(..., new_air_links)
  # which produces a plain list with air_links elements — should not be
  # flagged as complex.
  captured <- NULL
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    at_get_schema = function(...) {
      list(list(
        id = "tbl1", name = "Projects",
        fields = list(
          list(name = "Project Name", type = "singleLineText"),
          list(name = "Lead Artist",  type = "multipleRecordLinks")
        )
      ))
    },
    at_update_records = function(base_id, table_id, records, ...) {
      captured <<- records
      list(records = records, createdRecords = character(), updatedRecords = "rec1")
    }
  )

  link_data <- tibble::tibble(
    `Project Name` = "Alpha",
    `Lead Artist`  = list(new_air_links(list("recArtist1")))
  )
  expect_no_error(
    suppressMessages(
      air_upsert(link_data, "Projects", "Project Name", "appX")
    )
  )
})

# ── serialize_json_cols() ─────────────────────────────────────────────────────

test_that("serialize_json_cols converts list elements to JSON strings", {
  data <- tibble::tibble(info = list(list(a = 1L, b = "x")))
  result <- serialize_json_cols(data, "info")
  expect_type(result$info, "character")
  expect_equal(jsonlite::fromJSON(result$info[[1]])$b, "x")
})

test_that("serialize_json_cols maps NULL and NA elements to NA_character_", {
  data <- tibble::tibble(info = list(list(a = 1), NULL, NA))
  result <- serialize_json_cols(data, "info")
  expect_false(is.na(result$info[[1]]))
  expect_true(is.na(result$info[[2]]))
  expect_true(is.na(result$info[[3]]))
})

test_that("serialize_json_cols warns and NAs oversized values for singleLineText", {
  big <- paste(rep("x", 100001L), collapse = "")   # JSON will be > 100k chars
  data <- tibble::tibble(col = list(list(v = big), list(v = "small")))
  expect_warning(
    result <- serialize_json_cols(data, "col", c(col = "singleLineText")),
    "100,000-character"
  )
  expect_true(is.na(result$col[[1]]))
  expect_false(is.na(result$col[[2]]))
})

test_that("serialize_json_cols warning names the affected rows", {
  big <- paste(rep("x", 100001L), collapse = "")
  data <- tibble::tibble(col = list(list(v = big), list(v = "ok")))
  expect_warning(
    serialize_json_cols(data, "col", c(col = "singleLineText")),
    "row"
  )
})

test_that("serialize_json_cols does not truncate for multilineText fields", {
  big <- paste(rep("x", 100001L), collapse = "")
  data <- tibble::tibble(col = list(list(v = big)))
  expect_no_warning(
    result <- serialize_json_cols(data, "col", c(col = "multilineText"))
  )
  expect_false(is.na(result$col[[1]]))
})

test_that("serialize_json_cols does not truncate when field_types is NULL", {
  big <- paste(rep("x", 100001L), collapse = "")
  data <- tibble::tibble(col = list(list(v = big)))
  expect_no_warning(
    result <- serialize_json_cols(data, "col", field_types = NULL)
  )
  expect_false(is.na(result$col[[1]]))
})

# ── complex_fields parameter in air_write() ───────────────────────────────────

test_that("air_write errors on complex columns by default", {
  local_mocked_bindings(
    get_computed_fields   = function(...) character(),
    get_attachment_fields = function(...) character()
  )
  data <- tibble::tibble(name = "Alice", info = list(list(a = 1)))
  expect_error(
    air_write(data, "Table1", "appX"),
    "complex"
  )
})

test_that("air_write complex_fields='warn' drops complex columns with a warning", {
  captured <- NULL
  local_mocked_bindings(
    get_computed_fields   = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(base_id, table_id, records, ...) {
      captured <<- records
      list(list(id = "rec1"))
    }
  )
  data <- tibble::tibble(name = "Alice", info = list(list(a = 1)))
  expect_warning(
    suppressMessages(
      air_write(data, "Table1", "appX", complex_fields = "warn")
    ),
    "complex column"
  )
  expect_false("info" %in% names(captured[[1L]]$fields))
  expect_true("name" %in% names(captured[[1L]]$fields))
})

test_that("air_write complex_fields='json' serialises complex columns to JSON strings", {
  captured <- NULL
  local_mocked_bindings(
    get_computed_fields   = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(base_id, table_id, records, ...) {
      captured <<- records
      list(list(id = "rec1"))
    }
  )
  data <- tibble::tibble(
    name = "Alice",
    info = list(list(a = 1L, b = "hello"))
  )
  suppressMessages(
    air_write(data, "Table1", "appX", complex_fields = "json")
  )
  json_val <- captured[[1L]]$fields$info
  expect_type(json_val, "character")
  parsed <- jsonlite::fromJSON(json_val)
  expect_equal(parsed$a, 1L)
  expect_equal(parsed$b, "hello")
})

test_that("air_write complex_fields='json' NA rows produce NULL field (dropped)", {
  captured <- NULL
  local_mocked_bindings(
    get_computed_fields   = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(base_id, table_id, records, ...) {
      captured <<- records
      lapply(seq_along(records), function(i) list(id = paste0("rec", i)))
    }
  )
  data <- tibble::tibble(
    name = c("Alice", "Bob"),
    info = list(list(a = 1), NULL)
  )
  suppressMessages(
    air_write(data, "Table1", "appX", complex_fields = "json")
  )
  expect_type(captured[[1L]]$fields$info, "character")
  expect_null(captured[[2L]]$fields$info)   # NA serialised → dropped by compact
})

# ── add_fields='yes' field-type inference ─────────────────────────────────────

test_that("add_fields='yes' creates checkbox fields with required icon/color options", {
  created <- list()
  local_mocked_bindings(
    get_computed_fields   = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_get_schema = function(...) {
      list(list(
        id = "tbl1", name = "Table1",
        fields = list(list(name = "Name", type = "singleLineText"))
      ))
    },
    schema_cache_invalidate = function(...) invisible(NULL),
    at_create_field = function(name, base_id, table_id, type,
                               options = NULL, token = NULL) {
      created[[name]] <<- list(type = type, options = options)
      list(id = paste0("fld", name), name = name, type = type)
    },
    at_create_records = function(...) list(list(id = "rec1"))
  )

  data <- tibble::tibble(Name = "Alice", Active = TRUE)
  suppressMessages(air_write(data, "Table1", "appX", add_fields = "yes"))

  expect_equal(created$Active$type, "checkbox")
  expect_equal(created$Active$options$icon, "check")
  expect_equal(created$Active$options$color, "greenBright")
})

test_that("add_fields='yes' creates multilineText for complex_fields='json' columns", {
  created <- list()
  local_mocked_bindings(
    get_computed_fields   = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_get_schema = function(...) {
      list(list(
        id = "tbl1", name = "Table1",
        fields = list(list(name = "Name", type = "singleLineText"))
      ))
    },
    schema_cache_invalidate = function(...) invisible(NULL),
    at_create_field = function(name, base_id, table_id, type,
                               options = NULL, token = NULL) {
      created[[name]] <<- list(type = type, options = options)
      list(id = paste0("fld", name), name = name, type = type)
    },
    at_create_records = function(...) list(list(id = "rec1"))
  )

  data <- tibble::tibble(Name = "Alice", events = list(list(x = 1)))
  suppressMessages(
    air_write(data, "Table1", "appX", add_fields = "yes", complex_fields = "json")
  )

  expect_equal(created$events$type, "multilineText")
})

# ── create_table = TRUE ───────────────────────────────────────────────────────

test_that("air_write with create_table = TRUE creates table when missing then writes", {
  create_called <- FALSE

  local_mocked_bindings(
    get_table_schema = function(...) NULL,
    at_create_table = function(name, fields, base_id = NULL, ...) {
      create_called <<- TRUE
      list(id = "tblNew", name = name)
    },
    schema_cache_invalidate = function(...) invisible(NULL),
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(base_id, table_id, records, ...) {
      lapply(seq_along(records), function(i) list(id = paste0("rec", i)))
    }
  )

  data <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(30L, 25L))
  expect_message(
    ids <- air_write(data, "NewTable", "appX", create_table = TRUE),
    "Created 2 record"
  )
  expect_true(create_called)
  expect_equal(ids, c("rec1", "rec2"))
})

test_that("air_write with create_table = TRUE skips creation when table exists", {
  create_called <- FALSE

  local_mocked_bindings(
    get_table_schema = function(...) {
      list(id = "tblEx", name = "Existing", fields = list(
        list(name = "Name", type = "singleLineText"),
        list(name = "Age",  type = "number")
      ))
    },
    at_create_table = function(...) { create_called <<- TRUE },
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(...) list(list(id = "rec1"))
  )

  data <- tibble::tibble(Name = "Alice", Age = 30L)
  expect_message(
    air_write(data, "Existing", "appX", create_table = TRUE),
    "Created 1 record"
  )
  expect_false(create_called)
})

test_that("air_write does not create table when create_table = FALSE (default)", {
  create_called <- FALSE

  local_mocked_bindings(
    get_table_schema = function(...) NULL,
    at_create_table = function(...) { create_called <<- TRUE },
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) character(),
    at_create_records = function(...) list(list(id = "rec1"))
  )

  data <- tibble::tibble(Name = "Alice")
  expect_message(air_write(data, "AnyTable", "appX"), "Created 1 record")
  expect_false(create_called)
})
