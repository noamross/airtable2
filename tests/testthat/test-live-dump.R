# Live round-trip test for air_dump / air_restore.
#
# Requires: AIRTABLE_TEST_LIVE=true AND AIRTABLE_TEST_SCHEMA=true
# (schema gate is used because this call creates a new base, which accumulates
# in the workspace since DELETE /meta/bases returns 403 on the free tier).
#
# Restored bases are NOT deleted - they are given unique timestamped names to
# avoid collisions on re-runs: "<TEST_MAIN_BASE_NAME>_restore_<YYYYmmddHHMMSS>".

test_that("air_dump/air_restore round-trip preserves table structure and record values", {
  skip_on_cran()
  # Gated behind both AIRTABLE_TEST_LIVE and AIRTABLE_TEST_SCHEMA because this
  # creates a new base that cannot be deleted (free-tier API limitation).
  skip_if_no_schema_tests()

  base_id <- get_test_base()

  # Seed the source base with known records
  clear_test_records()
  air_write(test_contacts_data(), base_id, "Contacts")

  # ── Dump source ─────────────────────────────────────────────────────────────
  dump1 <- air_dump(base_id, format = "list", attachments = "meta")
  expect_named(dump1, c("schema", "Contacts"), ignore.order = TRUE)

  contacts1 <- dump1$Contacts
  expect_equal(nrow(contacts1), 3L)

  # ── Restore to a new base ───────────────────────────────────────────────────
  restore_name <- paste0(
    TEST_MAIN_BASE_NAME,
    "_restore_",
    format(Sys.time(), "%Y%m%d%H%M%S")
  )
  new_base_id <- air_restore(
    dump1,
    base_name   = restore_name,
    attachments = "meta"
  )
  expect_type(new_base_id, "character")
  expect_match(new_base_id, "^app")

  # ── Dump restored base ──────────────────────────────────────────────────────
  dump2 <- air_dump(new_base_id, format = "list", attachments = "meta")
  contacts2 <- dump2$Contacts

  # ── Assert: table names ─────────────────────────────────────────────────────
  tbl_names1 <- vapply(dump1$schema, function(t) t$name, character(1L))
  tbl_names2 <- vapply(dump2$schema, function(t) t$name, character(1L))
  expect_setequal(tbl_names2, tbl_names1)

  # ── Assert: field names and types (Contacts table) ──────────────────────────
  # All fields should be fully restored. The only exceptions are types that
  # are documented as unrestorable in inst/airtable-api-notes.md
  # (multipleRecordLinks, rollup, lookup, count, and read-only auto-fields).
  # The test base uses only restorable types.
  schema1 <- Filter(function(t) t$name == "Contacts", dump1$schema)[[1]]
  schema2 <- Filter(function(t) t$name == "Contacts", dump2$schema)[[1]]

  fnames1 <- vapply(schema1$fields, function(f) f$name, character(1L))
  fnames2 <- vapply(schema2$fields, function(f) f$name, character(1L))
  expect_setequal(fnames2, fnames1)

  ftypes1 <- stats::setNames(
    vapply(schema1$fields, function(f) f$type, character(1L)),
    fnames1
  )
  ftypes2 <- stats::setNames(
    vapply(schema2$fields, function(f) f$type, character(1L)),
    fnames2
  )
  for (fname in fnames1) {
    if (fname %in% names(ftypes2)) {
      expect_equal(
        ftypes2[[fname]],
        ftypes1[[fname]],
        info = paste("field type mismatch:", fname)
      )
    }
  }

  # ── Assert: record count ────────────────────────────────────────────────────
  expect_equal(nrow(contacts2), nrow(contacts1))

  # ── Assert: scalar field values (sorted by Name for stable comparison) ──────
  # Only compare columns present in both dumps (restored may lack some field types)
  scalar_cols <- intersect(
    c("Name", "Email", "Age", "Active"),
    intersect(names(contacts1), names(contacts2))
  )
  ord1 <- order(contacts1$Name)
  ord2 <- order(contacts2$Name)
  c1 <- contacts1[ord1, scalar_cols, drop = FALSE]
  c2 <- contacts2[ord2, scalar_cols, drop = FALSE]
  expect_equal(c2, c1, ignore_attr = TRUE)

  # ── Assert: Tags (multiselect, order-independent within record) ─────────────
  if ("Tags" %in% names(contacts1) && "Tags" %in% names(contacts2)) {
    tags1 <- lapply(contacts1$Tags[ord1], function(x) sort(as.character(x)))
    tags2 <- lapply(contacts2$Tags[ord2], function(x) sort(as.character(x)))
    expect_equal(tags2, tags1, ignore_attr = TRUE)
  }
})
