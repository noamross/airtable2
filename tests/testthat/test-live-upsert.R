# Live integration tests for upsert operations
# Uses shared "airtable2_test_main" base.

test_that("air_upsert creates new records via merge field", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  data <- tibble::tibble(
    Name = c("Alice", "Bob"),
    Email = c("alice@test.com", "bob@test.com"),
    Age = c(30L, 25L)
  )

  result <- air_upsert(data, base_id, "Contacts", merge_on = "Name")
  expect_length(result$created, 2L)
  expect_length(result$updated, 0L)
})

test_that("air_upsert updates existing records via merge field", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  # Create records
  data <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(30L, 25L))
  air_write(data, base_id, "Contacts")

  # Upsert: update Alice's age, add Charlie
  upsert_data <- tibble::tibble(
    Name = c("Alice", "Charlie"),
    Age = c(31L, 35L)
  )
  result <- air_upsert(upsert_data, base_id, "Contacts", merge_on = "Name")
  expect_length(result$created, 1L)
  expect_length(result$updated, 1L)

  # Verify
  all_records <- air_read(base_id, "Contacts")
  expect_equal(nrow(all_records), 3L)
  alice <- all_records[all_records$Name == "Alice", ]
  expect_equal(alice$Age, 31, ignore_attr = TRUE)
})

test_that("air_upsert uses airtable_id for direct matching", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  # Create a record
  data <- tibble::tibble(Name = "Alice", Age = 30L)
  air_write(data, base_id, "Contacts")

  # Read back to get the ID
  records <- air_read(base_id, "Contacts")
  alice_id <- records$airtable_id[records$Name == "Alice"]

  # Upsert using airtable_id
  update_data <- tibble::tibble(
    airtable_id = alice_id,
    Name = "Alice",
    Age = 99L
  )
  result <- air_upsert(update_data, base_id, "Contacts", merge_on = "Name")
  expect_length(result$updated, 1L)

  # Verify the update
  records <- air_read(base_id, "Contacts")
  expect_equal(records$Age[records$Name == "Alice"], 99)
})

test_that("air_upsert with add_fields='error' rejects unknown columns", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  data <- tibble::tibble(Name = "Alice", FakeField = "nope")
  expect_error(
    air_upsert(data, base_id, "Contacts", merge_on = "Name", add_fields = "error"),
    "not found in table"
  )
})

test_that("air_upsert with add_fields='warn' drops unknown columns", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  data <- tibble::tibble(Name = "Alice", FakeField = "nope")
  expect_warning(
    result <- air_upsert(
      data, base_id, "Contacts",
      merge_on = "Name", add_fields = "warn"
    ),
    "unknown column"
  )
  expect_length(result$created, 1L)
})
