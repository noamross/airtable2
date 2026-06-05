# airtable2

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/noamross/airtable2/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/noamross/airtable2/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/noamross/airtable2/graph/badge.svg)](https://app.codecov.io/gh/noamross/airtable2)
[![R-universe version](https://noamross.r-universe.dev/airtable2/badges/version)](https://noamross.r-universe.dev/airtable2)
<!-- badges: end -->

An [httr2](https://httr2.r-lib.org/)-based Airtable client package.
`airtable2` is a refactor of `airtabler` originally by Darko Bergant and then extended by myself,
Collin Schwantes and Nathan Layman. 

- **Full CRUD** for records, tables, and bases via the Airtable REST API
- **Type-aware** reading and writing: multiselect, linked records, attachments, collaborators, and barcodes as S3 list-columns
- **DBI interface** for use in standard database workflows and the RStudio/Positron connection pane
- **Backup/restore** with `air_dump()` / `air_restore()`
- **Metadata management** with `air_meta()` / `air_schema()`
- **Joins** between local data frames and Airtable tables
- **Attachment** downloads and uploads (parallelized)
- **API call tracking** to stay within free-tier limits

> **For LLM-assisted development**: the primary documentation source is
> `https://noamross.github.io/airtable2/llms.txt`

## Installation

```r
# From R-universe (recommended)
install.packages("airtable2", repos = c("https://noamross.r-universe.dev", "https://cloud.r-project.org"))

# From GitHub
pak::pak("noamross/airtable2")
# or
remotes::install_github("noamross/airtable2")
```

## Quick start

```r
library(airtable2)

# Set credentials (or use AIRTABLE_API_KEY / AIRTABLE_BASE_ID env vars)
air_set_token("your_personal_access_token")
air_set_base("appXXXXXXXXXXXXXX")

# Confirm access
at_sitrep()

# Read a table
df <- air_read("My Table")

# Write new rows
air_write(df, "My Table")

# Upsert (update matching rows, insert new ones)
air_upsert(df, "My Table", merge_on = "Name")

# Sync (diff-based: only send changes, delete removed rows)
air_sync(df, "My Table", key = "Name")
```

## DBI interface

```r
con <- DBI::dbConnect(airtable2(), base_id = "appXXXXXXXXXXXXXX")
DBI::dbListTables(con)
DBI::dbReadTable(con, "My Table")
DBI::dbDisconnect(con)
```

## Special types

Airtable complex field types are returned as S3 list-columns and display compactly in tibbles:

```r
df <- air_read("My Table")
# multiselect fields  -> <air_multiselect>  (e.g. sel[])
# linked records      -> <air_links>         (e.g. lnk[])
# attachments         -> <air_attachments>   (e.g. att[])
# collaborators       -> <air_collaborator>  (e.g. collab)

# Flatten to character for spreadsheet-style use
df$Tags <- air_flatten_multiselect(df$Tags)

# Or flatten all complex columns at once
df_flat <- air_simplify(df)
```

## Backup and restore

```r
# Full backup with attachments
air_dump("appXXXXXXXXXXXXXX", dir = "backup/")

# Restore from backup
air_restore("backup/")
```

## Documentation

- **[Getting started vignette](https://noamross.github.io/airtable2/articles/airtable2.html)**: credentials, API limits, full walkthrough
- **[Special types](https://noamross.github.io/airtable2/articles/special-types.html)**: multiselect, attachments, linked records
- **[Metadata & backup](https://noamross.github.io/airtable2/articles/metadata-backup.html)**: schema, dump/restore
- **[Full reference](https://noamross.github.io/airtable2/)**: pkgdown site
- **[llms.txt](https://noamross.github.io/airtable2/llms.txt)**: LLM-readable index of all docs

