mock_contacts_schema <- function() {
  list(
    list(
      id = "tblContacts",
      name = "Contacts",
      fields = list(
        list(id = "fldName", name = "Name", type = "singleLineText"),
        list(id = "fldAge", name = "Age", type = "number"),
        list(id = "fldTags", name = "Tags", type = "multipleSelects")
      )
    )
  )
}

mock_contacts_records <- function() {
  list(
    list(
      id = "rec1",
      createdTime = "2024-01-01T00:00:00.000Z",
      fields = list(Name = "Alice", Age = 30, Tags = list("R", "Python"))
    ),
    list(
      id = "rec2",
      createdTime = "2024-01-02T00:00:00.000Z",
      fields = list(Name = "Bob", Age = 25, Tags = list("Julia"))
    )
  )
}

test_that("DBI connection lists and reads base-mode tables", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    at_list_records = function(...) mock_contacts_records()
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  expect_true(DBI::dbIsValid(con))
  expect_equal(DBI::dbListTables(con), "Contacts")
  expect_true(DBI::dbExistsTable(con, "Contacts"))
  expect_equal(DBI::dbListFields(con, "Contacts"), c("Name", "Age", "Tags"))

  data <- DBI::dbReadTable(con, "Contacts")
  expect_s3_class(data, "tbl_df")
  expect_equal(data$Name, c("Alice", "Bob"), ignore_attr = TRUE)
  expect_s3_class(data$Tags, "air_multiselect")
})

test_that("DBI results fetch incrementally", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    at_list_records = function(...) mock_contacts_records()
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  res <- DBI::dbSendQuery(con, "Contacts WHERE {Age} > 20")
  on.exit(DBI::dbClearResult(res), add = TRUE)

  first <- DBI::dbFetch(res, n = 1)
  second <- DBI::dbFetch(res, n = 1)

  expect_equal(first$Name, "Alice")
  expect_equal(second$Name, "Bob")
  expect_true(DBI::dbHasCompleted(res))
  expect_equal(DBI::dbGetRowCount(res), 2L)
  expect_equal(DBI::dbGetStatement(res), "Contacts WHERE {Age} > 20")
})

test_that("dbRemoveTable errors with a message mentioning the web UI", {
  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  expect_error(DBI::dbRemoveTable(con, "MyTable"), "web UI")
})

test_that("show() for base-mode connection displays base name from at_get_base", {
  local_mocked_bindings(
    at_list_bases = function(token = NULL) tibble::tibble(
      id = "appTEST",
      name = "My Test Base",
      permissionLevel = "create"
    )
  )
  state <- new.env(parent = emptyenv())
  state$valid <- TRUE
  con <- methods::new(
    "AirtableConnection",
    token = "tok",
    base_id = "appTEST",
    state = state
  )
  out <- cli::cli_fmt(show(con))
  expect_true(any(grepl("My Test Base", out)))
  expect_true(any(grepl("appTEST", out)))
})

test_that("show() for all-bases connection displays mode info", {
  state <- new.env(parent = emptyenv())
  state$valid <- TRUE
  con <- methods::new(
    "AirtableConnection",
    token = "tok",
    base_id = "",
    state = state
  )
  out <- cli::cli_fmt(show(con))
  expect_true(any(grepl("all accessible bases", out)))
})

test_that("schema cache reuses and invalidates base schemas", {
  schema_cache_invalidate()
  calls <- 0L

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) {
      calls <<- calls + 1L
      mock_contacts_schema()
    }
  )

  expect_equal(get_base_schema("appTEST", token = "tok"), mock_contacts_schema())
  expect_equal(get_base_schema("appTEST", token = "tok"), mock_contacts_schema())
  expect_equal(calls, 1L)

  schema_cache_invalidate("appTEST")
  expect_equal(get_base_schema("appTEST", token = "tok"), mock_contacts_schema())
  expect_equal(calls, 2L)
})
