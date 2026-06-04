# Mocked tests for at_create_records, at_update_records, at_delete_records
# covering the batch logic (chunking, progress, result accumulation).

batch_resp <- function(records) list(records = records)

make_records <- function(n) {
  lapply(seq_len(n), function(i) {
    list(id = paste0("rec", sprintf("%03d", i)),
         fields = list(Name = paste0("Person ", i)))
  })
}

# ── at_create_records ────────────────────────────────────────────────────────

test_that("at_create_records returns record IDs from API response", {
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      batch_resp(list(list(id = "recNEW", fields = list(Name = "Alice"))))
    }
  )

  result <- at_create_records("appX", "tblY",
    records = list(list(fields = list(Name = "Alice"))),
    typecast = FALSE
  )

  expect_length(result, 1L)
  expect_equal(result[[1]]$id, "recNEW")
})

test_that("at_create_records batches >10 records into multiple calls", {
  call_count <- 0L
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      call_count <<- call_count + 1L
      # Return one fake record per call to keep it simple
      batch_resp(list(list(id = paste0("rec", call_count), fields = list())))
    }
  )

  recs <- lapply(seq_len(25), function(i) list(fields = list(Name = paste0("P", i))))
  result <- at_create_records("appX", "tblY", records = recs)

  # 25 records → 3 batches (10 + 10 + 5)
  expect_equal(call_count, 3L)
  expect_length(result, 3L)  # one result per batch call in our stub
})

test_that("at_create_records validates base_id and table_id", {
  expect_error(at_create_records(123, "tbl", list()),  "must be a single non-NA string")
  expect_error(at_create_records("app", 123, list()),  "must be a single non-NA string")
  expect_error(at_create_records("app", "tbl", list(), typecast = "yes"),
               "must be.*TRUE.*FALSE")
})

# ── at_update_records ────────────────────────────────────────────────────────

test_that("at_update_records sends PATCH by default", {
  methods_seen <- character()
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      methods_seen <<- c(methods_seen, req$method)
      list(records = list(list(id = "recUPD", fields = list())),
           createdRecords = character(),
           updatedRecords = "recUPD")
    }
  )

  at_update_records("appX", "tblY",
    records = list(list(id = "recUPD", fields = list(Name = "Alice")))
  )
  expect_equal(methods_seen, "PATCH")
})

test_that("at_update_records with upsert_fields runs without error", {
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      list(records = list(), createdRecords = "recNEW", updatedRecords = character())
    }
  )

  # Should succeed without error; upsert_fields triggers performUpsert in body
  result <- at_update_records("appX", "tblY",
    records = list(list(fields = list(Name = "Alice"))),
    upsert_fields = "Name"
  )
  expect_type(result, "list")
})

test_that("at_update_records batches >10 records", {
  call_count <- 0L
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      call_count <<- call_count + 1L
      list(records = list(), createdRecords = character(), updatedRecords = character())
    }
  )
  recs <- lapply(seq_len(21), function(i) list(id = paste0("rec", i), fields = list()))
  at_update_records("appX", "tblY", records = recs)
  expect_equal(call_count, 3L)  # 10 + 10 + 1
})

test_that("at_update_records validates method argument", {
  expect_error(
    at_update_records("app1", "tbl1", list(), method = "DELETE"),
    "should be one of"
  )
})

# ── at_delete_records ────────────────────────────────────────────────────────

test_that("at_delete_records sends DELETE with records[] query params", {
  req_captured <- list()
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      req_captured[[length(req_captured) + 1L]] <<- req
      list(records = list(list(id = "recDEL", deleted = TRUE)))
    }
  )

  result <- at_delete_records("appX", "tblY", record_ids = c("recDEL"))

  expect_length(req_captured, 1L)
  expect_true(grepl("records", req_captured[[1]]$url))
  expect_equal(result[[1]]$id, "recDEL")
})

test_that("at_delete_records batches >10 IDs into multiple calls", {
  call_count <- 0L
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      call_count <<- call_count + 1L
      list(records = list())
    }
  )
  ids <- paste0("rec", sprintf("%03d", seq_len(15)))
  at_delete_records("appX", "tblY", record_ids = ids)
  expect_equal(call_count, 2L)  # 10 + 5
})

test_that("at_delete_records validates base_id", {
  expect_error(at_delete_records(123, "tbl", "rec1"), "must be a single non-NA string")
})
