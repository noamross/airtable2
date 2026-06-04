# Live integration tests for read/write operations
# Requires AIRTABLE_API_KEY and AIRTABLE_WORKSPACE_ID env vars.
# Uses shared "airtable2_test_main" base.

test_that("air_write creates records and air_read retrieves them", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  data <- test_contacts_data()
  ids <- air_write(data, base_id, "Contacts")

  expect_length(ids, 3L)
 expect_true(all(grepl("^rec", ids)))

  result <- air_read(base_id, "Contacts")
  expect_equal(nrow(result), 3L)
  expect_true("airtable_id" %in% names(result))
  expect_true("airtable_created_time" %in% names(result))

  expect_type(result$Name, "character")
  expect_type(result$Age, "double")
  expect_type(result$Active, "logical")
  expect_type(result$Tags, "list")
  expect_s3_class(result$airtable_created_time, "POSIXct")

  expect_setequal(result$Name, c("Alice", "Bob", "Charlie"))
})

test_that("air_read returns correct types for checkboxes", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  data <- tibble::tibble(Name = c("Yes", "No"), Active = c(TRUE, FALSE))
  air_write(data, base_id, "Contacts")

  result <- air_read(base_id, "Contacts")
  yes_row <- result[result$Name == "Yes", ]
  no_row <- result[result$Name == "No", ]
  expect_true(yes_row$Active)
  expect_false(no_row$Active)
})

test_that("air_read with fields parameter returns subset", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  air_write(test_contacts_data(), base_id, "Contacts")

  result <- air_read(base_id, "Contacts", fields = c("Name", "Age"))
  expect_true("Name" %in% names(result))
  expect_true("Age" %in% names(result))
  expect_equal(nrow(result), 3L)
})

test_that("air_read with formula filters records", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  air_write(test_contacts_data(), base_id, "Contacts")

  result <- air_read(base_id, "Contacts", formula = "{Age} > 28")
  expect_equal(nrow(result), 2L)
  expect_true(all(result$Age > 28))
})

test_that("air_read on empty table returns 0-row tibble", {
  skip_on_cran()
  clear_test_records()
  base_id <- get_test_base()

  result <- air_read(base_id, "Contacts")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true("airtable_id" %in% names(result))
})
