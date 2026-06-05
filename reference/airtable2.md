# Airtable DBI driver

Create a DBI driver for Airtable. Use with
[`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html) to
create an Airtable DBI connection.

## Usage

``` r
airtable2()

at()

airtable()

# S4 method for class 'AirtableDriver'
dbConnect(
  drv,
  token = NULL,
  base_id = NULL,
  include_views = FALSE,
  connect_code = NULL,
  bases_filter = NULL,
  ...
)

# S4 method for class 'AirtableDriver'
dbDataType(dbObj, obj, ...)

# S4 method for class 'AirtableDriver'
dbUnloadDriver(drv, ...)
```

## Arguments

- drv, dbObj:

  An `AirtableDriver` object.

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

- base_id:

  Optional Airtable base ID. If omitted, all accessible bases are shown
  as schemas in the connection pane.

- include_views:

  Logical. If `TRUE`, views are listed in the connection pane as
  separate objects alongside tables.

- connect_code:

  Optional custom reconnect code string for the IDE connection pane. If
  `NULL` (default), a code snippet is auto-generated.

- bases_filter:

  Optional character vector of base IDs or names to restrict the
  connection pane to specific bases.

- ...:

  Additional arguments passed to DBI methods.

- obj:

  An R object to map to an Airtable field type.

## Value

An `AirtableDriver` object.

## Usage

Use this driver to create DBI-compliant connections to Airtable for use
with RStudio/Positron's connection pane. See
[airtable2-package](https://noamross.github.io/airtable2/reference/airtable2-package.md)
for package-level documentation and
[AirtableConnection](https://noamross.github.io/airtable2/reference/AirtableConnection-class.md)
for details on available DBI methods.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- DBI::dbConnect(airtable2(), base_id = "appXXXXXX")
DBI::dbListTables(con)
DBI::dbDisconnect(con)
} # }
```
