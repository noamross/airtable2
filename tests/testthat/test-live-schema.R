# Integration tests for schema mutation operations (create/update table/field).
#
# Mocked by default using local_mocked_bindings on air_perform.
# Opt-in to live tests with:
#   AIRTABLE_TEST_SCHEMA=true (also requires AIRTABLE_API_KEY, AIRTABLE_WORKSPACE_ID)
#
# Live tests use the shared "airtable2_test_schema" base.

# --- Mocked tests (always run) ---

test_that("at_create_table returns created table object", {
  local_mocked_bindings(
    air_perform = function(req) {
      list(
        id = "tblNEW123",
        name = "Projects",
        fields = list(
          list(id = "fldTITLE1", name = "Title", type = "singleLineText"),
          list(id = "fldBUDGET1", name = "Budget", type = "number")
        ),
        description = "Test projects table"
      )
    }
  )

  result <- at_create_table(
    base_id = "appTEST123",
    name = "Projects",
    fields = list(
      list(name = "Title", type = "singleLineText"),
      list(name = "Budget", type = "number", options = list(precision = 2L))
    ),
    description = "Test projects table",
    token = "fake_token"
  )

  expect_equal(result$name, "Projects")
  expect_equal(result$id, "tblNEW123")
})

test_that("at_update_table returns updated table object", {
  local_mocked_bindings(
    air_perform = function(req) {
      list(
        id = "tblTEST123",
        name = "People",
        description = "Renamed from Contacts"
      )
    }
  )

  result <- at_update_table(
    base_id = "appTEST123",
    table_id = "tblTEST123",
    name = "People",
    description = "Renamed from Contacts",
    token = "fake_token"
  )

  expect_equal(result$name, "People")
  expect_equal(result$description, "Renamed from Contacts")
})

test_that("at_create_field returns created field object", {
  local_mocked_bindings(
    air_perform = function(req) {
      list(
        id = "fldWEB1",
        name = "Website",
        type = "url",
        description = "Personal website"
      )
    }
  )

  result <- at_create_field(
    base_id = "appTEST123",
    table_id = "tblTEST123",
    name = "Website",
    type = "url",
    description = "Personal website",
    token = "fake_token"
  )

  expect_equal(result$name, "Website")
  expect_equal(result$type, "url")
  expect_equal(result$id, "fldWEB1")
})

test_that("at_update_field returns updated field object", {
  local_mocked_bindings(
    air_perform = function(req) {
      list(
        id = "fldEMAIL1",
        name = "EmailAddress",
        type = "email",
        description = "Primary email"
      )
    }
  )

  result <- at_update_field(
    base_id = "appTEST123",
    table_id = "tblTEST123",
    field_id = "fldEMAIL1",
    name = "EmailAddress",
    description = "Primary email",
    token = "fake_token"
  )

  expect_equal(result$name, "EmailAddress")
  expect_equal(result$description, "Primary email")
})

test_that("at_update_table requires name or description", {
  expect_error(
    at_update_table("appX", "tblX"),
    "name.*description"
  )
})

test_that("at_update_field requires name or description", {
  expect_error(
    at_update_field("appX", "tblX", "fldX"),
    "name.*description"
  )
})

# --- Live tests (opt-in with AIRTABLE_TEST_SCHEMA=true) ---

test_that("live: at_create_table creates a table in schema base", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()

  table_name <- paste0("TestTable_", format(Sys.time(), "%H%M%S"))

  new_table <- at_create_table(
    base_id = base_id,
    name = table_name,
    fields = list(
      list(name = "Title", type = "singleLineText"),
      list(name = "Budget", type = "number", options = list(precision = 2L))
    ),
    description = "Created by live schema test"
  )

  expect_equal(new_table$name, table_name)
  expect_false(is.null(new_table$id))
  expect_match(new_table$id, "^tbl")

  # Verify it appears in schema
  schema <- at_get_schema(base_id)
  table_names <- vapply(schema, function(t) t$name, character(1))
  expect_true(table_name %in% table_names)
})

test_that("live: at_create_field adds a field to schema base", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()

  # Get the Scratch table ID
  schema <- at_get_schema(base_id)
  scratch <- Filter(function(t) t$name == "Scratch", schema)
  if (length(scratch) == 0L) {
    skip("Scratch table not found in schema base")
  }
  table_id <- scratch[[1]]$id

  field_name <- paste0("Field_", format(Sys.time(), "%H%M%S"))

  new_field <- at_create_field(
    base_id = base_id,
    table_id = table_id,
    name = field_name,
    type = "singleLineText",
    description = "Created by live test"
  )

  expect_equal(new_field$name, field_name)
  expect_equal(new_field$type, "singleLineText")
  expect_false(is.null(new_field$id))
})

test_that("live: at_update_table changes table name", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()

  # Create a table to rename
  orig_name <- paste0("ToRename_", format(Sys.time(), "%H%M%S"))
  tbl <- at_create_table(
    base_id = base_id,
    name = orig_name,
    fields = list(list(name = "Dummy", type = "singleLineText"))
  )

  new_name <- paste0("Renamed_", format(Sys.time(), "%H%M%S"))
  result <- at_update_table(
    base_id = base_id,
    table_id = tbl$id,
    name = new_name,
    description = "Renamed by live test"
  )

  expect_equal(result$name, new_name)
})

test_that("live: at_update_field changes field name", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()

  # Get the Scratch table
  schema <- at_get_schema(base_id)
  scratch <- Filter(function(t) t$name == "Scratch", schema)
  if (length(scratch) == 0L) {
    skip("Scratch table not found in schema base")
  }
  table_id <- scratch[[1]]$id

  # Create a field to rename
  orig_name <- paste0("ToRename_", format(Sys.time(), "%H%M%S"))
  field <- at_create_field(
    base_id = base_id,
    table_id = table_id,
    name = orig_name,
    type = "singleLineText"
  )

  new_name <- paste0("Renamed_", format(Sys.time(), "%H%M%S"))
  result <- at_update_field(
    base_id = base_id,
    table_id = table_id,
    field_id = field$id,
    name = new_name,
    description = "Renamed by live test"
  )

  expect_equal(result$name, new_name)
})

test_that("live: air_schema returns structured schema tibble", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()

  result <- air_schema(base_id)
  expect_s3_class(result, "tbl_df")
  expect_gte(nrow(result), 1L)
  expect_true("Scratch" %in% result$table_name)
  expect_false(is.na(result$table_id[result$table_name == "Scratch"]))

  # Check nested fields tibble
  scratch_row <- result[result$table_name == "Scratch", ]
  fields <- scratch_row$fields[[1]]
  expect_s3_class(fields, "tbl_df")
  expect_gte(nrow(fields), 1L)
  expect_true(all(c("id", "name", "type") %in% names(fields)))
})

test_that("live: air_meta returns flat field metadata", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()

  result <- air_meta(base_id)
  expect_s3_class(result, "tbl_df")
  expect_gte(nrow(result), 1L)
  expect_true(all(
    c("table_name", "table_id", "field_name", "field_id", "field_type") %in%
      names(result)
  ))
})
