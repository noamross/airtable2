# Tests for air_attachment_preview_url()
#
# The Airtable API returns a temporary download URL (from airtableusercontent.com)
# that expires after ~2 hours. There is NO way to construct a stable
# attachment viewer URL (from airtable.com) from API metadata alone — that URL
# is only obtainable by navigating to the record in a browser.
#
# Therefore air_attachment_preview_url() always returns NA_character_ and issues
# an informative message explaining how to obtain the stable link manually.
# Tests here verify: correct output shape, vectorized behaviour, edge cases,
# and that the documentation example runs without error.

# ── air_attachment_preview_url() ─────────────────────────────────────────────

test_that("air_attachment_preview_url returns NA for a single attachment", {
  att <- list(
    id       = "attABCDEF123456",
    url      = "https://v5.airtableusercontent.com/v3/abc123",
    filename = "photo.jpg",
    size     = 102400L,
    type     = "image/jpeg"
  )
  result <- suppressMessages(air_attachment_preview_url(att))
  expect_equal(result, NA_character_)
})

test_that("air_attachment_preview_url returns a character vector", {
  att <- list(id = "attXYZ", url = "https://v5.airtableusercontent.com/v3/xyz",
              filename = "doc.pdf", size = 5000L, type = "application/pdf")
  result <- suppressMessages(air_attachment_preview_url(att))
  expect_type(result, "character")
  expect_length(result, 1L)
})

test_that("air_attachment_preview_url emits an informative message", {
  att <- list(id = "attXYZ", url = "https://v5.airtableusercontent.com/v3/xyz",
              filename = "doc.pdf", size = 5000L, type = "application/pdf")
  expect_message(
    air_attachment_preview_url(att),
    regexp = "stable|permanent|viewer|browser",
    ignore.case = TRUE
  )
})

test_that("air_attachment_preview_url is vectorized over a list of attachments", {
  atts <- list(
    list(id = "att1", url = "https://v5.airtableusercontent.com/v3/a1",
         filename = "a.png", size = 1L, type = "image/png"),
    list(id = "att2", url = "https://v5.airtableusercontent.com/v3/a2",
         filename = "b.png", size = 2L, type = "image/png"),
    list(id = "att3", url = "https://v5.airtableusercontent.com/v3/a3",
         filename = "c.png", size = 3L, type = "image/png")
  )
  result <- suppressMessages(air_attachment_preview_url(atts))
  expect_type(result, "character")
  expect_length(result, 3L)
  expect_true(all(is.na(result)))
})

test_that("air_attachment_preview_url handles empty list", {
  result <- suppressMessages(air_attachment_preview_url(list()))
  expect_type(result, "character")
  expect_length(result, 0L)
})

test_that("air_attachment_preview_url handles attachment without id field", {
  att <- list(url = "https://v5.airtableusercontent.com/v3/xyz",
              filename = "orphan.txt", size = 10L, type = "text/plain")
  result <- suppressMessages(air_attachment_preview_url(att))
  expect_equal(result, NA_character_)
})

test_that("air_attachment_preview_url handles attachment with NULL url", {
  att <- list(id = "attABC", url = NULL, filename = "nurl.jpg",
              size = 0L, type = "image/jpeg")
  result <- suppressMessages(air_attachment_preview_url(att))
  expect_equal(result, NA_character_)
})

test_that("air_attachment_preview_url handles mixed list with NULLs", {
  atts <- list(
    list(id = "att1", url = "https://v5.airtableusercontent.com/v3/a1",
         filename = "a.png", size = 1L, type = "image/png"),
    NULL,
    list(id = "att3", url = "https://v5.airtableusercontent.com/v3/a3",
         filename = "c.png", size = 3L, type = "image/png")
  )
  result <- suppressMessages(air_attachment_preview_url(atts))
  expect_type(result, "character")
  expect_length(result, 3L)
  expect_true(all(is.na(result)))
})

# ── Documentation example runs without error ─────────────────────────────────
# This test verifies that the recommended workflow (documented in the @examples
# of air_attachment_preview_url) does not throw an error on mock data.

test_that("documentation example workflow runs without error on mock data", {
  # Simulate the list of attachment objects returned by air_read(..., attachments = "meta")
  attachments_meta <- list(
    list(
      id       = "attABCDEF123456",
      url      = "https://v5.airtableusercontent.com/v3/some_signed_path",
      filename = "report.pdf",
      size     = 204800L,
      type     = "application/pdf",
      thumbnails = list(
        small  = list(url = "https://v5.airtableusercontent.com/v3/thumb_s"),
        large  = list(url = "https://v5.airtableusercontent.com/v3/thumb_l"),
        full   = list(url = "https://v5.airtableusercontent.com/v3/thumb_f")
      )
    )
  )

  # The recommended way to get a stable link is to navigate to the record in
  # the Airtable web app. The helper documents this and returns NA.
  expect_no_error(
    suppressMessages(air_attachment_preview_url(attachments_meta))
  )

  # The temporary download URL is accessible via $url — document its limit
  tmp_url <- attachments_meta[[1]]$url
  expect_true(grepl("airtableusercontent\\.com", tmp_url))
})

# ── Expiry documentation: url field is from airtableusercontent.com ───────────

test_that("attachment $url field is from airtableusercontent.com (expiring domain)", {
  # Confirm the shape returned by the API so the documentation note is testable.
  att <- list(
    id       = "attXYZ789",
    url      = "https://v5.airtableusercontent.com/v3/signed_token_here",
    filename = "image.jpg",
    size     = 512000L,
    type     = "image/jpeg"
  )
  expect_true(grepl("airtableusercontent\\.com", att$url))
  # The stable viewer URL (airtable.com) cannot be derived from metadata.
  result <- suppressMessages(air_attachment_preview_url(att))
  expect_false(grepl("airtable\\.com", result %||% ""))
})
