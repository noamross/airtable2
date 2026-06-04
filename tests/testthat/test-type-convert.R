test_that("air_flatten_multiselect default uses '; ' not ', '", {
  x <- list(c("R", "Python"), NULL, "Julia")
  result <- air_flatten_multiselect(x)
  expect_equal(result, c("R; Python", NA, "Julia"))
})

test_that("air_flatten_multiselect explicit sep overrides default", {
  x <- list(c("R", "Python"))
  expect_equal(air_flatten_multiselect(x, sep = ", "), "R, Python")
  expect_equal(air_flatten_multiselect(x, sep = " | "), "R | Python")
})

test_that("air_flatten_multiselect respects options(airtable2.delimiter)", {
  withr::local_options(airtable2.delimiter = " | ")
  x <- list(c("A", "B"), "C")
  result <- air_flatten_multiselect(x)
  expect_equal(result, c("A | B", "C"))
})

test_that("air_flatten_multiselect respects AIRTABLE2_DELIMITER env var", {
  withr::local_envvar(AIRTABLE2_DELIMITER = " :: ")
  x <- list(c("A", "B"), "C")
  result <- air_flatten_multiselect(x)
  expect_equal(result, c("A :: B", "C"))
})

test_that("explicit sep beats options() and env var", {
  withr::local_options(airtable2.delimiter = " | ")
  withr::local_envvar(AIRTABLE2_DELIMITER = " :: ")
  x <- list(c("A", "B"))
  expect_equal(air_flatten_multiselect(x, sep = ", "), "A, B")
})

test_that("options() beats env var for delimiter resolution", {
  withr::local_options(airtable2.delimiter = " | ")
  withr::local_envvar(AIRTABLE2_DELIMITER = " :: ")
  x <- list(c("A", "B"))
  result <- air_flatten_multiselect(x)
  expect_equal(result, "A | B")
})

test_that("air_expand_multiselect default uses '; ' splitting", {
  flat <- c("R; Python", NA, "Julia")
  result <- air_expand_multiselect(flat)
  expect_equal(result[[1]], c("R", "Python"))
  expect_null(result[[2]])
  expect_equal(result[[3]], "Julia")
})

test_that("air_expand_multiselect round-trips with default delimiter", {
  original <- list(c("A", "B"), NULL, "C")
  flat <- air_flatten_multiselect(original)
  expanded <- air_expand_multiselect(flat)
  expect_equal(expanded[[1]], c("A", "B"))
  expect_null(expanded[[2]])
  expect_equal(expanded[[3]], "C")
})

test_that("air_expand_multiselect round-trips with custom delimiter via options", {
  withr::local_options(airtable2.delimiter = " | ")
  original <- list(c("A", "B"), NULL, "C")
  flat <- air_flatten_multiselect(original)
  expanded <- air_expand_multiselect(flat)
  expect_equal(expanded[[1]], c("A", "B"))
  expect_null(expanded[[2]])
  expect_equal(expanded[[3]], "C")
})

test_that("air_expand_multiselect tolerates spaces around semicolon (default)", {
  # flatten produces "A; B" but splitting should also handle "A;B" or "A ;B"
  expect_equal(air_expand_multiselect("A;B")[[1]], c("A", "B"))
  expect_equal(air_expand_multiselect("A ; B")[[1]], c("A", "B"))
  expect_equal(air_expand_multiselect("A; B")[[1]], c("A", "B"))
})

test_that("air_expand_multiselect explicit sep overrides default", {
  flat <- c("A, B", "C")
  result <- air_expand_multiselect(flat, sep = ", ")
  expect_equal(result[[1]], c("A", "B"))
  expect_equal(result[[2]], "C")
})

test_that("air_flatten_links default uses '; '", {
  x <- list(c("rec1", "rec2"), NULL)
  result <- air_flatten_links(x)
  expect_equal(result, c("rec1; rec2", NA))
})

test_that("air_flatten_links respects explicit sep", {
  x <- list(c("rec1", "rec2"), NULL)
  result <- air_flatten_links(x, sep = ", ")
  expect_equal(result, c("rec1, rec2", NA))
})

test_that("air_flatten_links respects options(airtable2.delimiter)", {
  withr::local_options(airtable2.delimiter = " | ")
  x <- list(c("rec1", "rec2"), NULL)
  result <- air_flatten_links(x)
  expect_equal(result, c("rec1 | rec2", NA))
})

test_that("air_flatten_attachments default uses '; '", {
  x <- list(
    list(list(filename = "a.pdf"), list(filename = "b.pdf")),
    NULL
  )
  result <- air_flatten_attachments(x)
  expect_equal(result, c("a.pdf; b.pdf", NA))
})

test_that("air_flatten_attachments explicit sep overrides default", {
  x <- list(
    list(list(filename = "a.pdf"), list(filename = "b.pdf")),
    NULL
  )
  result <- air_flatten_attachments(x, sep = ", ")
  expect_equal(result, c("a.pdf, b.pdf", NA))
})

test_that("air_flatten_attachments respects options(airtable2.delimiter)", {
  withr::local_options(airtable2.delimiter = " | ")
  x <- list(
    list(list(filename = "a.pdf"), list(filename = "b.pdf")),
    NULL
  )
  result <- air_flatten_attachments(x)
  expect_equal(result, c("a.pdf | b.pdf", NA))
})

test_that("air_flatten_collaborator and air_expand_collaborator unchanged (no sep)", {
  x <- list(
    list(name = "Alice", email = "alice@example.com"),
    NULL
  )
  result <- air_flatten_collaborator(x)
  expect_equal(result, c("Alice <alice@example.com>", NA))

  expanded <- air_expand_collaborator(result)
  expect_equal(expanded[[1]]$name, "Alice")
  expect_equal(expanded[[1]]$email, "alice@example.com")
  expect_null(expanded[[2]])
})

# ── air_flatten() S3 generic (Phase 4A) ──────────────────────────────────────

test_that("air_flatten dispatches on air_multiselect to flatten_multiselect", {
  obj <- new_air_multiselect(list(c("R", "Python"), NULL, "Julia"))
  result <- air_flatten(obj)
  expect_equal(result, air_flatten_multiselect(unclass(obj)))
  expect_equal(result, c("R; Python", NA, "Julia"))
})

test_that("air_flatten.air_multiselect respects sep via ...", {
  obj <- new_air_multiselect(list(c("A", "B")))
  expect_equal(air_flatten(obj, sep = ", "), "A, B")
})

test_that("air_flatten dispatches on air_links to flatten_links", {
  obj <- new_air_links(list(c("rec1", "rec2"), NULL))
  result <- air_flatten(obj)
  expect_equal(result, air_flatten_links(unclass(obj)))
  expect_equal(result, c("rec1; rec2", NA))
})

test_that("air_flatten dispatches on air_attachments to flatten_attachments", {
  obj <- new_air_attachments(list(
    list(list(filename = "a.pdf"), list(filename = "b.pdf")),
    NULL
  ))
  result <- air_flatten(obj)
  expect_equal(result, air_flatten_attachments(unclass(obj)))
  expect_equal(result, c("a.pdf; b.pdf", NA))
})

test_that("air_flatten.air_attachments accepts field via ...", {
  obj <- new_air_attachments(list(
    list(list(filename = "a.pdf", url = "http://x/a"))
  ))
  expect_equal(air_flatten(obj, field = "url"), "http://x/a")
})

test_that("air_flatten dispatches on air_collaborator to flatten_collaborator", {
  obj <- new_air_collaborator(list(
    list(name = "Alice", email = "alice@example.com"),
    NULL
  ))
  result <- air_flatten(obj)
  expect_equal(result, air_flatten_collaborator(unclass(obj)))
  expect_equal(result, c("Alice <alice@example.com>", NA))
})

test_that("air_flatten.air_collaborator accepts format via ...", {
  obj <- new_air_collaborator(list(list(name = "Alice", email = "a@x.com")))
  expect_equal(air_flatten(obj, format = "{email}"), "a@x.com")
})

test_that("air_flatten.default returns plain character vector unchanged", {
  x <- c("a", "b", NA)
  expect_identical(air_flatten(x), x)
})

test_that("air_simplify uses new default '; ' separator", {
  data <- tibble::tibble(
    Name = c("A", "B"),
    Tags = list(c("x", "y"), NULL)
  )
  schema <- list(
    list(name = "Name", type = "singleLineText"),
    list(name = "Tags", type = "multipleSelects")
  )
  result <- air_simplify(data, schema = schema)
  expect_type(result$Tags, "character")
  expect_equal(result$Tags, c("x; y", NA))
})
