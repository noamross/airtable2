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
