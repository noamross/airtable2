# airtable2 0.0.0.9000

Initial development release — complete rewrite of `airtabler` using modern R packages.

## New features

* Full httr2-based Airtable REST client replacing legacy `airtabler` (httr-based)
* Type-aware `air_read()` / `air_write()` with S3 list-columns for multiselect, linked
  records, attachments, collaborators, and barcodes
* Diff-based `air_sync()` and `air_upsert()` that exclude computed/read-only fields
  automatically using the table schema
* DBI S4 interface (`AirtableDriver`, `AirtableConnection`) for standard database workflows
  and RStudio/Positron connection pane integration
* Join helpers: `air_left_join()`, `air_inner_join()`, `air_full_join()`
* Parallel attachment downloads/uploads (`air_read_attachments()`, `air_write_attachments()`)
* Base metadata management: `air_meta()`, `air_meta_push()`, `air_meta_sync()`
* Schema inspection: `air_schema()` returns a tidy tibble of tables/fields/types
* Backup/restore: `air_dump()` (JSON/CSV + optional attachments) and `air_restore()`
* Type helpers: `air_flatten_multiselect()`, `air_flatten_links()`,
  `air_flatten_attachments()`, `air_flatten_collaborator()`, `air_expand_multiselect()`,
  `air_expand_collaborator()`, `air_simplify()`
* Field/table template builders: `air_field_template()`, `air_table_template()`
* Project-level defaults: `air_set_token()`, `air_set_base()` with env var fallback
  (`AIRTABLE_API_KEY`, `AIRTABLE_BASE_ID`)
* API call tracking: `air_api_usage()`, respects free-tier ~1000 calls/month limit
* Situation report: `at_sitrep()` for debugging credentials and accessible bases
* Browser navigation: `air_browse()` to open bases, tables, views, and records
* Low-level `at_*` wrappers covering all Airtable REST endpoints (records, tables, bases,
  fields, views)
* Convenience wrappers `air_connect()` / `air_pane()` for DBI connection pane integration
* `air_delete()` high-level record deletion with messaging
