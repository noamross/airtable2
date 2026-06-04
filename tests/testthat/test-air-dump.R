# Tests for air_dump() and air_restore() (R/air_dump.R)
# All mocked - no network access.

fake_schema <- function() {
  list(
    list(
      id = "tblAAA",
      name = "Contacts",
      description = "Contact records",
      fields = list(
        list(id = "fldNAME", name = "Name", type = "singleLineText"),
        list(id = "fldEMAIL", name = "Email", type = "email")
      ),
      views = list()
    ),
    list(
      id = "tblBBB",
      name = "Projects",
      description = NULL,
      fields = list(list(
        id = "fldTITLE",
        name = "Title",
        type = "singleLineText"
      )),
      views = list()
    )
  )
}

fake_contacts <- function() {
  tibble::tibble(
    airtable_id = c("recAAA", "recBBB"),
    airtable_created_time = as.POSIXct(
      c("2024-01-01", "2024-01-02"),
      tz = "UTC"
    ),
    Name = c("Alice", "Bob"),
    Email = c("alice@x.com", "bob@x.com")
  )
}

fake_projects <- function() {
  tibble::tibble(
    airtable_id = "recCCC",
    airtable_created_time = as.POSIXct("2024-01-03", tz = "UTC"),
    Title = "Project Alpha"
  )
}

# ── air_dump (format = "list") ───────────────────────────────────────────────

test_that("air_dump returns a named list with schema + one tibble per table", {
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    air_read = function(base_id, table, ...) {
      if (table == "Contacts") fake_contacts() else fake_projects()
    }
  )

  result <- air_dump("appXXX", format = "list", attachments = "meta")

  expect_type(result, "list")
  expect_named(result, c("schema", "Contacts", "Projects"))
  expect_equal(result$schema, fake_schema())
  expect_s3_class(result$Contacts, "tbl_df")
  expect_equal(nrow(result$Contacts), 2L)
  expect_equal(nrow(result$Projects), 1L)
})

# ── air_dump (format = "json") ───────────────────────────────────────────────

test_that("air_dump writes schema.json and per-table JSON files", {
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    air_read = function(base_id, table, ...) {
      if (table == "Contacts") fake_contacts() else fake_projects()
    }
  )

  dir <- withr::local_tempdir()
  invisible(air_dump(
    "appXXX",
    dir = dir,
    format = "json",
    attachments = "meta"
  ))

  expect_true(file.exists(file.path(dir, "schema.json")))
  expect_true(file.exists(file.path(dir, "contacts.json")))
  expect_true(file.exists(file.path(dir, "projects.json")))
})

# ── air_dump (format = "csv") ────────────────────────────────────────────────

test_that("air_dump writes schema.json and CSV files for each table", {
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    air_read = function(base_id, table, ...) {
      if (table == "Contacts") fake_contacts() else fake_projects()
    }
  )

  dir <- withr::local_tempdir()
  invisible(air_dump("appXXX", dir = dir, format = "csv", attachments = "meta"))

  expect_true(file.exists(file.path(dir, "schema.json")))
  expect_true(file.exists(file.path(dir, "contacts.csv")))
  expect_true(file.exists(file.path(dir, "projects.csv")))

  contacts_csv <- read.csv(
    file.path(dir, "contacts.csv"),
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(contacts_csv), 2L)
  expect_true("Name" %in% names(contacts_csv))
})

test_that("air_dump CSV flattens list-columns", {
  tbl <- tibble::tibble(airtable_id = "rec1", Tags = list(c("R", "Python")))
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) {
      list(list(
        id = "tbl1",
        name = "T",
        fields = list(list(id = "f1", name = "Tags", type = "multipleSelects")),
        views = list()
      ))
    },
    air_read = function(...) tbl
  )

  dir <- withr::local_tempdir()
  invisible(air_dump("appXXX", dir = dir, format = "csv", attachments = "meta"))
  csv <- read.csv(file.path(dir, "t.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(csv), 1L)
  expect_type(csv$Tags, "character")
})

# ── air_dump input validation ────────────────────────────────────────────────

test_that("air_dump validates base_id", {
  expect_error(air_dump(123), "must be a single non-NA string")
})

# ── load_dump ────────────────────────────────────────────────────────────────

test_that("load_dump handles a list dump correctly", {
  d <- list(schema = fake_schema(), Contacts = fake_contacts())
  loaded <- load_dump(d)
  expect_equal(loaded$schema, fake_schema())
  expect_named(loaded$table_data, "Contacts")
})

test_that("load_dump reads a JSON directory dump", {
  dir <- withr::local_tempdir()
  jsonlite::write_json(
    fake_schema(),
    file.path(dir, "schema.json"),
    auto_unbox = TRUE
  )
  jsonlite::write_json(
    fake_contacts(),
    file.path(dir, "contacts.json"),
    auto_unbox = TRUE
  )
  loaded <- load_dump(dir)
  expect_equal(length(loaded$schema), 2L)
  expect_named(loaded$table_data, "contacts")
})

test_that("load_dump reads a CSV directory dump", {
  dir <- withr::local_tempdir()
  jsonlite::write_json(
    fake_schema(),
    file.path(dir, "schema.json"),
    auto_unbox = TRUE
  )
  write.csv(
    fake_contacts(),
    file.path(dir, "contacts.csv"),
    row.names = FALSE,
    na = ""
  )
  loaded <- load_dump(dir)
  expect_named(loaded$table_data, "contacts")
  expect_true(is.data.frame(loaded$table_data$contacts))
})

test_that("load_dump errors on invalid input", {
  expect_error(load_dump(42), class = "rlang_error")
})

# ── air_restore ──────────────────────────────────────────────────────────────

test_that("air_restore creates a base and inserts records from a list dump", {
  created_records <- list()
  local_mocked_bindings(
    at_create_base = function(name, workspace_id, tables, token = NULL) {
      list(id = "appNEWBASE", name = name, tables = tables)
    },
    at_get_schema = function(base_id, token = NULL) {
      list(list(
        id = "tblRESTORED",
        name = "Contacts",
        fields = list(
          list(id = "fldN", name = "Name", type = "singleLineText"),
          list(id = "fldE", name = "Email", type = "email")
        ),
        views = list()
      ))
    },
    at_create_field = function(...) list(id = "fldNEW"),
    air_write = function(data, base_id = NULL, table, ...) {
      created_records[[length(created_records) + 1L]] <<- list(
        base_id = base_id,
        table = table,
        nrow = nrow(data)
      )
      invisible(paste0("rec", seq_len(nrow(data))))
    },
    count_api_call = function(...) invisible(NULL)
  )

  dump <- list(schema = fake_schema(), Contacts = fake_contacts())
  new_id <- air_restore(
    dump,
    base_name = "Test Restore",
    workspace_id = "wspWSP"
  )

  expect_equal(new_id, "appNEWBASE")
  # Records were written (metadata cols stripped)
  expect_true(length(created_records) > 0L)
  # airtable_id and airtable_created_time should be stripped
  first_write_nrow <- created_records[[1]]$nrow
  expect_equal(first_write_nrow, 2L) # 2 contact rows
})

test_that("air_restore uses a generated base_name when not supplied", {
  called_name <- NULL
  local_mocked_bindings(
    at_create_base = function(name, workspace_id, tables, token = NULL) {
      called_name <<- name
      list(id = "appGEN", name = name, tables = tables)
    },
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    at_create_field = function(...) list(id = "f"),
    air_write = function(...) invisible(character())
  )
  dump <- list(schema = fake_schema()[1], Contacts = fake_contacts())
  air_restore(dump, workspace_id = "wspWSP")
  expect_match(called_name, "^Restored_")
})

# ── sanitize_field_for_create ─────────────────────────────────────────────────

test_that("sanitize_field_for_create strips id from select choices", {
  f <- list(
    id = "fldT",
    name = "Tags",
    type = "multipleSelects",
    options = list(
      choices = list(
        list(id = "sel1", name = "R", color = "blueLight2"),
        list(id = "sel2", name = "Python", color = "greenLight2")
      )
    )
  )
  result <- sanitize_field_for_create(f, list(f))
  expect_null(result$options$choices[[1]][["id"]])
  expect_equal(result$options$choices[[1]]$name, "R")
  expect_equal(result$options$choices[[1]]$color, "blueLight2")
})

test_that("sanitize_field_for_create converts formula field-ID refs to names", {
  name_field <- list(id = "fldNAME", name = "Name", type = "singleLineText")
  formula_field <- list(
    id = "fldFORM",
    name = "Upper",
    type = "formula",
    options = list(
      formula = "UPPER({fldNAME})",
      isValid = TRUE,
      referencedFieldIds = list("fldNAME"),
      result = list(type = "singleLineText")
    )
  )
  result <- sanitize_field_for_create(
    formula_field,
    list(name_field, formula_field)
  )
  expect_equal(result$options$formula, "UPPER({Name})")
  expect_null(result$options$isValid)
  expect_null(result$options$referencedFieldIds)
  expect_null(result$options$result)
})

test_that("sanitize_field_for_create returns NULL for unrestorable types", {
  for (tp in c(
    "multipleRecordLinks",
    "rollup",
    "lookup",
    "count",
    "lastModifiedTime",
    "autoNumber",
    "aiText"
  )) {
    f <- list(id = "fldX", name = "X", type = tp)
    expect_null(
      sanitize_field_for_create(f, list(f)),
      info = paste("expected NULL for type:", tp)
    )
  }
})

# ── restore_fields ────────────────────────────────────────────────────────────

test_that("restore_fields creates fields[-1] and skips the first", {
  created_fields <- character(0)
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) {
      list(list(
        id = "tblNEW",
        name = "Contacts",
        fields = list(list(
          id = "fldN",
          name = "Name",
          type = "singleLineText"
        )),
        views = list()
      ))
    },
    at_create_field = function(base_id, table_id, name, type, ...) {
      created_fields <<- c(created_fields, name)
      list(id = paste0("fld", name))
    }
  )

  schema <- list(list(
    id = "tblAAA",
    name = "Contacts",
    fields = list(
      list(id = "fldN", name = "Name", type = "singleLineText"),
      list(id = "fldE", name = "Email", type = "email"),
      list(id = "fldA", name = "Age", type = "number")
    ),
    views = list()
  ))
  restore_fields(schema, "appNEW", NULL)
  expect_equal(created_fields, c("Email", "Age"))
})

test_that("restore_fields warns and continues when a field creation fails", {
  created_fields <- character(0)
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) {
      list(list(
        id = "tblNEW",
        name = "Contacts",
        fields = list(list(
          id = "fldN",
          name = "Name",
          type = "singleLineText"
        )),
        views = list()
      ))
    },
    at_create_field = function(base_id, table_id, name, ...) {
      if (name == "Email") {
        rlang::abort("API error")
      }
      created_fields <<- c(created_fields, name)
      list(id = paste0("fld", name))
    }
  )

  schema <- list(list(
    id = "tblAAA",
    name = "Contacts",
    fields = list(
      list(id = "fldN", name = "Name", type = "singleLineText"),
      list(id = "fldE", name = "Email", type = "email"),
      list(id = "fldA", name = "Age", type = "number")
    ),
    views = list()
  ))
  expect_warning(
    restore_fields(schema, "appNEW", NULL),
    "Could not create field"
  )
  expect_equal(created_fields, "Age")
})

test_that("restore_fields warns (not errors) for unrestorable field types", {
  created_fields <- character(0)
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) {
      list(list(
        id = "tblNEW",
        name = "Items",
        fields = list(list(
          id = "fldN",
          name = "Name",
          type = "singleLineText"
        )),
        views = list()
      ))
    },
    at_create_field = function(base_id, table_id, name, ...) {
      created_fields <<- c(created_fields, name)
      list(id = paste0("fld", name))
    }
  )

  schema <- list(list(
    id = "tblAAA",
    name = "Items",
    fields = list(
      list(id = "fldN", name = "Name", type = "singleLineText"),
      list(
        id = "fldRL",
        name = "Related",
        type = "multipleRecordLinks",
        options = list(linkedTableId = "tblOTHER")
      ),
      list(id = "fldTXT", name = "Notes", type = "multilineText")
    ),
    views = list()
  ))
  expect_warning(
    restore_fields(schema, "appNEW", NULL),
    "cannot be restored via the API"
  )
  # Notes still created despite the unrestorable field being skipped
  expect_equal(created_fields, "Notes")
})

# ── round-trip: metadata stripping ───────────────────────────────────────────

test_that("air_restore strips airtable_id and airtable_created_time before writing", {
  written_cols <- NULL
  local_mocked_bindings(
    at_create_base = function(name, workspace_id, tables, token = NULL) {
      list(id = "appREST", name = name, tables = tables)
    },
    at_get_schema = function(base_id, token = NULL) {
      list(list(
        id = "tblC",
        name = "Contacts",
        fields = list(
          list(id = "fldN", name = "Name", type = "singleLineText"),
          list(id = "fldE", name = "Email", type = "email")
        ),
        views = list()
      ))
    },
    at_create_field = function(...) list(id = "fldX"),
    air_write = function(data, base_id = NULL, table, ...) {
      written_cols <<- names(data)
      invisible(character())
    }
  )

  dump <- list(schema = fake_schema(), Contacts = fake_contacts())
  air_restore(dump, base_name = "Test", workspace_id = "wspWSP")

  expect_false("airtable_id" %in% written_cols)
  expect_false("airtable_created_time" %in% written_cols)
  expect_true("Name" %in% written_cols)
  expect_true("Email" %in% written_cols)
})

# ── JSON dump → load_dump round-trip ─────────────────────────────────────────

test_that("JSON dump preserves record values through load_dump", {
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) fake_schema(),
    air_read = function(base_id, table, ...) {
      if (table == "Contacts") fake_contacts() else fake_projects()
    }
  )

  dir <- withr::local_tempdir()
  air_dump("appXXX", dir = dir, format = "json", attachments = "meta")

  loaded <- load_dump(dir)
  contacts <- loaded$table_data$contacts

  expect_equal(nrow(contacts), 2L)
  expect_equal(contacts$Name, c("Alice", "Bob"))
  expect_equal(contacts$Email, c("alice@x.com", "bob@x.com"))
})
