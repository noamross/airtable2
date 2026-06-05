# Changelog

## airtable2 0.0.0.9000

Initial development release — complete rewrite of `airtabler` using
modern R packages.

### DBI improvements (Stage 8A)

- Added
  [`dbGetRowsAffected()`](https://dbi.r-dbi.org/reference/dbGetRowsAffected.html)
  for `AirtableResult` — returns `NA_integer_` (read-only results
  satisfy the DBI contract).
- Added [`dbFetch()`](https://dbi.r-dbi.org/reference/dbFetch.html)
  dispatch for missing `n` so `dbFetch(res)` works without specifying
  `n`.
- Extended DBI test coverage: `dbGetInfo`, `dbWriteTable` modes,
  `dbExistsTable` FALSE case, `dbListFields` error path,
  `dbi_parse_statement` edge cases, multi-base `dbListTables`,
  `dbSendQuery` formula forwarding.
- Added `tests/testthat/test-dbitest.R` as DBItest conformance
  placeholder.
- Added DBI vignette `vignettes/dbi.Rmd` (Stage 8C).

### Breaking changes

- Normalized function signatures so the piped/main object comes first
  and the container hierarchy (table → base → workspace) comes last,
  letting a session default base be used positionally:
  - `air_read(table, base_id = NULL, ...)` (was base-first)
  - `air_write(data, table, base_id = NULL, ...)`,
    `air_upsert(data, table, merge_on, base_id = NULL, ...)`,
    `air_sync(data, table, key, base_id = NULL, ...)`
  - `air_delete(record_ids, table, base_id = NULL, ...)` (now resolves
    the session default base)
  - [`air_left_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md)
    /
    [`air_inner_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md)
    /
    [`air_full_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md)
    are now `(x, table, base_id = NULL, by = NULL, ...)`
  - `at_create_base(name, tables, workspace_id = NULL, ...)`

### Bug fixes

- Attachment uploads now work.
  [`at_upload_attachment()`](https://noamross.github.io/airtable2/reference/at_upload_attachment.md)
  (and the
  [`air_write_attachments()`](https://noamross.github.io/airtable2/reference/air_write_attachments.md)
  /
  [`air_sync_attachments()`](https://noamross.github.io/airtable2/reference/air_sync_attachments.md)
  /
  [`air_demo()`](https://noamross.github.io/airtable2/reference/air_demo.md)
  paths that call it) previously POSTed to `api.airtable.com` and always
  got a 404, because Airtable serves the `uploadAttachment` endpoint
  from a separate host. Uploads now go to `content.airtable.com`.
  [`air_req()`](https://noamross.github.io/airtable2/reference/air_req.md)
  gained a `host` argument to select the host.
- API errors are now informative: `air_perform()` surfaces Airtable’s
  error `type` and `message` plus actionable hints (e.g. a wrong table
  name / missing permission, an unknown field name, or an invalid
  `filterByFormula`). This also fixes a dead error handler — the old
  code caught the non-existent `httr2_http_error` condition class, so
  Airtable’s explanation was silently dropped and users only saw the
  bare HTTP status.
- [`air_api_usage()`](https://noamross.github.io/airtable2/reference/air_api_usage.md)
  now counts parallel attachment downloads (which previously bypassed
  the counter via `req_perform_parallel()`), and its print method shows
  the workspace ID as a clickable link.
- Airtable IDs in
  [`air_browse()`](https://noamross.github.io/airtable2/reference/air_browse.md)
  messages are now clickable cli hyperlinks.
- [`air_browse()`](https://noamross.github.io/airtable2/reference/air_browse.md)
  now honors its `base_id`/`table_id` arguments (they previously leaked
  into [`utils::browseURL()`](https://rdrr.io/r/utils/browseURL.html)),
  so browsing a table/view by ID works.
- `.onAttach` now warns (once, via
  [`packageStartupMessage()`](https://rdrr.io/r/base/message.html)) when
  both `airtabler` and `airtable2` are loaded and their function names
  would mask.
- Fixed the pkgdown reference index so the site builds (documented the
  `AirtableDriver` topic; indexed
  [`air_req()`](https://noamross.github.io/airtable2/reference/air_req.md)/[`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  and the package doc).

### New features

- Full httr2-based Airtable REST client replacing legacy `airtabler`
  (httr-based)
- Type-aware
  [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)
  /
  [`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md)
  with S3 list-columns for multiselect, linked records, attachments,
  collaborators, and barcodes
- Diff-based
  [`air_sync()`](https://noamross.github.io/airtable2/reference/air_sync.md)
  and
  [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
  that exclude computed/read-only fields automatically using the table
  schema
- DBI S4 interface (`AirtableDriver`, `AirtableConnection`) for standard
  database workflows and RStudio/Positron connection pane integration
- Join helpers:
  [`air_left_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md),
  [`air_inner_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md),
  [`air_full_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md)
- Parallel attachment downloads/uploads
  ([`air_read_attachments()`](https://noamross.github.io/airtable2/reference/air_read_attachments.md),
  [`air_write_attachments()`](https://noamross.github.io/airtable2/reference/air_write_attachments.md))
- Base metadata management:
  [`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md),
  [`air_meta_push()`](https://noamross.github.io/airtable2/reference/air_meta_push.md),
  [`air_meta_sync()`](https://noamross.github.io/airtable2/reference/air_meta_sync.md)
- Schema inspection:
  [`air_schema()`](https://noamross.github.io/airtable2/reference/air_schema.md)
  returns a tidy tibble of tables/fields/types
- Backup/restore:
  [`air_dump()`](https://noamross.github.io/airtable2/reference/air_dump.md)
  (JSON/CSV + optional attachments) and
  [`air_restore()`](https://noamross.github.io/airtable2/reference/air_restore.md)
- Type helpers:
  [`air_flatten_multiselect()`](https://noamross.github.io/airtable2/reference/air_flatten_multiselect.md),
  [`air_flatten_links()`](https://noamross.github.io/airtable2/reference/air_flatten_links.md),
  [`air_flatten_attachments()`](https://noamross.github.io/airtable2/reference/air_flatten_attachments.md),
  [`air_flatten_collaborator()`](https://noamross.github.io/airtable2/reference/air_flatten_collaborator.md),
  [`air_expand_multiselect()`](https://noamross.github.io/airtable2/reference/air_expand_multiselect.md),
  [`air_expand_collaborator()`](https://noamross.github.io/airtable2/reference/air_expand_collaborator.md),
  [`air_simplify()`](https://noamross.github.io/airtable2/reference/air_simplify.md)
- Field/table template builders:
  [`air_field_template()`](https://noamross.github.io/airtable2/reference/air_field_template.md),
  [`air_table_template()`](https://noamross.github.io/airtable2/reference/air_table_template.md)
- Project-level defaults:
  [`air_set_token()`](https://noamross.github.io/airtable2/reference/air_set_token.md),
  [`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
  with env var fallback (`AIRTABLE_API_KEY`, `AIRTABLE_BASE_ID`)
- API call tracking:
  [`air_api_usage()`](https://noamross.github.io/airtable2/reference/air_api_usage.md),
  respects free-tier ~1000 calls/month limit
- Situation report:
  [`at_sitrep()`](https://noamross.github.io/airtable2/reference/at_sitrep.md)
  for debugging credentials and accessible bases
- Browser navigation:
  [`air_browse()`](https://noamross.github.io/airtable2/reference/air_browse.md)
  to open bases, tables, views, and records
- Low-level `at_*` wrappers covering all Airtable REST endpoints
  (records, tables, bases, fields, views)
- Convenience wrappers
  [`air_connect()`](https://noamross.github.io/airtable2/reference/air_connect.md)
  /
  [`air_pane()`](https://noamross.github.io/airtable2/reference/air_pane.md)
  for DBI connection pane integration
- [`air_delete()`](https://noamross.github.io/airtable2/reference/air_delete.md)
  high-level record deletion with messaging
- The default delimiter for flattening/expanding multiselect, links, and
  attachment fields is now `"; "` (was `", "`), overridable with the
  `airtable2.delimiter` option or `AIRTABLE2_DELIMITER` env var;
  expansion tolerates spaces around the separator so flatten/expand
  round-trips
- [`air_browse()`](https://noamross.github.io/airtable2/reference/air_browse.md)
  accepts base/table NAMES (not just IDs), opens the session default
  base when called with no argument, and resolves
  `app`/`wsp`/`tbl`/`viw` prefixes
- [`air_attachment_preview_url()`](https://noamross.github.io/airtable2/reference/air_attachment_preview_url.md)
  plus documentation of Airtable attachment URL behavior (the API `url`
  expires ~2h; stable viewer links are obtained in the web app)
- [`air_flatten()`](https://noamross.github.io/airtable2/reference/air_flatten.md)
  is now an S3 generic dispatching on the `air_multiselect`,
  `air_links`, `air_attachments`, and `air_collaborator` column classes
  (the per-type `air_flatten_*()` functions remain as exported wrappers)
- Write/upsert/sync now auto-expand flat character columns to the
  structure Airtable expects, inferred from the table schema (e.g. a
  `"; "`-joined string into a multiselect or linked-record array, an
  email into a collaborator object) — manual `air_expand_*()` is no
  longer required
- [`air_left_join_upload()`](https://noamross.github.io/airtable2/reference/air_left_join_upload.md)
  (was `air_upload_join()`) joins a local data frame to matched Airtable
  records and upserts only new or changed field values; reads the remote
  table minimally (key + existing target fields) and skips unmatched
  rows without creating records — the upload complement to
  [`air_left_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md)
- [`air_meta_sync()`](https://noamross.github.io/airtable2/reference/air_meta_sync.md)
  now accepts a local data frame, a CSV/JSON file path, or a table name
  (defaults to `"_metadata"`) and performs a pull-then-patch: it fetches
  the current remote metadata, computes a diff, and pushes only changed
  fields
- [`air_meta_init()`](https://noamross.github.io/airtable2/reference/air_meta_init.md)
  seeds a `_metadata` table in a base from a schema data frame or an
  existing schema object, creating the table and populating it in one
  call
- Added
  [`vignette("dbi", package = "airtable2")`](https://noamross.github.io/airtable2/articles/dbi.md)
  — “Using airtable2 with DBI”: covers connecting via
  [`air_connect()`](https://noamross.github.io/airtable2/reference/air_connect.md)
  /
  [`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html),
  exploring connections, reading (full table and formula-filtered
  queries), writing (append and overwrite/sync), multi-base mode, and
  DBI limitations
