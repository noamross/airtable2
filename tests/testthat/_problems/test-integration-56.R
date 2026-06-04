# Extracted from test-integration.R:56

# test -------------------------------------------------------------------------
httptest2::with_mock_dir("fixtures", {
    result <- air_schema("appTEST123", .token = "fake_token")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 1L)
    expect_equal(result$table_name, "Contacts")
    expect_s3_class(result$fields[[1]], "tbl_df")
    expect_equal(nrow(result$fields[[1]]), 5L)
  })
