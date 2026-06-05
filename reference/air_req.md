# Build an httr2 request to the Airtable API

Constructs a base request with auth, user-agent, retry policy, and
throttle.

## Usage

``` r
air_req(endpoint, token = NULL, host = c("api", "content"))
```

## Arguments

- endpoint:

  Path appended to the host root (e.g., `"meta/bases"` or
  `"appXXX/TableName"`).

- token:

  Personal access token (resolved via
  [`air_token()`](https://noamross.github.io/airtable2/reference/air_token.md)
  if `NULL`).

- host:

  Which Airtable host to target: `"api"` (the default REST API at
  `https://api.airtable.com/v0`) or `"content"` (the attachment-upload
  host at `https://content.airtable.com/v0`).

## Value

An `httr2_request` object ready for further modification.
