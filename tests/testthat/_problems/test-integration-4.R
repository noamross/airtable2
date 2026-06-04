# Extracted from test-integration.R:4

# test -------------------------------------------------------------------------
httptest2::with_mock_dir("fixtures", {
    result <- at_whoami(token = "fake_token")
    expect_equal(result$id, "usrTEST123")
    expect_equal(result$email, "test@example.com")
  })
