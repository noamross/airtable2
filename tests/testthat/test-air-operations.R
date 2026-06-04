test_that("air_read validates inputs", {
  # base_id must be a string (data-first signature: base_id is arg 1)
  expect_error(air_read(123, "Table"), "must be a single non-NA string")
  expect_error(air_read("app1", 123), "must be a single non-NA string")
})

test_that("air_write validates inputs", {
  # data-first signature: air_write(data, base_id, table)
  expect_error(
    air_write(data.frame(), 123, "Table"),
    "must be a single non-NA string"
  )
  expect_error(
    air_write(data.frame(), "app1", 123),
    "must be a single non-NA string"
  )
})

test_that("air_upsert validates inputs", {
  # data-first signature: air_upsert(data, base_id, table, merge_on)
  expect_error(
    air_upsert(data.frame(), 123, "Table", "key"),
    "must be a single non-NA string"
  )
  expect_error(
    air_upsert(data.frame(), "app1", "Table", "key", add_fields = "invalid"),
    "should be one of"
  )
})

test_that("air_sync validates inputs", {
  # data-first signature: air_sync(data, base_id, table, key)
  expect_error(
    air_sync(data.frame(), 123, "Table", "key"),
    "must be a single non-NA string"
  )
  df <- data.frame(x = 1)
  expect_error(air_sync(df, "app1", "Table", "missing_key"), "not found")
})

test_that("air_delete validates inputs", {
  expect_error(
    air_delete(123, "Table", "rec1"),
    "must be a single non-NA string"
  )
})

test_that("air_delete handles empty input", {
  expect_message(
    air_delete("app1", "Table", character()),
    "No records to delete"
  )
})
