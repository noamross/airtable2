test_that("air_token errors with no token available", {
  withr::local_envvar(AIRTABLE_API_KEY = "")
  withr::local_options(airtable2.token = NULL)
  expect_error(air_token(), "No Airtable token found")
})

test_that("air_token resolves from explicit argument", {
  expect_equal(air_token("pat_test123"), "pat_test123")
})

test_that("air_token resolves from option", {
  withr::local_envvar(AIRTABLE_API_KEY = "")
  withr::local_options(airtable2.token = "pat_from_option")
  expect_equal(air_token(), "pat_from_option")
})

test_that("air_token resolves from env var", {
  withr::local_envvar(AIRTABLE_API_KEY = "pat_from_env")
  withr::local_options(airtable2.token = NULL)
  expect_equal(air_token(), "pat_from_env")
})

test_that("air_token prefers option over env var", {
  withr::local_envvar(AIRTABLE_API_KEY = "pat_from_env")
  withr::local_options(airtable2.token = "pat_from_option")
  expect_equal(air_token(), "pat_from_option")
})

test_that("air_req builds proper request", {
  withr::local_envvar(AIRTABLE_API_KEY = "pat_test_req")
  req <- air_req("appABC123/TableName")
  expect_s3_class(req, "httr2_request")
  expect_true(grepl("api.airtable.com/v0/appABC123/TableName", req$url))
})
