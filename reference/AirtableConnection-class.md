# Airtable DBI connection

Stores Airtable credentials and connection state for DBI methods. Use
[`airtable2()`](https://noamross.github.io/airtable2/reference/airtable2.md)
with
[`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html) to
create connections.

## Usage

``` r
# S4 method for class 'AirtableConnection'
dbDisconnect(conn, ...)

# S4 method for class 'AirtableConnection'
dbIsValid(dbObj, ...)

# S4 method for class 'AirtableConnection'
dbListTables(conn, ...)

# S4 method for class 'AirtableConnection,character'
dbExistsTable(conn, name, ...)

# S4 method for class 'AirtableConnection,character'
dbListFields(conn, name, ...)

# S4 method for class 'AirtableConnection,character'
dbReadTable(conn, name, ...)

# S4 method for class 'AirtableConnection,character'
dbWriteTable(conn, name, value, overwrite = FALSE, append = FALSE, ...)

# S4 method for class 'AirtableConnection,character'
dbRemoveTable(conn, name, ...)

# S4 method for class 'AirtableConnection'
dbGetInfo(dbObj, ...)
```

## Arguments

- conn, dbObj:

  An `AirtableConnection` object.

- ...:

  Additional arguments passed to Airtable helpers.

- name:

  Table name.

- value:

  Data frame to write.

- overwrite, append:

  DBI write mode flags.

## Capabilities and limitations

- Reading tables:

  [`dbReadTable()`](https://dbi.r-dbi.org/reference/dbReadTable.html)
  works on any accessible table. You can also pass
  `"TableName WHERE <formula>"` as the name to filter records using
  Airtable's formula syntax.

- Writing tables:

  [`dbWriteTable()`](https://dbi.r-dbi.org/reference/dbWriteTable.html)
  creates the table if it does not exist (inferring field types from the
  data frame). When the table already exists, `append = TRUE` creates
  new records; `overwrite = TRUE` syncs (upsert + delete-missing) using
  the first column as the key.

- No table removal:

  Airtable's API cannot delete tables. Use the Airtable web UI instead.
  [`dbRemoveTable()`](https://dbi.r-dbi.org/reference/dbRemoveTable.html)
  will error with a clear message.

- No SQL queries:

  Arbitrary SQL is not supported. Use the high-level helpers
  ([`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md),
  [`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md),
  [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md),
  [`air_sync()`](https://noamross.github.io/airtable2/reference/air_sync.md))
  for more ergonomic access.

- No transactions:

  Airtable does not support database transactions.

- Single-base or all-bases:

  When a `base_id` is given, the connection shows that base's tables
  directly. Without a `base_id`, all accessible bases appear as schemas
  in the connection pane.

For most use cases, the high-level functions like
[`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md),
[`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md),
[`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md),
and
[`air_sync()`](https://noamross.github.io/airtable2/reference/air_sync.md)
provide more ergonomic interfaces for Airtable operations.
