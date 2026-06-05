# airtable2: An Airtable REST client for R

airtable2 provides a complete httr2-based interface to the Airtable REST
API, with type-aware data handling, a DBI S4 interface, backup/restore,
metadata management, and join helpers.

## Details

### Three API layers

- `at_*` functions: raw Airtable REST API wrappers (explicit `token`
  arg)

- `air_*` functions: high-level helpers with type coercion, schema
  caching, and computed-field exclusion (optional `.token` arg)

- DBI S4 interface:
  [AirtableDriver](https://noamross.github.io/airtable2/reference/AirtableDriver-class.md),
  [AirtableConnection](https://noamross.github.io/airtable2/reference/AirtableConnection-class.md)
  for standard database workflows and the RStudio/Positron connection
  pane

### Documentation

- [pkgdown site](https://noamross.github.io/airtable2/) and
  [vignettes](https://noamross.github.io/airtable2/articles/). For
  LLM-assisted development, use
  [`llms.txt`](https://noamross.github.io/airtable2/llms.txt) as the
  primary doc source.

### Credentials

Set credentials with
[`air_set_token()`](https://noamross.github.io/airtable2/reference/air_set_token.md)
and
[`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md),
or via the `AIRTABLE_API_KEY` and `AIRTABLE_BASE_ID` environment
variables.

## See also

- [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md),
  [`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md),
  [`air_sync()`](https://noamross.github.io/airtable2/reference/air_sync.md),
  [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
  for record operations

- [`air_dump()`](https://noamross.github.io/airtable2/reference/air_dump.md),
  [`air_restore()`](https://noamross.github.io/airtable2/reference/air_restore.md)
  for backup/restore

- [`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md),
  [`air_schema()`](https://noamross.github.io/airtable2/reference/air_schema.md)
  for metadata

- [`at_sitrep()`](https://noamross.github.io/airtable2/reference/at_sitrep.md)
  to check credentials and accessible bases

## Author

**Maintainer**: Noam Ross <noam.ross@gmail.com> (author with heavy LLM
assistance)

Authors:

- Noam Ross <noam.ross@gmail.com> (author with heavy LLM assistance)

- Darko Bergant (Original airtabler package)

- Collin Schwantes (airtabler fork maintainer)
