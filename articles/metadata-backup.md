# 

## 

title: “Metadata, Schema, and Backup in airtable2” output:
rmarkdown::html_vignette vignette: \> % % % —

``` r

library(airtable2)
```

## Overview

airtable2 provides two related but distinct capabilities for working
with the structure of your Airtable bases:

1.  **Reading and writing human-readable descriptions** — the metadata
    attached to tables and fields. These are the descriptions you see
    when you hover over a field in the Airtable UI, and they can be
    managed programmatically with
    [`air_schema()`](https://noamross.github.io/airtable2/reference/air_schema.md),
    [`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md),
    [`air_meta_push()`](https://noamross.github.io/airtable2/reference/air_meta_push.md),
    and
    [`air_meta_sync()`](https://noamross.github.io/airtable2/reference/air_meta_sync.md).

2.  **Full structural and data backup/restore** — a complete snapshot of
    a base including its schema and all record data, managed with
    [`air_dump()`](https://noamross.github.io/airtable2/reference/air_dump.md)
    and
    [`air_restore()`](https://noamross.github.io/airtable2/reference/air_restore.md).

Both capabilities serve the principle of *documentation as code*: your
base’s structure and descriptions should live in version-controlled
files alongside the R code that uses them. They also support disaster
recovery (restoring a base after accidental deletion) and base migration
(moving data between workspaces).

See the [Getting
Started](https://noamross.github.io/airtable2/articles/airtable2.md)
vignette for authentication setup and basic read/write operations. For
field types that require special handling (multi-select, attachments,
linked records), see the [Special
Types](https://noamross.github.io/airtable2/articles/data-types.md)
vignette.

------------------------------------------------------------------------

## Schema inspection with `air_schema()`

[`air_schema()`](https://noamross.github.io/airtable2/reference/air_schema.md)
returns a tidy tibble describing every table and field in a base. It is
the fastest way to understand the structure of a base before reading
data or writing code against it.

``` r

schema <- air_schema("appXXXXXX")
schema
```

The result has one row per table, with a `fields` list-column containing
a tibble for each table’s fields:

    # A tibble: 3 x 4
      table_id        table_name   table_description fields
      <chr>           <chr>        <chr>             <list>
    1 tblABCDEFGHIJKL Projects     Project registry  <tibble [8 x 4]>
    2 tblMNOPQRSTUVWX People       Team members      <tibble [5 x 4]>
    3 tblYZABCDEFGHIJ Status Codes Lookup values     <tibble [3 x 4]>

Drill into a single table’s fields:

``` r

schema$fields[[1]]
```

    # A tibble: 8 x 4
      id              name          type                  description
      <chr>           <chr>         <chr>                 <chr>
    1 fldAAAAAAAAAAAAAA Name         singleLineText        Primary project name
    2 fldBBBBBBBBBBBBBB Status       singleSelect          Current project phase
    3 fldCCCCCCCCCCCCCC Owner        multipleRecordLinks   Link to People table
    4 fldDDDDDDDDDDDDDD Budget       currency              Approved budget (USD)
    5 fldEEEEEEEEEEEEEE Start Date   date                  NA
    6 fldFFFFFFFFFFFFFF End Date     date                  NA
    7 fldGGGGGGGGGGGGGG Progress     formula               Computed from milestones
    8 fldHHHHHHHHHHHHHH Record ID    autoNumber            NA

**Common use cases for
[`air_schema()`](https://noamross.github.io/airtable2/reference/air_schema.md):**

- **Auditing field types** before writing — confirm that a `currency`
  field will be read as `numeric`, that `multipleSelects` will arrive as
  a list-column, and so on. The [Special
  Types](https://noamross.github.io/airtable2/articles/data-types.md)
  vignette maps Airtable types to their R representations.
- **Programmatic base introspection** — extract field names for a
  specific table to build dynamic column selections or formulas.
- **Checking for computed fields** before a restore — fields with types
  like `formula`, `rollup`, `autoNumber`, and `lookup` cannot be written
  via the API and will need to be re-created manually.

``` r

# Find computed fields that cannot be restored
fields_df <- schema$fields[[1]]
computed_types <- c(
  "formula", "rollup", "lookup", "count",
  "autoNumber", "createdTime", "lastModifiedTime",
  "createdBy", "lastModifiedBy", "externalSyncSource", "aiText", "button"
)
fields_df[fields_df$type %in% computed_types, c("name", "type")]
```

------------------------------------------------------------------------

## Self-documenting bases with `air_meta()`

Where
[`air_schema()`](https://noamross.github.io/airtable2/reference/air_schema.md)
returns a nested tibble organised by table,
[`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md)
returns a *flat* tibble — one row per field across all tables —
including the human-readable `description` stored in Airtable’s metadata
API.

``` r

meta <- air_meta("appXXXXXX")
meta
```

    # A tibble: 16 x 6
       table_name   table_id        field_name   field_id         field_type          description
       <chr>        <chr>           <chr>        <chr>            <chr>               <chr>
     1 Projects     tblABCDEFGHIJKL Name         fldAAAAAAAAAAAAA singleLineText      Primary project name
     2 Projects     tblABCDEFGHIJKL Status       fldBBBBBBBBBBBBBB singleSelect       Current project phase
     3 Projects     tblABCDEFGHIJKL Owner        fldCCCCCCCCCCCCCC multipleRecordLinks Link to People table
     4 Projects     tblABCDEFGHIJKL Budget       fldDDDDDDDDDDDDDD currency           Approved budget (USD)
     ...

This flat format makes it easy to edit descriptions in bulk — open in a
spreadsheet, modify the `description` or `field_name` columns, and push
the changes back.

### Pushing changes with `air_meta_push()`

[`air_meta_push()`](https://noamross.github.io/airtable2/reference/air_meta_push.md)
accepts the tibble returned by
[`air_meta()`](https://noamross.github.io/airtable2/reference/air_meta.md)
(possibly modified), compares it against the current schema, and applies
only the changed rows via API PATCH requests:

``` r

# Read the current metadata
meta <- air_meta("appXXXXXX")

# Edit descriptions for undocumented fields
meta$description[is.na(meta$description) & meta$field_name == "Start Date"] <-
  "ISO 8601 date when the project officially kicks off"

meta$description[is.na(meta$description) & meta$field_name == "End Date"] <-
  "Planned completion date; may be NA for open-ended projects"

# Push only the changed rows back to Airtable
air_meta_push("appXXXXXX", meta)
#> i Pushed 2 field changes.
```

[`air_meta_push()`](https://noamross.github.io/airtable2/reference/air_meta_push.md)
compares each row by `field_id` — so renaming a field in the
`field_name` column and pushing will rename it in Airtable as well. Type
changes are silently ignored because the Airtable API does not allow
most field type conversions.

### Making a base self-documenting with `air_meta_sync()`

[`air_meta_sync()`](https://noamross.github.io/airtable2/reference/air_meta_sync.md)
takes documentation one step further. The recommended workflow:

1.  Call
    [`air_meta_init()`](https://noamross.github.io/airtable2/reference/air_meta_init.md)
    to create a `_metadata` table in your base, populated with the
    current schema.
2.  Open the base in Airtable and edit the description text directly in
    the `_metadata` table — no R required.
3.  Call
    [`air_meta_sync()`](https://noamross.github.io/airtable2/reference/air_meta_sync.md)
    to read the updated `_metadata` table and push the changes back to
    the field descriptions.

``` r

# Step 1: create the _metadata table (one-time setup)
air_meta_init("appXXXXXX")

# Step 2: edit descriptions in Airtable web UI (no R code needed)

# Step 3: sync changes back to field descriptions
air_meta_sync("appXXXXXX")
```

[`air_meta_sync()`](https://noamross.github.io/airtable2/reference/air_meta_sync.md)
is idempotent — running it again updates existing descriptions and adds
new rows for any fields added since the last sync.

**Alternative: sync from a local file**

If you prefer to manage descriptions in a CSV or data.frame:

``` r

# Sync from a local CSV
air_meta_sync("appXXXXXX", source = "descriptions.csv")

# Or build descriptions in R and sync directly
meta <- air_meta("appXXXXXX")
meta[meta$field_name == "Budget", "description"] <- "Total budget in USD"
air_meta_sync("appXXXXXX", source = meta)
```

------------------------------------------------------------------------

## Full backup with `air_dump()`

[`air_dump()`](https://noamross.github.io/airtable2/reference/air_dump.md)
creates a complete local snapshot of a base: the full schema (as
`schema.json`) plus all record data, one file per table. It is designed
to be a safe starting point for disaster recovery or base migration.

``` r

# Full backup including attachment files
air_dump("appXXXXXX", dir = "backup/my-base/")

# Backup metadata only for attachments (faster; skips downloading files)
air_dump("appXXXXXX", dir = "backup/my-base/", attachments = "meta")

# CSV format (flattens complex columns; good for spreadsheet portability)
air_dump("appXXXXXX", dir = "backup/my-base/", format = "csv")

# In-memory list (no files written; useful for inspection or small bases)
dump_list <- air_dump("appXXXXXX", format = "list")
names(dump_list)
#> [1] "schema"   "Projects" "People"   "Status Codes"
```

### Parameters

| Argument | Default | Notes |
|----|----|----|
| `base_id` | required | Base ID (starts with `app`) |
| `dir` | `NULL` (temp dir for json) | Output directory |
| `format` | `"list"` | `"list"`, `"json"`, or `"csv"` |
| `attachments` | `"file"` | `"file"` downloads; `"meta"` keeps URLs only; `"blob"` embeds in memory |
| `.token` | env var | Override the API token |

### Output structure (JSON format)

    backup/my-base/
    ├── schema.json          # Full table/field schema
    ├── projects.json        # All records from the Projects table
    ├── people.json          # All records from the People table
    ├── status_codes.json    # All records from the Status Codes table
    └── attachments/         # Downloaded attachment files (if attachments = "file")
        └── projects/
            └── recXXXXXXXX/
                └── proposal.pdf

Table names are sanitised for use as filenames: spaces and special
characters are replaced with underscores, and names are lowercased.
`schema.json` preserves the original names.

### What is included

- All records and all writable field values
- The full schema including field types and options (select choices,
  formula strings, currency symbols, etc.)
- Attachment metadata (URLs, filenames, MIME types) always; file
  contents when `attachments = "file"`

### What is NOT included

Computed and read-only fields are **excluded from data files** because
they cannot be written back via the API:

| Field type | Reason excluded from data |
|----|----|
| `formula` | Computed from other fields; formula string is in schema |
| `rollup` | Computed across linked records |
| `lookup` | Looks up values from a linked table |
| `count` | Counts linked records |
| `autoNumber` | Assigned by Airtable; cannot be set on write |
| `createdTime` | Set by Airtable on record creation |
| `lastModifiedTime` | Set by Airtable on last edit |
| `createdBy` | Set by Airtable |
| `lastModifiedBy` | Set by Airtable |
| `externalSyncSource` | Synced from external source |
| `aiText` | AI-generated |
| `button` | UI-only |

The schema captures these field definitions, so you can re-create them
manually in the web UI after a restore.

**Linked-record IDs are preserved** in the dump: `multipleRecordLinks`
columns contain the `recXXX` IDs of the linked records. However, after a
restore, new records receive new IDs, which means these links will be
broken in the restored base. See the [Re-linking after
restore](#re-linking-after-restore-advanced) section for the workaround.

------------------------------------------------------------------------

## Restoring with `air_restore()`

[`air_restore()`](https://noamross.github.io/airtable2/reference/air_restore.md)
recreates a base from the output of
[`air_dump()`](https://noamross.github.io/airtable2/reference/air_dump.md).
It creates a new base, adds all restorable fields to each table, and
inserts the saved records.

``` r

# Restore from a directory dump
new_base_id <- air_restore(
  "backup/my-base/",
  base_name = "My Base (restored 2025-06-04)",
  workspace_id = "wspXXXXXX"
)
#> i Creating base "My Base (restored 2025-06-04)"...
#> i Adding fields...
#> ! Field "Progress" (type formula) cannot be restored via the API - create it manually in the web UI.
#> ! Field "Record ID" (type autoNumber) cannot be restored via the API - create it manually in the web UI.
#> i Inserting records...
#> i Restore complete. New base ID: appYYYYYY.

# Restore from an in-memory list dump
new_base_id <- air_restore(
  dump_list,
  base_name = "My Base (copy)",
  workspace_id = "wspXXXXXX"
)
```

### Parameters

| Argument | Default | Notes |
|----|----|----|
| `dump` | required | List from `air_dump(format = "list")` or path to a dump directory |
| `base_name` | auto-generated | Name for the new base |
| `workspace_id` | env var | Workspace to create the base in |
| `attachments` | `"file"` | `"file"` re-uploads attachment files; `"meta"` skips upload |
| `attachment_dir` | inferred from `dump` | Override path to saved attachment files |
| `.token` | env var | Override the API token |

### What works

- All writable field types: text, numbers, dates, checkboxes, selects,
  URLs, emails, ratings, currencies, durations
- Formula fields: the formula string is translated from field IDs back
  to field names and re-created, though Airtable will mark it as
  `isValid: false` until all referenced fields exist
- Select choices: restored without their original choice IDs (Airtable
  assigns new IDs)
- Record data for all restorable fields

### Restore limitations

**Computed fields cannot be created via the API.** The following types
are silently skipped during field creation, and a warning is emitted for
each:

- `formula`, `rollup`, `lookup`, `count`
- `autoNumber`, `createdTime`, `lastModifiedTime`, `createdBy`,
  `lastModifiedBy`
- `externalSyncSource`, `aiText`, `button`
- `multipleRecordLinks` (see below)

After a restore, open the base in the Airtable UI and manually re-create
these fields using the saved schema as a reference.

**Linked-record fields break on restore.** `multipleRecordLinks` fields
store lists of record IDs (e.g. `["recABC", "recDEF"]`). When records
are inserted into the restored base they receive *new* record IDs. The
old IDs stored in linked fields no longer refer to anything in the new
base. For a workaround, see [Re-linking after
restore](#re-linking-after-restore-advanced).

**Record metadata cannot be preserved.** `airtable_id` (the original
record ID) and `airtable_created_time` are stripped before inserting
records into the new base. Records will have new IDs and new creation
timestamps.

------------------------------------------------------------------------

## Backup/restore workflow example

The following end-to-end example covers a typical backup-and-migrate
scenario. All chunks use `eval = FALSE` as they require live API
credentials.

``` r

library(airtable2)

# Step 1: Dump the source base to a local directory
air_dump(
  "appSOURCEBASE",
  dir     = "backup/",
  format  = "json",
  attachments = "file"   # download all attachment files
)
```

``` r

# Step 2: Inspect the schema to identify computed fields
schema <- jsonlite::read_json("backup/schema.json")

# Or use air_schema() on the live base
schema_tbl <- air_schema("appSOURCEBASE")
computed_types <- c(
  "formula", "rollup", "lookup", "count", "autoNumber",
  "createdTime", "lastModifiedTime", "createdBy", "lastModifiedBy"
)
needs_manual <- lapply(schema_tbl$fields, function(f) {
  f[f$type %in% computed_types, c("name", "type")]
})
names(needs_manual) <- schema_tbl$table_name
needs_manual
```

``` r

# Step 3: Restore to a new base in the same (or different) workspace
new_id <- air_restore(
  "backup/",
  base_name    = "Projects (migrated)",
  workspace_id = "wspTARGETWORKSPACE"
)
```

``` r

# Step 4: Verify record counts match
original <- air_schema("appSOURCEBASE")
restored  <- air_schema(new_id)

# Check table names
setdiff(original$table_name, restored$table_name)  # Should be character(0)
```

``` r

# Step 5 (manual): In the Airtable UI, re-create computed fields
# (formulas, rollups, lookups, autoNumber, etc.) in the new base.
# Use the saved schema.json as a reference.

# Step 6: Re-link records if any tables use multipleRecordLinks
# (see the next section)
```

------------------------------------------------------------------------

## Re-linking after restore (advanced)

When a base is restored, every record receives a new Airtable record ID.
[`air_restore()`](https://noamross.github.io/airtable2/reference/air_restore.md)
handles this automatically: by default (`restore_linked_fields = TRUE`),
after all records are created it runs a two-step pass:

1.  **Field definitions** — `multipleRecordLinks` fields are recreated
    with their `linkedTableId` remapped to the new base’s table IDs.
2.  **Cell values** — the link values from the dump (old record IDs) are
    remapped to the new record IDs using the insertion-order mapping,
    then written back via
    [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md).

``` r

# Full restore — linked-record fields AND cell values restored automatically
new_base_id <- air_restore(
  "backup/",
  workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
  base_name = "Restored Base"
)
# Creating base "Restored Base"...
# Adding fields...
# Inserting records...
# Recreated 2 link fields and 0 dependent fields.
# Re-linked records in 1 table.
# Restore complete. New base ID: appYYYYYYYY.

# Skip the re-linking step (faster; links will be empty)
new_base_id <- air_restore(
  "backup/",
  workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
  restore_linked_fields = FALSE
)
```

**When automatic re-linking might not be sufficient:** the automatic
approach matches records by insertion order, which works when the dump
and restore are done as a unit. If you are merging records from multiple
sources, or if some tables were partially restored, you may need to
re-link manually using a natural key:

``` r

# Manual re-link using a stable natural key (e.g. Name/Email)
# Useful when insertion order doesn't reliably map old IDs to new ones.
projects_new <- air_read("Projects", new_base_id)
artists_new  <- air_read("Artists",  new_base_id)

# Build old-to-new ID map using Name as stable key
# (assumes artists_old was saved from the source base before restore)
id_map <- stats::setNames(artists_new$airtable_id, artists_old$Name)
remap  <- function(ids) lapply(ids, function(v) unname(id_map[v]))

projects_new$`Lead Artist` <- remap(projects_new$`Lead Artist`)
air_upsert(
  projects_new[, c("airtable_id", "Lead Artist")],
  "Projects",
  merge_on = "airtable_id",
  base_id = new_base_id
)
```
