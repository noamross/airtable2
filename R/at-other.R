# Low-level utility endpoints

#' Get current user info
#'
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return A list with `id` and (if scoped) `email`, `scopes`.
#' @export
at_whoami <- function(token = NULL) {
  req <- air_req("meta/whoami", token = token)
  air_perform(req)
}

#' Upload an attachment to a record field
#'
#' @param base_id Base ID.
#' @param table_id Table ID or name.
#' @param record_id Record ID.
#' @param field_id Field ID or name.
#' @param file Path to the file to upload.
#' @param token Personal access token (resolved via [air_token()] if `NULL`).
#' @return The attachment object returned by the API.
#' @export
at_upload_attachment <- function(base_id, table_id, record_id, field_id,
                                 file, token = NULL) {
  check_string(base_id)
  check_string(table_id)
  check_string(record_id)
  check_string(field_id)
  check_string(file)

  if (!file.exists(file)) {
    cli_abort("File {.file {file}} does not exist.")
  }

  endpoint <- paste0(base_id, "/", table_id, "/", record_id, "/",
                     field_id, "/uploadAttachment")
  token_resolved <- air_token(token)

  req <- httr2::request(base_url()) |>
    httr2::req_url_path_append(endpoint) |>
    httr2::req_auth_bearer_token(token_resolved) |>
    httr2::req_user_agent(paste0("airtable2/", utils::packageVersion("airtable2"))) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = function(resp) httr2::resp_status(resp) == 429L,
      backoff = ~ 30
    ) |>
    httr2::req_method("POST") |>
    httr2::req_body_multipart(file = curl::form_file(file))

  air_perform(req)
}
