# Tests for broad attachment strategy across air_write, air_upsert, air_sync,
# air_dump, and air_restore.
# Uses local_mocked_bindings to avoid hitting the API.

test_that("air_write excludes attachment fields from payload", {
  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) "Photos",
    at_create_records = function(base_id, table_id, records, ...) {
      # Verify attachment field is not in the payload
      for (rec in records) {
        expect_false("Photos" %in% names(rec$fields))
      }
      list(list(id = "rec1"), list(id = "rec2"))
    },
    upload_attachments_from_tibble = function(...) invisible(NULL),
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = c("A", "B"),
    Photos = list(
      list(list(filename = "a.png", url = "http://x/a.png")),
      list(list(filename = "b.png", url = "http://x/b.png"))
    )
  )

  ids <- air_write(data, "tbl1", "app1", attachments = "file")
  expect_equal(ids, c("rec1", "rec2"))
})

test_that("air_write uploads attachments when mode is 'file'", {
  upload_calls <- list()

  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) "Photos",
    at_create_records = function(base_id, table_id, records, ...) {
      list(list(id = "rec1"), list(id = "rec2"))
    },
    upload_attachments_from_tibble = function(...) {
      args <- list(...)
      upload_calls[[length(upload_calls) + 1L]] <<- args
      invisible(NULL)
    },
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = c("A", "B"),
    Photos = list(
      list(list(filename = "a.png", local_path = "/tmp/a.png")),
      list(list(filename = "b.png", local_path = "/tmp/b.png"))
    )
  )

  air_write(data, "tbl1", "app1", attachments = "file")
  expect_length(upload_calls, 1)
  expect_equal(upload_calls[[1]]$mode, "file")
  expect_equal(upload_calls[[1]]$record_ids, c("rec1", "rec2"))
  expect_equal(upload_calls[[1]]$att_fields, "Photos")
})

test_that("air_write does not upload when attachments = 'meta'", {
  upload_calls <- list()

  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) "Photos",
    at_create_records = function(base_id, table_id, records, ...) {
      list(list(id = "rec1"))
    },
    upload_attachments_from_tibble = function(...) {
      upload_calls[[length(upload_calls) + 1L]] <<- list(...)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = "A",
    Photos = list(list(list(filename = "a.png")))
  )

  air_write(data, "tbl1", "app1", attachments = "meta")
  expect_length(upload_calls, 0)
})

test_that("air_write skips attachment upload when no att cols in data", {
  upload_calls <- list()

  local_mocked_bindings(
    get_computed_fields = function(...) character(),
    get_attachment_fields = function(...) "Photos",
    at_create_records = function(base_id, table_id, records, ...) {
      list(list(id = "rec1"))
    },
    upload_attachments_from_tibble = function(...) {
      upload_calls[[length(upload_calls) + 1L]] <<- list(...)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  data <- tibble::tibble(Name = "A", Age = 30L)
  air_write(data, "tbl1", "app1", attachments = "file")
  expect_length(upload_calls, 0)
})

test_that("air_upsert excludes attachment fields from payload", {
  local_mocked_bindings(
    at_get_schema = function(...) list(
      list(
        id = "tbl1", name = "tbl1",
        fields = list(
          list(name = "Name", type = "singleLineText"),
          list(name = "Photos", type = "multipleAttachments")
        )
      )
    ),
    at_update_records = function(base_id, table_id, records, ...) {
      for (rec in records) {
        expect_false("Photos" %in% names(rec$fields))
      }
      list(
        records = list(list(id = "rec1")),
        createdRecords = "rec1",
        updatedRecords = character()
      )
    },
    upload_attachments_from_tibble = function(...) invisible(NULL),
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = "Alice",
    Photos = list(list(list(filename = "pic.jpg")))
  )

  result <- air_upsert(data, "tbl1", "app1", merge_on = "Name", attachments = "file")
  expect_equal(result$created, "rec1")
})

test_that("air_upsert uploads attachments in 'blob' mode", {
  upload_calls <- list()

  local_mocked_bindings(
    at_get_schema = function(...) list(
      list(
        id = "tbl1", name = "tbl1",
        fields = list(
          list(name = "Name", type = "singleLineText"),
          list(name = "Docs", type = "multipleAttachments")
        )
      )
    ),
    at_update_records = function(base_id, table_id, records, ...) {
      list(
        records = list(list(id = "rec1")),
        createdRecords = "rec1",
        updatedRecords = character()
      )
    },
    upload_attachments_from_tibble = function(...) {
      upload_calls[[length(upload_calls) + 1L]] <<- list(...)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = "Alice",
    Docs = list(list(list(filename = "doc.pdf", content = charToRaw("hello"))))
  )

  air_upsert(data, "tbl1", "app1", merge_on = "Name", attachments = "blob")
  expect_length(upload_calls, 1)
  expect_equal(upload_calls[[1]]$mode, "blob")
})

test_that("air_upsert does not count attachment fields as unknown", {
  local_mocked_bindings(
    at_get_schema = function(...) list(
      list(
        id = "tbl1", name = "tbl1",
        fields = list(
          list(name = "Name", type = "singleLineText"),
          list(name = "Photos", type = "multipleAttachments")
        )
      )
    ),
    at_update_records = function(...) {
      list(
        records = list(list(id = "rec1")),
        createdRecords = "rec1",
        updatedRecords = character()
      )
    },
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = "Alice",
    Photos = list(list(list(filename = "x.png")))
  )

  # Should NOT error about "Photos" being unknown

  expect_no_error(
    air_upsert(data, "tbl1", "app1", merge_on = "Name")
  )
})

test_that("air_sync excludes attachment fields from hash", {
  # Simulate existing data that differs only in attachment URLs (volatile)
  local_mocked_bindings(
    get_table_schema = function(...) list(
      id = "tbl1", name = "tbl1",
      fields = list(
        list(name = "Name", type = "singleLineText"),
        list(name = "Age", type = "number"),
        list(name = "Photos", type = "multipleAttachments")
      )
    ),
    air_read = function(...) {
      tibble::tibble(
        airtable_id = "rec1",
        Name = "Alice",
        Age = 30L,
        Photos = list(list(list(
          filename = "pic.jpg",
          url = "http://expired-url/pic.jpg"
        )))
      )
    },
    air_upsert = function(...) {
      list(created = character(), updated = character())
    },
    at_delete_records = function(...) invisible(NULL),
    .package = "airtable2"
  )

  # Local data has same Name + Age but different attachment metadata
  data <- tibble::tibble(
    Name = "Alice",
    Age = 30L,
    Photos = list(list(list(
      filename = "pic.jpg",
      url = "http://new-url/pic.jpg"
    )))
  )

  result <- air_sync(data, "tbl1", "app1", key = "Name")
  # Attachment URL difference should NOT cause an update
  expect_equal(result$unchanged, 1L)
  expect_equal(result$updated, 0L)
})

test_that("air_sync uploads attachments for created records", {
  upload_calls <- list()

  local_mocked_bindings(
    get_table_schema = function(...) list(
      id = "tbl1", name = "tbl1",
      fields = list(
        list(name = "Name", type = "singleLineText"),
        list(name = "Age", type = "number"),
        list(name = "Photos", type = "multipleAttachments")
      )
    ),
    air_read = function(...) {
      tibble::tibble(
        airtable_id = character(),
        Name = character(),
        Age = integer(),
        Photos = list()
      )
    },
    air_upsert = function(...) {
      list(created = "rec_new", updated = character())
    },
    upload_attachments_from_tibble = function(...) {
      upload_calls[[length(upload_calls) + 1L]] <<- list(...)
      invisible(NULL)
    },
    at_delete_records = function(...) invisible(NULL),
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = "Bob",
    Age = 25L,
    Photos = list(list(list(filename = "b.png", local_path = "/tmp/b.png")))
  )

  result <- air_sync(
    data, "tbl1", "app1",
    key = "Name",
    attachments = "file",
    attachment_dir = "/tmp"
  )
  expect_equal(result$created, 1L)
  expect_length(upload_calls, 1)
  expect_equal(upload_calls[[1]]$mode, "file")
  expect_equal(upload_calls[[1]]$record_ids, "rec_new")
})

test_that("air_sync does not upload attachments in meta mode", {
  upload_calls <- list()

  local_mocked_bindings(
    get_table_schema = function(...) list(
      id = "tbl1", name = "tbl1",
      fields = list(
        list(name = "Name", type = "singleLineText"),
        list(name = "Photos", type = "multipleAttachments")
      )
    ),
    air_read = function(...) {
      tibble::tibble(
        airtable_id = character(),
        Name = character(),
        Photos = list()
      )
    },
    air_upsert = function(...) {
      list(created = "rec1", updated = character())
    },
    upload_attachments_from_tibble = function(...) {
      upload_calls[[length(upload_calls) + 1L]] <<- list(...)
      invisible(NULL)
    },
    at_delete_records = function(...) invisible(NULL),
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = "X",
    Photos = list(list(list(filename = "x.png")))
  )

  air_sync(data, "tbl1", "app1", key = "Name", attachments = "meta")
  expect_length(upload_calls, 0)
})

test_that("air_dump passes attachments param to air_read", {
  read_calls <- list()

  local_mocked_bindings(
    at_get_schema = function(...) list(
      list(id = "tbl1", name = "Tasks", fields = list(
        list(name = "Name", type = "singleLineText")
      ))
    ),
    air_read = function(table, base_id, ...) {
      args <- list(table = table, base_id = base_id, ...)
      read_calls[[length(read_calls) + 1L]] <<- args
      tibble::tibble(airtable_id = "rec1", Name = "A")
    },
    .package = "airtable2"
  )

  air_dump("app1", format = "list", attachments = "file")
  expect_length(read_calls, 1)
  expect_equal(read_calls[[1]]$attachments, "file")
})

test_that("air_dump defaults to attachments = 'file'", {
  read_calls <- list()

  local_mocked_bindings(
    at_get_schema = function(...) list(
      list(id = "tbl1", name = "Items", fields = list(
        list(name = "Title", type = "singleLineText")
      ))
    ),
    air_read = function(table, base_id, ...) {
      args <- list(table = table, base_id = base_id, ...)
      read_calls[[length(read_calls) + 1L]] <<- args
      tibble::tibble(airtable_id = "rec1", Title = "X")
    },
    .package = "airtable2"
  )

  # When called without specifying attachments, it should default to "file"
  air_dump("app1", format = "list")
  expect_equal(read_calls[[1]]$attachments, "file")
})

test_that("air_dump with meta mode does not download attachments", {
  read_calls <- list()

  local_mocked_bindings(
    at_get_schema = function(...) list(
      list(id = "tbl1", name = "Items", fields = list(
        list(name = "Title", type = "singleLineText")
      ))
    ),
    air_read = function(table, base_id, ...) {
      args <- list(table = table, base_id = base_id, ...)
      read_calls[[length(read_calls) + 1L]] <<- args
      tibble::tibble(airtable_id = "rec1", Title = "X")
    },
    .package = "airtable2"
  )

  air_dump("app1", format = "list", attachments = "meta")
  expect_equal(read_calls[[1]]$attachments, "meta")
  # attachment_dir should be NULL in meta mode
  expect_null(read_calls[[1]]$attachment_dir)
})

test_that("download_attachments_in_tibble errors without dir in file mode", {
  tbl <- tibble::tibble(
    airtable_id = "rec1",
    Photos = list(list(list(filename = "a.png", url = "http://x/a.png")))
  )
  expect_error(
    download_attachments_in_tibble(tbl, "Photos", mode = "file", dir = NULL),
    "attachment_dir"
  )
})

test_that("download_attachments_in_tibble creates dir in file mode", {
  tmp <- file.path(tempdir(), "test_att_dir_create")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  # Mock the HTTP download
  local_mocked_bindings(
    req_perform = function(req, ...) {
      # Create the target file for "file" download
      path <- list(...)$path
      if (!is.null(path)) {
        dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
        writeLines("fake", path)
      }
      structure(list(body = charToRaw("fake")), class = "httr2_response")
    },
    .package = "httr2"
  )

  tbl <- tibble::tibble(
    airtable_id = "rec1",
    Photos = list(list(list(filename = "a.png", url = "http://x/a.png")))
  )

  result <- download_attachments_in_tibble(tbl, "Photos", mode = "file", dir = tmp)
  expect_true(dir.exists(tmp))
  att <- result$Photos[[1]][[1]]
  expect_true(!is.null(att$local_path))
  expect_equal(basename(att$local_path), "a.png")
})

test_that("resolve_attachment_file handles blob mode", {
  att <- list(filename = "test.txt", content = charToRaw("hello world"))
  path <- resolve_attachment_file(att, mode = "blob")
  on.exit(unlink(path), add = TRUE)

  expect_true(file.exists(path))
  expect_equal(readBin(path, "raw", 100), charToRaw("hello world"))
  expect_true(grepl("airtable2_blob_", basename(path)))
})

test_that("resolve_attachment_file returns NULL for blob without content", {
  att <- list(filename = "test.txt")
  expect_null(resolve_attachment_file(att, mode = "blob"))
})

test_that("resolve_attachment_file resolves local_path in file mode", {
  tmp <- tempfile("att_test_")
  writeLines("data", tmp)
  on.exit(unlink(tmp), add = TRUE)

  att <- list(filename = "x.txt", local_path = tmp)
  expect_equal(resolve_attachment_file(att, mode = "file"), tmp)
})

test_that("resolve_attachment_file resolves from attachment_dir", {
  dir <- tempfile("att_dir_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines("data", file.path(dir, "doc.pdf"))

  att <- list(filename = "doc.pdf")
  expect_equal(
    resolve_attachment_file(att, mode = "file", attachment_dir = dir),
    file.path(dir, "doc.pdf")
  )
})

test_that("resolve_attachment_file returns NULL when file not found", {
  att <- list(filename = "missing.txt", local_path = "/nonexistent/path.txt")
  expect_null(resolve_attachment_file(att, mode = "file"))
})

test_that("upload_attachments_from_tibble calls at_upload_attachment", {
  upload_calls <- list()

  local_mocked_bindings(
    at_upload_attachment = function(...) {
      upload_calls[[length(upload_calls) + 1L]] <<- list(...)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  # Create a temp file
  tmp <- tempfile("test_upload_")
  writeLines("content", tmp)
  on.exit(unlink(tmp), add = TRUE)

  data <- tibble::tibble(
    Name = "A",
    Photos = list(list(list(filename = "a.png", local_path = tmp)))
  )

  upload_attachments_from_tibble(
    base_id = "app1",
    table = "tbl1",
    record_ids = "rec1",
    data = data,
    att_fields = "Photos",
    mode = "file",
    .token = NULL
  )

  expect_length(upload_calls, 1)
  expect_equal(upload_calls[[1]]$record_id, "rec1")
  expect_equal(upload_calls[[1]]$field_id, "Photos")
  expect_equal(upload_calls[[1]]$file, tmp)
})

test_that("upload_attachments_from_tibble handles blob mode", {
  upload_calls <- list()

  local_mocked_bindings(
    at_upload_attachment = function(...) {
      upload_calls[[length(upload_calls) + 1L]] <<- list(...)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = "A",
    Docs = list(list(list(
      filename = "report.txt",
      content = charToRaw("blob content")
    )))
  )

  upload_attachments_from_tibble(
    base_id = "app1",
    table = "tbl1",
    record_ids = "rec1",
    data = data,
    att_fields = "Docs",
    mode = "blob",
    .token = NULL
  )

  expect_length(upload_calls, 1)
  # Should have written to a temp file
  uploaded_file <- upload_calls[[1]]$file
  expect_true(grepl("airtable2_blob_", uploaded_file))
})

test_that("upload_attachments_from_tibble skips NULL attachment entries", {
  upload_calls <- list()

  local_mocked_bindings(
    at_upload_attachment = function(...) {
      upload_calls[[length(upload_calls) + 1L]] <<- list(...)
      invisible(NULL)
    },
    .package = "airtable2"
  )

  data <- tibble::tibble(
    Name = c("A", "B"),
    Photos = list(NULL, NULL)
  )

  upload_attachments_from_tibble(
    base_id = "app1",
    table = "tbl1",
    record_ids = c("rec1", "rec2"),
    data = data,
    att_fields = "Photos",
    mode = "file",
    .token = NULL
  )

  expect_length(upload_calls, 0)
})

test_that("get_attachment_fields identifies multipleAttachments type", {
  local_mocked_bindings(
    at_get_schema = function(...) list(
      list(
        id = "tbl1", name = "Projects",
        fields = list(
          list(name = "Name", type = "singleLineText"),
          list(name = "Files", type = "multipleAttachments"),
          list(name = "Logo", type = "multipleAttachments"),
          list(name = "Age", type = "number")
        )
      )
    ),
    .package = "airtable2"
  )

  result <- get_attachment_fields("app1", "Projects")
  expect_equal(sort(result), c("Files", "Logo"))
})
