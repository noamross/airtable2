# Airtable DBI result

Eagerly materialized DBI result object used by
[`DBI::dbSendQuery()`](https://dbi.r-dbi.org/reference/dbSendQuery.html).
Unlike traditional DBI results which may be cursor-based, AirtableResult
objects fetch all matching records immediately (due to Airtable API
limitations).

## Usage

``` r
# S4 method for class 'AirtableConnection,character'
dbSendQuery(conn, statement, ...)

# S4 method for class 'AirtableResult,numeric'
dbFetch(res, n = -1, ...)

# S4 method for class 'AirtableResult'
dbClearResult(res, ...)

# S4 method for class 'AirtableResult'
dbHasCompleted(res, ...)

# S4 method for class 'AirtableResult'
dbGetRowCount(res, ...)

# S4 method for class 'AirtableResult'
dbGetStatement(res, ...)

# S4 method for class 'AirtableResult'
dbIsValid(dbObj, ...)

# S4 method for class 'AirtableResult'
dbGetRowsAffected(res, ...)

# S4 method for class 'AirtableResult,missing'
dbFetch(res, n = -1, ...)
```

## Arguments

- conn:

  An `AirtableConnection` object.

- statement:

  Table name, optionally followed by `WHERE <formula>`.

- ...:

  Additional arguments passed to Airtable helpers.

- res, dbObj:

  An `AirtableResult` object.

- n:

  Number of rows to fetch. Use a negative value to fetch all rows. Note:
  Due to eager evaluation, this parameter is primarily for
  compatibility.

## Limitations

- Eager evaluation:

  All data is fetched when the result is created. There is no
  cursor-based iteration.

- Read-only:

  AirtableResult objects are for reading data only.

- Formula filtering:

  The `statement` parameter supports Airtable formula syntax after the
  table name (e.g., `"Contacts WHERE Age > 30"`). This is not SQL.
