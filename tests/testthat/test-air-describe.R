# tests/testthat/test-air-meta.R
# Mocked tests for air_describe and air_describe_init (seed).
# NO live API calls.

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

base_id <- "appTEST0000000001"




# ---------------------------------------------------------------------------
# air_describe_init — respects custom table name
# -------------------------------------------------------------------------------

test_that("air_describe works as expected", {

  desc_dataframe <- air_describe(title = "Mock Base",
                                 creator = "Collin Schwantes",
                                 created = "2026-10-20")

  generic_tibble <- tibble::tibble(desc_key = 1,
                                   title = "Mock Base",
                                   creator = "Collin Schwantes",
                                   created = "2026-10-20",
                                   primary_contact=NA_character_,
                                   email = NA_character_,
                                   description = NA_character_,
                                   contributor = NA_character_,
                                   identifier =NA_character_,
                                   license = NA_character_,)

  expect_equal(generic_tibble, desc_dataframe)
})



# ---------------------------------------------------------------------------
# air_describe_init — respects custom table name
# -------------------------------------------------------------------------------

test_that("air_describe_init() respects custom description_table name", {
  upsert_table <- NULL

  desc_dataframe <- air_describe(title = "Mock Base",
                                 creator = "Collin Schwantes",
                                 created = "2026-10-20")

  with_mocked_bindings(
    code = {
      air_describe_init(base_id, desc_table = "Description",desc_dataframe = desc_dataframe, .token = "tok")
    },
    air_upsert      = function(data, table, merge_on, base_id, ...) {
      upsert_table <<- table
      invisible(NULL)
    },
    at_get_schema   = function(...) list(),
    at_create_table = function(...) invisible(NULL),
    .package = "airtable2"
  )

  expect_equal(upsert_table, "Description")
})

