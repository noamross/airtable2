# Tests for parallel attachment downloads (Feature 5)

# ── parallel_enabled() ────────────────────────────────────────────────────────

test_that("parallel_enabled() returns TRUE when option is TRUE", {
  withr::local_options(airtable2.parallel = TRUE)
  expect_true(parallel_enabled(NULL))
})

test_that("parallel_enabled() returns FALSE when option is FALSE", {
  withr::local_options(airtable2.parallel = FALSE)
  expect_false(parallel_enabled(NULL))
})

test_that("parallel_enabled() respects env var", {
  withr::local_options(airtable2.parallel = NULL)
  withr::local_envvar(AIRTABLE2_PARALLEL = "false")
  expect_false(parallel_enabled(NULL))

  withr::local_envvar(AIRTABLE2_PARALLEL = "true")
  expect_true(parallel_enabled(NULL))
})

test_that("parallel_enabled() argument overrides option/env", {
  withr::local_options(airtable2.parallel = FALSE)
  expect_true(parallel_enabled(TRUE))
  expect_false(parallel_enabled(FALSE))
})

test_that("parallel_enabled() defaults to TRUE", {
  withr::local_options(airtable2.parallel = NULL)
  withr::local_envvar(AIRTABLE2_PARALLEL = "")
  expect_true(parallel_enabled(NULL))
})

# ── download_attachments_in_tibble parallel ───────────────────────────────────

test_that("download_attachments_in_tibble parallel=FALSE uses sequential perform", {
  seq_calls <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) {
      seq_calls <<- seq_calls + 1L
      structure(list(status_code = 200L, body = as.raw(1:3)), class = "httr2_response")
    },
    resp_body_raw = function(resp) as.raw(1:3),
    .package = "httr2"
  )

  tbl <- tibble::tibble(
    airtable_id = "rec1",
    Photos = list(list(list(url = "https://example.com/a.jpg", filename = "a.jpg")))
  )
  class(tbl$Photos) <- c("air_attachments", "list")

  result <- download_attachments_in_tibble(tbl, "Photos", mode = "blob",
                                            parallel = FALSE)
  # Sequential: req_perform called once per attachment
  expect_equal(seq_calls, 1L)
})

test_that("download_attachments_in_tibble parallel=TRUE uses req_perform_parallel", {
  parallel_called <- FALSE
  local_mocked_bindings(
    req_perform_parallel = function(reqs, paths = NULL, ...) {
      parallel_called <<- TRUE
      lapply(reqs, function(r) {
        structure(list(status_code = 200L, body = as.raw(1:3)), class = "httr2_response")
      })
    },
    resp_body_raw = function(resp) as.raw(1:3),
    .package = "httr2"
  )

  tbl <- tibble::tibble(
    airtable_id = c("rec1", "rec2"),
    Photos = list(
      list(list(url = "https://example.com/a.jpg", filename = "a.jpg")),
      list(list(url = "https://example.com/b.jpg", filename = "b.jpg"))
    )
  )
  class(tbl$Photos) <- c("air_attachments", "list")

  download_attachments_in_tibble(tbl, "Photos", mode = "blob", parallel = TRUE)
  expect_true(parallel_called)
})

# ── air_read_attachments parallel param ──────────────────────────────────────

test_that("air_read_attachments accepts parallel parameter", {
  local_mocked_bindings(
    at_list_records = function(base_id, table, ...) list(),
    air_token       = function(token = NULL) "fake_token"
  )
  # empty result — just checking no error
  result <- air_read_attachments(
    "appX", "T", "Photos",
    parallel = FALSE
  )
  expect_s3_class(result, "tbl_df")
})
