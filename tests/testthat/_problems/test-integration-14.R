# Extracted from test-integration.R:14

# test -------------------------------------------------------------------------
httptest2::with_mock_dir("fixtures", {
    result <- at_list_bases(token = "fake_token")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 1L)
    expect_equal(result$id, "appTEST123")
    expect_equal(result$name, "Test Base")
  })
