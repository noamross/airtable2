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
    air_read = function(table, base_id = NULL, ...) {
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
    air_read = function(table, base_id = NULL, ...) {
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
    air_read = function(table, base_id = NULL, ...) {
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
    at_create_base = function(name, tables, workspace_id = NULL, token = NULL) {
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
    air_write = function(data, table, base_id = NULL, ...) {
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
    at_create_base = function(name, tables, workspace_id = NULL, token = NULL) {
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

# ── restore_linked_fields ─────────────────────────────────────────────────────

# An old schema with two tables: "Tasks" has a multipleRecordLinks field
# pointing at "People" (by its OLD table id), plus a rollup that references
# that link field. "People" is the linked-to table.
fake_linked_schema <- function() {
  list(
    list(
      id = "tblTASKS_OLD",
      name = "Tasks",
      description = NULL,
      fields = list(
        list(id = "fldTITLE_OLD", name = "Title", type = "singleLineText"),
        list(
          id = "fldLINK_OLD",
          name = "Assignee",
          type = "multipleRecordLinks",
          options = list(
            linkedTableId = "tblPEOPLE_OLD",
            isReversed = FALSE,
            prefersSingleRecordLink = FALSE,
            inverseLinkFieldId = "fldINV_OLD",
            viewIdForRecordSelection = "viwOLD"
          )
        ),
        list(
          id = "fldROLLUP_OLD",
          name = "Assignee Count",
          type = "rollup",
          options = list(
            recordLinkFieldId = "fldLINK_OLD",
            fieldIdInLinkedTable = "fldPNAME_OLD",
            referencedFieldIds = list("fldPNAME_OLD"),
            isValid = TRUE,
            result = list(type = "number")
          )
        )
      ),
      views = list()
    ),
    list(
      id = "tblPEOPLE_OLD",
      name = "People",
      description = NULL,
      fields = list(
        list(id = "fldPNAME_OLD", name = "Person Name", type = "singleLineText")
      ),
      views = list()
    )
  )
}

# The NEW schema: same table NAMES, different IDs, and (after link creation)
# the new link field "Assignee" with a new field id.
fake_new_schema_no_link <- function() {
  list(
    list(
      id = "tblTASKS_NEW",
      name = "Tasks",
      fields = list(
        list(id = "fldTITLE_NEW", name = "Title", type = "singleLineText")
      ),
      views = list()
    ),
    list(
      id = "tblPEOPLE_NEW",
      name = "People",
      fields = list(
        list(id = "fldPNAME_NEW", name = "Person Name", type = "singleLineText")
      ),
      views = list()
    )
  )
}

fake_new_schema_with_link <- function() {
  list(
    list(
      id = "tblTASKS_NEW",
      name = "Tasks",
      fields = list(
        list(id = "fldTITLE_NEW", name = "Title", type = "singleLineText"),
        list(
          id = "fldLINK_NEW",
          name = "Assignee",
          type = "multipleRecordLinks",
          options = list(linkedTableId = "tblPEOPLE_NEW")
        )
      ),
      views = list()
    ),
    list(
      id = "tblPEOPLE_NEW",
      name = "People",
      fields = list(
        list(id = "fldPNAME_NEW", name = "Person Name", type = "singleLineText")
      ),
      views = list()
    )
  )
}

test_that("build_table_id_map maps old->new table ids by name", {
  m <- build_table_id_map(fake_linked_schema(), fake_new_schema_with_link())
  expect_equal(m[["tblTASKS_OLD"]], "tblTASKS_NEW")
  expect_equal(m[["tblPEOPLE_OLD"]], "tblPEOPLE_NEW")
})

test_that("restore_linked_fields creates a remapped multipleRecordLinks field", {
  link_calls <- list()
  # at_get_schema is called repeatedly: first call has no link (used to map
  # field ids for dependents), subsequent calls include the new link.
  schema_calls <- 0L
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) {
      schema_calls <<- schema_calls + 1L
      if (schema_calls == 1L) {
        fake_new_schema_no_link()
      } else {
        fake_new_schema_with_link()
      }
    },
    at_create_field = function(name, table_id, type, base_id = NULL,
                               description = NULL, options = NULL, token = NULL) {
      link_calls[[length(link_calls) + 1L]] <<- list(
        name = name,
        table_id = table_id,
        type = type,
        options = options
      )
      list(id = paste0("fldCREATED_", name))
    }
  )

  table_id_map <- build_table_id_map(
    fake_linked_schema(),
    fake_new_schema_no_link()
  )
  restore_linked_fields(
    fake_linked_schema(),
    "appNEW",
    table_id_map,
    .token = NULL
  )

  link_call <- Find(
    function(c) c$type == "multipleRecordLinks",
    link_calls
  )
  expect_false(is.null(link_call))
  expect_equal(link_call$name, "Assignee")
  expect_equal(link_call$table_id, "tblTASKS_NEW")
  # linkedTableId remapped to the NEW People table id
  expect_equal(link_call$options$linkedTableId, "tblPEOPLE_NEW")
  # Only linkedTableId is sent; all other options are read-only / auto-set.
  expect_equal(names(link_call$options), "linkedTableId")
})

test_that("restore_linked_fields skips auto-created reverse link (name == linked table)", {
  # Schema with a symmetric pair: Tasks.Assignee -> People, People.Tasks -> Tasks.
  # "Tasks" is the auto-created reverse link (field name == linked table name).
  # Only "Assignee" should be created; "Tasks" should be skipped.
  symmetric_schema <- list(
    list(
      id = "tblTASKS_OLD",
      name = "Tasks",
      fields = list(
        list(id = "fldTITLE_OLD", name = "Title", type = "singleLineText"),
        list(
          id = "fldLINK_OLD",
          name = "Assignee",
          type = "multipleRecordLinks",
          options = list(
            linkedTableId = "tblPEOPLE_OLD",
            isReversed = FALSE,
            prefersSingleRecordLink = FALSE,
            inverseLinkFieldId = "fldINV_OLD"
          )
        )
      ),
      views = list()
    ),
    list(
      id = "tblPEOPLE_OLD",
      name = "People",
      fields = list(
        list(id = "fldPNAME_OLD", name = "Person Name", type = "singleLineText"),
        list(
          id = "fldINV_OLD",
          name = "Tasks",  # matches the linked table name -> auto-created reverse
          type = "multipleRecordLinks",
          options = list(
            linkedTableId = "tblTASKS_OLD",
            isReversed = FALSE,
            prefersSingleRecordLink = FALSE,
            inverseLinkFieldId = "fldLINK_OLD"
          )
        )
      ),
      views = list()
    )
  )

  new_schema_no_link <- list(
    list(
      id = "tblTASKS_NEW", name = "Tasks",
      fields = list(list(id = "fldTITLE_NEW", name = "Title", type = "singleLineText")),
      views = list()
    ),
    list(
      id = "tblPEOPLE_NEW", name = "People",
      fields = list(list(id = "fldPNAME_NEW", name = "Person Name", type = "singleLineText")),
      views = list()
    )
  )

  link_calls <- list()
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) new_schema_no_link,
    at_create_field = function(name, table_id, type, base_id = NULL,
                               description = NULL, options = NULL, token = NULL) {
      link_calls[[length(link_calls) + 1L]] <<- list(name = name, type = type, options = options)
      list(id = paste0("fldCREATED_", name))
    }
  )

  table_id_map <- build_table_id_map(symmetric_schema, new_schema_no_link)
  restore_linked_fields(symmetric_schema, "appNEW", table_id_map, .token = NULL)

  ml_calls <- Filter(function(c) c$type == "multipleRecordLinks", link_calls)
  # Exactly one link field created: "Assignee" (not the reverse "Tasks")
  expect_length(ml_calls, 1L)
  expect_equal(ml_calls[[1]]$name, "Assignee")
  expect_equal(ml_calls[[1]]$options$linkedTableId, "tblPEOPLE_NEW")
})

test_that("restore_linked_fields skips isReversed=TRUE fields (old Airtable API)", {
  # Some older dumps may have isReversed=TRUE; these should still be skipped.
  schema_with_reversed <- list(
    list(
      id = "tblA_OLD", name = "TableA",
      fields = list(
        list(id = "fldFWD", name = "ForwardLink",
             type = "multipleRecordLinks",
             options = list(linkedTableId = "tblB_OLD", isReversed = FALSE)),
        list(id = "fldREV", name = "ReverseLink",
             type = "multipleRecordLinks",
             options = list(linkedTableId = "tblB_OLD", isReversed = TRUE))
      ),
      views = list()
    ),
    list(
      id = "tblB_OLD", name = "TableB",
      fields = list(list(id = "fldBN", name = "Name", type = "singleLineText")),
      views = list()
    )
  )

  new_schema <- list(
    list(
      id = "tblA_NEW", name = "TableA",
      fields = list(list(id = "fldAN", name = "Name", type = "singleLineText")),
      views = list()
    ),
    list(
      id = "tblB_NEW", name = "TableB",
      fields = list(list(id = "fldBN2", name = "Name", type = "singleLineText")),
      views = list()
    )
  )

  link_calls <- list()
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) new_schema,
    at_create_field = function(name, table_id, type, base_id = NULL,
                               description = NULL, options = NULL, token = NULL) {
      link_calls[[length(link_calls) + 1L]] <<- list(name = name, type = type)
      list(id = paste0("fldCREATED_", name))
    }
  )

  table_id_map <- build_table_id_map(schema_with_reversed, new_schema)
  restore_linked_fields(schema_with_reversed, "appNEW", table_id_map, .token = NULL)

  ml_calls <- Filter(function(c) c$type == "multipleRecordLinks", link_calls)
  # Only the forward link created; reverse (isReversed=TRUE) skipped
  expect_length(ml_calls, 1L)
  expect_equal(ml_calls[[1]]$name, "ForwardLink")
})

test_that("restore_linked_fields recreates dependent rollup with remapped recordLinkFieldId", {
  link_calls <- list()
  schema_calls <- 0L
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) {
      schema_calls <<- schema_calls + 1L
      if (schema_calls == 1L) {
        fake_new_schema_no_link()
      } else {
        fake_new_schema_with_link()
      }
    },
    at_create_field = function(name, table_id, type, base_id = NULL,
                               description = NULL, options = NULL, token = NULL) {
      link_calls[[length(link_calls) + 1L]] <<- list(
        name = name,
        type = type,
        options = options
      )
      list(id = paste0("fldCREATED_", name))
    }
  )

  table_id_map <- build_table_id_map(
    fake_linked_schema(),
    fake_new_schema_no_link()
  )
  restore_linked_fields(
    fake_linked_schema(),
    "appNEW",
    table_id_map,
    .token = NULL
  )

  rollup_call <- Find(function(c) c$type == "rollup", link_calls)
  expect_false(is.null(rollup_call))
  expect_equal(rollup_call$name, "Assignee Count")
  # recordLinkFieldId remapped to the NEW link field id (looked up by name)
  expect_equal(rollup_call$options$recordLinkFieldId, "fldLINK_NEW")
})

test_that("restore_linked_fields warns and skips a link to an unmapped table", {
  link_calls <- list()
  local_mocked_bindings(
    at_get_schema = function(base_id, token = NULL) fake_new_schema_no_link(),
    at_create_field = function(name, table_id, type, base_id = NULL,
                               description = NULL, options = NULL, token = NULL) {
      link_calls[[length(link_calls) + 1L]] <<- list(name = name, type = type)
      list(id = "x")
    }
  )

  # Old schema whose link points at a table name that does not exist in the new
  # base (here the map simply won't contain its target).
  bad_schema <- list(
    list(
      id = "tblTASKS_OLD",
      name = "Tasks",
      fields = list(
        list(id = "fldT", name = "Title", type = "singleLineText"),
        list(
          id = "fldL",
          name = "Ghost",
          type = "multipleRecordLinks",
          options = list(linkedTableId = "tblGONE_OLD")
        )
      ),
      views = list()
    )
  )
  # Map only contains the Tasks table -> nothing maps tblGONE_OLD
  table_id_map <- c(tblTASKS_OLD = "tblTASKS_NEW")

  expect_warning(
    restore_linked_fields(bad_schema, "appNEW", table_id_map, .token = NULL),
    "could not be remapped|not found"
  )
  # No multipleRecordLinks field created
  expect_null(Find(function(c) c$type == "multipleRecordLinks", link_calls))
})

# ── restore_linked_fields argument ───────────────────────────────────────────

test_that("air_restore restore_linked_fields = FALSE skips field and record relinking", {
  field_calls <- list()
  upsert_calls <- list()
  local_mocked_bindings(
    at_create_base = function(name, tables, workspace_id = NULL, token = NULL) {
      list(id = "appNEWBASE", name = name, tables = tables)
    },
    at_get_schema = function(base_id, token = NULL) {
      list(list(
        id = "tblC", name = "Contacts",
        fields = list(list(id = "fldN", name = "Name", type = "singleLineText")),
        views = list()
      ))
    },
    at_create_field = function(name, ...) {
      field_calls[[length(field_calls) + 1L]] <<- name
      list(id = "fldNEW")
    },
    air_write = function(...) invisible(c("recNEW1")),
    air_upsert = function(...) {
      upsert_calls[[length(upsert_calls) + 1L]] <<- list(...)
      list(created = character(), updated = character())
    }
  )

  dump <- list(
    schema = list(list(
      id = "tblAAA", name = "Contacts",
      fields = list(
        list(id = "fldN", name = "Name", type = "singleLineText"),
        list(id = "fldL", name = "Ref", type = "multipleRecordLinks",
             options = list(linkedTableId = "tblBBB"))
      ), views = list()
    )),
    Contacts = tibble::tibble(
      airtable_id = "recOLD1", Name = "Alice", Ref = list(list("recOLD2"))
    )
  )

  expect_warning(
    air_restore(dump, workspace_id = "wspWSP", restore_linked_fields = FALSE),
    "cannot be restored"
  )

  # at_create_field never called with link type
  expect_false(any(vapply(field_calls, function(n) identical(n, "Ref"), logical(1))))
  # air_upsert never called
  expect_equal(length(upsert_calls), 0L)
})

# ── restore_linked_records ────────────────────────────────────────────────────

test_that("restore_linked_records remaps old record IDs to new in link columns", {
  upsert_calls <- list()
  local_mocked_bindings(
    air_upsert = function(data, table, merge_on, base_id = NULL, ...) {
      upsert_calls[[length(upsert_calls) + 1L]] <<- list(
        data = data, table = table, merge_on = merge_on
      )
      list(created = character(), updated = character())
    }
  )

  table_data <- list(
    Tasks = tibble::tibble(
      airtable_id = c("recOLD_T1", "recOLD_T2"),
      Title = c("Alpha", "Beta"),
      Assignee = list(list("recOLD_P1"), list("recOLD_P2", "recOLD_P1"))
    )
  )
  id_map <- c(
    recOLD_T1 = "recNEW_T1", recOLD_T2 = "recNEW_T2",
    recOLD_P1 = "recNEW_P1", recOLD_P2 = "recNEW_P2"
  )
  schema <- list(list(
    id = "tblT", name = "Tasks",
    fields = list(
      list(id = "fldT", name = "Title", type = "singleLineText"),
      list(id = "fldA", name = "Assignee", type = "multipleRecordLinks",
           options = list(linkedTableId = "tblP"))
    ), views = list()
  ))

  restore_linked_records(table_data, "appNEW", id_map, schema)

  expect_equal(length(upsert_calls), 1L)
  call <- upsert_calls[[1]]
  expect_equal(call$table, "Tasks")
  expect_equal(call$merge_on, "airtable_id")
  expect_equal(call$data$airtable_id, c("recNEW_T1", "recNEW_T2"))
  expect_equal(call$data$Assignee[[1]], list("recNEW_P1"))
  expect_equal(call$data$Assignee[[2]], list("recNEW_P2", "recNEW_P1"))
})

test_that("restore_linked_records skips tables with no link fields", {
  upsert_calls <- list()
  local_mocked_bindings(
    air_upsert = function(...) {
      upsert_calls[[length(upsert_calls) + 1L]] <<- TRUE
      list(created = character(), updated = character())
    }
  )
  table_data <- list(
    NoLinks = tibble::tibble(airtable_id = "rec1", Name = "A")
  )
  schema <- list(list(
    id = "tbl1", name = "NoLinks",
    fields = list(list(id = "fldN", name = "Name", type = "singleLineText")),
    views = list()
  ))
  restore_linked_records(table_data, "appNEW", c(rec1 = "recNEW1"), schema)
  expect_equal(length(upsert_calls), 0L)
})

test_that("air_restore builds ID map and re-links records (integration)", {
  write_calls <- list()
  upsert_calls <- list()
  schema_calls <- 0L

  local_mocked_bindings(
    at_create_base = function(name, tables, workspace_id = NULL, token = NULL) {
      list(id = "appNEW", name = name, tables = tables)
    },
    at_get_schema = function(base_id, token = NULL) {
      schema_calls <<- schema_calls + 1L
      base_schema <- list(
        list(
          id = "tblTASKS_NEW", name = "Tasks",
          fields = list(list(id = "fldT_NEW", name = "Title", type = "singleLineText")),
          views = list()
        ),
        list(
          id = "tblPEOPLE_NEW", name = "People",
          fields = list(list(id = "fldN_NEW", name = "Name", type = "singleLineText")),
          views = list()
        )
      )
      if (schema_calls >= 3L) {
        # After restore_linked_fields: Tasks has the new link field
        base_schema[[1]]$fields[[2]] <- list(
          id = "fldA_NEW", name = "Assignee", type = "multipleRecordLinks",
          options = list(linkedTableId = "tblPEOPLE_NEW")
        )
      }
      base_schema
    },
    at_create_field = function(...) list(id = "fldCREATED"),
    air_write = function(data, table, base_id = NULL, ...) {
      write_calls[[length(write_calls) + 1L]] <<- list(
        data = data, table = table
      )
      if (table == "Tasks") c("recNEW_T1", "recNEW_T2")
      else if (table == "People") c("recNEW_P1", "recNEW_P2")
      else character(0)
    },
    air_upsert = function(data, table, merge_on, base_id = NULL, ...) {
      upsert_calls[[length(upsert_calls) + 1L]] <<- list(
        data = data, table = table, merge_on = merge_on
      )
      list(created = character(), updated = character())
    }
  )

  dump <- list(
    schema = list(
      list(
        id = "tblTASKS_OLD", name = "Tasks",
        fields = list(
          list(id = "fldT_OLD", name = "Title", type = "singleLineText"),
          list(id = "fldA_OLD", name = "Assignee", type = "multipleRecordLinks",
               options = list(linkedTableId = "tblPEOPLE_OLD"))
        ), views = list()
      ),
      list(
        id = "tblPEOPLE_OLD", name = "People",
        fields = list(list(id = "fldN_OLD", name = "Name", type = "singleLineText")),
        views = list()
      )
    ),
    Tasks = tibble::tibble(
      airtable_id = c("recOLD_T1", "recOLD_T2"),
      Title = c("Alpha", "Beta"),
      Assignee = list(list("recOLD_P1"), list("recOLD_P2"))
    ),
    People = tibble::tibble(
      airtable_id = c("recOLD_P1", "recOLD_P2"),
      Name = c("Alice", "Bob")
    )
  )

  air_restore(dump, workspace_id = "wspWSP", restore_linked_fields = TRUE)

  # Assignee column NOT in the initial Tasks write (link cols excluded)
  tasks_write <- Find(function(c) c$table == "Tasks", write_calls)
  expect_false("Assignee" %in% names(tasks_write$data))

  # air_upsert called for Tasks to restore remapped link values
  tasks_upsert <- Find(function(c) c$table == "Tasks", upsert_calls)
  expect_false(is.null(tasks_upsert))
  expect_equal(tasks_upsert$merge_on, "airtable_id")
  expect_equal(tasks_upsert$data$airtable_id, c("recNEW_T1", "recNEW_T2"))
  expect_equal(tasks_upsert$data$Assignee[[1]], list("recNEW_P1"))
  expect_equal(tasks_upsert$data$Assignee[[2]], list("recNEW_P2"))
})

# ── round-trip: metadata stripping ───────────────────────────────────────────

test_that("air_restore strips airtable_id and airtable_created_time before writing", {
  written_cols <- NULL
  local_mocked_bindings(
    at_create_base = function(name, tables, workspace_id = NULL, token = NULL) {
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
    air_write = function(data, table, base_id = NULL, ...) {
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
    air_read = function(table, base_id = NULL, ...) {
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
