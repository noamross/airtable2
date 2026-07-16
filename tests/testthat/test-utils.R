test_that("compact removes NULL elements", {
  expect_equal(compact(list(a = 1, b = NULL, c = 3)), list(a = 1, c = 3))
  expect_equal(compact(list()), list())
  expect_equal(compact(list(a = NULL)), structure(list(), names = character(0)))
})

test_that("check_string validates input", {
  expect_invisible(check_string("hello"))
  expect_error(check_string(123), "must be a single non-NA string")
  expect_error(check_string(c("a", "b")), "must be a single non-NA string")
  expect_error(check_string(NA_character_), "must be a single non-NA string")
  expect_error(check_string(NULL), "must be a single non-NA string")
  expect_invisible(check_string(NULL, allow_null = TRUE))
})

test_that("check_bool validates input", {
  expect_invisible(check_bool(TRUE))
  expect_invisible(check_bool(FALSE))
  expect_error(check_bool(1), "must be.*TRUE.*FALSE")
  expect_error(check_bool(NA), "must be.*TRUE.*FALSE")
  expect_error(check_bool("yes"), "must be.*TRUE.*FALSE")
})

test_that("check_count validates input", {
  expect_invisible(check_count(1))
  expect_invisible(check_count(100))
  expect_error(check_count(0), "must be a positive integer")
  expect_error(check_count(-1), "must be a positive integer")
  expect_error(check_count(1.5), "must be a positive integer")
  expect_error(check_count(Inf), "must be a positive integer")
  expect_invisible(check_count(Inf, allow_inf = TRUE))
})

test_that("check_character validates input", {
  expect_invisible(check_character("NA"))
  expect_invisible(check_character(c("NA", "N/A")))
  expect_invisible(check_character(NULL, allow_null = TRUE))
  expect_error(check_character(NULL), "must be a character vector")
  expect_error(check_character(1), "must be a character vector")
  expect_error(check_character(TRUE), "must be a character vector")
})

test_that("chunk splits correctly", {
  expect_equal(chunk(1:10, 3), list(`1` = 1:3, `2` = 4:6, `3` = 7:9, `4` = 10L))
  expect_equal(chunk(1:5, 5), list(`1` = 1:5))
  expect_equal(chunk(1:5, 10), list(`1` = 1:5))
})
