# Run an interactive airtable2 demo walkthrough

Runs through canonical airtable2 operations against a BollardsForArt
demo base, pausing at each step so you can watch changes appear in the
browser. If no `base_id` is provided and none is set as the session
default, calls
[`air_demo_setup()`](https://noamross.github.io/airtable2/reference/air_demo_setup.md)
first.

## Usage

``` r
air_demo(
  base_id = NULL,
  workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
  .token = NULL
)
```

## Arguments

- base_id:

  Base ID to use. If `NULL`, checks the session default
  ([`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md))
  and `AIRTABLE_BASE_ID` env var; calls
  [`air_demo_setup()`](https://noamross.github.io/airtable2/reference/air_demo_setup.md)
  if nothing is found.

- workspace_id:

  Passed to
  [`air_demo_setup()`](https://noamross.github.io/airtable2/reference/air_demo_setup.md)
  if base creation is needed.

- .token:

  API token (see
  [`air_set_token()`](https://noamross.github.io/airtable2/reference/air_set_token.md)).

## Value

Invisibly returns a list of results from each step.

## Details

Open the Airtable base in a browser alongside the console. The
walkthrough pauses with `<Enter>` prompts whenever you need to switch to
a different table, and sleeps two seconds between steps so changes can
appear.

Steps covered:

1.  Read all Artists with a progress bar

2.  Write one new artist; read back showing `airtable_created_time`

3.  Write 120 community supporters in 12 batches – progress bar is
    clearly visible; read back over 2 pages to demonstrate read
    pagination

4.  Bulk-upsert 30 artists with a progress bar

5.  Sync back to the original 15 with a progress bar (watch deletions)

6.  Upsert a new `Engagement Score` column into Artists from R

7.  Upload an image attachment to a Project record

8.  Link artists to projects via `multipleRecordLinks`

9.  Left-join Airtable columns into a local R tibble

10. View the base schema

11. Seed a `_metadata` table with
    [`air_meta_init()`](https://noamross.github.io/airtable2/reference/air_meta_init.md),
    edit table/column names as rows in Airtable, then apply with
    [`air_meta_sync()`](https://noamross.github.io/airtable2/reference/air_meta_sync.md)

12. Connect via the DBI interface:
    [`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html),
    [`DBI::dbListTables()`](https://dbi.r-dbi.org/reference/dbListTables.html),
    [`DBI::dbReadTable()`](https://dbi.r-dbi.org/reference/dbReadTable.html),
    [`DBI::dbWriteTable()`](https://dbi.r-dbi.org/reference/dbWriteTable.html)

13. View API usage

All operations keyed on `Name` are idempotent; re-running will not
accumulate duplicate records.

## Examples

``` r
if (FALSE) { # \dontrun{
# Run with an existing demo base (set via air_set_base() or env var)
air_set_base("appXXXXXXXXXXXXXX")
air_demo()

# Or create a new demo base first (needs AIRTABLE_WORKSPACE_ID)
air_demo(workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"))
} # }
```
