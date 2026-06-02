test_that("at_create_table validates inputs", {
  expect_error(at_create_table(123, "Table", list()), "must be a single non-NA string")
  expect_error(at_create_table("app1", 123, list()), "must be a single non-NA string")
})

test_that("at_update_table requires at least one argument", {
  expect_error(at_update_table("app1", "tbl1"), "At least one")
})

test_that("at_create_field validates inputs", {
  expect_error(
    at_create_field("app1", "tbl1", 123, "singleLineText"),
    "must be a single non-NA string"
  )
  expect_error(
    at_create_field("app1", "tbl1", "Name", 123),
    "must be a single non-NA string"
  )
})

test_that("at_update_field requires at least one argument", {
  expect_error(at_update_field("app1", "tbl1", "fld1"), "At least one")
})
