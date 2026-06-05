# Report Airtable API usage for a workspace

Returns this session's best-effort tally of API calls made against a
workspace during the current calendar month (UTC). Airtable free/team
plans cap each workspace at roughly 1000 calls per month and provide no
way to query the remaining quota, so `airtable2` keeps its own counter
on disk.

## Usage

``` r
air_api_usage(workspace = NULL)
```

## Arguments

- workspace:

  Workspace ID (starts with `wsp`). Defaults to the configured default
  workspace (`getOption("airtable2.workspace_id")` or
  `Sys.getenv("AIRTABLE_WORKSPACE_ID")`).

## Value

A list of class `air_api_usage` with elements `workspace_id`, `count`,
`since`, and `last`. Has a `{cli}` print method.

## Examples

``` r
if (FALSE) { # \dontrun{
air_api_usage("wspXXXXXXXXXXXXXX")
} # }
```
