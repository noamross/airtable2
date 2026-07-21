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
  expect_equal(result$airtable_id, c("rec1", "rec2"), ignore_attr = TRUE)
  expect_equal(result$Name, c("Alice", "Bob"), ignore_attr = TRUE)
  expect_equal(result$Age, c(30, 25), ignore_attr = TRUE)
})

test_that("records_to_tibble handles missing fields with NA", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T00:00:00.000Z",
         fields = list(Name = "Alice", Status = "Active")),
    list(id = "rec2", createdTime = "2024-01-02T00:00:00.000Z",
         fields = list(Name = "Bob"))
  )
  result <- records_to_tibble(records, schema = NULL)
  expect_equal(result$Status, c("Active", NA), ignore_attr = TRUE)
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

test_that("records_to_tibble coerces date-only createdTime fields to Date", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T12:34:56.000Z",
         fields = list(event_date = "2024-01-01")),
    list(id = "rec2", createdTime = "2024-01-02T12:34:56.000Z",
         fields = list(event_date = "2024-01-02"))
  )
  schema <- list(
    list(
      name = "event_date", type = "createdTime",
      options = list(result = list(
        type = "date",
        options = list(dateFormat = list(name = "iso", format = "YYYY-MM-DD"))
      ))
    )
  )
  result <- records_to_tibble(records, schema = schema)
  expect_s3_class(result$event_date, "Date")
  expect_equal(
    as.numeric(result$event_date),
    as.numeric(as.Date(c("2024-01-01", "2024-01-02")))
  )
  # airtable_created_time (the meta column) always stays a full datetime
  expect_s3_class(result$airtable_created_time, "POSIXct")
})

test_that("records_to_tibble coerces date-only lastModifiedTime fields to Date", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T12:34:56.000Z",
         fields = list(last_touched = "2024-01-03")),
    list(id = "rec2", createdTime = "2024-01-02T12:34:56.000Z",
         fields = list(last_touched = "2024-01-04"))
  )
  schema <- list(
    list(
      name = "last_touched", type = "lastModifiedTime",
      options = list(result = list(
        type = "date",
        options = list(dateFormat = list(name = "iso", format = "YYYY-MM-DD"))
      ))
    )
  )
  result <- records_to_tibble(records, schema = schema)
  expect_s3_class(result$last_touched, "Date")
  expect_equal(
    as.numeric(result$last_touched),
    as.numeric(as.Date(c("2024-01-03", "2024-01-04")))
  )
})

test_that("records_to_tibble keeps full datetime lastModifiedTime fields as POSIXct", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T12:34:56.000Z",
         fields = list(last_touched_at = "2024-01-01T12:34:56.000Z"))
  )
  schema <- list(
    list(
      name = "last_touched_at", type = "lastModifiedTime",
      options = list(result = list(type = "dateTime"))
    )
  )
  result <- records_to_tibble(records, schema = schema)
  expect_s3_class(result$last_touched_at, "POSIXct")
})

test_that("records_to_tibble keeps full datetime createdTime fields as POSIXct", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T12:34:56.000Z",
         fields = list(event_time = "2024-01-01T12:34:56.000Z"))
  )
  schema <- list(
    list(
      name = "event_time", type = "createdTime",
      options = list(result = list(type = "dateTime"))
    )
  )
  result <- records_to_tibble(records, schema = schema)
  expect_s3_class(result$event_time, "POSIXct")
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

test_that("records_to_tibble converts na strings to NA (no schema)", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T00:00:00.000Z",
         fields = list(Name = "Alice", SubprojectId = "NA")),
    list(id = "rec2", createdTime = "2024-01-02T00:00:00.000Z",
         fields = list(Name = "Bob", SubprojectId = "sub123"))
  )
  result <- records_to_tibble(records, schema = NULL, na = "NA")
  expect_equal(result$SubprojectId, c(NA, "sub123"), ignore_attr = TRUE)
})

test_that("records_to_tibble na conversion applies before schema coercion", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T00:00:00.000Z",
         fields = list(Score = "N/A"))
  )
  schema <- list(list(name = "Score", type = "number"))
  result <- records_to_tibble(records, schema = schema, na = c("N/A", "NA"))
  expect_true(is.na(result$Score))
  expect_type(result$Score, "double")
})

test_that("records_to_tibble na = NULL leaves values untouched", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T00:00:00.000Z",
         fields = list(Name = "NA"))
  )
  result <- records_to_tibble(records, schema = NULL, na = NULL)
  expect_equal(result$Name, "NA", ignore_attr = TRUE)
})

test_that("records_to_tibble na conversion does not touch list-columns", {
  records <- list(
    list(id = "rec1", createdTime = "2024-01-01T00:00:00.000Z",
         fields = list(Tags = list("NA", "Python")))
  )
  schema <- list(list(name = "Tags", type = "multipleSelects"))
  result <- records_to_tibble(records, schema = schema, na = "NA")
  expect_equal(result$Tags[[1]], list("NA", "Python"))
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

test_that("tibble_to_records sends JSON null for NA fields to clear Airtable values", {
  data <- tibble::tibble(Name = "Alice", Status = NA_character_)
  records <- tibble_to_records(data, id_col = NULL)
  expect_true("Status" %in% names(records[[1]]$fields))
  expect_equal(records[[1]]$fields$Status, jsonlite::unbox(NA))
})

test_that("tibble_to_records sends JSON null for list-column NULL to clear Airtable values", {
  data <- tibble::tibble(Name = c("Alice", "Bob"), Tags = list(c("R", "Python"), NULL))
  records <- tibble_to_records(data, id_col = NULL)
  expect_equal(records[[1]]$fields$Tags, c("R", "Python"))
  expect_true("Tags" %in% names(records[[2]]$fields))
  expect_equal(records[[2]]$fields$Tags, jsonlite::unbox(NA))
})

test_that("tibble_to_records NA fields serialize to JSON null", {
  data <- tibble::tibble(Name = "Alice", Age = NA_real_)
  records <- tibble_to_records(data, id_col = NULL)
  json <- jsonlite::toJSON(records[[1]]$fields, auto_unbox = TRUE)
  expect_match(json, '"Age":null')
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

# ── print methods: no bare quoted IDs ────────────────────────────────────────

test_that("print.air_multiselect shows class and count without raw IDs", {
  obj <- new_air_multiselect(list(c("a", "b"), "c"))
  out <- capture.output(print(obj))
  expect_match(out, "air_multiselect", fixed = TRUE)
})

test_that("print.air_links shows class header without quoting IDs", {
  obj <- new_air_links(list(c("rec123", "rec456")))
  out <- capture.output(print(obj))
  expect_match(out, "air_links", fixed = TRUE)
})

test_that("format.air_links shows single record ID without extra quotes", {
  obj <- new_air_links(list("recABC123XYZ"))
  result <- format(obj)
  # The raw id should appear without surrounding quotes
  expect_equal(result, "recABC123XYZ")
  expect_false(grepl("^\"", result))
})

test_that("print.air_attachments shows class header", {
  obj <- new_air_attachments(list(list(list(filename = "photo.jpg"))))
  out <- capture.output(print(obj))
  expect_match(out, "air_attachments", fixed = TRUE)
})

test_that("print.air_collaborator shows class header", {
  obj <- new_air_collaborator(list(list(name = "Alice", email = "alice@example.com", id = "usrABC")))
  out <- capture.output(print(obj))
  expect_match(out, "air_collaborator", fixed = TRUE)
})

test_that("print.air_barcode shows class header", {
  obj <- new_air_barcode(list(list(text = "12345", type = "QR")))
  out <- capture.output(print(obj))
  expect_match(out, "air_barcode", fixed = TRUE)
})

test_that("air_simplify flattens classed air_* columns via the generic", {
  data <- tibble::tibble(
    Name = c("A", "B"),
    Tags = new_air_multiselect(list(c("x", "y"), NULL)),
    Links = new_air_links(list("rec1", c("rec2", "rec3")))
  )
  # No schema: classed columns should still flatten via dispatch
  result <- air_simplify(data)
  expect_type(result$Tags, "character")
  expect_equal(result$Tags, c("x; y", NA))
  expect_type(result$Links, "character")
  expect_equal(result$Links, c("rec1", "rec2; rec3"))
  expect_equal(result$Name, c("A", "B"))
})
