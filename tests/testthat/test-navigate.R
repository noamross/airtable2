# Tests for air_resolve_id() and air_browse() (R/navigate.R)

# ── air_resolve_id ──────────────────────────────────────────────────────────

test_that("air_resolve_id identifies workspace IDs", {
  r <- air_resolve_id("wspABC123XYZ")
  expect_equal(r$type, "workspace")
  expect_equal(r$id, "wspABC123XYZ")
})

test_that("air_resolve_id identifies base IDs", {
  r <- air_resolve_id("appABC123XYZ")
  expect_equal(r$type, "base")
  expect_equal(r$id, "appABC123XYZ")
})

test_that("air_resolve_id identifies table IDs", {
  r <- air_resolve_id("tblABC123XYZ")
  expect_equal(r$type, "table")
  expect_equal(r$id, "tblABC123XYZ")
})

test_that("air_resolve_id identifies view IDs", {
  r <- air_resolve_id("viwABC123XYZ")
  expect_equal(r$type, "view")
  expect_equal(r$id, "viwABC123XYZ")
})

test_that("air_resolve_id identifies record IDs", {
  r <- air_resolve_id("recABC123XYZ")
  expect_equal(r$type, "record")
  expect_equal(r$id, "recABC123XYZ")
})

test_that("air_resolve_id parses a base URL", {
  r <- air_resolve_id("https://airtable.com/appBASE123")
  expect_equal(r$type, "base")
  expect_equal(r$id, "appBASE123")
})

test_that("air_resolve_id parses a table URL", {
  r <- air_resolve_id("https://airtable.com/appBASE123/tblTABLE123")
  expect_equal(r$type, "table")
  expect_equal(r$id, "tblTABLE123")
  expect_equal(r$base_id, "appBASE123")
})

test_that("air_resolve_id parses a view URL", {
  r <- air_resolve_id("https://airtable.com/appBASE123/tblTABLE123/viwVIEW123")
  expect_equal(r$type, "view")
  expect_equal(r$id, "viwVIEW123")
  expect_equal(r$table_id, "tblTABLE123")
  expect_equal(r$base_id, "appBASE123")
})

test_that("air_resolve_id parses a workspace URL", {
  r <- air_resolve_id("https://airtable.com/workspaces/wspWSP123")
  expect_equal(r$type, "workspace")
  expect_equal(r$id, "wspWSP123")
})

test_that("air_resolve_id parses a record URL", {
  r <- air_resolve_id("https://airtable.com/appBASE123/tblTABLE123/recREC123")
  expect_equal(r$type, "record")
  expect_equal(r$id, "recREC123")
})

test_that("air_resolve_id extracts base_id from an AirtableConnection", {
  local_mocked_bindings(
    dbConnect = function(drv, ...) {
      methods::new(
        "AirtableConnection",
        token = "tok",
        base_id = "appCONN123",
        state = new.env(parent = emptyenv())
      )
    },
    .package = "DBI"
  )
  # Build a minimal connection object directly to avoid hitting API
  con <- methods::new(
    "AirtableConnection",
    token = "tok",
    base_id = "appCONN456",
    state = local({
      e <- new.env(parent = emptyenv())
      e$valid <- TRUE
      e
    })
  )
  r <- air_resolve_id(con)
  expect_equal(r$type, "base")
  expect_equal(r$id, "appCONN456")
})


test_that("air_resolve_id warns on unrecognised strings", {
  expect_warning(
    r <- air_resolve_id("something-unrecognised"),
    "Could not determine"
  )
  expect_true(is.na(r$type))
})

test_that("air_resolve_id errors on non-scalar or non-string inputs", {
  expect_error(air_resolve_id(123), class = "rlang_error")
  expect_error(air_resolve_id(c("appA", "appB")), class = "rlang_error")
})

# ── air_browse ──────────────────────────────────────────────────────────────

test_that("air_browse returns URL invisibly (browse suppressed)", {
  # Suppress the actual browser call
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse("appABC123")
  expect_equal(url, "https://airtable.com/appABC123")
})

test_that("air_browse builds workspace URL", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse("wspWSP123")
  expect_equal(url, "https://airtable.com/workspaces/wspWSP123")
})

test_that("air_browse errors for table without base_id", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  expect_error(air_browse("tblTABLE123"), class = "rlang_error")
})

test_that("air_browse accepts a full URL passthrough", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  full_url <- "https://airtable.com/appBASE123/tblTABLE123/viwVIEW123"
  url <- air_browse(full_url)
  expect_equal(url, full_url)
})

# ── air_id_link ──────────────────────────────────────────────────────────────

test_that("air_id_link builds correct URL for base IDs", {
  withr::local_options(cli.hyperlink = TRUE, cli.num_colors = 1)
  result <- air_id_link("appABC123")
  # Raw id is visible as link text
  expect_match(result, "appABC123", fixed = TRUE)
  # URL contains airtable.com and the id
  expect_match(result, "airtable.com", fixed = TRUE)
  expect_match(result, "appABC123", fixed = TRUE)
})

test_that("air_id_link builds correct URL for workspace IDs", {
  withr::local_options(cli.hyperlink = TRUE, cli.num_colors = 1)
  result <- air_id_link("wspXYZ789")
  expect_match(result, "wspXYZ789", fixed = TRUE)
  expect_match(result, "airtable.com/workspaces/wspXYZ789", fixed = TRUE)
})

test_that("air_id_link builds correct URL for table IDs with base_id", {
  withr::local_options(cli.hyperlink = TRUE, cli.num_colors = 1)
  result <- air_id_link("tblTABLE123", base_id = "appBASE456")
  expect_match(result, "tblTABLE123", fixed = TRUE)
  expect_match(result, "appBASE456/tblTABLE123", fixed = TRUE)
})

test_that("air_id_link builds correct URL for view IDs with base_id and table_id", {
  withr::local_options(cli.hyperlink = TRUE, cli.num_colors = 1)
  result <- air_id_link("viwVIEW123", base_id = "appBASE456", table_id = "tblTABLE789")
  expect_match(result, "viwVIEW123", fixed = TRUE)
  expect_match(result, "appBASE456/tblTABLE789/viwVIEW123", fixed = TRUE)
})

test_that("air_id_link degrades gracefully when hyperlinks unsupported", {
  withr::local_options(cli.hyperlink = FALSE)
  result <- air_id_link("appABC123")
  # Plain id is still visible even without hyperlink support
  expect_match(result, "appABC123", fixed = TRUE)
})

test_that("air_browse message contains hyperlink to the URL", {
  withr::local_options(cli.hyperlink = TRUE, cli.num_colors = 1)
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  msg <- testthat::capture_messages(air_browse("appABC123XYZ"))
  combined <- paste(msg, collapse = "")
  expect_match(combined, "airtable.com", fixed = TRUE)
  expect_match(combined, "appABC123XYZ", fixed = TRUE)
})

test_that("air_browse message contains hyperlink for workspace URL", {
  withr::local_options(cli.hyperlink = TRUE, cli.num_colors = 1)
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  msg <- testthat::capture_messages(air_browse("wspWSP456"))
  combined <- paste(msg, collapse = "")
  expect_match(combined, "airtable.com", fixed = TRUE)
  expect_match(combined, "wspWSP456", fixed = TRUE)
})

# ── air_browse new formals & name resolution ─────────────────────────────────

test_that("air_browse() with no args opens the session default base", {
  withr::local_options(airtable2.base_id = "appDEF456")
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse()
  expect_equal(url, "https://airtable.com/appDEF456")
})

test_that("air_browse() with no args and no default aborts", {
  withr::local_options(airtable2.base_id = NULL, airtable2.workspace_id = NULL)
  withr::local_envvar(AIRTABLE_BASE_ID = "", AIRTABLE_WORKSPACE_ID = "")
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  expect_error(air_browse(), class = "rlang_error")
})

test_that("air_browse('tblXXX', base_id='appXXX') builds table URL without aborting", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse("tblABC123", base_id = "appXYZ789")
  expect_equal(url, "https://airtable.com/appXYZ789/tblABC123")
})

test_that("air_browse table branch uses session default base_id when not supplied", {
  withr::local_options(airtable2.base_id = "appDEFAULT")
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse("tblABC123")
  expect_equal(url, "https://airtable.com/appDEFAULT/tblABC123")
})

test_that("air_browse resolves table name via at_get_schema when base_id given", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  local_mocked_bindings(
    at_get_schema = function(base_id, ...) {
      list(
        list(id = "tblTABLE999", name = "My Table"),
        list(id = "tblOTHER111", name = "Other Table")
      )
    },
    .package = "airtable2"
  )
  url <- air_browse("My Table", base_id = "appXYZ789")
  expect_equal(url, "https://airtable.com/appXYZ789/tblTABLE999")
})

test_that("air_browse resolves base name via at_list_bases when no base context", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  local_mocked_bindings(
    at_list_bases = function(...) {
      tibble::tibble(
        id = c("appBASE111", "appBASE222"),
        name = c("My Base", "Other Base"),
        permissionLevel = c("create", "read")
      )
    },
    .package = "airtable2"
  )
  withr::local_options(airtable2.base_id = NULL)
  withr::local_envvar(AIRTABLE_BASE_ID = "")
  url <- air_browse("My Base")
  expect_equal(url, "https://airtable.com/appBASE111")
})

test_that("air_browse aborts with helpful message when name not found in bases", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  local_mocked_bindings(
    at_list_bases = function(...) {
      tibble::tibble(
        id = c("appBASE111"),
        name = c("My Base"),
        permissionLevel = c("create")
      )
    },
    .package = "airtable2"
  )
  withr::local_options(airtable2.base_id = NULL)
  withr::local_envvar(AIRTABLE_BASE_ID = "")
  expect_error(air_browse("Nonexistent Base"), class = "rlang_error")
})

test_that("air_browse aborts with helpful message when table name not found in schema", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  local_mocked_bindings(
    at_get_schema = function(base_id, ...) {
      list(list(id = "tblTABLE999", name = "My Table"))
    },
    .package = "airtable2"
  )
  expect_error(
    air_browse("Nonexistent Table", base_id = "appXYZ789"),
    class = "rlang_error"
  )
})

test_that("air_browse table name match is case-insensitive with a warning", {
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  local_mocked_bindings(
    at_get_schema = function(base_id, ...) {
      list(list(id = "tblTABLE999", name = "My Table"))
    },
    .package = "airtable2"
  )
  expect_warning(
    url <- air_browse("my table", base_id = "appXYZ789"),
    "case"
  )
  expect_equal(url, "https://airtable.com/appXYZ789/tblTABLE999")
})

# ── air_browse() workspace fallback (no base set) ────────────────────────────

test_that("air_browse() with no base but workspace set opens workspace URL", {
  withr::local_options(airtable2.base_id = NULL, airtable2.workspace_id = "wspFALLBACK")
  withr::local_envvar(AIRTABLE_BASE_ID = "", AIRTABLE_WORKSPACE_ID = "")
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse()
  expect_equal(url, "https://airtable.com/workspaces/wspFALLBACK")
})

test_that("air_browse() with no base but workspace env var opens workspace URL", {
  withr::local_options(airtable2.base_id = NULL, airtable2.workspace_id = NULL)
  withr::local_envvar(AIRTABLE_BASE_ID = "", AIRTABLE_WORKSPACE_ID = "wspENVFALLBACK")
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  url <- air_browse()
  expect_equal(url, "https://airtable.com/workspaces/wspENVFALLBACK")
})

test_that("air_browse() with neither base nor workspace aborts with informative message", {
  withr::local_options(airtable2.base_id = NULL, airtable2.workspace_id = NULL)
  withr::local_envvar(AIRTABLE_BASE_ID = "", AIRTABLE_WORKSPACE_ID = "")
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  expect_error(air_browse(), class = "rlang_error")
})

test_that("air_browse() workspace fallback message contains the workspace URL", {
  withr::local_options(
    airtable2.base_id = NULL,
    airtable2.workspace_id = "wspMSGTEST",
    cli.hyperlink = TRUE,
    cli.num_colors = 1
  )
  withr::local_envvar(AIRTABLE_BASE_ID = "", AIRTABLE_WORKSPACE_ID = "")
  local_mocked_bindings(
    browseURL = function(url, ...) invisible(url),
    .package = "utils"
  )
  msg <- testthat::capture_messages(air_browse())
  combined <- paste(msg, collapse = "")
  expect_match(combined, "wspMSGTEST", fixed = TRUE)
  expect_match(combined, "airtable.com", fixed = TRUE)
})

# ── resolve_workspace_id ─────────────────────────────────────────────────────

test_that("resolve_workspace_id returns explicit arg unchanged", {
  result <- resolve_workspace_id("wspEXPLICIT")
  expect_equal(result, "wspEXPLICIT")
})

test_that("resolve_workspace_id falls back to option", {
  withr::local_options(airtable2.workspace_id = "wspFROMOPT")
  result <- resolve_workspace_id(NULL)
  expect_equal(result, "wspFROMOPT")
})

test_that("resolve_workspace_id falls back to env var", {
  withr::local_options(airtable2.workspace_id = NULL)
  withr::local_envvar(AIRTABLE_WORKSPACE_ID = "wspFROMENV")
  result <- resolve_workspace_id(NULL)
  expect_equal(result, "wspFROMENV")
})

test_that("resolve_workspace_id aborts when neither arg nor default is set", {
  withr::local_options(airtable2.workspace_id = NULL)
  withr::local_envvar(AIRTABLE_WORKSPACE_ID = "")
  expect_error(resolve_workspace_id(NULL), class = "rlang_error")
})
