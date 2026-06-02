# Live integration tests for sync, delete, and computed field handling.
# Uses shared "airtable2_test_main" base.

test_that("air_sync creates, updates, deletes, and detects unchanged", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  # Seed with initial data
  initial <- tibble::tibble(
    Name = c("Alice", "Bob", "Charlie"),
    Age = c(30L, 25L, 35L)
  )
  air_write(base_id, "Contacts", initial)

  # Sync to desired state: keep Alice unchanged, update Bob, drop Charlie, add Dana
  desired <- tibble::tibble(
    Name = c("Alice", "Bob", "Dana"),
    Age = c(30L, 26L, 28L)
  )

  result <- air_sync(
    base_id,
    "Contacts",
    desired,
    key = "Name",
    hash_fields = "Age",
    delete_missing = TRUE
  )

  expect_equal(result$created, 1L)
  expect_equal(result$updated, 1L)
  expect_equal(result$deleted, 1L)
  expect_equal(result$unchanged, 1L)

  # Verify final state
  final <- air_read(base_id, "Contacts")
  expect_setequal(final$Name, c("Alice", "Bob", "Dana"))
  expect_equal(final$Age[final$Name == "Bob"], 26)
  expect_equal(final$Age[final$Name == "Dana"], 28)
})

test_that("air_sync with delete_missing=FALSE preserves extra records", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  initial <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(30L, 25L))
  air_write(base_id, "Contacts", initial)

  # Sync with only Alice (Bob should remain)
  desired <- tibble::tibble(Name = "Alice", Age = 30L)
  result <- air_sync(
    base_id,
    "Contacts",
    desired,
    key = "Name",
    delete_missing = FALSE
  )

  expect_equal(result$deleted, 0L)
  final <- air_read(base_id, "Contacts")
  expect_equal(nrow(final), 2L)
})

test_that("air_sync is idempotent (no changes on second run)", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  data <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(30L, 25L))
  air_write(base_id, "Contacts", data)

  result <- air_sync(
    base_id,
    "Contacts",
    data,
    key = "Name",
    hash_fields = "Age",
    delete_missing = TRUE
  )

  expect_equal(result$created, 0L)
  expect_equal(result$updated, 0L)
  expect_equal(result$deleted, 0L)
  expect_equal(result$unchanged, 2L)
})

test_that("air_delete removes specific records", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  air_write(base_id, "Contacts", test_contacts_data())
  records <- air_read(base_id, "Contacts")

  alice_id <- records$airtable_id[records$Name == "Alice"]
  air_delete(base_id, "Contacts", alice_id)

  remaining <- air_read(base_id, "Contacts")
  expect_equal(nrow(remaining), 2L)
  expect_false("Alice" %in% remaining$Name)
})

test_that("air_write silently drops computed fields", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()
  ensure_formula_field()

  # Write data that includes the computed field column
  data <- tibble::tibble(
    Name = "Alice",
    Age = 30L,
    NameUpper = "ALICE"
  )

  # Should succeed (computed field silently dropped)
  expect_message(
    ids <- air_write(base_id, "Contacts", data),
    "Dropping computed"
  )
  expect_length(ids, 1L)

  # Verify the record was created and formula computed
  result <- air_read(base_id, "Contacts")
  expect_equal(result$Name, "Alice")
  expect_equal(result$NameUpper, "ALICE")
})

test_that("air_upsert silently drops computed fields", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()
  ensure_formula_field()

  # Upsert with the formula column present
  data <- tibble::tibble(
    Name = "Bob",
    Age = 25L,
    NameUpper = "BOB"
  )
  expect_message(
    result <- air_upsert(base_id, "Contacts", data, merge_on = "Name"),
    "Dropping computed"
  )
  expect_length(result$created, 1L)
})

test_that("air_sync excludes computed fields from hash", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()
  ensure_formula_field()

  # Write initial data
  initial <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(30L, 25L))
  air_write(base_id, "Contacts", initial)

  # Read back (includes NameUpper from server-computed formula)
  current <- air_read(base_id, "Contacts")
  expect_true("NameUpper" %in% names(current))

  # Sync with the same writable data — should detect no changes
  # The formula field should be excluded from hash comparison automatically.
  desired <- tibble::tibble(Name = c("Alice", "Bob"), Age = c(30L, 25L))
  result <- air_sync(
    base_id,
    "Contacts",
    desired,
    key = "Name",
    hash_fields = NULL
  )

  expect_equal(result$unchanged, 2L)
  expect_equal(result$created, 0L)
  expect_equal(result$updated, 0L)
})
