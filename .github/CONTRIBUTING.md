# Contributing to airtable2

## Table of Contents

1. [Scope](#scope)
2. [Setup for development](#setup)
3. [Testing](#testing)
4. [Architecture](#architecture)
5. [Design decisions](#design-decisions)
6. [Credentials and environment variables](#credentials)
7. [API quirks reference](#api-quirks)
8. [Agentic development](#agentic)
9. [Code of Conduct](#code-of-conduct)

---

## Scope {#scope}

airtable2 is developed for internal use. Users and contributors are welcome,
but with limited capacity we will prioritize internal needs. We do not expect
to publish on CRAN or R-Multiverse in the near future.

Package scope is Airtable API interactions and working with Airtable data in
integrated projects with other workflows, especially R-focused ones, with
convenience functions for R and R-focused IDEs. Development has focused on
free/teams-tier API interactions. Contributions for Enterprise-level API
interactions are welcome, but we do not have access to them and a sharing of
resources for testing should be discussed. Nonstandard interactions like
browser automation to work around API limitations are in scope.

Note that airtable2 is developed with heavy contribution of LLMs — it is a
test bed for experimenting with AI-assisted development.

What is explicitly out of scope (some of which are implemented in the {airtabler}
package and forks):

- ODK upload/integration
- `deposits` package integration (backup-to-repository)
- Excel/readxl functionality
- Enterprise-only endpoints (SCIM, org management, change events)
- OAuth flow (users manage their own PATs)
- dbplyr/SQL translation (Airtable is not SQL; `filterByFormula` is the query
  language)

---

## Setup for development {#setup}

```r
# 1. Clone the repo and install development dependencies
devtools::install_dev_deps()

# 2. (Optional) Set credentials for live testing
# Add to your ~/.Renviron:
#   AIRTABLE_API_KEY=patXXXXXX...
#   AIRTABLE_WORKSPACE_ID=wspXXXXXX
#   AIRTABLE_TEST_LIVE=true

# 3. Run mocked tests (no credentials needed)
devtools::test()
```

### Testing modes

There are two testing modes:

- **Mocked (default)**: Uses `local_mocked_bindings()` to intercept API calls.
  No credentials required. This is what runs in CI.
- **Live**: Hits the real Airtable API. Requires `AIRTABLE_TEST_LIVE=true` plus
  `AIRTABLE_API_KEY` and `AIRTABLE_WORKSPACE_ID`.

We recommend setting up a **dedicated free workspace** for testing. Free
accounts are capped at 1000 API calls per month per workspace, which can be
exhausted quickly during development.

### Reducing base accumulation

Some tests create new bases each run. Because base deletion is not available
via API on free/team plans, these accumulate and must be cleaned up manually.
Set `AIRTABLE_TEST_SCHEMA=false` (or simply leave it unset) to skip any tests
that create new bases. Alternatively, delete the entire test workspace and
create a new one (updating `AIRTABLE_WORKSPACE_ID` accordingly).

### PR workflow

Mocked tests run automatically in CI. Live tests require reviewer approval
before merge — a reviewer must explicitly trigger the live test run after other
checks pass.

---

## Testing {#testing}

### Mocked tests

New tests should use `local_mocked_bindings()` to mock the API layer.
`local_mocked_bindings()` is preferred for all new write-operation tests.

```r
# Preferred pattern for mocking API calls
test_that("air_write() batches records correctly", {
  local_mocked_bindings(
    air_perform = function(req, call) list(records = list(list(id = "recXXX")))
  )
  # ... test body ...
})
```

### Live tests

Live tests are gated by two environment variables:

- `AIRTABLE_TEST_LIVE=true` — master switch for any test that hits the API
- `AIRTABLE_TEST_SCHEMA=true` — additionally required for tests that create new
  bases (also requires `AIRTABLE_TEST_LIVE=true`)

Use the skip helpers defined in `tests/testthat/helper.R`:

| Helper | Requires |
|--------|---------|
| `skip_if_not_live()` | `AIRTABLE_TEST_LIVE=true` |
| `skip_if_no_token()` | above + `AIRTABLE_API_KEY` |
| `skip_if_no_workspace()` | above + `AIRTABLE_WORKSPACE_ID` |
| `skip_if_no_schema_tests()` | above + `AIRTABLE_TEST_SCHEMA=true` |

### Shared test bases

Two fixed-name bases are created on first use and reused across test runs:

- `airtable2_test_main_<hash>` — for record CRUD (read/write/upsert/sync).
  Has a permanent "Contacts" table with standard fields.
- `airtable2_test_schema_<hash>` — for table/field creation/modification tests.
  Only used when `AIRTABLE_TEST_SCHEMA=true`.

The `<hash>` suffix is an 8-character hex digest of the workspace ID, so each
workspace gets its own non-colliding set of test bases.

Between tests: clear records with `clear_test_records()`. Between test files:
nothing special needed. Table creation tests accumulate tables/fields in the
schema base — these will grow over time but the base itself persists.

### GOTCHA: `on.exit()` + `local_mocked_bindings()` interaction

If a test uses both `on.exit(add = TRUE)` and `local_mocked_bindings()`, place
the `local_mocked_bindings()` call **after** all `on.exit()` registrations.
`local_mocked_bindings()` registers its own `on.exit()` cleanup, and if it
fires before your cleanup code, the mock teardown can happen while your cleanup
is still trying to call mocked functions.

```r
# Correct ordering
test_that("example", {
  on.exit(cleanup_something(), add = TRUE)  # register cleanup first
  local_mocked_bindings(                    # mock AFTER on.exit
    air_perform = function(...) fake_response
  )
  # ... test body ...
})
```

### GOTCHA: httptest2 fixture paths are non-portable

httptest2 records fixture files using the full URL path. A fixture recorded
against `appABC123/Contacts` cannot be replayed against a different base ID.
For new tests, use `local_mocked_bindings()` instead of recording new httptest2
fixtures for write operations. Existing httptest2 fixtures for read operations
may remain in place.

---

## Architecture {#architecture}

airtable2 uses a three-layer model:

- **`at_*` functions** (low-level): direct Airtable REST API wrappers. Return
  raw parsed JSON (lists/tibbles). Accept explicit `token` (undotted) argument.
  Exported and documented as advanced/low-level.
- **`air_*` functions** (high-level): ergonomic helpers with type coercion,
  schema caching, computed-field exclusion, auto-pagination, and batching.
  Accept `.token` (dotted) argument — dotted signals it is optional and
  project-level.
- **DBI S4 interface**: `AirtableDriver`, `AirtableConnection`, and
  `AirtableResult` classes for standard database workflows, Positron/RStudio
  connection pane integration, and `dbplyr`-compatible usage.

### Single API chokepoint

All HTTP goes through `air_perform()` in `R/client.R`. It handles auth, retry
on 429, rate limiting (5 req/sec via `httr2::req_throttle()`), and the API call
counter. Do not call `httr2::req_perform()` directly in feature code — always
go through `air_perform()`.

### Schema caching

Schemas are cached per `(base_id, table)` in the `.schema_cache` environment
for the session lifetime. Change detection uses
`digest::digest(..., algo = "xxhash64")`. The cache can be invalidated manually
or is cleared after write operations via DBI. Always use `get_base_schema()` /
`get_table_schema()` in high-level code rather than calling `at_get_schema()`
directly.

<details>
<summary>File-by-file layout</summary>

**Core HTTP**

| File | Role |
|------|------|
| `R/client.R` | `air_perform()`, `air_req()`, `air_token()`, `air_paginate()` |
| `R/auth.R` | Token resolution helpers |

**High-level records**

| File | Role |
|------|------|
| `R/air_read.R` | `air_read()` — paginated read with type coercion |
| `R/air_write.R` | `air_write()` — batched create (10 records/call) |
| `R/air_upsert.R` | `air_upsert()` — upsert with auto column creation |
| `R/air_sync.R` | `air_sync()` — hash-based smart sync (diff → upsert + delete) |
| `R/air_delete.R` | `air_delete()` — batched delete |
| `R/air_join.R` | Join helpers for linked record columns |
| `R/air_attachments.R` | `air_read/write/sync_attachments()` — blob or file |
| `R/air_dump.R` | `air_dump()` / `air_restore()` — backup/restore entire base |

**Types**

| File | Role |
|------|------|
| `R/types.R` | S3 vctrs classes for list-columns (`air_multiselect`, `air_links`, etc.); pillar print methods; label attributes |
| `R/type-convert.R` | `air_flatten_*` / `air_expand_*` helpers; `air_simplify()` |

**Schema / metadata**

| File | Role |
|------|------|
| `R/air_schema.R` | `air_schema()`, `get_base_schema()`, `get_table_schema()`; schema cache |
| `R/air_meta.R` | `air_meta()`, `air_meta_push()`, `air_meta_sync()` |
| `R/air_template.R` | `air_table_template()`, `air_field_template()` for programmatic base creation |
| `R/navigate.R` | `air_resolve_id()`, `air_browse()` |

**Low-level API wrappers**

| File | Role |
|------|------|
| `R/at-records.R` | `at_list_records()`, `at_get_record()`, `at_create_records()`, `at_update_records()`, `at_delete_records()` |
| `R/at-bases.R` | `at_list_bases()`, `at_get_schema()`, `at_create_base()` |
| `R/at-tables.R` | `at_create_table()`, `at_update_table()`, `at_create_field()`, `at_update_field()` |
| `R/at-views.R` | `at_list_views()`, `at_get_view()` |
| `R/at-other.R` | `at_whoami()`, `at_upload_attachment()`, `at_sitrep()` |

**DBI**

| File | Role |
|------|------|
| `R/dbi-driver.R` | `AirtableDriver` S4 class; `airtable2()` constructor |
| `R/dbi-connection.R` | `AirtableConnection` S4 class; base mode and workspace mode |
| `R/dbi-result.R` | `AirtableResult` S4 class; eagerly materialised |
| `R/connections.R` | RStudio/Positron connection pane observer |

**State and package init**

| File | Role |
|------|------|
| `R/defaults.R` | `air_set_token()`, `air_set_base()` — session defaults |
| `R/airtable2-package.R` | Package-level docs; `pkg_env`; `.onLoad` hook |
| `R/utils.R` | `%||%`, `compact()`, `check_string()`, `resolve_progress()`, etc. |
| `R/zzz.R` | `.onLoad` hooks: S3 method registration, connection observer |

</details>

---

## Design decisions {#design-decisions}

Key conventions in brief:

- **Naming**: `air_` prefix for high-level user functions; `at_` prefix for raw
  API wrappers (exported, documented as advanced).
- **Token parameter**: `.token` (dotted) for `air_*` — signals optional,
  project-level. `token` (undotted) for `at_*` — these callers are
  API-knowledgeable and may supply tokens explicitly.
- **Argument ordering**: no-default args first, defaulted args second,
  project-level args last. The piped or main object goes first. ID hierarchy:
  record → field → base → workspace.
- **Pipe**: base R `|>` throughout (requires R >= 4.1.0).
- **Error handling**: `cli_abort()`, `cli_warn()`, `cli_inform()` from cli/rlang.
  Never use base `stop()`, `warning()`, or `message()`.
- **cli pluralization**: use `{.val {n} field{?s}}` syntax (or a count variable
  like `{n_fields} field{?s}`). Do not use `{?s}` alone with an unknown-length
  vector — always bind to a count.
- **Mocking**: `local_mocked_bindings()` preferred over httptest2 for all new
  tests, especially write operations.
- **Batch size**: 10 records per API call (Airtable hard limit).
- **Typecast default**: `TRUE` for high-level `air_*` ops; `FALSE` for low-level
  `at_*` ops.

<details>
<summary>Rationale for key decisions</summary>

**Why `air_` vs `at_` prefixes?**

The two layers have different stability contracts. `at_*` functions are thin
wrappers whose signatures track the Airtable REST API closely — callers who use
them accept that the API can change. `air_*` functions present a stable,
ergonomic interface; their internals can change as the API evolves. Having
distinct prefixes makes this contract visible in tab-completion.

**Why `.token` (dotted) for `air_*` functions?**

Dotted arguments are hidden from tab-completion in most R IDEs, which keeps the
primary interface clean. Most users set a token once via `AIRTABLE_API_KEY` or
`options(airtable2.token = ...)` and never think about it again. The dotted
convention signals "this is a secondary concern for most callers." Low-level
`at_*` callers are API-knowledgeable and may legitimately want to pass tokens
explicitly, so `token` (undotted) is more appropriate there.

**Why httr2 instead of httr?**

httr2 provides built-in `req_retry()` and `req_throttle()`, making the retry
and rate-limit logic declarative rather than manual. It also makes requests
composable (each step returns a modified request object) and is more testable.

**Why the DBI layer?**

The DBI interface enables standard R database workflows (`dbReadTable()`,
`dbWriteTable()`) and gives Positron/RStudio connection pane integration for
free. It also makes airtable2 interoperable with any package that knows how to
talk to DBI connections. The DBI layer wraps `air_*` functions — it adds no new
API calls, just adapts the interface.

**Auth resolution order: arg → option → env var**

This is the standard R pattern used by usethis, gh, and similar packages. The
option layer (`getOption("airtable2.token")`) lets users set a session default
programmatically without touching the environment. The env var layer
(`AIRTABLE_API_KEY`) works for `.Renviron`, CI, Docker, and similar contexts.

**Why native pipe `|>` and not magrittr `%>%`?**

Fewer dependencies, faster loading, and R >= 4.1.0 is already required for
other reasons. The native pipe covers all patterns used in this package.

**Why not dbplyr/SQL translation?**

Airtable is not a relational database. Its query language is `filterByFormula`,
a custom formula language. Building a full SQL-to-formula translator would be
fragile and incomplete. Users who need filtering should pass `formula =` to
`air_read()` directly.

**Arg ordering rationale**

Consistent arg ordering reduces cognitive load. No-default args first means the
function can always be called positionally. Project-level args (`.token`,
`.base_id`) last means they disappear from tab-completion near the front of the
signature. ID hierarchy (record → field → base → workspace) follows the
Airtable containment hierarchy.

**Record matching in upsert/sync**

If `airtable_id` is present in `data`, it is used for direct record updates
(most efficient). Records without `airtable_id` fall back to `merge_on` field
matching. Both paths must work, and they can be mixed within a single call.

</details>

---

## Credentials and environment variables {#credentials}

### Reference table

| Variable / Option | Purpose | Default |
|-------------------|---------|---------|
| `AIRTABLE_API_KEY` (env) | Personal access token (PAT) | — |
| `AIRTABLE_BASE_ID` (env) | Default base ID | — |
| `AIRTABLE_WORKSPACE_ID` (env) | Workspace for base creation | — |
| `AIRTABLE_TEST_LIVE` (env) | Enable live tests (`true`/`1`/`yes`) | `false` |
| `AIRTABLE_TEST_SCHEMA` (env) | Enable base-creating live tests | `false` |
| `AIRTABLE2_COUNT_API` (env) | Set `false` to disable on-disk API counter | `true` |
| `AIRTABLE2_PARALLEL` (env) | Enable parallel attachment downloads | `false` |
| `airtable2.token` (option) | Token — overrides `AIRTABLE_API_KEY` | — |
| `airtable2.base_id` (option) | Base ID — overrides `AIRTABLE_BASE_ID` | — |
| `airtable2.count_api` (option) | Enable API call counting | `TRUE` |

### Resolution order

For token: function arg → `getOption("airtable2.token")` →
`Sys.getenv("AIRTABLE_API_KEY")`

For base ID: function arg → `getOption("airtable2.base_id")` →
`Sys.getenv("AIRTABLE_BASE_ID")`

For workspace ID: function arg → `getOption("airtable2.workspace_id")` →
`Sys.getenv("AIRTABLE_WORKSPACE_ID")`

### Finding your workspace ID

The Airtable API provides no endpoint to list or discover workspace IDs for
non-enterprise accounts. Open Airtable in a browser; your workspace URL looks
like `https://airtable.com/wspXXXXXX/...` — the `wspXXXXXX` part is your
workspace ID.

---

## API quirks reference {#api-quirks}

<details>
<summary>Airtable API quirks and gotchas (expand)</summary>

### Workspace ID cannot be discovered via API

The Airtable API provides **no endpoint** for non-enterprise accounts to list
or discover workspace IDs. The `/meta/workspaces` endpoint exists but returns
403 for non-enterprise PATs.

No other endpoint (whoami, list bases, get schema, create base response) returns
workspace information. `GET /meta/whoami` does not return workspace IDs even
with `?include=collaborations`.

**How to find your workspace ID**: Open Airtable in a browser. Your workspace
URL looks like `https://airtable.com/wspXXXXXX/...` — the `wspXXXXXX` part is
your workspace ID. You will need this for `at_create_base()` and related
functions.

---

### `/meta/bases` rejects `pageSize` parameter

The list-bases endpoint returns 422 if you include `pageSize` in the query
string. Despite paginating via `offset`, the page size is fixed server-side
(up to 1000 per page). Do not send `pageSize` to `/meta/bases` — pass
`page_size = NULL` to the internal pagination helper for this endpoint. The
`airtable2` package handles this internally.

---

### `POST /meta/bases` gives unhelpful error when `workspaceId` is missing

If you omit `workspaceId` from a create-base request, the API returns:

```json
{"error": {"type": "INVALID_REQUEST", "message": "Server error"}}
```

This should say "workspaceId is required" but instead gives a generic 422.
When an invalid `workspaceId` is provided, the API correctly returns
`MODEL_ID_NOT_FOUND` (404).

---

### Checkbox fields require `options` on creation

When creating tables or fields with type `"checkbox"`, you **must** include the
`options` object with `icon` and `color` keys. Omitting options produces:

```
INVALID_FIELD_TYPE_OPTIONS_FOR_CREATE: Failed schema validation: <Field>.options is missing
```

Example of valid options:

```r
air_field_template("Done", "checkbox",
  options = list(icon = "check", color = "greenBright"))
```

---

### Unchecked checkboxes return as `null` / absent

When reading records, Airtable **omits** checkbox fields that are unchecked
rather than returning `false`. This means:

- A checked checkbox returns `true`
- An unchecked checkbox is **absent from the response** (not `false`)

The `airtable2` package handles this automatically: `air_read()` uses the table
schema to identify checkbox columns and fills missing values with `FALSE`, so
you always get a proper logical column with no `NA` values for checkboxes.

---

### Formula field options key is `formula`, not `expression`

When creating a formula field via the API, the correct options key is `formula`:

```r
at_create_field(base_id, table_id, "MyFormula", "formula",
  options = list(formula = "UPPER({Name})"))
```

Using `expression` instead of `formula` will give a schema validation error.
The error message helpfully says `expression is not included in the schema`.

---

### Some field types cannot be created via API

The following field types cannot be created via the Meta API and return
`UNSUPPORTED_FIELD_TYPE_FOR_CREATE`:

- `lastModifiedTime`
- `lastModifiedBy`
- `createdTime`
- `createdBy`
- `autoNumber`

These must be created via the Airtable web UI or are generated automatically
when a base is created. For testing computed field handling, use `formula` type
which can be created via API.

---

### Computed fields are read-only

Fields whose values are computed by Airtable (formula, rollup, lookup, count,
autoNumber, createdTime, lastModifiedTime, createdBy, lastModifiedBy) cannot be
written to via the API. Attempting to include them in a create/update request
will produce an error.

The `airtable2` package handles this automatically: `air_write()`,
`air_upsert()`, and `air_sync()` detect computed fields from the table schema
and silently exclude them from write payloads (with an informative message).

---

### `GET /meta/whoami` does not return scopes or collaborations

Despite what some documentation suggests, the whoami endpoint only returns `id`
and `email`. Token scopes, workspace memberships, and collaborations are not
included in the response for PATs. This is true even for PATs with all scopes
enabled. `at_sitrep()$scopes` is legitimately `NULL`.

---

### Base deletion not available on free tier

`DELETE /v0/meta/bases/{baseId}` returns 403 for free-tier accounts. There is
no programmatic way to delete bases without an enterprise plan. Bases must be
deleted manually through the Airtable web interface.

**Impact on testing**: Test bases cannot be automatically deleted. Tests share
a fixed-name base per workspace and clean up by deleting records, not bases.
Some schema-mutation tests create new bases each run — use
`AIRTABLE_TEST_SCHEMA=false` to skip those and avoid accumulation.

---

### `richText` fields return with a trailing newline

Airtable appends a `\n` to the value of every `richText` field in read
responses, even when the value was written without one. This means a round-trip
write → read → sync produces a false-positive change if the trailing newline is
not stripped before comparison.

`air_sync()` normalizes `richText` values by right-trimming whitespace before
hashing, so round-trips do not trigger spurious updates.

---

### Empty and blank character values are absent from responses

Airtable **omits** any field whose value is an empty string, `null`, or `false`
(for checkboxes). This means:

- Writing `""` or `NA` to a text field → Airtable stores nothing → read back
  produces `NA`.
- Writing `FALSE` to a checkbox → Airtable stores nothing → read back produces
  `FALSE` only because `air_read()` fills checkbox columns from the schema.

`air_sync()` normalizes empty strings (`""`) to `NA` before hashing, so
user data with `""` matches Airtable's `NA` response.

---

### `dateTime` fields require `timeFormat` and `timeZone` options on creation

Unlike `date` fields (which only need `dateFormat`), creating a `dateTime`
field via the API requires three option keys:

```r
at_create_field(
  "LastSeen", base_id = base_id, table_id = table_id,
  type = "dateTime",
  options = list(
    dateFormat = list(name = "iso"),
    timeFormat = list(name = "24hour"),
    timeZone   = "utc"
  )
)
```

Omitting `timeFormat` or `timeZone` produces a schema validation error.

---

### `multipleAttachments` use a separate upload endpoint

Attachments cannot be embedded in record create or update payloads. They must
be uploaded via the dedicated attachment upload endpoint
(`at_upload_attachment()`), which returns a URL that can then be referenced in
a record write. The `air_write_attachments()` and `air_sync_attachments()`
functions handle this flow automatically.

---

### Test gotcha: `on.exit()` + `local_mocked_bindings()` interaction

`local_mocked_bindings()` registers its own cleanup via `on.exit()`. If you
also register cleanup in the test, put the `local_mocked_bindings()` call
**after** all `on.exit(add = TRUE)` registrations. If the mock teardown fires
first, any cleanup code that calls a mocked function will operate on the
un-mocked version, which can produce unexpected behavior or API calls.

---

### Test gotcha: httptest2 fixture paths are non-portable

httptest2 records fixture files using the full URL path, which includes the
base ID. A fixture recorded against one base ID cannot be replayed against a
different base ID. For new tests, use `local_mocked_bindings()` instead of
recording httptest2 fixtures, especially for write operations. Existing fixtures
for read operations may remain in place.

</details>

---

## Agentic development {#agentic}

This package uses a convention for cross-agent and cross-session memory:

- **Primary fixed instructions**: `AGENTS.md` (committed) — loaded by most
  agentic coding assistants automatically.
- **Local memory** (gitignored): `.agents/` directory containing:
  - `todo.md` — deferred work and in-progress features
  - `decisions.md` — design decisions with rationale
  - `architecture.md` — full architecture reference
- **Prefer generic `AGENTS.md` + gitignored `.agents/`** over
  provider-specific memory files (e.g., `.cursorrules`, `.github/copilot`).
  This enables handoff between different agents and sessions.
- **Primary user/LLM doc source**: pkgdown site and
  `https://noamross.github.io/airtable2/llms.txt`
- **Do NOT run `devtools::document()`** in sub-agent tasks or touch `man/` or
  `NAMESPACE` — only a dedicated alignment pass does that.
- Stable, widely useful items should be graduated from `.agents/` into committed
  docs (this file, README, pkgdown articles).

---

## Code of Conduct {#code-of-conduct}

Please note that the airtable2 project is released with a
[Contributor Code of Conduct](CODE_OF_CONDUCT.md). By contributing to this
project you agree to abide by its terms.
