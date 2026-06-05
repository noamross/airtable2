# Common test helpers for airtable2
# Loaded automatically by testthat before tests run.
#
# TEST INFRASTRUCTURE DESIGN:
#
# We use a small number of FIXED-NAME bases that persist across test runs.
# This avoids accumulating bases (the API doesn't support base deletion on
# free tier).
#
# Bases:
#   - "airtable2_test_main" - for record CRUD (read/write/upsert/sync)
#     Has a permanent "Contacts" table with standard fields.
#   - "airtable2_test_schema" - for table/field creation/modification tests.
#     Only used when AIRTABLE_TEST_SCHEMA=true (to avoid cluttering workspace).
#
# Between tests: clear records. Between test files: nothing special needed.
# Table creation tests mock by default, opt-in to live with env var.

# Absolute path to httptest2 mock fixtures, captured here when CWD is the
# testthat directory (before tests change the working directory).
.fixture_path <- normalizePath("fixtures", mustWork = FALSE)
message("DEBUG fixture path: ", .fixture_path, " (exists: ", dir.exists(.fixture_path), ")")

# Disable the on-disk API counter during tests so fixture-replay tests never
# touch the user's real counter directory. Counter-specific tests re-enable it
# locally with a temporary R_USER_DATA_DIR.
options(airtable2.count_api = FALSE)

# Make .demo_sleep a no-op for the whole test session so demo tests run without
# 2-second pauses between steps.
local({
  ns <- getNamespace("airtable2")
  unlockBinding(".demo_sleep", ns)
  assign(".demo_sleep", function() invisible(NULL), envir = ns)
  lockBinding(".demo_sleep", ns)
})

# --- Skip conditions ---

# Master switch for any test that hits the Airtable API. Airtable free/team plans
# cap each workspace at ~1000 API calls/month, so live tests are opt-in only.
# Set AIRTABLE_TEST_LIVE=true to enable them; otherwise we rely on mocked tests.
skip_if_not_live <- function() {
  live <- Sys.getenv("AIRTABLE_TEST_LIVE", unset = "false")
  if (!tolower(trimws(live)) %in% c("true", "1", "yes")) {
    testthat::skip("Set AIRTABLE_TEST_LIVE=true to run live API tests")
  }
}

skip_if_no_token <- function() {
  skip_if_not_live()
  token <- Sys.getenv("AIRTABLE_API_KEY", unset = "")
  if (!nzchar(token)) {
    testthat::skip("No AIRTABLE_API_KEY set")
  }
}

skip_if_no_workspace <- function() {
  skip_if_no_token()
  wsp <- Sys.getenv("AIRTABLE_WORKSPACE_ID", unset = "")
  if (!nzchar(wsp)) {
    testthat::skip("No AIRTABLE_WORKSPACE_ID set")
  }
}

skip_if_no_schema_tests <- function() {
  skip_if_no_workspace()
  if (!identical(Sys.getenv("AIRTABLE_TEST_SCHEMA", unset = ""), "true")) {
    testthat::skip("Set AIRTABLE_TEST_SCHEMA=true to run schema mutation tests")
  }
}

# --- Shared test base infrastructure ---

test_env <- new.env(parent = emptyenv())
test_env$main_base_id <- NULL
test_env$schema_base_id <- NULL
test_env$table_ids <- list()
test_env$formula_field_added <- FALSE

# Compute an 8-character hex suffix from the workspace ID so each workspace gets
# its own set of test bases and never collides with another user's bases.
# Falls back to "00000000" when no workspace is configured (no live tests run).
.wsp_hash8 <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      wsp <- Sys.getenv("AIRTABLE_WORKSPACE_ID", "")
      cache <<- if (nzchar(wsp)) {
        substr(digest::digest(wsp, algo = "sha256", serialize = FALSE), 1L, 8L)
      } else {
        "00000000"
      }
    }
    cache
  }
})

TEST_MAIN_BASE_NAME <- paste0("airtable2_test_main_", .wsp_hash8())
TEST_SCHEMA_BASE_NAME <- paste0("airtable2_test_schema_", .wsp_hash8())

#' Find or create a base by fixed name
#'
#' Looks up existing bases by name. If found, returns its ID.
#' If not found, creates it with the given table config.
#'
#' @param name Fixed base name.
#' @param tables Table config list for creation.
#' @return Character scalar: base ID.
#' @noRd
find_or_create_base <- function(name, tables) {
  # Check if it already exists
  bases <- at_list_bases()
  existing <- bases[bases$name == name, ]
  if (nrow(existing) > 0L) {
    return(existing$id[1])
  }

  # Create it (workspace_id defaults to AIRTABLE_WORKSPACE_ID env var)
  result <- at_create_base(name = name, tables = tables)
  result$id
}

#' Get the shared main test base
#'
#' Returns (and lazily creates) the "airtable2_test_main" base with a
#' "Contacts" table.
#'
#' @return Character scalar: base ID.
get_test_base <- function() {
  skip_if_no_workspace()

  if (!is.null(test_env$main_base_id)) {
    return(test_env$main_base_id)
  }

  test_env$main_base_id <- find_or_create_base(
    TEST_MAIN_BASE_NAME,
    tables = list(list(
      name = "Contacts",
      fields = list(
        list(name = "Name", type = "singleLineText"),
        list(name = "Email", type = "email"),
        list(name = "Age", type = "number", options = list(precision = 0L)),
        list(
          name = "Active",
          type = "checkbox",
          options = list(icon = "check", color = "greenBright")
        ),
        list(
          name = "Tags",
          type = "multipleSelects",
          options = list(
            choices = list(
              list(name = "R"),
              list(name = "Python"),
              list(name = "Julia")
            )
          )
        )
      )
    ))
  )

  # Cache the table ID
  schema <- at_get_schema(test_env$main_base_id)
  contacts <- Filter(function(t) t$name == "Contacts", schema)
  if (length(contacts) > 0L) {
    test_env$table_ids[["Contacts"]] <- contacts[[1]]$id
  }

  test_env$main_base_id
}

#' Get the shared schema test base
#'
#' Returns (and lazily creates) the "airtable2_test_schema" base.
#' Only used when AIRTABLE_TEST_SCHEMA=true.
#'
#' @return Character scalar: base ID.
get_schema_test_base <- function() {
  skip_if_no_schema_tests()

  if (!is.null(test_env$schema_base_id)) {
    return(test_env$schema_base_id)
  }

  test_env$schema_base_id <- find_or_create_base(
    TEST_SCHEMA_BASE_NAME,
    tables = list(list(
      name = "Scratch",
      fields = list(list(name = "Name", type = "singleLineText"))
    ))
  )

  test_env$schema_base_id
}

#' Clear all records from a table in the shared test base
#'
#' Call at the start of each test for a clean slate.
#'
#' @param table Table name or ID.
#' @param base_id Base ID (defaults to main test base).
#' @return Invisible NULL.
clear_test_records <- function(table = "Contacts", base_id = NULL) {
  base_id <- base_id %||% get_test_base()
  records <- at_list_records(base_id, table)
  if (length(records) > 0L) {
    ids <- vapply(records, function(r) r$id, character(1))
    at_delete_records(base_id, table, ids)
  }
  invisible(NULL)
}

#' Get the table ID for a named table in the test base
#' @return Character scalar: table ID.
get_test_table_id <- function(table = "Contacts") {
  base_id <- get_test_base()
  if (!is.null(test_env$table_ids[[table]])) {
    return(test_env$table_ids[[table]])
  }
  schema <- at_get_schema(base_id)
  tbl <- Filter(function(t) t$name == table, schema)
  if (length(tbl) == 0L) {
    cli::cli_abort("Table {.val {table}} not found in test base.")
  }
  test_env$table_ids[[table]] <- tbl[[1]]$id
  tbl[[1]]$id
}

#' Ensure a formula field exists in the Contacts table
#'
#' Adds it once per session; subsequent calls are no-ops.
#'
#' @return Invisible NULL.
ensure_formula_field <- function() {
  if (test_env$formula_field_added) {
    return(invisible(NULL))
  }

  base_id <- get_test_base()
  table_id <- get_test_table_id("Contacts")

  # Check if it already exists
  schema <- at_get_schema(base_id)
  contacts <- Filter(function(t) t$name == "Contacts", schema)[[1]]
  field_names <- vapply(contacts$fields, function(f) f$name, character(1))

  if (!"NameUpper" %in% field_names) {
    at_create_field(
      "NameUpper",
      base_id = base_id,
      table_id = table_id,
      type = "formula",
      options = list(formula = "UPPER({Name})")
    )
  }

  test_env$formula_field_added <- TRUE
  invisible(NULL)
}

#' Standard test data for the Contacts table
#' @return A tibble with Name, Email, Age, Active, Tags columns.
test_contacts_data <- function() {
  tibble::tibble(
    Name = c("Alice", "Bob", "Charlie"),
    Email = c("alice@test.com", "bob@test.com", "charlie@test.com"),
    Age = c(30L, 25L, 35L),
    Active = c(TRUE, FALSE, TRUE),
    Tags = list(c("R", "Python"), "Julia", c("R", "Julia"))
  )
}
