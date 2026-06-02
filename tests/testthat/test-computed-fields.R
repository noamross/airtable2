test_that("computed_field_types returns expected types", {
  types <- computed_field_types()
  expect_true("formula" %in% types)
  expect_true("rollup" %in% types)
  expect_true("autoNumber" %in% types)
  expect_true("createdTime" %in% types)
  expect_true("lastModifiedTime" %in% types)
  expect_true("lastModifiedBy" %in% types)
  expect_true("createdBy" %in% types)
  expect_true("lookup" %in% types)
  expect_true("count" %in% types)
  # Writable types should NOT be included
  expect_false("singleLineText" %in% types)
  expect_false("number" %in% types)
  expect_false("checkbox" %in% types)
})

test_that("computed_fields_from_schema identifies computed fields", {
  schema <- list(
    list(name = "Name", type = "singleLineText"),
    list(name = "Age", type = "number"),
    list(name = "FullName", type = "formula"),
    list(name = "Total", type = "rollup"),
    list(name = "Modified", type = "lastModifiedTime"),
    list(name = "ModifiedBy", type = "lastModifiedBy"),
    list(name = "ID", type = "autoNumber"),
    list(name = "Tags", type = "multipleSelects")
  )
  computed <- computed_fields_from_schema(schema)
  expect_equal(
    sort(computed),
    sort(c("FullName", "Total", "Modified", "ModifiedBy", "ID"))
  )
})

test_that("computed_fields_from_schema handles NULL schema", {
  expect_equal(computed_fields_from_schema(NULL), character())
})

test_that("tibble_to_records respects exclude parameter", {
  data <- tibble::tibble(
    Name = "Alice",
    Age = 30L,
    Formula = "computed",
    Modified = "2024-01-01"
  )
  records <- tibble_to_records(data, id_col = NULL, exclude = c("Formula", "Modified"))
  expect_equal(names(records[[1]]$fields), c("Name", "Age"))
})

test_that("tibble_to_records with exclude still handles airtable_id", {
  data <- tibble::tibble(
    airtable_id = "rec123",
    Name = "Alice",
    Formula = "computed"
  )
  records <- tibble_to_records(data, id_col = "airtable_id", exclude = "Formula")
  expect_equal(records[[1]]$id, "rec123")
  expect_equal(names(records[[1]]$fields), "Name")
})
