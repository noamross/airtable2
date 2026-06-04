# Extracted from test-integration.R:24

# test -------------------------------------------------------------------------
httptest2::with_mock_dir("fixtures", {
    result <- at_get_schema("appTEST123", token = "fake_token")
    expect_length(result, 1L)
    expect_equal(result[[1]]$name, "Contacts")
    expect_length(result[[1]]$fields, 5L)
    expect_equal(result[[1]]$fields[[1]]$name, "Name")
  })
