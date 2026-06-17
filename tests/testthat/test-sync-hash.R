# Focused regression for the datetime wall-clock behaviour in
# normalize_for_hash() (https://github.com/noamross/airtable2/issues/13).
#
# The broad normalize_for_hash() unit tests live in test-air-write-sync.R.
# These specifically guard the NON-UTC case: Airtable round-trips a datetime by
# WALL-CLOCK, not absolute instant -- a POSIXct is uploaded as its naive local
# time and read back as that same wall-clock with a "Z" suffix. Normalizing in
# UTC would shift a non-UTC column by its offset and flag every row as changed.

.dt_types <- field_types_from_schema(list(
  fields = list(list(name = "When", type = "dateTime"))
))

test_that("normalize_for_hash: non-UTC POSIXct uses wall-clock, not UTC instant", {
  # 13:45 in New York must normalize to 13:45Z (the wall-clock Airtable stores),
  # NOT 18:45Z (the absolute UTC instant).
  ny <- tibble::tibble(When = as.POSIXct("2024-01-15 13:45:00", tz = "America/New_York"))
  out <- normalize_for_hash(ny, .dt_types)
  expect_equal(out$When, "2024-01-15T13:45:00.000Z")
})

test_that("normalize_for_hash: local POSIXct matches the API ISO string round-trip", {
  # `existing` is what air_read(coerce = FALSE) returns: the raw API string.
  # `data` is the local POSIXct that produced it. They must normalize equally
  # regardless of the local column's timezone.
  existing <- tibble::tibble(When = "2024-01-15T13:45:00.000Z")
  data_df <- tibble::tibble(
    When = as.POSIXct("2024-01-15 13:45:00", tz = "America/New_York")
  )
  en <- normalize_for_hash(existing, .dt_types)
  dn <- normalize_for_hash(data_df, .dt_types)
  expect_equal(en$When, dn$When)
  expect_equal(
    compute_row_hashes(en, "When"),
    compute_row_hashes(dn, "When")
  )
})

test_that("normalize_for_hash: genuinely different datetimes still differ", {
  a <- normalize_for_hash(
    tibble::tibble(When = as.POSIXct("2024-01-15 13:45:00", tz = "UTC")),
    .dt_types
  )
  b <- normalize_for_hash(
    tibble::tibble(When = as.POSIXct("2024-01-15 13:45:01", tz = "UTC")),
    .dt_types
  )
  expect_false(identical(a$When, b$When))
})

test_that("normalize_for_hash: NA datetime stays NA (not 'NAZ')", {
  out <- normalize_for_hash(
    tibble::tibble(When = as.POSIXct(c("2024-01-15 13:45:00", NA), tz = "UTC")),
    .dt_types
  )
  expect_equal(out$When, c("2024-01-15T13:45:00.000Z", NA_character_))
})
