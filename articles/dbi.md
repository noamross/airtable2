# 

## 

title: “Using airtable2 with DBI” output: rmarkdown::html_vignette
vignette: \> % % % —

## Introduction

**airtable2** provides a DBI interface so you can use the familiar
[`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html),
[`DBI::dbReadTable()`](https://dbi.r-dbi.org/reference/dbReadTable.html),
[`DBI::dbWriteTable()`](https://dbi.r-dbi.org/reference/dbWriteTable.html),
and related functions to interact with Airtable bases. This makes it
easy to integrate Airtable into existing R workflows that expect
standard database connections, and enables the RStudio and Positron
connection pane for point-and-click table browsing.

The DBI interface covers the most common database operations, but
Airtable is not an SQL database, though it has many relational database
features. Some functionality is intentionally absent. **Capabilities:**
reading tables, listing tables and fields, appending records, and
overwrite-syncing records. **Limitations:** no SQL queries (use Airtable
formula syntax instead), no table creation or deletion via DBI, no
transactions, and no `dbplyr` lazy `tbl()` support (deferred). For the
full feature set — type coercion, attachments, multi-select, upsert by
key — use the `air_*` functions directly.

## Connecting

The primary way to open a DBI connection to Airtable is
[`air_connect()`](https://noamross.github.io/airtable2/reference/air_connect.md).
You can connect to a single base by name or ID, or open a multi-base
connection that exposes all accessible bases as schemas.

``` r

library(airtable2)
library(DBI)

# Connect to a specific base by name
con <- air_connect(base = "BollardsForArt")

# Connect to a specific base by ID (replace with your own base ID)
con <- air_connect(base = "appXXXXXXXXXXXXXX")  # placeholder — use your base ID

# Using the raw DBI interface directly
con <- DBI::dbConnect(airtable2(), base_id = "appXXXXXXXXXXXXXX")

# Connect to all bases (multi-base mode — all bases appear as schemas)
con_all <- air_connect()

# Open in the RStudio / Positron connection pane
air_pane(base = "appXXXXXXXXXXXXXX")

# Always disconnect when done
DBI::dbDisconnect(con)
```

If you have set a default base via
[`air_set_base()`](https://noamross.github.io/airtable2/reference/air_set_base.md)
or the `AIRTABLE_BASE_ID` environment variable,
[`air_connect()`](https://noamross.github.io/airtable2/reference/air_connect.md)
will use it when called with no arguments.

## Exploring the connection

Once connected, standard DBI introspection functions work as expected:

``` r

# List all tables in the base
DBI::dbListTables(con)
#> [1] "Artists"  "Grants"   "Projects"

# Check whether a table exists
DBI::dbExistsTable(con, "Artists")
#> [1] TRUE

# List the fields (columns) of a table
DBI::dbListFields(con, "Artists")
#> [1] "airtable_id"           "airtable_created_time" "Name"
#> [4] "Age"                   "Active"                "Role"
#> [7] "Disciplines"           "Member Since"          "Email"
```

Note that every table includes the `airtable_id` and
`airtable_created_time` columns, which are Airtable’s internal record
identifier and creation timestamp.

## Reading data

[`DBI::dbReadTable()`](https://dbi.r-dbi.org/reference/dbReadTable.html)
reads an entire table and returns a data frame:

``` r

# Read the entire Artists table
artists <- DBI::dbReadTable(con, "Artists")
artists
#>   airtable_id airtable_created_time          Name Age Active              Role
#> 1 recABCDEFGH 2026-05-01 10:00:00   Zara Okonkwo  33   TRUE Guerilla Muralist
#> ...
```

For filtered queries, use
[`DBI::dbSendQuery()`](https://dbi.r-dbi.org/reference/dbSendQuery.html)
with Airtable’s formula syntax (not SQL). The query string is of the
form `"TableName WHERE <formula>"`:

``` r

# Filtered query using Airtable formula syntax
res <- DBI::dbSendQuery(con, "Artists WHERE {Active} = 1")
active_artists <- DBI::dbFetch(res)
DBI::dbClearResult(res)

# The high-level air_read() helper is equivalent and more idiomatic
active_artists2 <- air_read("Artists", formula = "{Active} = 1")
```

Both approaches return the same result.
[`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)
also supports sorting, field selection, and type coercion via the table
schema.

## Writing data

Use
[`DBI::dbWriteTable()`](https://dbi.r-dbi.org/reference/dbWriteTable.html)
to add or sync records. The `append` and `overwrite` arguments control
the write mode:

``` r

# Append new records (append = TRUE is required to add rows)
new_artists <- data.frame(
  Name = c("Frida K.", "Diego R."),
  Age  = c(47L, 53L)
)
DBI::dbWriteTable(con, "Artists", new_artists, append = TRUE)
#> Inserted 2 records.

# Sync / overwrite: upserts by the first column as the key,
# and deletes any Airtable records not present in updated_artists
updated_artists <- data.frame(
  Name = c("Frida K.", "Diego R.", "Georgia O."),
  Age  = c(47L, 53L, 98L)
)
DBI::dbWriteTable(con, "Artists", updated_artists, overwrite = TRUE)
#> Sync complete: 1 created, 2 updated, 0 deleted, 0 unchanged.
```

`overwrite = TRUE` maps to
[`air_sync()`](https://noamross.github.io/airtable2/reference/air_sync.md)
under the hood: it upserts records whose key (first column) matches and
deletes records that are absent from the supplied data frame. Use
[`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
directly if you want upsert-without- delete semantics.

## Multi-base mode

When
[`air_connect()`](https://noamross.github.io/airtable2/reference/air_connect.md)
is called without a `base` argument, it opens a multi-base connection.
In this mode all accessible bases are exposed as DBI schemas, and table
names use a `"BaseName.TableName"` dotted format:

``` r

# Open a connection to all accessible bases
con_all <- air_connect()

# Tables are listed in "BaseName.TableName" format
DBI::dbListTables(con_all)
#> [1] "BollardsForArt.Artists"  "BollardsForArt.Grants"
#> [3] "BollardsForArt.Projects" "OtherBase.Contacts"
#> ...

# Check existence and read using the dotted name
DBI::dbExistsTable(con_all, "BollardsForArt.Artists")
#> [1] TRUE

DBI::dbReadTable(con_all, "BollardsForArt.Artists")

# Alternatively, use DBI::Id() for qualified schema + table names
DBI::dbReadTable(con_all, DBI::Id(schema = "BollardsForArt", table = "Artists"))

DBI::dbDisconnect(con_all)
```

## Limitations

The DBI interface provides a convenient entry point, but it does not
expose the full power of airtable2. Key limitations:

- **No SQL.** Airtable does not have a SQL engine.
  [`DBI::dbSendQuery()`](https://dbi.r-dbi.org/reference/dbSendQuery.html)
  accepts Airtable formula syntax (`"TableName WHERE <formula>"`), not
  SQL.
- **No table creation or deletion.**
  [`DBI::dbCreateTable()`](https://dbi.r-dbi.org/reference/dbCreateTable.html)
  and
  [`DBI::dbRemoveTable()`](https://dbi.r-dbi.org/reference/dbRemoveTable.html)
  are not implemented. Use the Airtable web UI or the low-level
  [`at_create_table()`](https://noamross.github.io/airtable2/reference/at_create_table.md)
  / `at_delete_table()` functions for these operations.
- **No transactions.**
  [`DBI::dbBegin()`](https://dbi.r-dbi.org/reference/transactions.html),
  [`DBI::dbCommit()`](https://dbi.r-dbi.org/reference/transactions.html),
  and
  [`DBI::dbRollback()`](https://dbi.r-dbi.org/reference/transactions.html)
  are not supported.
- **No `dbplyr` lazy tables.** `dplyr::tbl(con, "Artists")` is not yet
  supported.

For the full feature set, use the `air_*` high-level functions:

- [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)
  — read with formula filtering, sorting, field selection, and type
  coercion
- [`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md)
  — create new records, optionally creating missing fields
- [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
  — upsert by key without deleting unmatched records
- [`air_sync()`](https://noamross.github.io/airtable2/reference/air_sync.md)
  — diff-based sync with optional deletion of missing records
