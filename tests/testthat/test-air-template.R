# Tests for air_infer_fields() and air_infer_table()

test_that("air_infer_fields maps basic R types to Airtable field types", {
  df <- data.frame(
    Name   = c("Alice", "Bob"),
    Score  = c(3.14, 2.71),
    Count  = c(1L, 2L),
    Active = c(TRUE, FALSE),
    Joined = as.Date(c("2024-01-01", "2024-02-01")),
    stringsAsFactors = FALSE
  )
  fields <- air_infer_fields(df)

  expect_length(fields, 5L)

  expect_equal(fields[[1]]$name, "Name")
  expect_equal(fields[[1]]$type, "singleLineText")
  expect_null(fields[[1]]$options)

  expect_equal(fields[[2]]$name, "Score")
  expect_equal(fields[[2]]$type, "number")
  expect_equal(fields[[2]]$options$precision, 8L)

  expect_equal(fields[[3]]$name, "Count")
  expect_equal(fields[[3]]$type, "number")
  expect_equal(fields[[3]]$options$precision, 0L)

  expect_equal(fields[[4]]$name, "Active")
  expect_equal(fields[[4]]$type, "checkbox")
  expect_equal(fields[[4]]$options$icon, "check")

  expect_equal(fields[[5]]$name, "Joined")
  expect_equal(fields[[5]]$type, "date")
  expect_equal(fields[[5]]$options$dateFormat$name, "iso")
})

test_that("air_infer_fields maps factor to singleSelect with level choices", {
  df <- data.frame(
    Name   = "Alice",
    Status = factor("Open", levels = c("Open", "Closed", "Pending")),
    stringsAsFactors = FALSE
  )
  fields <- air_infer_fields(df)
  status <- fields[[2]]

  expect_equal(status$name, "Status")
  expect_equal(status$type, "singleSelect")
  choice_names <- vapply(status$options$choices, `[[`, character(1), "name")
  expect_equal(choice_names, c("Open", "Closed", "Pending"))
})

test_that("air_infer_fields first column becomes primary (position preserved)", {
  df <- data.frame(Title = "foo", Notes = "bar", stringsAsFactors = FALSE)
  fields <- air_infer_fields(df)
  expect_equal(fields[[1]]$name, "Title")
  expect_equal(fields[[2]]$name, "Notes")
})

test_that("air_infer_fields errors on data frame with no columns", {
  expect_error(air_infer_fields(data.frame()), "at least one column")
})

test_that("air_infer_fields falls back to singleLineText for unknown types", {
  df <- data.frame(
    Name = "Alice",
    Time = as.POSIXct("2024-01-01 12:00:00"),
    stringsAsFactors = FALSE
  )
  fields <- air_infer_fields(df)
  expect_equal(fields[[2]]$type, "singleLineText")
})

test_that("air_infer_fields handles a single-column data frame", {
  df <- data.frame(ID = c("a", "b"), stringsAsFactors = FALSE)
  fields <- air_infer_fields(df)
  expect_length(fields, 1L)
  expect_equal(fields[[1]]$name, "ID")
  expect_equal(fields[[1]]$type, "singleLineText")
})

test_that("air_infer_table returns complete table spec", {
  df <- data.frame(Name = "Alice", Age = 30L, stringsAsFactors = FALSE)
  spec <- air_infer_table(df, "People")

  expect_equal(spec$name, "People")
  expect_length(spec$fields, 2L)
  expect_equal(spec$fields[[1]]$name, "Name")
  expect_equal(spec$fields[[1]]$type, "singleLineText")
  expect_equal(spec$fields[[2]]$name, "Age")
  expect_equal(spec$fields[[2]]$type, "number")
})

test_that("air_infer_table passes through description", {
  df <- data.frame(Name = "Alice", stringsAsFactors = FALSE)
  spec <- air_infer_table(df, "People", description = "Test table")
  expect_equal(spec$description, "Test table")
})

test_that("air_infer_table with no description omits that field", {
  df <- data.frame(Name = "Alice", stringsAsFactors = FALSE)
  spec <- air_infer_table(df, "People")
  expect_null(spec$description)
})
