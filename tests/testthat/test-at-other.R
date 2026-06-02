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
