# Common test helpers

skip_if_no_token <- function() {
  token <- Sys.getenv("AIRTABLE_API_KEY", unset = "")
  if (!nzchar(token)) {
    testthat::skip("No AIRTABLE_API_KEY set")
  }
}
