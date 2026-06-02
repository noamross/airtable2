test_that("air_flatten_multiselect works", {
  x <- list(c("R", "Python"), NULL, "Julia")
  result <- air_flatten_multiselect(x)
  expect_equal(result, c("R, Python", NA, "Julia"))
})

test_that("air_expand_multiselect round-trips", {
  original <- list(c("A", "B"), NULL, "C")
  flat <- air_flatten_multiselect(original)
  expanded <- air_expand_multiselect(flat)
  expect_equal(expanded[[1]], c("A", "B"))
  expect_null(expanded[[2]])
  expect_equal(expanded[[3]], "C")
})

test_that("air_flatten_collaborator works", {
  x <- list(
    list(name = "Alice", email = "alice@example.com"),
    NULL
  )
  result <- air_flatten_collaborator(x)
  expect_equal(result, c("Alice <alice@example.com>", NA))
})

test_that("air_expand_collaborator round-trips", {
  flat <- c("Alice <alice@example.com>", NA)
  expanded <- air_expand_collaborator(flat)
  expect_equal(expanded[[1]]$name, "Alice")
  expect_equal(expanded[[1]]$email, "alice@example.com")
  expect_null(expanded[[2]])
})

test_that("air_flatten_links works", {
  x <- list(c("rec1", "rec2"), NULL)
  result <- air_flatten_links(x)
  expect_equal(result, c("rec1, rec2", NA))
})

test_that("air_flatten_attachments works", {
  x <- list(
    list(list(filename = "a.pdf"), list(filename = "b.pdf")),
    NULL
  )
  result <- air_flatten_attachments(x)
  expect_equal(result, c("a.pdf, b.pdf", NA))
})

test_that("air_simplify handles basic list columns", {
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
  expect_equal(result$Tags, c("x, y", NA))
})
