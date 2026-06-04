test_that("airtabler_conflict_msg() returns NULL when airtabler is not loaded", {
  msg <- airtabler_conflict_msg(loaded = FALSE)
  expect_null(msg)
})

test_that("airtabler_conflict_msg() returns a character string when airtabler is loaded", {
  msg <- airtabler_conflict_msg(loaded = TRUE)
  expect_type(msg, "character")
  expect_true(length(msg) >= 1L)
})

test_that("airtabler_conflict_msg() message mentions both package names when loaded", {
  msg <- airtabler_conflict_msg(loaded = TRUE)
  combined <- paste(msg, collapse = " ")
  expect_match(combined, "airtabler", fixed = TRUE)
  expect_match(combined, "airtable2", fixed = TRUE)
})

test_that("airtabler_conflict_msg() message mentions name collision or conflict", {
  msg <- airtabler_conflict_msg(loaded = TRUE)
  combined <- paste(msg, collapse = " ")
  expect_true(
    grepl("conflict", combined, ignore.case = TRUE) ||
      grepl("collid", combined, ignore.case = TRUE) ||
      grepl("overlap", combined, ignore.case = TRUE) ||
      grepl("mask", combined, ignore.case = TRUE)
  )
})

test_that("airtabler_conflict_msg() default loaded argument uses real detection", {
  # When airtabler is not actually loaded in the test session, the default
  # argument should also return NULL.
  if (isNamespaceLoaded("airtabler")) {
    skip("airtabler is loaded in this session; skipping default-arg test")
  }
  msg <- airtabler_conflict_msg()
  expect_null(msg)
})
