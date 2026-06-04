# Tests for at_list_views() and at_get_view() (R/at-views.R)

test_that("at_list_views validates inputs", {
  expect_error(at_list_views(123, "tbl1"), "must be a single non-NA string")
  expect_error(at_list_views("app1", 123), "must be a single non-NA string")
})

test_that("at_list_views returns a tibble with id, name, type", {
  local_mocked_bindings(
    air_token  = function(token = NULL) "fake_token",
    air_perform = function(req) {
      list(
        views = list(
          list(id = "viw111", name = "Grid view",    type = "grid"),
          list(id = "viw222", name = "Gallery view", type = "gallery"),
          list(id = "viw333", name = "Kanban",       type = "kanban")
        )
      )
    }
  )

  result <- at_list_views("appXXX", "tblYYY")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3L)
  expect_named(result, c("id", "name", "type"))
  expect_equal(result$id,   c("viw111", "viw222", "viw333"))
  expect_equal(result$name, c("Grid view", "Gallery view", "Kanban"))
  expect_equal(result$type, c("grid", "gallery", "kanban"))
})

test_that("at_list_views handles a table with no views gracefully", {
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) list(views = list())
  )
  result <- at_list_views("appXXX", "tblYYY")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

test_that("at_get_view validates inputs", {
  expect_error(at_get_view(123,    "tbl1",  "viw1"), "must be a single non-NA string")
  expect_error(at_get_view("app1", 123,     "viw1"), "must be a single non-NA string")
  expect_error(at_get_view("app1", "tbl1",  123),    "must be a single non-NA string")
})

test_that("at_get_view returns view metadata list", {
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      list(
        id = "viwAAA",
        name = "My Grid",
        type = "grid",
        visibleFieldIds = list("fldA", "fldB")
      )
    }
  )

  result <- at_get_view("appXXX", "tblYYY", "viwAAA")

  expect_equal(result$id,   "viwAAA")
  expect_equal(result$name, "My Grid")
  expect_equal(result$type, "grid")
  expect_length(result$visibleFieldIds, 2L)
})

test_that("at_list_views request hits the correct endpoint path", {
  req_captured <- NULL
  local_mocked_bindings(
    air_token   = function(token = NULL) "fake_token",
    air_perform = function(req) {
      req_captured <<- req
      list(views = list())
    }
  )
  at_list_views("appBASE", "tblTABLE")
  expect_true(grepl("appBASE/tables/tblTABLE/views", req_captured$url))
})
