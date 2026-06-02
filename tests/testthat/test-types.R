test_that("records_to_tibble handles empty input", {
  result <- records_to_tibble(list(), schema = NULL)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true("airtable_id" %in% names(result))
  expect_true("airtable_created_time" %in% names(result))
})

test_that("records_to_tibble produces correct structure", {
  records <- list(
    list(
      id = "rec1",
      createdTime = "2024-01-01T00:00:00.000Z",
      fields = list(Name = "Alice", Age = 30)
    ),
    list(
      id = "rec2",
      createdTime = "2024-01-02T00:00:00.000Z",
      fields = list(Name = "Bob", Age = 25)
    )
  )
  result <- records_to_tibble(records, schema = NULL)
  expect_equal(nrow(result), 2L)
  expect_equal(result$airtable_id, c("rec1", "rec2"))
  expect_equal(result$Name, c("Alice", "Bob"))
  expect_equal(result$Age, c(30, 25))
})

test_that("records_to_tibble handles missing fields with NA", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T00:00:00.000Z",
         fields = list(Name = "Alice", Status = "Active")),
    list(id = "rec2", createdTime = "2024-01-02T00:00:00.000Z",
         fields = list(Name = "Bob"))
  )
  result <- records_to_tibble(records, schema = NULL)
  expect_equal(result$Status, c("Active", NA))
})

test_that("records_to_tibble with schema coerces types", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T00:00:00.000Z",
         fields = list(Name = "Alice", StartDate = "2024-06-15", Active = TRUE))
  )
  schema <- list(
    list(name = "Name", type = "singleLineText"),
    list(name = "StartDate", type = "date"),
    list(name = "Active", type = "checkbox")
  )
  result <- records_to_tibble(records, schema = schema)
  expect_s3_class(result$StartDate, "Date")
  expect_type(result$Active, "logical")
})

test_that("records_to_tibble keeps list-columns for multi-select", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T00:00:00.000Z",
         fields = list(Tags = list("R", "Python")))
  )
  schema <- list(
    list(name = "Tags", type = "multipleSelects")
  )
  result <- records_to_tibble(records, schema = schema)
  expect_type(result$Tags, "list")
  expect_equal(result$Tags[[1]], list("R", "Python"))
})

test_that("tibble_to_records converts correctly", {
  data <- tibble::tibble(
    airtable_id = c("rec1", "rec2"),
    Name = c("Alice", "Bob"),
    Age = c(30L, 25L)
  )
  records <- tibble_to_records(data, id_col = "airtable_id")
  expect_length(records, 2L)
  expect_equal(records[[1]]$id, "rec1")
  expect_equal(records[[1]]$fields$Name, "Alice")
  expect_equal(records[[1]]$fields$Age, 30L)
})

test_that("tibble_to_records without id_col omits id", {
  data <- tibble::tibble(Name = c("Alice", "Bob"))
  records <- tibble_to_records(data, id_col = NULL)
  expect_null(records[[1]]$id)
  expect_equal(records[[1]]$fields$Name, "Alice")
})

test_that("tibble_to_records converts NA fields to NULL (omitted)", {
  data <- tibble::tibble(Name = "Alice", Status = NA_character_)
  records <- tibble_to_records(data, id_col = NULL)
  expect_false("Status" %in% names(records[[1]]$fields))
})

test_that("coerce_date works", {
  expect_equal(coerce_date("2024-06-15"), as.Date("2024-06-15"))
  expect_true(is.na(coerce_date(NA_character_)))
})

test_that("coerce_datetime works", {
  result <- coerce_datetime("2024-01-01T12:30:00.000Z")
  expect_s3_class(result, "POSIXct")
  expect_equal(attr(result, "tzone"), "UTC")
})
