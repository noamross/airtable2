test_that("at_get_schema validates base_id", {
  expect_error(at_get_schema(123), "must be a single non-NA string")
})

test_that("at_create_base validates inputs", {
  expect_error(at_create_base(123, "wsp1", list()), "must be a single non-NA string")
  expect_error(at_create_base("Base", 123, list()), "must be a single non-NA string")
})
