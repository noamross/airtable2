# Tests for air_demo_setup() and air_demo()

# ── air_demo_setup() ----------------------------------------------------------

test_that("air_demo_setup() errors when workspace_id is missing", {
  withr::with_envvar(c(AIRTABLE_WORKSPACE_ID = ""), {
    expect_error(
      air_demo_setup(workspace_id = ""),
      "workspace_id.*required|required.*workspace_id"
    )
  })
})

test_that("air_demo_setup() makes the right API calls (mocked)", {
  # Track which functions were called
  calls_made <- character()

  # Fake base + tables returned by at_create_base()
  fake_base <- list(
    id = "appDEMO123",
    name = "airtable2_demo",
    tables = list(
      list(id = "tblPEOPLE",      name = "People"),
      list(id = "tblPROJECTS",    name = "Projects"),
      list(id = "tblATTACHMENTS", name = "Attachments")
    )
  )

  local_mocked_bindings(
    at_create_base = function(name, workspace_id, tables, token = NULL) {
      calls_made <<- c(calls_made, "at_create_base")
      expect_equal(name, "airtable2_demo")
      expect_equal(workspace_id, "wspTEST")
      # Three tables should be configured
      expect_length(tables, 3L)
      fake_base
    },
    at_create_field = function(name, table_id, type, base_id = NULL,
                               options = NULL, description = NULL,
                               token = NULL) {
      calls_made <<- c(calls_made, paste0("at_create_field:", name))
      list(id = "fldDUMMY", name = name, type = type)
    },
    air_write = function(data, base_id, table, ...) {
      calls_made <<- c(calls_made, paste0("air_write:", table))
      invisible(paste0("recDUMMY", seq_len(nrow(data))))
    }
  )

  result <- air_demo_setup(workspace_id = "wspTEST")

  expect_equal(result, "appDEMO123")
  expect_true("at_create_base" %in% calls_made)
  # Members linked field should have been attempted
  expect_true(
    any(grepl("at_create_field:Members", calls_made)),
    label = "at_create_field called for Members"
  )
  expect_true("air_write:People"   %in% calls_made)
  expect_true("air_write:Projects" %in% calls_made)
})

test_that("air_demo_setup() passes .token through to API calls (mocked)", {
  captured_token <- NULL

  local_mocked_bindings(
    at_create_base = function(name, workspace_id, tables, token = NULL) {
      captured_token <<- token
      list(
        id = "appTOKEN",
        name = name,
        tables = list(
          list(id = "tblP", name = "People"),
          list(id = "tblPR", name = "Projects"),
          list(id = "tblA", name = "Attachments")
        )
      )
    },
    at_create_field = function(..., token = NULL) {
      list(id = "fldX", name = "Members", type = "multipleRecordLinks")
    },
    air_write = function(data, base_id, table, ..., .token = NULL) {
      invisible(character())
    }
  )

  air_demo_setup(workspace_id = "wspX", .token = "mytoken")
  expect_equal(captured_token, "mytoken")
})

test_that("air_demo_setup() warns (not errors) when Members field creation fails", {
  local_mocked_bindings(
    at_create_base = function(name, workspace_id, tables, token = NULL) {
      list(
        id = "appWARN",
        name = name,
        tables = list(
          list(id = "tblP", name = "People"),
          list(id = "tblPR", name = "Projects"),
          list(id = "tblA", name = "Attachments")
        )
      )
    },
    at_create_field = function(...) {
      stop("Simulated field creation failure")
    },
    air_write = function(data, base_id, table, ...) {
      invisible(character())
    }
  )

  expect_warning(
    result <- air_demo_setup(workspace_id = "wspX"),
    "Simulated field creation failure"
  )
  expect_equal(result, "appWARN")
})

# ── air_demo() ----------------------------------------------------------------

test_that("air_demo() calls air_demo_setup() when no base is configured (mocked)", {
  setup_called <- FALSE

  withr::with_envvar(c(AIRTABLE_BASE_ID = ""), {
    withr::with_options(list(airtable2.base_id = NULL), {
      local_mocked_bindings(
        air_demo_setup = function(workspace_id = "", .token = NULL) {
          setup_called <<- TRUE
          "appSETUP"
        },
        air_read = function(base_id, table, .token = NULL, ...) {
          tibble::tibble(
            airtable_id = "rec1",
            airtable_created_time = Sys.time(),
            Name = "Alice", Age = 30L, Active = TRUE,
            Role = "Engineer", Tags = list("R"),
            Joined = Sys.Date(), Email = "alice@example.com"
          )
        },
        air_write = function(...) invisible("rec2"),
        air_upsert = function(...) list(created = "rec3", updated = character()),
        air_sync = function(...) list(created = 0L, updated = 0L,
                                      deleted = 0L, unchanged = 1L),
        air_left_join = function(...) tibble::tibble(Name = "Alice", Score = 98L),
        air_schema = function(base_id, .token = NULL) {
          tibble::tibble(
            table_id = "tblP",
            table_name = "People",
            table_description = NA_character_,
            fields = list(tibble::tibble(
              id = "fldN", name = "Name",
              type = "singleLineText", description = NA_character_
            ))
          )
        },
        air_api_usage = function(...) NULL
      )

      result <- suppressMessages(air_demo())
      expect_true(setup_called)
      expect_named(result, c("read", "write", "upsert", "sync", "join",
                              "schema", "usage"))
    })
  })
})

test_that("air_demo() uses supplied base_id without calling air_demo_setup() (mocked)", {
  setup_called <- FALSE

  fake_people <- tibble::tibble(
    airtable_id = c("rec1", "rec2"),
    airtable_created_time = rep(Sys.time(), 2L),
    Name   = c("Alice Chen", "Bob Okafor"),
    Age    = c(32L, 28L),
    Active = c(TRUE, TRUE),
    Role   = c("Engineer", "Designer"),
    Tags   = list("R", "Python"),
    Joined = rep(Sys.Date(), 2L),
    Email  = c("alice@example.com", "bob@example.com")
  )

  local_mocked_bindings(
    air_demo_setup = function(...) {
      setup_called <<- TRUE
      "appSHOULDNOTBECALLED"
    },
    air_read  = function(base_id, table, .token = NULL, ...) fake_people,
    air_write = function(...) invisible("recNEW"),
    air_upsert = function(...) list(created = "recX", updated = character()),
    air_sync   = function(...) list(created = 0L, updated = 0L,
                                    deleted = 0L, unchanged = 2L),
    air_left_join = function(...) {
      tibble::tibble(Name = "Alice Chen", Score = 98L)
    },
    air_schema = function(base_id, .token = NULL) {
      tibble::tibble(
        table_id = "tblP",
        table_name = "People",
        table_description = NA_character_,
        fields = list(tibble::tibble(
          id = "fldN", name = "Name",
          type = "singleLineText", description = NA_character_
        ))
      )
    },
    air_api_usage = function(...) NULL
  )

  result <- suppressMessages(air_demo(base_id = "appSUPPLIED"))

  expect_false(setup_called)
  expect_named(result, c("read", "write", "upsert", "sync", "join",
                          "schema", "usage"))
  expect_s3_class(result$read, "data.frame")
})

# ── Live tests ----------------------------------------------------------------

test_that("air_demo_setup() creates a real demo base (live)", {
  skip_if_no_schema_tests()

  base_id <- air_demo_setup(
    workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
    name = paste0("airtable2_demo_test_", format(Sys.time(), "%Y%m%d%H%M%S"))
  )

  expect_type(base_id, "character")
  expect_match(base_id, "^app")

  # Verify the base exists and has the expected tables
  schema <- at_get_schema(base_id)
  table_names <- vapply(schema, function(t) t$name, character(1))
  expect_true("People"      %in% table_names)
  expect_true("Projects"    %in% table_names)
  expect_true("Attachments" %in% table_names)

  # Verify People has records
  people <- at_list_records(base_id, "People")
  expect_gt(length(people), 0L)
})
