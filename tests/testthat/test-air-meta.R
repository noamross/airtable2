# tests/testthat/test-air-meta.R
# Mocked tests for air_meta_sync (pull-then-patch) and air_meta_init (seed).
# NO live API calls.

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

base_id <- "appTEST0000000001"

# Minimal "current schema" as returned by air_meta()
current_meta <- tibble::tibble(
  table_name  = c("People", "People",  "Jobs"),
  table_id    = c("tbl1",   "tbl1",    "tbl2"),
  field_name  = c("Name",   "Email",   "Title"),
  field_id    = c("fld1",   "fld2",    "fld3"),
  field_type  = c("singleLineText", "email", "singleLineText"),
  description = c(NA_character_, "Contact e-mail", NA_character_)
)

# Edited version: Name renamed to "Full Name", Email description changed.
edited_meta <- current_meta
edited_meta$field_name[1]  <- "Full Name"
edited_meta$description[2] <- "Primary e-mail address"

# What the _metadata table looks like after air_meta_init (includes meta_key)
metadata_table_rows <- edited_meta
metadata_table_rows$meta_key <- paste(
  metadata_table_rows$table_name,
  metadata_table_rows$field_name,
  sep = "||"
)

# ---------------------------------------------------------------------------
# air_meta_sync — default source: "_metadata" table
# ---------------------------------------------------------------------------

test_that("air_meta_sync() pulls from _metadata and patches changed fields", {
  patches <- list()

  with_mocked_bindings(
    code = {
      air_meta_sync(base_id, .token = "tok")
    },
    air_read = function(table, base_id, ...) {
      expect_equal(table, "_metadata")
      metadata_table_rows
    },
    air_meta = function(base_id, .token = NULL) current_meta,
    at_update_field = function(base_id, table_id, field_id, name = NULL,
                               description = NULL, token = NULL) {
      patches[[length(patches) + 1L]] <<- list(
        field_id    = field_id,
        table_id    = table_id,
        name        = name,
        description = description
      )
      invisible(NULL)
    },
    .package = "airtable2"
  )

  # Two fields were edited -> two PATCH calls
  expect_length(patches, 2L)

  field_ids_patched <- vapply(patches, `[[`, character(1), "field_id")
  expect_setequal(field_ids_patched, c("fld1", "fld2"))

  # fld1: only name changed
  p1 <- patches[[which(field_ids_patched == "fld1")]]
  expect_equal(p1$name, "Full Name")

  # fld2: only description changed
  p2 <- patches[[which(field_ids_patched == "fld2")]]
  expect_equal(p2$description, "Primary e-mail address")
})

test_that("air_meta_sync() uses custom source table name", {
  read_table <- NULL

  with_mocked_bindings(
    code = {
      air_meta_sync(base_id, source = "_my_meta", .token = "tok")
    },
    air_read = function(table, base_id, ...) {
      read_table <<- table
      edited_meta
    },
    air_meta        = function(base_id, .token = NULL) current_meta,
    at_update_field = function(...) invisible(NULL),
    .package = "airtable2"
  )

  expect_equal(read_table, "_my_meta")
})

# ---------------------------------------------------------------------------
# air_meta_sync — source: data.frame
# ---------------------------------------------------------------------------

test_that("air_meta_sync() patches from a data.frame source", {
  patches <- list()

  with_mocked_bindings(
    code = {
      air_meta_sync(base_id, source = edited_meta, .token = "tok")
    },
    air_meta = function(base_id, .token = NULL) current_meta,
    at_update_field = function(base_id, table_id, field_id, name = NULL,
                               description = NULL, token = NULL) {
      patches[[length(patches) + 1L]] <<- list(
        field_id    = field_id,
        name        = name,
        description = description
      )
      invisible(NULL)
    },
    .package = "airtable2"
  )

  expect_length(patches, 2L)
  patched_ids <- vapply(patches, `[[`, character(1), "field_id")
  expect_setequal(patched_ids, c("fld1", "fld2"))
})

# ---------------------------------------------------------------------------
# air_meta_sync — source: CSV file
# ---------------------------------------------------------------------------

test_that("air_meta_sync() reads a CSV file and patches", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(edited_meta, tmp, row.names = FALSE)

  patches <- list()

  with_mocked_bindings(
    code = {
      air_meta_sync(base_id, source = tmp, .token = "tok")
    },
    air_meta = function(base_id, .token = NULL) current_meta,
    at_update_field = function(base_id, table_id, field_id, name = NULL,
                               description = NULL, token = NULL) {
      patches[[length(patches) + 1L]] <<- list(field_id = field_id)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  expect_length(patches, 2L)
})

# ---------------------------------------------------------------------------
# air_meta_sync — source: JSON file
# ---------------------------------------------------------------------------

test_that("air_meta_sync() reads a JSON file and patches", {
  tmp <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(edited_meta, tmp)

  patches <- list()

  with_mocked_bindings(
    code = {
      air_meta_sync(base_id, source = tmp, .token = "tok")
    },
    air_meta = function(base_id, .token = NULL) current_meta,
    at_update_field = function(base_id, table_id, field_id, name = NULL,
                               description = NULL, token = NULL) {
      patches[[length(patches) + 1L]] <<- list(field_id = field_id)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  expect_length(patches, 2L)
})

# ---------------------------------------------------------------------------
# air_meta_sync — unedited rows produce no PATCH
# ---------------------------------------------------------------------------

test_that("air_meta_sync() makes no PATCH calls when nothing changed", {
  patches <- list()

  with_mocked_bindings(
    code = {
      air_meta_sync(base_id, .token = "tok")
    },
    air_read  = function(table, base_id, ...) current_meta,
    air_meta  = function(base_id, .token = NULL) current_meta,
    at_update_field = function(...) {
      patches[[length(patches) + 1L]] <<- TRUE
      invisible(NULL)
    },
    .package = "airtable2"
  )

  expect_length(patches, 0L)
})

# ---------------------------------------------------------------------------
# air_meta_sync — meta_key column is tolerated but field_id / table_id used
# ---------------------------------------------------------------------------

test_that("air_meta_sync() handles extra meta_key column from _metadata table", {
  with_key <- edited_meta
  with_key$meta_key <- paste(with_key$table_name, with_key$field_name, sep = "||")

  patches <- list()

  with_mocked_bindings(
    code = {
      air_meta_sync(base_id, .token = "tok")
    },
    air_read = function(table, base_id, ...) with_key,
    air_meta = function(base_id, .token = NULL) current_meta,
    at_update_field = function(base_id, table_id, field_id, name = NULL,
                               description = NULL, token = NULL) {
      patches[[length(patches) + 1L]] <<- list(field_id = field_id)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  # Still two patches (meta_key column doesn't break matching)
  expect_length(patches, 2L)
})

# ---------------------------------------------------------------------------
# air_meta_init — seeds _metadata table from live schema
# ---------------------------------------------------------------------------

test_that("air_meta_init() upserts schema into _metadata table", {
  upsert_args <- NULL

  with_mocked_bindings(
    code = {
      air_meta_init(base_id, .token = "tok")
    },
    air_meta      = function(base_id, .token = NULL) current_meta,
    air_upsert    = function(data, table, merge_on, base_id, ...) {
      upsert_args <<- list(
        table    = table,
        merge_on = merge_on,
        nrow     = nrow(data)
      )
      invisible(NULL)
    },
    at_get_schema  = function(...) list(),
    at_create_table = function(...) invisible(NULL),
    .package = "airtable2"
  )

  expect_false(is.null(upsert_args))
  expect_equal(upsert_args$table,    "_metadata")
  expect_equal(upsert_args$merge_on, "meta_key")
  expect_equal(upsert_args$nrow,     nrow(current_meta))
})

test_that("air_meta_init() respects custom meta_table name", {
  upsert_table <- NULL

  with_mocked_bindings(
    code = {
      air_meta_init(base_id, meta_table = "_docs", .token = "tok")
    },
    air_meta        = function(base_id, .token = NULL) current_meta,
    air_upsert      = function(data, table, merge_on, base_id, ...) {
      upsert_table <<- table
      invisible(NULL)
    },
    at_get_schema   = function(...) list(),
    at_create_table = function(...) invisible(NULL),
    .package = "airtable2"
  )

  expect_equal(upsert_table, "_docs")
})
