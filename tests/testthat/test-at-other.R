# ── at_sitrep ────────────────────────────────────────────────────────────────

test_that("at_sitrep returns a list with user, scopes, bases, error", {
  local_mocked_bindings(
    at_whoami = function(token = NULL) {
      list(id = "usrABC", email = "test@example.com")
    },
    at_list_bases = function(token = NULL) {
      tibble::tibble(
        id = c("appAAA", "appBBB"),
        name = c("Base One", "Base Two"),
        permissionLevel = c("create", "edit")
      )
    }
  )

  result <- at_sitrep()

  expect_type(result, "list")
  expect_named(result, c("user", "scopes", "bases", "error"))
  expect_equal(result$user$id,    "usrABC")
  expect_equal(result$user$email, "test@example.com")
  expect_null(result$scopes)
  expect_s3_class(result$bases, "tbl_df")
  expect_equal(nrow(result$bases), 2L)
  expect_named(result$bases, c("id", "name", "permissionLevel"))
  expect_null(result$error)
})

test_that("at_sitrep captures whoami errors without stopping", {
  local_mocked_bindings(
    at_whoami     = function(token = NULL) stop("auth failed"),
    at_list_bases = function(token = NULL) tibble::tibble(
      id = character(), name = character(), permissionLevel = character()
    )
  )
  result <- at_sitrep()
  expect_null(result$user)
  expect_match(result$error, "Failed to get user info")
})

test_that("at_sitrep captures bases errors without stopping", {
  local_mocked_bindings(
    at_whoami     = function(token = NULL) list(id = "usrABC", email = "test@example.com"),
    at_list_bases = function(token = NULL) stop("no permission")
  )
  result <- at_sitrep()
  expect_null(result$bases)
  expect_match(result$error, "Failed to list bases")
  expect_false(is.null(result$user))
})

test_that("at_sitrep returns an 'at_sitrep' classed list", {
  local_mocked_bindings(
    at_whoami     = function(token = NULL) list(id = "usrX"),
    at_list_bases = function(token = NULL) tibble::tibble(
      id = character(), name = character(), permissionLevel = character()
    )
  )
  result <- at_sitrep()
  expect_s3_class(result, "at_sitrep")
})

test_that("at_sitrep returns NULL scopes when whoami has no scopes field", {
  local_mocked_bindings(
    at_whoami     = function(token = NULL) list(id = "usrXYZ", email = "x@x.com"),
    at_list_bases = function(token = NULL) tibble::tibble(
      id = character(), name = character(), permissionLevel = character()
    )
  )
  result <- at_sitrep()
  expect_null(result$scopes)
})

# ── print.at_sitrep ──────────────────────────────────────────────────────────

test_that("print.at_sitrep renders user and bases without error", {
  result <- structure(
    list(
      user = list(id = "usr1", email = "a@b.com"),
      scopes = NULL,
      bases = tibble::tibble(
        id = "appX",
        name = "MyBase",
        permissionLevel = "create"
      ),
      error = NULL
    ),
    class = "at_sitrep"
  )
  out <- cli::cli_fmt(print(result))
  expect_true(any(grepl("a@b.com", out)))
  expect_true(any(grepl("MyBase", out)))
})

test_that("print.at_sitrep shows error when present", {
  result <- structure(
    list(user = NULL, scopes = NULL, bases = NULL, error = "auth failed"),
    class = "at_sitrep"
  )
  out <- cli::cli_fmt(print(result))
  expect_true(any(grepl("auth failed", out)))
})

test_that("print.at_sitrep returns the object invisibly", {
  result <- structure(
    list(user = NULL, scopes = NULL, bases = NULL, error = NULL),
    class = "at_sitrep"
  )
  ret <- withVisible(print(result))
  expect_false(ret$visible)
})

# ── print.at_sitrep hyperlinks ──────────────────────────────────────────────

test_that("print.at_sitrep uses hyperlinks for base IDs", {
  withr::local_options(cli.hyperlink = TRUE, cli.num_colors = 1)
  result <- structure(
    list(
      user = list(id = "usr1", email = "a@b.com"),
      scopes = NULL,
      bases = tibble::tibble(
        id = "appXXXXXX",
        name = "MyBase",
        permissionLevel = "create"
      ),
      error = NULL
    ),
    class = "at_sitrep"
  )
  out <- cli::cli_fmt(print(result))
  combined <- paste(out, collapse = "")
  # The output should contain the base URL for the hyperlink
  expect_match(combined, "https://airtable.com/appXXXXXX", fixed = TRUE)
})

test_that("print.at_sitrep base ID hyperlink text is the ID itself", {
  withr::local_options(cli.hyperlink = TRUE, cli.num_colors = 1)
  result <- structure(
    list(
      user = list(id = "usr1", email = "a@b.com"),
      scopes = NULL,
      bases = tibble::tibble(
        id = "appHYPERLINK",
        name = "MyBase",
        permissionLevel = "create"
      ),
      error = NULL
    ),
    class = "at_sitrep"
  )
  out <- cli::cli_fmt(print(result))
  combined <- paste(out, collapse = "")
  # The ID string must appear as the visible link text
  expect_match(combined, "appHYPERLINK", fixed = TRUE)
})

# ── at_upload_attachment ─────────────────────────────────────────────────────

test_that("at_upload_attachment validates inputs", {
  expect_error(
    at_upload_attachment("app1", "tbl1", "rec1", "fld1", "nonexistent.txt"),
    "does not exist"
  )
  expect_error(
    at_upload_attachment(123, "tbl1", "rec1", "fld1", "file.txt"),
    "must be a single non-NA string"
  )
})
