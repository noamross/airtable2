# Live tests for air_describe_init. Creates a table in the schema test base,
# so it requires AIRTABLE_TEST_LIVE=true and AIRTABLE_TEST_SCHEMA=true.

test_that("live: air_describe_init creates and seeds a description table", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()

  desc_table <- paste0("_desc_", format(Sys.time(), "%H%M%S"))
  desc <- air_describe(
    title = "Live Test Base",
    creator = "airtable2 tests",
    license = "CC BY 4.0",
    isPartOf = "https://doi.org/10.48321/MyDMP01"
  )

  air_describe_init(desc, base_id, desc_table = desc_table)

  result <- air_read(desc_table, base_id)
  expect_equal(nrow(result), 1L)
  expect_equal(result$title, "Live Test Base", ignore_attr = TRUE)
  expect_equal(result$license, "CC BY 4.0", ignore_attr = TRUE)
  expect_equal(result$isPartOf, "https://doi.org/10.48321/MyDMP01", ignore_attr = TRUE)

  # Re-running upserts on desc_key rather than duplicating the row
  air_describe_init(desc, base_id, desc_table = desc_table)
  expect_equal(nrow(air_read(desc_table, base_id)), 1L)
})

test_that("live: air_describe_init uses the session default base", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()

  desc_table <- paste0("_desc_", format(Sys.time(), "%H%M%S"), "b")
  withr::local_options(airtable2.base_id = base_id)

  air_describe_init(air_describe(title = "Session Base"), desc_table = desc_table)

  expect_equal(air_read(desc_table)$title, "Session Base", ignore_attr = TRUE)
})
