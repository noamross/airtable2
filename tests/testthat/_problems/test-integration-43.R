# Extracted from test-integration.R:43

# test -------------------------------------------------------------------------
httptest2::with_mock_dir("fixtures", {
    result <- air_read("appTEST123", "Contacts", .token = "fake_token")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 2L)

    # Check metadata columns
    expect_true("airtable_id" %in% names(result))
    expect_true("airtable_created_time" %in% names(result))
    expect_equal(result$airtable_id, c("recALICE1", "recBOB1"), ignore_attr = TRUE)

    # Check type coercion
    expect_type(result$Name, "character")
    expect_type(result$Age, "double")
    expect_type(result$Active, "logical")
    expect_s3_class(result$airtable_created_time, "POSIXct")

    # Check list-column
    expect_type(result$Tags, "list")
  })
