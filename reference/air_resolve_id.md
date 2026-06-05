# Resolve an Airtable ID or URL to its component parts

Takes an ID string (e.g., "appXXXXXX", "tblXXXXXX", "wspXXXXXX",
"viwXXXXXX") or a full URL and extracts the ID, determining its type.

## Usage

``` r
air_resolve_id(x)
```

## Arguments

- x:

  Character string. An ID, a connection object, or a URL.

## Value

A list with components: `type` ("workspace", "base", "table", "view", or
"record"), `id` (the extracted ID), and any other parsed components.

## See also

[`air_browse()`](https://noamross.github.io/airtable2/reference/air_browse.md)
for opening the ID in a browser.

## Examples

``` r
air_resolve_id("appXXXXXX")
#> $type
#> [1] "base"
#> 
#> $id
#> [1] "appXXXXXX"
#> 
air_resolve_id("wspXXXXXX")
#> $type
#> [1] "workspace"
#> 
#> $id
#> [1] "wspXXXXXX"
#> 
air_resolve_id("https://airtable.com/appXXXXXX/tblXXXXXX/viwXXXXXX")
#> $type
#> [1] "view"
#> 
#> $id
#> [1] "viwXXXXXX"
#> 
#> $table_id
#> [1] "tblXXXXXX"
#> 
#> $base_id
#> [1] "appXXXXXX"
#> 
```
