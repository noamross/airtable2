# airtable2 0.1.2.9000

## Breaking changes

* `air_write()` and other upload functions now clear values from fields when the
   corresponding column contains `NA` or `NULL`. Previously, these values were
   ignored, leaving the existing field value unchanged.

* `air_write()`, `air_upsert()`, and `air_sync()` now error by default when
  `data` contains **complex list-columns** (nested lists or data frames that
  Airtable cannot store directly). Previously these columns were silently
  problematic. Set `complex_fields = "warn"` to drop them or `complex_fields =
  "json"` to serialize them as JSON text.

* `add_fields = "yes"` in `air_write()`, `air_upsert()`, and `air_sync()` now
  **infers field types** from column class instead of always creating
  `singleLineText`. Mapping: `numeric` → `number`, `logical` → `checkbox`,
  `Date` → `date`, complex/JSON columns → `multilineText`, everything else →
  `singleLineText`. This changes which Airtable field type is created when a
  new column is first written.

## New features

* `air_write()` gains a `create_table` argument. When `TRUE`, the table is
  created in the base if it does not already exist; field types are inferred
  from the data using the same rules as `add_fields = "yes"`.

* `air_infer_fields(data)` maps R column types to Airtable field specification
  lists suitable for `at_create_table()` / `at_create_base()`. Factors become
  `singleSelect` fields with choices from `levels()`.

* `air_infer_table(data, name)` wraps `air_infer_fields()` to produce a
  complete table specification in one call.

* `air_left_join_upload()` gains `typecast`, `complex_fields`, and `progress`
  arguments, bringing its API in line with `air_upsert()`.

* When `add_fields = "yes"` creates multiple new fields, a progress bar is
  shown instead of one message per field.

* `air_read()` gains an `na` argument (similar to `readr::read_csv(na = ...)`)
  that converts matching string values (e.g. the literal text `"NA"`) to a
  real `NA` before type coercion (#19). Default `NULL` performs no
  conversion, so existing behavior is unchanged unless opted into.
  Functions that forward `...`/arguments to `air_read()` internally
  (`air_left_join()`/`air_inner_join()`/`air_full_join()`, `dbReadTable()`,
  `dbGetQuery()` on an Airtable DBI connection) support `na` as well.

## Bug fixes

* `air_sync()` no longer reports unchanged rows as changed (#13). Change
  detection now reduces each field to a canonical, type-aware representation
  before hashing, so a local column compares equal to the value Airtable
  actually stores and returns. Previously the hash relied on `format()`
  happening to agree across representations, which produced spurious updates on
  every sync for several field types:
  - **dateTime** — compared the wrong moment (the hash used the absolute UTC
    instant, but Airtable round-trips datetimes by wall-clock).
  - **checkbox** — unchecked boxes read back as `NA` (Airtable omits them) and
    never matched a local `FALSE`.
  - **multipleSelects / linked records** and other list-columns — were padded
    by `format()` so a list never matched the identical list read back.
  - **number** — integer-vs-double and scientific-notation drift
    (e.g. `1e+05` vs `100000`).
  These are covered by live tests exercising every writable field type.

* `air_restore()` now correctly handles tables containing multiselect,
  linked-record, attachment, or other list-type columns. Previously `air_write()`
  would abort with a "complex columns" error because `air_dump()` stores those
  columns as plain lists (without the `air_*` class); they are now re-wrapped
  before writing.

# airtable2 0.0.0.9000

Initial development release — complete rewrite of `airtabler` using modern R packages.

## DBI improvements (Stage 8A)

* Added `dbGetRowsAffected()` for `AirtableResult` — returns `NA_integer_`
  (read-only results satisfy the DBI contract).
* Added `dbFetch()` dispatch for missing `n` so `dbFetch(res)` works without
  specifying `n`.
* Extended DBI test coverage: `dbGetInfo`, `dbWriteTable` modes, `dbExistsTable`
  FALSE case, `dbListFields` error path, `dbi_parse_statement` edge cases,
  multi-base `dbListTables`, `dbSendQuery` formula forwarding.
* Added `tests/testthat/test-dbitest.R` as DBItest conformance placeholder.
* Added DBI vignette `vignettes/dbi.Rmd` (Stage 8C).

## Breaking changes

* Normalized function signatures so the piped/main object comes first and the
  container hierarchy (table → base → workspace) comes last, letting a session
  default base be used positionally:
  * `air_read(table, base_id = NULL, ...)` (was base-first)
  * `air_write(data, table, base_id = NULL, ...)`,
    `air_upsert(data, table, merge_on, base_id = NULL, ...)`,
    `air_sync(data, table, key, base_id = NULL, ...)`
  * `air_delete(record_ids, table, base_id = NULL, ...)` (now resolves the
    session default base)
  * `air_left_join()` / `air_inner_join()` / `air_full_join()` are now
    `(x, table, base_id = NULL, by = NULL, ...)`
  * `at_create_base(name, tables, workspace_id = NULL, ...)`

## Bug fixes

* Attachment uploads now work. `at_upload_attachment()` (and the
  `air_write_attachments()` / `air_sync_attachments()` / `air_demo()` paths that
  call it) previously POSTed to `api.airtable.com` and always got a 404, because
  Airtable serves the `uploadAttachment` endpoint from a separate host. Uploads
  now go to `content.airtable.com`. `air_req()` gained a `host` argument to
  select the host.
* API errors are now informative: `air_perform()` surfaces Airtable's error
  `type` and `message` plus actionable hints (e.g. a wrong table name / missing
  permission, an unknown field name, or an invalid `filterByFormula`). This also
  fixes a dead error handler — the old code caught the non-existent
  `httr2_http_error` condition class, so Airtable's explanation was silently
  dropped and users only saw the bare HTTP status.
* `air_api_usage()` now counts parallel attachment downloads (which previously
  bypassed the counter via `req_perform_parallel()`), and its print method shows
  the workspace ID as a clickable link.
* Airtable IDs in `air_browse()` messages are now clickable cli hyperlinks.
* `air_browse()` now honors its `base_id`/`table_id` arguments (they previously
  leaked into `utils::browseURL()`), so browsing a table/view by ID works.
* `.onAttach` now warns (once, via `packageStartupMessage()`) when both
  `airtabler` and `airtable2` are loaded and their function names would mask.
* Fixed the pkgdown reference index so the site builds (documented the
  `AirtableDriver` topic; indexed `air_req()`/`air_token()` and the package doc).

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
* The default delimiter for flattening/expanding multiselect, links, and
  attachment fields is now `"; "` (was `", "`), overridable with the
  `airtable2.delimiter` option or `AIRTABLE2_DELIMITER` env var; expansion
  tolerates spaces around the separator so flatten/expand round-trips
* `air_browse()` accepts base/table NAMES (not just IDs), opens the session
  default base when called with no argument, and resolves `app`/`wsp`/`tbl`/`viw`
  prefixes
* `air_attachment_preview_url()` plus documentation of Airtable attachment URL
  behavior (the API `url` expires ~2h; stable viewer links are obtained in the
  web app)
* `air_flatten()` is now an S3 generic dispatching on the `air_multiselect`,
  `air_links`, `air_attachments`, and `air_collaborator` column classes (the
  per-type `air_flatten_*()` functions remain as exported wrappers)
* Write/upsert/sync now auto-expand flat character columns to the structure
  Airtable expects, inferred from the table schema (e.g. a `"; "`-joined string
  into a multiselect or linked-record array, an email into a collaborator
  object) — manual `air_expand_*()` is no longer required
* `air_left_join_upload()` (was `air_upload_join()`) joins a local data frame
  to matched Airtable records and upserts only new or changed field values;
  reads the remote table minimally (key + existing target fields) and skips
  unmatched rows without creating records — the upload complement to
  `air_left_join()`
* `air_meta_sync()` now accepts a local data frame, a CSV/JSON file path, or a
  table name (defaults to `"_metadata"`) and performs a pull-then-patch: it
  fetches the current remote metadata, computes a diff, and pushes only changed
  fields
* `air_meta_init()` seeds a `_metadata` table in a base from a schema data
  frame or an existing schema object, creating the table and populating it in
  one call
* Added `vignette("dbi", package = "airtable2")` — "Using airtable2 with DBI":
  covers connecting via `air_connect()` / `DBI::dbConnect()`, exploring
  connections, reading (full table and formula-filtered queries), writing
  (append and overwrite/sync), multi-base mode, and DBI limitations
