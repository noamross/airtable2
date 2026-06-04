# Extracted from test-at-other.R:58

# test -------------------------------------------------------------------------
local_mocked_bindings(
    air_perform = function(req) {
      if (grepl("whoami", req$url)) {
        list(id = "usrABC", email = "test@example.com")
      } else {
        stop("no permission")
      }
    }
  )
result <- at_sitrep()
expect_null(result$bases)
expect_match(result$error, "Failed to list bases")
expect_false(is.null(result$user))
