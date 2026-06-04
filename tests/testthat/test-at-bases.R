test_that("at_get_schema validates base_id", {
  expect_error(at_get_schema(123), "must be a single non-NA string")
})

test_that("at_create_base validates inputs", {
  expect_error(at_create_base(123, "wsp1", list()), "must be a single non-NA string")
  expect_error(at_create_base("Base", 123, list()), "must be a single non-NA string")
})

# ── at_get_base ───────────────────────────────────────────────────────────────

test_that("at_get_base returns info for a known base ID", {
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      list(bases = list(
        list(id = "appAAA", name = "Test Base", permissionLevel = "create"),
        list(id = "appBBB", name = "Other Base", permissionLevel = "edit")
      ))
    }
  )
  info <- at_get_base("appAAA")
  expect_equal(info$id, "appAAA")
  expect_equal(info$name, "Test Base")
  expect_equal(info$permissionLevel, "create")
})

test_that("at_get_base returns NULL for unknown base ID", {
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      list(bases = list(
        list(id = "appAAA", name = "Test Base", permissionLevel = "create")
      ))
    }
  )
  expect_null(at_get_base("appNOTHERE"))
})

test_that("at_get_base validates base_id input", {
  expect_error(at_get_base(123), "must be a single non-NA string")
})

