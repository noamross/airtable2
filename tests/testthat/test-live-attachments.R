# Live integration tests for attachment uploads.
#
# Attachment uploads go to a different host (content.airtable.com) than the
# rest of the REST API, so they need their own live coverage. These tests
# create a scratch table with an attachment field in the shared schema base.
#
# Opt-in with AIRTABLE_TEST_SCHEMA=true (also needs AIRTABLE_API_KEY and
# AIRTABLE_WORKSPACE_ID).

# A small real image shipped with the package, used as the upload payload.
demo_upload_image_path <- function() {
  path <- system.file("icons", "airtable-icon-32-32.png", package = "airtable2")
  if (!nzchar(path) || !file.exists(path)) {
    testthat::skip("Bundled test image not found")
  }
  path
}

# Create a fresh scratch table with a multipleAttachments field and one record.
# Returns list(table_id, table_name, record_id).
setup_attachment_table <- function(base_id) {
  table_name <- paste0("AttachTest_", format(Sys.time(), "%H%M%S"))
  tbl <- at_create_table(
    base_id = base_id,
    name = table_name,
    fields = list(
      list(name = "Name", type = "singleLineText"),
      list(name = "Files", type = "multipleAttachments")
    ),
    description = "Created by live attachment test"
  )
  ids <- air_write(
    tibble::tibble(Name = "upload-target"),
    table_name, base_id
  )
  list(table_id = tbl$id, table_name = table_name, record_id = ids[[1L]])
}

test_that("live: at_upload_attachment uploads a local file to a record", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()
  img <- demo_upload_image_path()

  setup <- setup_attachment_table(base_id)

  result <- at_upload_attachment(
    base_id   = base_id,
    table_id  = setup$table_id,
    record_id = setup$record_id,
    field_id  = "Files",
    file      = img
  )

  # The API echoes the updated record; the attachment field should now hold one.
  expect_equal(result$id, setup$record_id)
  att_field <- result$fields[[1L]]
  expect_length(att_field, 1L)
  expect_equal(att_field[[1L]]$filename, basename(img))
  expect_equal(att_field[[1L]]$type, "image/png")

  # Read the record back independently to confirm the attachment persisted.
  back <- air_read(setup$table_name, base_id)
  row <- back[back$Name == "upload-target", ]
  expect_equal(length(row$Files[[1L]]), 1L)
})

test_that("live: at_upload_attachment populates a newly created attachment field", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()
  img <- demo_upload_image_path()

  # Start from a table with no attachment field, then add one with at_create_field.
  table_name <- paste0("AttachField_", format(Sys.time(), "%H%M%S"))
  tbl <- at_create_table(
    base_id = base_id,
    name = table_name,
    fields = list(list(name = "Name", type = "singleLineText")),
    description = "Created by live attachment-field test"
  )
  ids <- air_write(tibble::tibble(Name = "needs-files"), table_name, base_id)

  field <- at_create_field(
    base_id  = base_id,
    table_id = tbl$id,
    name     = "Docs",
    type     = "multipleAttachments",
    description = "Attachment field added live"
  )
  expect_equal(field$type, "multipleAttachments")

  result <- at_upload_attachment(
    base_id   = base_id,
    table_id  = tbl$id,
    record_id = ids[[1L]],
    field_id  = "Docs",
    file      = img
  )
  expect_equal(result$id, ids[[1L]])

  back <- air_read(table_name, base_id)
  row <- back[back$Name == "needs-files", ]
  expect_equal(length(row$Docs[[1L]]), 1L)
  expect_equal(row$Docs[[1L]][[1L]]$filename, basename(img))
})

test_that("live: air_write_attachments uploads files for multiple records", {
  skip_on_cran()
  skip_if_no_schema_tests()
  base_id <- get_schema_test_base()
  img <- demo_upload_image_path()

  table_name <- paste0("AttachBatch_", format(Sys.time(), "%H%M%S"))
  at_create_table(
    base_id = base_id,
    name = table_name,
    fields = list(
      list(name = "Name", type = "singleLineText"),
      list(name = "Files", type = "multipleAttachments")
    ),
    description = "Created by live air_write_attachments test"
  )
  ids <- air_write(
    tibble::tibble(Name = c("doc-a", "doc-b")),
    table_name, base_id
  )

  air_write_attachments(
    base_id, table_name, "Files",
    data = tibble::tibble(airtable_id = ids, file_path = img)
  )

  back <- air_read(table_name, base_id)
  expect_equal(length(back$Files[[1L]]), 1L)
  expect_equal(length(back$Files[[2L]]), 1L)
})
