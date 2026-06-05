# Get a stable preview URL for an Airtable attachment

The Airtable REST API returns a **temporary** download URL in the `url`
field of every attachment object. This URL is served from
`airtableusercontent.com` and **expires after approximately 2 hours**.
Do not save or share the raw API `url` as a permanent link — it will
stop working shortly after it is issued.

## Usage

``` r
air_attachment_preview_url(attachment)
```

## Arguments

- attachment:

  A single attachment metadata list (as returned by
  `air_read(..., attachments = "meta")`) **or** a list of such
  attachment lists. Each element should contain fields such as `id`,
  `url`, `filename`, `size`, and `type`.

## Value

A character vector of `NA_character_`, one element per attachment. The
function always returns `NA` because a stable viewer URL cannot be
constructed from API metadata alone. See the @section above for the
correct manual workflow.

## Stable attachment viewer URLs

Airtable maintains a separate **attachment viewer URL** (served from
`airtable.com`) that does **not** expire (unless the attachment or
record is deleted). This stable URL requires the recipient to have
access to the base or interface in which the attachment lives.

**Crucially, the stable viewer URL cannot be derived from any field that
the REST API returns** (`id`, `url`, `filename`, `size`, `type`,
`thumbnails`). It is only obtainable by navigating to the record in the
Airtable web app, clicking the attachment to open its preview, and
copying the URL from the browser address bar.

Because no stable URL can be constructed programmatically from
attachment metadata, `air_attachment_preview_url()` always returns
`NA_character_` and emits an informative message directing users to the
correct workflow.

## Examples

``` r
# Suppose you have attachment metadata from air_read():
att <- list(
  id       = "attABCDEF123456",
  url      = "https://v5.airtableusercontent.com/v3/some_signed_path",
  filename = "report.pdf",
  size     = 204800L,
  type     = "application/pdf"
)

# The temporary download URL (expires in ~2 hours):
att$url
#> [1] "https://v5.airtableusercontent.com/v3/some_signed_path"

# Attempting to get a stable preview URL — always NA with an explanation:
if (FALSE) { # \dontrun{
air_attachment_preview_url(att)
} # }

# To obtain a permanent, shareable link for a colleague:
# 1. Open the record in the Airtable web app.
# 2. Click the attachment to open its viewer.
# 3. Copy the URL from the browser address bar (it is from airtable.com).
# 4. Share that URL — it does not expire as long as the attachment exists
#    and the recipient has access to the base.
```
