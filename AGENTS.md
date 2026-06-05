# AGENTS.md — airtable2

**airtable2** is an httr2-based Airtable REST API client for R. It
provides a DBI-compliant interface for Positron/RStudio connection-pane
integration and includes robust upsert/sync/dump/restore workflows. No
ODK, Excel, or other integrations.

## Documentation Map

| Source | Purpose |
|----|----|
| pkgdown site + `https://noamross.github.io/airtable2/llms.txt` | Primary doc source for users and agents, may not be in sync, build locally to find under docs/ |
| `.github/CONTRIBUTING.md` | Architecture, design decisions, API quirks reference, test infra |
| `.agents/todo.md` | In-progress work and deferred features (local scratch) |
| `.agents/*.md` | Local cross-session memory (gitignored) |
| `NOTES.md` | user notes, read-only, may be out of sync but store new instructions. (gitignored) |

**Local-memory convention**: prefer generic `AGENTS.md` + gitignored
`.agents/` files (`todo.md`, `decisions.md`, `architecture.md`) over
provider-specific memory. This enables cross-agent and cross-session
handoff. Graduate stable items to committed docs (CONTRIBUTING.md,
pkgdown).

## Testing Strategy (TDD — mandatory)

**Iterative cycle for any new or broken feature hitting the API:**

1.  **Write the failing test first** (or reproduce the failure in a
    targeted live call). Never implement before tests.
2.  **Targeted live run**:
    `AIRTABLE_TEST_LIVE=true AIRTABLE_TEST_SCHEMA=true Rscript -e "devtools::test(filter='<file>', reporter='progress')"`
    — fix until the targeted tests pass.
3.  **Full mocked suite**:
    `Rscript -e "devtools::test(reporter='progress')"` — fix any
    regressions.
4.  **Full live suite**:
    `AIRTABLE_TEST_LIVE=true AIRTABLE_TEST_SCHEMA=true Rscript -e "devtools::test(reporter='progress')"`
    — fix any live regressions.
5.  **Add/update mocked tests** that cover the same scenario offline
    (use `local_mocked_bindings()`). Live tests stay in `test-live-*.R`;
    mocked counterparts go in the corresponding `test-air-*.R` file.
6.  **Iterate** between targeted live ↔︎ full mocked ↔︎ full live as
    needed.
7.  Push and verify CI.

**Live test gates**: `AIRTABLE_TEST_LIVE=true` enables read-only live
calls. `AIRTABLE_TEST_SCHEMA=true` (+ LIVE) enables base/table creation.
Require both for scheme, dump/restore, or other tests generating new
bases. `.Renviron` has real credentials — never expose or create bases
without the schema gate.

## Coding Conventions

**Testing**: testthat v3. Mocked tests run by default using
`local_mocked_bindings()`. Live tests require `AIRTABLE_TEST_LIVE=true`.
Skip on CRAN. Do not add live API calls to `@examples` without
`\dontrun{}`.

**Style**: Tidyverse, `|>` pipe, [cli](https://cli.r-lib.org) for all
messages/errors, [rlang](https://rlang.r-lib.org) for condition
signalling. Use `{n_x}` count variables for cli pluralization — do not
use `{?s}` alone with a vector `{.field {unknown}}`.

**Commits**: atomic per logical unit, prefix `feat:` / `fix:` / `docs:`
/ `test:` / `chore:`.

**Docs**: roxygen2 with markdown. Use `@inheritParams air_read` for
shared params. Do NOT run `devtools::document()` or touch `man/` or
`NAMESPACE` in sub-agent tasks — only a dedicated alignment pass does
that.

## Token / Argument Conventions

- `air_*` functions: `.token = NULL` (dotted — optional, project-level).
- `at_*` functions: `token = NULL` (undotted — required,
  caller-supplied).

**Argument ordering**: no-default args first, defaulted args second,
project-level args last. The piped or main object to operate on goes
first. Hierarchy within IDs: record → field → base → workspace.

## Key Environment Variables

| Variable | Purpose |
|----|----|
| `AIRTABLE_API_KEY` | PAT with all scopes |
| `AIRTABLE_WORKSPACE_ID` | Default workspace for base creation |
| `AIRTABLE_BASE_ID` | Default base (also `getOption("airtable2.base_id")`) |
| `AIRTABLE_TEST_LIVE` | Master switch for live tests (`true`/`TRUE`/`1`) |
| `AIRTABLE_TEST_SCHEMA` | Enable live schema-mutation tests (also needs `AIRTABLE_TEST_LIVE`) |
| `AIRTABLE2_COUNT_API` | Set `false` to disable on-disk API counter |

See CONTRIBUTING.md for architecture, design decisions, API quirks, and
test infrastructure details. See `.agents/todo.md` for deferred features
and in-progress work.
