# Copilot Instructions — airtable2

This repo uses `AGENTS.md` for fixed agent instructions and
`.github/CONTRIBUTING.md` for architecture, conventions, and the Airtable API
quirks reference.

Prefer generic `AGENTS.md` + gitignored `./.agents/` local memory (`todo.md`,
`decisions.md`, `architecture.md`) over provider-specific memory, enabling
cross-agent and cross-session handoff. Graduate stable items to committed docs.

**Primary doc source** for users and agents: pkgdown site +
`https://noamross.github.io/airtable2/llms.txt`

**Testing**: mocked tests run by default; live tests require
`AIRTABLE_TEST_LIVE=true`. No live API calls in `@examples` without `\dontrun{}`.

**Style**: tidyverse, `|>` pipe, `{cli}` for messages/errors, `{rlang}` for
conditions. Commit prefixes: `feat:` / `fix:` / `docs:` / `test:` / `chore:`.

**Token naming**: `.token` (dotted) for `air_*` functions; `token` (undotted)
for `at_*` functions.

**Arg ordering**: no-default first, defaulted second, project-level last; main /
piped object first; ID hierarchy: record → field → base → workspace.

**DO NOT** run `devtools::document()` or touch `man/` / `NAMESPACE` — only a
dedicated alignment pass does that.

See `.agents/todo.md` for deferred features and in-progress work.
