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

# --- Gap-filling tests (Stage 8A) ---

test_that("dbGetInfo returns expected fields", {
  skip_if_not_installed("DBI")
  state <- new.env(parent = emptyenv())
  state$valid <- TRUE
  con <- methods::new(
    "AirtableConnection",
    token = "tok",
    base_id = "appTEST",
    state = state
  )
  info <- DBI::dbGetInfo(con)
  expect_type(info, "list")
  expect_true("db.version" %in% names(info))
  expect_true("host" %in% names(info))
  expect_true("valid" %in% names(info))
  expect_true("base_id" %in% names(info))
  expect_equal(info$host, "appTEST")
  expect_equal(info$base_id, "appTEST")
  expect_true(info$valid)
})

test_that("dbWriteTable with append = TRUE calls air_write", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()
  write_called <- FALSE

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    air_write = function(data, table, base_id, .token = NULL, ...) {
      write_called <<- TRUE
      invisible(character())
    }
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  df <- data.frame(Name = "Charlie", Age = 40L)
  result <- DBI::dbWriteTable(con, "Contacts", df, append = TRUE)

  expect_true(result)
  expect_true(write_called)
})

test_that("dbWriteTable with overwrite = TRUE calls air_sync", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()
  sync_called <- FALSE

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    air_sync = function(data, table, key, base_id, delete_missing = TRUE, .token = NULL, ...) {
      sync_called <<- TRUE
      invisible(list(created = 0L, updated = 0L, deleted = 0L, unchanged = 0L))
    }
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  df <- data.frame(Name = "Charlie", Age = 40L)
  result <- DBI::dbWriteTable(con, "Contacts", df, overwrite = TRUE)

  expect_true(result)
  expect_true(sync_called)
})

test_that("dbWriteTable without append or overwrite errors", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema()
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  df <- data.frame(Name = "Charlie", Age = 40L)
  expect_error(DBI::dbWriteTable(con, "Contacts", df), "append")
})

test_that("dbWriteTable creates table and writes when table does not exist", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()
  create_called <- FALSE
  write_called  <- FALSE

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    at_create_table = function(name, fields, base_id = NULL, ...) {
      create_called <<- TRUE
      list(id = "tblNew", name = name)
    },
    schema_cache_invalidate = function(...) invisible(NULL),
    air_write = function(data, table, base_id, ...) {
      write_called <<- TRUE
      invisible(character())
    }
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  df <- data.frame(Name = "Charlie")
  result <- DBI::dbWriteTable(con, "NoSuchTable", df)

  expect_true(result)
  expect_true(create_called)
  expect_true(write_called)
})

test_that("dbExistsTable returns FALSE for unknown table", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema()
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  expect_false(DBI::dbExistsTable(con, "NoSuchTable"))
})

test_that("dbListFields errors for non-existent table", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema()
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  expect_error(DBI::dbListFields(con, "NoSuchTable"), "does not exist")
})

test_that("dbi_parse_statement handles no-WHERE statement", {
  result <- airtable2:::dbi_parse_statement("Contacts")
  expect_equal(result$table, "Contacts")
  expect_null(result$formula)
})

test_that("dbi_parse_statement handles lower-case where", {
  result <- airtable2:::dbi_parse_statement("Contacts where {Age} > 30")
  expect_equal(result$table, "Contacts")
  expect_equal(result$formula, "{Age} > 30")
})

test_that("dbi_parse_statement handles multiple-word formula", {
  result <- airtable2:::dbi_parse_statement("My Table WHERE AND({Age} > 30, {Active})")
  expect_equal(result$table, "My Table")
  expect_equal(result$formula, "AND({Age} > 30, {Active})")
})

test_that("dbListTables in multi-base mode returns Base.Table format", {
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    at_list_bases = function(token = NULL) tibble::tibble(
      id = "appTEST",
      name = "My Base",
      permissionLevel = "create"
    )
  )

  state <- new.env(parent = emptyenv())
  state$valid <- TRUE
  state$bases <- NULL
  con <- methods::new(
    "AirtableConnection",
    token = "tok",
    base_id = "",
    state = state
  )

  tables <- DBI::dbListTables(con)
  expect_equal(tables, "My Base.Contacts")
})

test_that("dbSendQuery with WHERE clause passes formula", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    at_list_records = function(...) mock_contacts_records()
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  res <- DBI::dbSendQuery(con, "Contacts WHERE {Age} > 25")
  on.exit(DBI::dbClearResult(res), add = TRUE)

  expect_equal(DBI::dbGetStatement(res), "Contacts WHERE {Age} > 25")
  expect_equal(nrow(DBI::dbFetch(res)), 2L)
})

test_that("dbGetRowsAffected returns NA_integer_ for read-only result", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    at_list_records = function(...) mock_contacts_records()
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  res <- DBI::dbSendQuery(con, "Contacts")
  on.exit(DBI::dbClearResult(res), add = TRUE)

  expect_identical(DBI::dbGetRowsAffected(res), NA_integer_)
})

test_that("dbFetch without n argument fetches all rows", {
  skip_if_not_installed("DBI")
  schema_cache_invalidate()

  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) mock_contacts_schema(),
    at_list_records = function(...) mock_contacts_records()
  )

  con <- DBI::dbConnect(airtable2(), token = "tok", base_id = "appTEST")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  res <- DBI::dbSendQuery(con, "Contacts")
  on.exit(DBI::dbClearResult(res), add = TRUE)

  all_rows <- DBI::dbFetch(res)
  expect_equal(nrow(all_rows), 2L)
  expect_equal(all_rows$Name, c("Alice", "Bob"), ignore_attr = TRUE)
})
