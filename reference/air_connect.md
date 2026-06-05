# Connect to Airtable via DBI

A convenience wrapper around
[`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html)
using the
[`airtable2()`](https://noamross.github.io/airtable2/reference/airtable2.md)
driver. When `base` is specified, the connection shows that base's
tables directly. When `base` is omitted, all accessible bases are shown
as schemas in the connection pane. Use `bases` to restrict the pane to a
specific subset of bases.

## Usage

``` r
air_connect(
  base = NULL,
  bases = NULL,
  .token = NULL,
  include_views = FALSE,
  .connect_code = NULL
)
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

- .connect_code:

  Character. Optional custom reconnect code for the IDE connection pane.
  Defaults to a
  [`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html)
  call. Set by
  [`air_pane()`](https://noamross.github.io/airtable2/reference/air_pane.md)
  to use
  [`airtable2::air_pane()`](https://noamross.github.io/airtable2/reference/air_pane.md)
  instead.

## Value

An
[AirtableConnection](https://noamross.github.io/airtable2/reference/AirtableConnection-class.md)
object.

## Examples

``` r
if (FALSE) { # \dontrun{
# Connect to a specific base by name
con <- air_connect(base = "Project Tracker")

# Connect to all accessible bases
con <- air_connect()

# Show only selected bases in the pane
con <- air_connect(bases = c("appXXXXXX", "appYYYYYY"))
} # }
```
