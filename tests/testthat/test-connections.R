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
