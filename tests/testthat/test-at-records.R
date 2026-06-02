test_that("at_list_records validates inputs", {
  expect_error(at_list_records(123, "Table"), "must be a single non-NA string")
  expect_error(at_list_records("app123", 456), "must be a single non-NA string")
})

test_that("at_get_record validates inputs", {
  expect_error(at_get_record("app123", "Table", 999), "must be a single non-NA string")
})

test_that("at_create_records validates inputs", {
  expect_error(at_create_records(123, "Table", list()), "must be a single non-NA string")
  expect_error(
    at_create_records("app123", "Table", list(), typecast = "yes"),
    "must be.*TRUE.*FALSE"
  )
})

test_that("at_update_records validates method", {
  expect_error(
    at_update_records("app123", "Table", list(), method = "DELETE"),
    "should be one of"
  )
})

test_that("at_delete_records validates inputs", {
  expect_error(at_delete_records(123, "Table", "rec1"), "must be a single non-NA string")
})
