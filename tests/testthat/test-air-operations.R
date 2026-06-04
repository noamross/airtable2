test_that("air_read validates inputs", {
  # table-first signature: air_read(table, base_id, ...)
  # bad table (arg 1)
  expect_error(air_read(123, "app1"), "must be a single non-NA string")
  # bad base_id (arg 2)
  expect_error(air_read("Table", 123), "must be a single non-NA string")
})

test_that("air_write validates inputs", {
  # data-first signature: air_write(data, table, base_id)
  # bad table (arg 2)
  expect_error(
    air_write(data.frame(), 123, "app1"),
    "must be a single non-NA string"
  )
  # bad base_id (arg 3)
  expect_error(
    air_write(data.frame(), "Table", 123),
    "must be a single non-NA string"
  )
})

test_that("air_upsert validates inputs", {
  # data-first signature: air_upsert(data, table, merge_on, base_id)
  # bad table (arg 2)
  expect_error(
    air_upsert(data.frame(), 123, "key", "app1"),
    "must be a single non-NA string"
  )
  # bad add_fields
  expect_error(
    air_upsert(data.frame(), "Table", "key", "app1", add_fields = "invalid"),
    "should be one of"
  )
})

test_that("air_sync validates inputs", {
  # data-first signature: air_sync(data, table, key, base_id)
  # bad table (arg 2)
  expect_error(
    air_sync(data.frame(), 123, "key", "app1"),
    "must be a single non-NA string"
  )
  df <- data.frame(x = 1)
  expect_error(air_sync(df, "Table", "missing_key", "app1"), "not found")
})

test_that("air_delete validates inputs", {
  # record_ids-first signature: air_delete(record_ids, table, base_id)
  # bad table (arg 2)
  expect_error(
    air_delete("rec1", 123, "app1"),
    "must be a single non-NA string"
  )
})

test_that("air_delete handles empty input", {
  expect_message(
    air_delete(character(), "Table", "app1"),
    "No records to delete"
  )
})
