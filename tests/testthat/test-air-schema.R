test_that("air_schema validates input", {
  expect_error(air_schema(123), "must be a single non-NA string")
})

test_that("air_meta validates input", {
  expect_error(air_meta(123), "must be a single non-NA string")
})

test_that("air_table_template builds correct structure", {
  result <- air_table_template(
    "My Table",
    fields = list(
      air_field_template("Name", "singleLineText"),
      air_field_template("Count", "number", description = "A count field")
    ),
    description = "A test table"
  )
  expect_equal(result$name, "My Table")
  expect_equal(result$description, "A test table")
  expect_length(result$fields, 2L)
  expect_equal(result$fields[[1]]$name, "Name")
  expect_equal(result$fields[[2]]$type, "number")
  expect_equal(result$fields[[2]]$description, "A count field")
})

test_that("air_field_template validates inputs", {
  expect_error(air_field_template(123, "text"), "must be a single non-NA string")
  expect_error(air_field_template("Name", 123), "must be a single non-NA string")
})

test_that("air_field_template omits NULL options", {
  result <- air_field_template("Status", "singleSelect")
  expect_false("options" %in% names(result))
  expect_false("description" %in% names(result))
})
