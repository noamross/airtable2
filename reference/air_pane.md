# Open the Airtable Connection Pane

Establishes a connection via
[`air_connect()`](https://noamross.github.io/airtable2/reference/air_connect.md)
and ensures it is registered with the RStudio/Positron connection pane.

## Usage

``` r
air_pane(base = NULL, bases = NULL, .token = NULL, include_views = FALSE)
```

## Arguments

- base:

  Character. A Base ID (starts with `app`) or a Base Name. If `NULL`,
  connects to all accessible bases.

- bases:

  Character vector of Base IDs or names. When supplied, the connection
  pane shows only those bases (as schemas). Cannot be combined with
  `base`.

- .token:

  Character. Airtable Personal Access Token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

- include_views:

  Logical. If `TRUE`, views are included in the connection pane
  alongside tables. Default `FALSE`.

## Value

An
[AirtableConnection](https://noamross.github.io/airtable2/reference/AirtableConnection-class.md)
object (invisibly).
