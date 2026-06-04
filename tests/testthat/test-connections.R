# Tests for air_connect() and air_pane() (R/connections.R)

# Minimal mocked at_list_bases / DBI::dbConnect so no network is touched.

fake_bases <- function() {
  tibble::tibble(
    id = c("appAAA111", "appBBB222"),
    name = c("My Base", "Other Base"),
    permissionLevel = c("create", "edit")
  )
}

fake_conn <- function(base_id = "appAAA111", valid = TRUE) {
  state <- new.env(parent = emptyenv())
  state$valid <- valid
  methods::new(
    "AirtableConnection",
    token = "fake_token",
    base_id = base_id,
    state = state
  )
}

# air_connect calls DBI::dbConnect internally. We mock air_token so no real
# credentials are needed, and at_list_bases so no network call is made.
# DBI::dbConnect runs naturally (just creates an S4 object; connection-pane
# observer is a no-op outside RStudio/Positron).

test_that("air_connect resolves a base ID directly without listing bases", {
  bases_called <- FALSE
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_list_bases = function(token = NULL) { bases_called <<- TRUE; fake_bases() }
  )
  con <- air_connect(base = "appAAA111")
  expect_false(bases_called)
  expect_equal(con@base_id, "appAAA111")
})

test_that("air_connect resolves a base name via at_list_bases", {
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_list_bases = function(token = NULL) fake_bases()
  )
  con <- air_connect(base = "My Base")
  expect_equal(con@base_id, "appAAA111")
})

test_that("air_connect errors with informative message on unknown base name", {
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_list_bases = function(token = NULL) fake_bases(),
    at_whoami     = function(token = NULL) list(id = "usrXYZ", email = "me@x.com")
  )
  expect_error(
    air_connect(base = "Nonexistent Base"),
    "Could not find an Airtable base"
  )
})

test_that("air_connect warns when multiple bases share the same name", {
  dup_bases <- tibble::tibble(
    id = c("appDUP1", "appDUP2"),
    name = c("Dup", "Dup"),
    permissionLevel = c("create", "edit")
  )
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_list_bases = function(token = NULL) dup_bases
  )
  expect_warning(
    con <- air_connect(base = "Dup"),
    "Multiple bases named"
  )
  expect_equal(con@base_id, "appDUP1")
})

test_that("air_connect with no base creates an all-bases connection", {
  local_mocked_bindings(air_token = function(token = NULL) "fake_token")
  con <- air_connect()
  expect_equal(con@base_id, "")
})

# ── air_pane ─────────────────────────────────────────────────────────────────

test_that("air_pane returns connection invisibly and emits a message", {
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_list_bases = function(token = NULL) fake_bases()
  )
  expect_message(con <- air_pane(base = "My Base"), "Connection")
  expect_s4_class(con, "AirtableConnection")
})

# ── observer registration ─────────────────────────────────────────────────────

# Mock observer using an env so callers can inspect updated `calls` after the
# withr::with_options block exits.
new_mock_observer <- function() {
  e <- new.env(parent = emptyenv())
  e$calls <- list()
  e$connectionOpened <- function(...) {
    e$calls[[length(e$calls) + 1L]] <- list(type = "connectionOpened", args = list(...))
  }
  e$connectionClosed <- function(...) {
    e$calls[[length(e$calls) + 1L]] <- list(type = "connectionClosed", args = list(...))
  }
  e
}

fake_schema <- function() {
  list(
    list(
      id = "tbl001", name = "Projects",
      fields = list(
        list(id = "fld001", name = "Title", type = "singleLineText")
      ),
      views = list(
        list(id = "viw001", name = "Grid view")
      )
    ),
    list(
      id = "tbl002", name = "Tasks",
      fields = list(
        list(id = "fld002", name = "Name", type = "singleLineText")
      ),
      views = list()
    )
  )
}

# --- dbListTables returns table names ----------------------------------------

test_that("dbListTables returns table names for a base-mode connection", {
  schema_cache_invalidate()
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) fake_schema()
  )
  state <- new.env(parent = emptyenv())
  state$valid <- TRUE
  con <- methods::new("AirtableConnection",
    token = "tok", base_id = "appFAKE", state = state)
  expect_equal(DBI::dbListTables(con), c("Projects", "Tasks"))
})

# --- connectionOpened is called when a connectionObserver is set -------------

test_that("dbConnect calls connectionOpened on the observer", {
  schema_cache_invalidate()
  obs <- new_mock_observer()
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    at_get_base   = function(base_id, token = NULL) list(name = "My Base")
  )
  withr::with_options(list(connectionObserver = obs), {
    con <- air_connect(base = "appFAKE")
    DBI::dbDisconnect(con)
  })
  opened <- Filter(function(x) x$type == "connectionOpened", obs$calls)
  expect_length(opened, 1L)
  args <- opened[[1L]]$args
  expect_equal(args$type, "Airtable")
})

# --- listObjects callback returns a data frame with table names --------------

test_that("listObjects callback in connectionOpened returns table rows", {
  schema_cache_invalidate()
  obs <- new_mock_observer()
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    at_get_base   = function(base_id, token = NULL) list(name = "My Base")
  )
  con <- withr::with_options(list(connectionObserver = obs), {
    air_connect(base = "appFAKE")
  })
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  opened <- Filter(function(x) x$type == "connectionOpened", obs$calls)
  expect_length(opened, 1L)
  list_objects <- opened[[1L]]$args$listObjects
  expect_true(is.function(list_objects))

  result <- list_objects(type = "table")
  expect_s3_class(result, "data.frame")
  expect_true("name" %in% names(result))
  expect_true("type" %in% names(result))
  expect_setequal(result$name, c("Projects", "Tasks"))
})

# --- listColumns callback returns a data frame with field names --------------

test_that("listColumns callback in connectionOpened returns field rows", {
  schema_cache_invalidate()
  obs <- new_mock_observer()
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    at_get_base   = function(base_id, token = NULL) list(name = "My Base")
  )
  con <- withr::with_options(list(connectionObserver = obs), {
    air_connect(base = "appFAKE")
  })
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  opened <- Filter(function(x) x$type == "connectionOpened", obs$calls)
  list_columns <- opened[[1L]]$args$listColumns
  expect_true(is.function(list_columns))

  result <- list_columns(table = "Projects")
  expect_s3_class(result, "data.frame")
  expect_true("name" %in% names(result))
  expect_equal(result$name, "Title")
})

# --- air_pane uses air_pane() as the reconnect code -------------------------

test_that("air_pane registers connection with air_pane() reconnect code", {
  schema_cache_invalidate()
  obs <- new_mock_observer()
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    at_get_base   = function(base_id, token = NULL) list(name = "My Base"),
    at_list_bases = function(token = NULL) fake_bases()
  )
  con <- withr::with_options(list(connectionObserver = obs), {
    air_pane(base = "appFAKE")
  })
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  opened <- Filter(function(x) x$type == "connectionOpened", obs$calls)
  expect_length(opened, 1L)
  connect_code <- opened[[1L]]$args$connectCode
  expect_match(connect_code, "air_pane")
  expect_match(connect_code, "appFAKE")
})

# --- connectionObserver not called when no observer is set ------------------

test_that("connection_observer_open is a no-op when no observer is set", {
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_get_base   = function(base_id, token = NULL) list(name = "My Base")
  )
  withr::with_options(
    list(connectionObserver = NULL),
    {
      # Should not error
      expect_no_error(con <- air_connect(base = "appFAKE"))
      DBI::dbDisconnect(con)
    }
  )
})

# --- connectionClosed is called on dbDisconnect when observer is set --------

test_that("dbDisconnect calls connectionClosed on the observer", {
  schema_cache_invalidate()
  obs <- new_mock_observer()
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    at_get_base   = function(base_id, token = NULL) list(name = "My Base")
  )
  withr::with_options(
    list(connectionObserver = obs),
    {
      con <- air_connect(base = "appFAKE")
      DBI::dbDisconnect(con)
    }
  )
  closed <- Filter(function(x) x$type == "connectionClosed", obs$calls)
  expect_length(closed, 1L)
})

# --- listObjectTypes for include_views includes view type -------------------

test_that("listObjects with include_views=TRUE returns views alongside tables", {
  schema_cache_invalidate()
  obs <- new_mock_observer()
  local_mocked_bindings(
    air_token     = function(token = NULL) "fake_token",
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    at_get_base   = function(base_id, token = NULL) list(name = "My Base")
  )
  con <- withr::with_options(list(connectionObserver = obs), {
    air_connect(base = "appFAKE", include_views = TRUE)
  })
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  opened <- Filter(function(x) x$type == "connectionOpened", obs$calls)
  list_objects <- opened[[1L]]$args$listObjects
  result <- list_objects(type = "table")
  # Should include "Projects:Grid view" in addition to base table names
  expect_true(any(grepl("Grid view", result$name)))
})
