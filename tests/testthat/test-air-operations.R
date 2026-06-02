test_that("air_read validates inputs", {
  expect_error(air_read(123, "Table"), "must be a single non-NA string")
  expect_error(air_read("app1", 123), "must be a single non-NA string")
})

test_that("air_write validates inputs", {
  expect_error(air_write(123, "Table", data.frame()), "must be a single non-NA string")
})

test_that("air_upsert validates inputs", {
  expect_error(air_upsert(123, "Table", data.frame(), "key"), "must be a single non-NA string")
  expect_error(
    air_upsert("app1", "Table", data.frame(), "key", add_fields = "invalid"),
    "should be one of"
  )
})

test_that("air_sync validates inputs", {
  expect_error(air_sync(123, "Table", data.frame(), "key"), "must be a single non-NA string")
  df <- data.frame(x = 1)
  expect_error(
    air_sync("app1", "Table", df, "missing_key"),
    "not found"
  )
})

test_that("air_delete validates inputs", {
  expect_error(air_delete(123, "Table", "rec1"), "must be a single non-NA string")
})

test_that("air_delete handles empty input", {
  expect_message(air_delete("app1", "Table", character()), "No records to delete")
})
