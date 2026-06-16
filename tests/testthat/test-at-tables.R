test_that("at_create_table validates inputs", {
  # name-first signature: at_create_table(name, fields, base_id = NULL)
  expect_error(at_create_table(123, list(), "appX"), "must be a single non-NA string")
  expect_error(at_create_table("T",  list(), 123),   "must be a single non-NA string")
})

test_that("at_update_table requires at least one argument", {
  expect_error(at_update_table("app1", "tbl1"), "At least one")
})

test_that("at_create_field validates inputs", {
  # name-first signature: at_create_field(name, table_id, type, base_id = NULL)
  expect_error(
    at_create_field(123, "tbl1", "singleLineText", "appX"),
    "must be a single non-NA string"
  )
  expect_error(
    at_create_field("Name", "tbl1", "singleLineText", 123),
    "must be a single non-NA string"
  )
})

test_that("at_update_field requires at least one argument", {
  expect_error(at_update_field("app1", "tbl1", "fld1"), "At least one")
})

test_that("at_create_table uses default id/singleLineText field when fields omitted", {
  captured_body <- NULL
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      captured_body <<- req$body$data
      list(id = "tblNew", name = "Scratch", fields = list())
    }
  )
  result <- at_create_table("Scratch", base_id = "appX")
  expect_equal(result$id, "tblNew")
  expect_length(captured_body$fields, 1L)
  expect_equal(captured_body$fields[[1]]$name, "id")
  expect_equal(captured_body$fields[[1]]$type, "singleLineText")
})

test_that("at_create_base uses default table when tables omitted", {
  captured_body <- NULL
  local_mocked_bindings(
    air_token            = function(token = NULL) "fake_token",
    default_workspace_id = function() "wspDEFAULT",
    air_perform          = function(req) {
      captured_body <<- req$body$data
      list(id = "appNew", name = "My Base", tables = list())
    }
  )
  result <- at_create_base("My Base")
  expect_equal(result$id, "appNew")
  expect_length(captured_body$tables, 1L)
  default_fields <- captured_body$tables[[1]]$fields
  expect_length(default_fields, 1L)
  expect_equal(default_fields[[1]]$name, "id")
  expect_equal(default_fields[[1]]$type, "singleLineText")
})
