# Tests for air_demo_setup() and air_demo()
# Theme: BollardsForArt — creative-arts advocacy nonprofit

# ── Shared helpers ─────────────────────────────────────────────────────────────

# Fake schema returned by at_get_schema() in mocked tests.
# The descriptions block calls at_get_schema() to look up field IDs before
# calling at_update_field(); without this mock it would make a real HTTP call.
.fake_schema <- function() {
  make_fields <- function(...) {
    nms <- c(...)
    lapply(seq_along(nms), function(i) {
      list(id = paste0("fld", i), name = nms[[i]], type = "singleLineText")
    })
  }
  list(
    list(id = "tblA", name = "Artists", fields = make_fields(
      "Name", "Age", "Active", "Role", "Disciplines", "Member Since", "Email"
    )),
    list(id = "tblP", name = "Projects", fields = make_fields(
      "Project Name", "Budget", "Status", "Installation Date", "Files"
    )),
    list(id = "tblG", name = "Grants", fields = make_fields(
      "Grant Name", "Amount", "Status", "Deadline", "Funder"
    ))
  )
}

# ── air_demo_setup() errors ───────────────────────────────────────────────────

test_that("air_demo_setup() errors when workspace_id is missing", {
  withr::with_envvar(c(AIRTABLE_WORKSPACE_ID = ""), {
    expect_error(
      air_demo_setup(workspace_id = ""),
      "workspace_id.*required|required.*workspace_id"
    )
  })
})

# ── air_demo_setup() mocked — table structure ─────────────────────────────────

test_that("air_demo_setup() creates Artists, Projects, Grants tables (mocked)", {
  calls_made <- character()
  table_names_seen <- character()

  fake_base <- list(
    id = "appDEMO123",
    name = "bollardsforart_demo",
    tables = list(
      list(id = "tblARTISTS",  name = "Artists"),
      list(id = "tblPROJECTS", name = "Projects"),
      list(id = "tblGRANTS",   name = "Grants")
    )
  )

  local_mocked_bindings(
    at_create_base = function(name, tables, workspace_id = NULL, token = NULL) {
      calls_made <<- c(calls_made, "at_create_base")
      table_names_seen <<- vapply(tables, `[[`, character(1), "name")
      fake_base
    },
    at_create_field = function(name, table_id, type, base_id = NULL,
                               options = NULL, description = NULL,
                               token = NULL) {
      calls_made <<- c(calls_made, paste0("at_create_field:", name))
      list(id = "fldDUMMY", name = name, type = type)
    },
    at_get_schema = function(...) .fake_schema(),
    at_update_field = function(base_id, table_id, field_id,
                               name = NULL, description = NULL,
                               token = NULL) {
      calls_made <<- c(calls_made, "at_update_field")
      list(id = field_id, name = name %||% "field", description = description)
    },
    # Mock .demo_upload_image to avoid real HTTP calls; it still calls
    # at_upload_attachment so we can track that separately if needed.
    .demo_upload_image = function(base_id, table_id, project_ids,
                                  image_url, .token = NULL) {
      calls_made <<- c(calls_made, "at_upload_attachment")
      invisible(NULL)
    },
    air_write = function(data, table, base_id = NULL, ...) {
      calls_made <<- c(calls_made, paste0("air_write:", table))
      invisible(paste0("recDUMMY", seq_len(nrow(data))))
    }
  )

  result <- air_demo_setup(workspace_id = "wspTEST")

  # Returns the base ID
  expect_equal(result, "appDEMO123")

  # Three tables should be configured in the base creation call
  expect_true("at_create_base" %in% calls_made)
  expect_equal(sort(table_names_seen), sort(c("Artists", "Projects", "Grants")))

  # Records written to Artists and Projects and Grants
  expect_true("air_write:Artists"  %in% calls_made)
  expect_true("air_write:Projects" %in% calls_made)
  expect_true("air_write:Grants"   %in% calls_made)
})

test_that("air_demo_setup() adds linked-records fields (mocked)", {
  calls_made <- character()

  fake_base <- list(
    id = "appLINKS",
    name = "bollardsforart_demo",
    tables = list(
      list(id = "tblA",  name = "Artists"),
      list(id = "tblP",  name = "Projects"),
      list(id = "tblG",  name = "Grants")
    )
  )

  local_mocked_bindings(
    at_create_base = function(...) fake_base,
    at_create_field = function(name, table_id, type, base_id = NULL,
                               options = NULL, description = NULL,
                               token = NULL) {
      calls_made <<- c(calls_made, paste0("at_create_field:", name))
      list(id = "fldX", name = name, type = type)
    },
    at_get_schema  = function(...) .fake_schema(),
    at_update_field = function(...) list(id = "fldX"),
    .demo_upload_image = function(...) invisible(NULL),
    air_write = function(data, table, base_id = NULL, ...) {
      invisible(paste0("recDUMMY", seq_len(nrow(data))))
    }
  )

  air_demo_setup(workspace_id = "wspX")

  # Should create linked fields: Artists on Projects, Projects on Grants
  linked_fields <- grep("^at_create_field:", calls_made, value = TRUE)
  linked_names  <- sub("^at_create_field:", "", linked_fields)
  expect_true(
    any(linked_names %in% c("Lead Artist", "Artists Involved",
                            "Funded Projects", "Projects")),
    label = "at least one linked-records field created"
  )
})

test_that("air_demo_setup() includes at least 15 rows per table (mocked)", {
  row_counts <- list()

  fake_base <- list(
    id = "appROWS",
    name = "bollardsforart_demo",
    tables = list(
      list(id = "tblA", name = "Artists"),
      list(id = "tblP", name = "Projects"),
      list(id = "tblG", name = "Grants")
    )
  )

  local_mocked_bindings(
    at_create_base = function(...) fake_base,
    at_create_field = function(...) list(id = "fldX", name = "x", type = "t"),
    at_get_schema  = function(...) .fake_schema(),
    at_update_field = function(...) list(id = "fldX"),
    .demo_upload_image = function(...) invisible(NULL),
    air_write = function(data, table, base_id = NULL, ...) {
      row_counts[[table]] <<- nrow(data)
      invisible(paste0("rec", seq_len(nrow(data))))
    }
  )

  air_demo_setup(workspace_id = "wspX")

  expect_gte(row_counts[["Artists"]],  15L)
  expect_gte(row_counts[["Projects"]], 15L)
  expect_gte(row_counts[["Grants"]],   15L)
})

test_that("air_demo_setup() calls at_upload_attachment for project images (mocked)", {
  upload_calls <- 0L

  fake_base <- list(
    id = "appUPL",
    name = "bollardsforart_demo",
    tables = list(
      list(id = "tblA", name = "Artists"),
      list(id = "tblP", name = "Projects"),
      list(id = "tblG", name = "Grants")
    )
  )

  local_mocked_bindings(
    at_create_base = function(...) fake_base,
    at_create_field = function(...) list(id = "fldX", name = "x", type = "t"),
    at_get_schema  = function(...) .fake_schema(),
    at_update_field = function(...) list(id = "fldX"),
    # Mock .demo_upload_image so it calls at_upload_attachment without HTTP
    .demo_upload_image = function(base_id, table_id, project_ids,
                                  image_url, .token = NULL) {
      if (length(project_ids) > 0L) {
        at_upload_attachment(
          base_id   = base_id,
          table_id  = table_id,
          record_id = project_ids[[1L]],
          field_id  = "Files",
          file      = tempfile(),   # doesn't exist; at_upload_attachment mocked
          token     = .token
        )
      }
      invisible(NULL)
    },
    at_upload_attachment = function(base_id, table_id, record_id,
                                    field_id, file, token = NULL) {
      upload_calls <<- upload_calls + 1L
      list(id = "attX")
    },
    air_write = function(data, table, base_id = NULL, ...) {
      paste0("rec", seq_len(nrow(data)))
    }
  )

  air_demo_setup(workspace_id = "wspX")

  expect_gt(upload_calls, 0L,
            label = "at_upload_attachment called at least once for project images")
})

test_that("air_demo_setup() calls at_update_field for descriptions (mocked)", {
  update_field_calls <- 0L

  fake_base <- list(
    id = "appDESC",
    name = "bollardsforart_demo",
    tables = list(
      list(id = "tblA", name = "Artists"),
      list(id = "tblP", name = "Projects"),
      list(id = "tblG", name = "Grants")
    )
  )

  local_mocked_bindings(
    at_create_base = function(...) fake_base,
    at_create_field = function(...) list(id = "fldX", name = "x", type = "t"),
    at_get_schema  = function(...) .fake_schema(),
    at_update_field = function(base_id, table_id, field_id,
                               name = NULL, description = NULL,
                               token = NULL) {
      update_field_calls <<- update_field_calls + 1L
      list(id = field_id, description = description)
    },
    .demo_upload_image = function(...) invisible(NULL),
    air_write = function(data, table, base_id = NULL, ...) {
      paste0("rec", seq_len(nrow(data)))
    }
  )

  air_demo_setup(workspace_id = "wspX")

  expect_gt(update_field_calls, 0L,
            label = "at_update_field called for at least one field description")
})

test_that("air_demo_setup() passes .token through to API calls (mocked)", {
  captured_token <- NULL

  fake_base <- list(
    id = "appTOKEN",
    name = "bollardsforart_demo",
    tables = list(
      list(id = "tblA", name = "Artists"),
      list(id = "tblP", name = "Projects"),
      list(id = "tblG", name = "Grants")
    )
  )

  local_mocked_bindings(
    at_create_base = function(name, tables, workspace_id = NULL, token = NULL) {
      captured_token <<- token
      fake_base
    },
    at_create_field = function(..., token = NULL) {
      list(id = "fldX", name = "x", type = "t")
    },
    at_get_schema  = function(...) .fake_schema(),
    at_update_field = function(..., token = NULL) list(id = "fldX"),
    .demo_upload_image = function(..., .token = NULL) invisible(NULL),
    air_write = function(data, table, base_id = NULL, ..., .token = NULL) {
      invisible(character())
    }
  )

  air_demo_setup(workspace_id = "wspX", .token = "mytoken")
  expect_equal(captured_token, "mytoken")
})

test_that("air_demo_setup() warns (not errors) when linked field creation fails (mocked)", {
  local_mocked_bindings(
    at_create_base = function(name, tables, workspace_id = NULL, token = NULL) {
      list(
        id = "appWARN",
        name = name,
        tables = list(
          list(id = "tblA", name = "Artists"),
          list(id = "tblP", name = "Projects"),
          list(id = "tblG", name = "Grants")
        )
      )
    },
    at_create_field = function(...) {
      stop("Simulated field creation failure")
    },
    at_get_schema  = function(...) .fake_schema(),
    at_update_field = function(...) list(id = "fldX"),
    .demo_upload_image = function(...) invisible(NULL),
    air_write = function(data, table, base_id = NULL, ...) {
      invisible(character())
    }
  )

  expect_warning(
    result <- air_demo_setup(workspace_id = "wspX"),
    "Simulated field creation failure|field creation"
  )
  expect_equal(result, "appWARN")
})

# ── air_demo_setup() data content checks ─────────────────────────────────────

test_that("air_demo_setup() Artists data has diverse names and imaginative roles", {
  captured_artists <- NULL

  fake_base <- list(
    id = "appCONT",
    name = "bollardsforart_demo",
    tables = list(
      list(id = "tblA", name = "Artists"),
      list(id = "tblP", name = "Projects"),
      list(id = "tblG", name = "Grants")
    )
  )

  local_mocked_bindings(
    at_create_base = function(...) fake_base,
    at_create_field = function(...) list(id = "fldX", name = "x", type = "t"),
    at_get_schema  = function(...) .fake_schema(),
    at_update_field = function(...) list(id = "fldX"),
    .demo_upload_image = function(...) invisible(NULL),
    air_write = function(data, table, base_id = NULL, ...) {
      if (table == "Artists") captured_artists <<- data
      invisible(paste0("rec", seq_len(nrow(data))))
    }
  )

  air_demo_setup(workspace_id = "wspX")

  expect_false(is.null(captured_artists), label = "Artists data captured")
  # Should have a Name column
  expect_true("Name" %in% names(captured_artists))
  # Should have a Role column (or similar)
  has_role <- any(c("Role", "Specialty", "Discipline") %in% names(captured_artists))
  expect_true(has_role, label = "Artists has a role/specialty/discipline column")
  # Roles should be imaginative (not just "Artist")
  if ("Role" %in% names(captured_artists)) {
    roles <- unique(captured_artists$Role)
    expect_gt(length(roles), 2L, label = "multiple distinct roles")
  }
})

test_that("air_demo_setup() Projects data has image URLs for attachments", {
  captured_projects <- NULL

  fake_base <- list(
    id = "appIMG",
    name = "bollardsforart_demo",
    tables = list(
      list(id = "tblA", name = "Artists"),
      list(id = "tblP", name = "Projects"),
      list(id = "tblG", name = "Grants")
    )
  )

  local_mocked_bindings(
    at_create_base = function(...) fake_base,
    at_create_field = function(...) list(id = "fldX", name = "x", type = "t"),
    at_get_schema  = function(...) .fake_schema(),
    at_update_field = function(...) list(id = "fldX"),
    .demo_upload_image = function(...) invisible(NULL),
    air_write = function(data, table, base_id = NULL, ...) {
      if (table == "Projects") captured_projects <<- data
      invisible(paste0("rec", seq_len(nrow(data))))
    }
  )

  air_demo_setup(workspace_id = "wspX")

  expect_false(is.null(captured_projects))
  # Must have a Project Name column (or "Title" etc.)
  has_name_col <- any(c("Project Name", "Title", "Name") %in% names(captured_projects))
  expect_true(has_name_col)
  # Must have Files / Image / Attachment column
  has_att_col <- any(
    c("Files", "Image", "Images", "Attachment", "Attachments") %in%
      names(captured_projects)
  )
  expect_true(has_att_col, label = "Projects has an attachment column")
})

# ── air_demo() mocked walkthrough ────────────────────────────────────────────

test_that("air_demo() calls air_demo_setup() when no base is configured (mocked)", {
  setup_called <- FALSE

  withr::with_envvar(c(AIRTABLE_BASE_ID = ""), {
    withr::with_options(list(airtable2.base_id = NULL), {
      local_mocked_bindings(
        air_demo_setup = function(workspace_id = "", .token = NULL) {
          setup_called <<- TRUE
          "appSETUP"
        },
        air_read = function(table, base_id = NULL, .token = NULL, ...) {
          tibble::tibble(
            airtable_id = "rec1",
            airtable_created_time = Sys.time(),
            Name = "Zara Okonkwo", Role = "Guerilla Muralist",
            Active = TRUE, Email = "zara@example.com"
          )
        },
        air_write  = function(...) invisible("rec2"),
        air_upsert = function(...) list(created = "rec3", updated = character()),
        air_sync   = function(...) list(created = 0L, updated = 0L,
                                        deleted = 0L, unchanged = 1L),
        air_left_join = function(...) tibble::tibble(Name = "Zara Okonkwo",
                                                     Grant = "NEA"),
        air_schema = function(base_id, .token = NULL) {
          tibble::tibble(
            table_id = "tblA",
            table_name = "Artists",
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
      expect_named(result,
                   c("read", "write", "upsert", "sync", "join", "schema", "usage"),
                   ignore.order = TRUE)
    })
  })
})

test_that("air_demo() uses supplied base_id without calling air_demo_setup() (mocked)", {
  setup_called <- FALSE

  fake_artists <- tibble::tibble(
    airtable_id = paste0("rec", 1:3),
    airtable_created_time = rep(Sys.time(), 3L),
    Name       = c("Zara Okonkwo", "Dmitri Volkov", "Sun-Li Park"),
    Role       = c("Guerilla Muralist", "Kinetic Sculptor", "Sound Installation Designer"),
    Active     = c(TRUE, TRUE, FALSE),
    Email      = c("z@example.com", "d@example.com", "s@example.com")
  )

  local_mocked_bindings(
    air_demo_setup = function(...) { setup_called <<- TRUE; "appNOPE" },
    air_read  = function(table, base_id = NULL, .token = NULL, ...) fake_artists,
    air_write = function(...) invisible("recNEW"),
    air_upsert = function(...) list(created = "recX", updated = character()),
    air_sync   = function(...) list(created = 0L, updated = 0L,
                                    deleted = 0L, unchanged = 3L),
    air_left_join = function(...) tibble::tibble(Name = "Zara Okonkwo", Score = 98L),
    air_schema = function(base_id, .token = NULL) {
      tibble::tibble(
        table_id = "tblA",
        table_name = "Artists",
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
  expect_named(result,
               c("read", "write", "upsert", "sync", "join", "schema", "usage"),
               ignore.order = TRUE)
  expect_s3_class(result$read, "data.frame")
})

test_that("air_demo() includes base URL in output (mocked)", {
  fake_data <- tibble::tibble(
    airtable_id = "rec1",
    airtable_created_time = Sys.time(),
    Name = "Zara Okonkwo", Role = "Guerilla Muralist"
  )

  local_mocked_bindings(
    air_read  = function(...) fake_data,
    air_write = function(...) invisible("recNEW"),
    air_upsert = function(...) list(created = character(), updated = character()),
    air_sync   = function(...) list(created = 0L, updated = 0L,
                                    deleted = 0L, unchanged = 1L),
    air_left_join = function(...) tibble::tibble(Name = "Zara Okonkwo"),
    air_schema = function(base_id, .token = NULL) {
      tibble::tibble(
        table_id = "tblA", table_name = "Artists",
        table_description = NA_character_,
        fields = list(tibble::tibble(
          id = "fldN", name = "Name",
          type = "singleLineText", description = NA_character_
        ))
      )
    },
    air_api_usage = function(...) NULL
  )

  msgs <- character()
  withCallingHandlers(
    air_demo(base_id = "appXXXDEMO"),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  # The base URL should appear somewhere in messages
  has_url <- any(grepl("airtable\\.com", msgs, ignore.case = TRUE))
  expect_true(has_url, label = "base URL (airtable.com) appears in demo output")
})

test_that("air_demo() uses Artists table (not People) (mocked)", {
  tables_read <- character()

  fake_data <- tibble::tibble(
    airtable_id = "rec1",
    airtable_created_time = Sys.time(),
    Name = "Zara Okonkwo"
  )

  local_mocked_bindings(
    air_read = function(table, base_id = NULL, .token = NULL, ...) {
      tables_read <<- c(tables_read, table)
      fake_data
    },
    air_write = function(...) invisible("recNEW"),
    air_upsert = function(...) list(created = character(), updated = character()),
    air_sync   = function(...) list(created = 0L, updated = 0L,
                                    deleted = 0L, unchanged = 1L),
    air_left_join = function(...) fake_data,
    air_schema = function(base_id, .token = NULL) {
      tibble::tibble(
        table_id = "tblA", table_name = "Artists",
        table_description = NA_character_,
        fields = list(tibble::tibble(
          id = "fldN", name = "Name",
          type = "singleLineText", description = NA_character_
        ))
      )
    },
    air_api_usage = function(...) NULL
  )

  suppressMessages(air_demo(base_id = "appXXX"))

  expect_true("Artists" %in% tables_read,
              label = "air_demo reads from Artists table")
  expect_false("People" %in% tables_read,
               label = "air_demo does not read from old People table")
})

# ── Live tests ────────────────────────────────────────────────────────────────

test_that("air_demo_setup() creates a real BollardsForArt demo base (live)", {
  skip_if(Sys.getenv("AIRTABLE_TEST_SCHEMA", "false") != "true")
  skip_if(Sys.getenv("AIRTABLE_TEST_LIVE",   "false") != "true")

  base_id <- air_demo_setup(
    workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
    name = paste0(
      "bollardsforart_demo_test_",
      format(Sys.time(), "%Y%m%d%H%M%S")
    )
  )

  expect_type(base_id, "character")
  expect_match(base_id, "^app")

  schema <- at_get_schema(base_id)
  table_names <- vapply(schema, function(t) t$name, character(1))
  expect_true("Artists"  %in% table_names)
  expect_true("Projects" %in% table_names)
  expect_true("Grants"   %in% table_names)

  # Verify Artists has records
  artists <- at_list_records(base_id, "Artists")
  expect_gte(length(artists), 15L)

  # Verify Projects has attachment field
  projects_tbl <- Filter(function(t) t$name == "Projects", schema)[[1]]
  field_types <- vapply(projects_tbl$fields, function(f) f$type, character(1))
  expect_true("multipleAttachments" %in% field_types)
})
