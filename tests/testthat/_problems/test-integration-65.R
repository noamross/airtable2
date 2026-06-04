# Extracted from test-integration.R:65

# test -------------------------------------------------------------------------
httptest2::with_mock_dir("fixtures", {
    result <- air_meta("appTEST123", .token = "fake_token")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 5L)
    expect_true(all(c("table_name", "table_id", "field_name",
                      "field_id", "field_type") %in% names(result)))
  })
