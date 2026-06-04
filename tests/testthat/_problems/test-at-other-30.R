# Extracted from test-at-other.R:30

# test -------------------------------------------------------------------------
local_mocked_bindings(
    air_perform = function(req) {
      if (grepl("whoami", req$url)) {
        list(id = "usrABC", email = "test@example.com")
      } else {
        # meta/bases response (no workspaceId per API spec)
        list(
          bases = list(
            list(id = "appAAA", name = "Base One", permissionLevel = "create"),
            list(id = "appBBB", name = "Base Two", permissionLevel = "edit")
          )
        )
      }
    }
  )
result <- at_sitrep()
expect_type(result, "list")
expect_named(result, c("user", "scopes", "bases", "error"))
expect_equal(result$user$id,    "usrABC")
expect_equal(result$user$email, "test@example.com")
expect_null(result$scopes)
expect_s3_class(result$bases, "tbl_df")
expect_equal(nrow(result$bases), 2L)
expect_named(result$bases, c("id", "name", "permissionLevel"))
expect_null(result$error)
