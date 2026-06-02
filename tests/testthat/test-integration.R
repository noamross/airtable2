test_that("at_whoami returns user info", {
  httptest2::with_mock_dir("fixtures", {
    result <- at_whoami(token = "fake_token")
    expect_equal(result$id, "usrTEST123")
    expect_equal(result$email, "test@example.com")
  })
})

test_that("at_list_bases returns tibble of bases", {
  httptest2::with_mock_dir("fixtures", {
    result <- at_list_bases(token = "fake_token")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 1L)
    expect_equal(result$id, "appTEST123")
    expect_equal(result$name, "Test Base")
  })
})

test_that("at_get_schema returns table metadata", {
  httptest2::with_mock_dir("fixtures", {
    result <- at_get_schema("appTEST123", token = "fake_token")
    expect_length(result, 1L)
    expect_equal(result[[1]]$name, "Contacts")
    expect_length(result[[1]]$fields, 5L)
    expect_equal(result[[1]]$fields[[1]]$name, "Name")
  })
})

test_that("air_read returns typed tibble", {
  httptest2::with_mock_dir("fixtures", {
    result <- air_read("appTEST123", "Contacts", .token = "fake_token")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 2L)

    # Check metadata columns
    expect_true("airtable_id" %in% names(result))
    expect_true("airtable_created_time" %in% names(result))
    expect_equal(result$airtable_id, c("recALICE1", "recBOB1"))

    # Check type coercion
    expect_type(result$Name, "character")
    expect_type(result$Age, "double")
    expect_type(result$Active, "logical")
    expect_s3_class(result$airtable_created_time, "POSIXct")

    # Check list-column
    expect_type(result$Tags, "list")
  })
})

test_that("air_schema returns structured schema tibble", {
  httptest2::with_mock_dir("fixtures", {
    result <- air_schema("appTEST123", .token = "fake_token")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 1L)
    expect_equal(result$table_name, "Contacts")
    expect_s3_class(result$fields[[1]], "tbl_df")
    expect_equal(nrow(result$fields[[1]]), 5L)
  })
})

test_that("air_meta returns flat field metadata", {
  httptest2::with_mock_dir("fixtures", {
    result <- air_meta("appTEST123", .token = "fake_token")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 5L)
    expect_true(all(c("table_name", "table_id", "field_name",
                      "field_id", "field_type") %in% names(result)))
  })
})
