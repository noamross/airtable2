# Live type-coverage tests for air_sync() change detection.
#
# Regression coverage for https://github.com/noamross/airtable2/issues/13:
# air_sync() must NOT report unchanged rows as changed for ANY field type.
# These exercise the full round-trip against a real "SyncTypes" table that has
# a writable field of every type air_sync() hashes.

# Two rows of representative data for every writable scalar/select type.
synctypes_data <- function() {
  tibble::tibble(
    Name  = c("Alice", "Bob"),
    Notes = c("hello\nworld", "second"),
    Email = c("a@x.com", "b@x.com"),
    Site  = c("https://a.org", "https://b.org"),
    Phone = c("555-1234", "555-5678"),
    Num   = c(1.5, 2.25),
    Pct   = c(0.1, 0.2),
    Cost  = c(100.5, 200),
    Dur   = c(3600, 5400),
    Stars = c(3L, 5L),
    Done  = c(TRUE, FALSE),
    Day   = as.Date(c("2024-01-15", "2024-02-01")),
    When  = as.POSIXct(
      c("2024-01-15 13:45:00", "2024-02-01 09:00:00"),
      tz = "UTC"
    ),
    Cat   = c("A", "B"),
    Tags  = list(c("R", "Python"), "Julia")
  )
}

clear_synctypes <- function(base_id) {
  recs <- at_list_records(base_id, "SyncTypes")
  if (length(recs)) {
    at_delete_records(
      base_id, "SyncTypes",
      vapply(recs, function(r) r$id, character(1))
    )
  }
}

test_that("air_sync is idempotent across all scalar/select/date types", {
  skip_on_cran()
  base_id <- get_test_base()
  ensure_synctypes_table()
  clear_synctypes(base_id)

  data <- synctypes_data()
  air_write(data, "SyncTypes", base_id)

  # Syncing the identical data must detect zero changes for every field type.
  result <- air_sync(
    data, "SyncTypes",
    key = "Name", base_id = base_id, delete_missing = TRUE
  )

  expect_equal(result$created, 0L)
  expect_equal(result$updated, 0L)
  expect_equal(result$deleted, 0L)
  expect_equal(result$unchanged, 2L)

  # And again — a second sync is also a no-op (true idempotency).
  result2 <- air_sync(
    data, "SyncTypes",
    key = "Name", base_id = base_id, delete_missing = TRUE
  )
  expect_equal(result2$updated, 0L)
  expect_equal(result2$unchanged, 2L)
})

test_that("air_sync detects a genuine change in each field type", {
  skip_on_cran()
  base_id <- get_test_base()
  ensure_synctypes_table()
  clear_synctypes(base_id)

  data <- synctypes_data()
  air_write(data, "SyncTypes", base_id)

  # Change exactly one field type at a time on Bob; each must be detected.
  changes <- list(
    Notes = function(d) {
      d$Notes[2] <- "edited"
      d
    },
    Num   = function(d) {
      d$Num[2] <- 9.99
      d
    },
    Pct   = function(d) {
      d$Pct[2] <- 0.5
      d
    },
    Cost  = function(d) {
      d$Cost[2] <- 1
      d
    },
    Dur   = function(d) {
      d$Dur[2] <- 60
      d
    },
    Stars = function(d) {
      d$Stars[2] <- 1L
      d
    },
    Done  = function(d) {
      d$Done[2] <- TRUE
      d
    },
    Day   = function(d) {
      d$Day[2] <- as.Date("2025-12-31")
      d
    },
    When  = function(d) {
      d$When[2] <- as.POSIXct("2025-12-31 23:59:00", tz = "UTC")
      d
    },
    Cat   = function(d) {
      d$Cat[2] <- "C"
      d
    },
    Tags  = function(d) {
      d$Tags[[2]] <- c("R", "Julia")
      d
    }
  )

  for (field in names(changes)) {
    changed <- changes[[field]](synctypes_data())
    result <- air_sync(
      changed, "SyncTypes",
      key = "Name", base_id = base_id, delete_missing = FALSE
    )
    expect_equal(result$updated, 1L, info = paste("field:", field))
    expect_equal(result$unchanged, 1L, info = paste("field:", field))
    # Restore baseline so the next iteration starts clean.
    air_sync(
      synctypes_data(), "SyncTypes",
      key = "Name", base_id = base_id, delete_missing = FALSE
    )
  }
})

test_that("air_sync is idempotent for multipleRecordLinks", {
  skip_on_cran()
  base_id <- get_test_base()
  ensure_synctypes_table()
  clear_synctypes(base_id)

  # Seed two unlinked rows, then link Alice -> Bob by record id.
  air_write(synctypes_data(), "SyncTypes", base_id)
  seeded <- air_read("SyncTypes", base_id)
  bob_id <- seeded$airtable_id[seeded$Name == "Bob"]

  linked <- synctypes_data()
  linked$Links <- list(bob_id, character(0))
  air_upsert(linked, "SyncTypes", merge_on = "Name", base_id = base_id)

  # Syncing the same linked data must be a no-op.
  result <- air_sync(
    linked, "SyncTypes",
    key = "Name", base_id = base_id, delete_missing = TRUE
  )
  expect_equal(result$updated, 0L)
  expect_equal(result$unchanged, 2L)
})

test_that("air_sync ignores attachment fields when detecting changes", {
  skip_on_cran()
  base_id <- get_test_base()
  table_id <- ensure_synctypes_table()
  clear_synctypes(base_id)

  # Seed one row (scalars only), then attach a file by URL via the raw API
  # (air_write's complex-column guard is not attachment-aware).
  air_write(synctypes_data()[1, ], "SyncTypes", base_id)
  seeded <- air_read("SyncTypes", base_id)
  at_update_records(
    base_id, table_id,
    records = list(list(
      id = seeded$airtable_id[1],
      fields = list(Files = list(list(
        url = "https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png"
      )))
    ))
  )

  # The local data has no attachment at all, yet the sync must be a no-op:
  # attachment fields are always excluded from the change-detection hash.
  result <- air_sync(
    synctypes_data()[1, ], "SyncTypes",
    key = "Name", base_id = base_id, delete_missing = TRUE
  )
  expect_equal(result$updated, 0L)
  expect_equal(result$unchanged, 1L)
})
