# Demo base setup and interactive walkthrough ----------------------------------

#' Set up a demo Airtable base for exploration
#'
#' Creates a new Airtable base with tables and sample records that exercise
#' all the key field types and airtable2 features. The demo base is intended
#' for learning and testing.
#'
#' @param workspace_id Workspace ID (defaults to AIRTABLE_WORKSPACE_ID env var).
#'   Find yours in the browser URL: `https://airtable.com/wspXXXXX/...`
#' @param name Base name (default: `"airtable2_demo"`).
#' @param .token API token (see [air_set_token()]).
#'
#' @details
#' The demo base contains:
#' - **People** table: text, number, checkbox, single/multi-select, date, email
#' - **Projects** table: text, number, date, single-select, linked records to People
#' - **Attachments** table: name + attachment field (for attachment demos)
#'
#' This function creates a real Airtable base and consumes several API calls.
#' The base cannot be deleted via the API on free/team-tier accounts; clean up
#' manually via the Airtable web interface.
#'
#' Field types that cannot be created via API (autoNumber, createdTime,
#' lastModifiedTime, etc.) are not included.
#'
#' @return The base ID (invisibly). Prints a summary of what was created.
#' @export
#'
#' @examples
#' \dontrun{
#' # Requires AIRTABLE_WORKSPACE_ID and AIRTABLE_API_KEY env vars
#' base_id <- air_demo_setup()
#' air_set_base(base_id)
#' air_read("People")
#' }
air_demo_setup <- function(
  workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
  name = "airtable2_demo",
  .token = NULL
) {
  if (!nzchar(workspace_id)) {
    cli::cli_abort(
      c(
        "x" = "{.arg workspace_id} is required.",
        "i" = paste0(
          "Find yours in the browser URL when you open Airtable: ",
          "{.url https://airtable.com/wspXXXXX/...}"
        ),
        "i" = "Set {.envvar AIRTABLE_WORKSPACE_ID} or pass it directly."
      )
    )
  }

  cli::cli_inform(
    c(
      "i" = "Creating demo base {.val {name}} in workspace {.val {workspace_id}}.",
      "i" = "This uses several API calls and creates a real base."
    )
  )

  # --- Build People table config (created with the base) ---------------------
  people_fields <- list(
    list(name = "Name",  type = "singleLineText"),
    list(name = "Age",   type = "number",
         options = list(precision = 0L)),
    list(
      name = "Active",
      type = "checkbox",
      options = list(icon = "check", color = "greenBright")
    ),
    list(
      name = "Role",
      type = "singleSelect",
      options = list(
        choices = list(
          list(name = "Engineer"),
          list(name = "Designer"),
          list(name = "Manager"),
          list(name = "Analyst")
        )
      )
    ),
    list(
      name = "Tags",
      type = "multipleSelects",
      options = list(
        choices = list(
          list(name = "R"),
          list(name = "Python"),
          list(name = "SQL"),
          list(name = "Shiny")
        )
      )
    ),
    list(name = "Joined", type = "date",
         options = list(dateFormat = list(name = "iso"))),
    list(name = "Email", type = "email")
  )

  # --- Build Projects table config (created with the base) ------------------
  projects_fields <- list(
    list(name = "Project Name", type = "singleLineText"),
    list(name = "Budget", type = "number",
         options = list(precision = 2L)),
    list(
      name = "Status",
      type = "singleSelect",
      options = list(
        choices = list(
          list(name = "Planning"),
          list(name = "In Progress"),
          list(name = "Complete"),
          list(name = "On Hold")
        )
      )
    ),
    list(name = "Due Date", type = "date",
         options = list(dateFormat = list(name = "iso")))
  )

  # --- Build Attachments table config (for attachment demos) ----------------
  attachments_fields <- list(
    list(name = "Item",  type = "singleLineText"),
    list(name = "Files", type = "multipleAttachments")
  )

  # Create the base with People, Projects, and Attachments tables
  cli::cli_inform("Creating base and tables...")
  new_base <- at_create_base(
    name = name,
    workspace_id = workspace_id,
    tables = list(
      list(name = "People",      fields = people_fields),
      list(name = "Projects",    fields = projects_fields),
      list(name = "Attachments", fields = attachments_fields)
    ),
    token = .token
  )
  base_id <- new_base$id

  # --- Add Members (linked records) field to Projects -----------------------
  # Must be done after base creation because we need the People table ID.
  created_tables <- new_base$tables %||% list()
  people_tbl <- Find(function(t) t$name == "People",    created_tables)
  projects_tbl <- Find(function(t) t$name == "Projects", created_tables)

  if (!is.null(people_tbl) && !is.null(projects_tbl)) {
    cli::cli_inform("Adding linked-records field {.field Members} to Projects...")
    tryCatch(
      at_create_field(
        name     = "Members",
        table_id = projects_tbl$id,
        type     = "multipleRecordLinks",
        base_id  = base_id,
        options  = list(
          linkedTableId  = people_tbl$id,
          isReversed     = FALSE
        ),
        token = .token
      ),
      error = function(e) {
        cli::cli_warn(
          "Could not create linked-records field: {conditionMessage(e)}"
        )
      }
    )
  }

  # --- Write sample People records ------------------------------------------
  cli::cli_inform("Writing sample People records...")
  people_data <- tibble::tibble(
    Name   = c("Alice Chen",    "Bob Okafor",  "Carol Smith",
                "David Park",    "Eva Larsson", "Frank M\u00fcller"),
    Age    = c(32L, 28L, 41L, 35L, 27L, 44L),
    Active = c(TRUE, TRUE, FALSE, TRUE, TRUE, FALSE),
    Role   = c("Engineer", "Designer", "Manager",
                "Analyst",  "Engineer", "Manager"),
    Tags   = list(
      c("R", "Shiny"),
      c("Python", "SQL"),
      c("R", "SQL"),
      "SQL",
      c("R", "Python"),
      c("Python", "Shiny")
    ),
    Joined = as.Date(c(
      "2022-01-15", "2023-03-08", "2019-07-01",
      "2021-11-20", "2023-09-05", "2018-04-12"
    )),
    Email  = c(
      "alice@example.com",  "bob@example.com",  "carol@example.com",
      "david@example.com",  "eva@example.com",  "frank@example.com"
    )
  )
  air_write(people_data, base_id, "People",
            typecast = TRUE, add_fields = "warn", .token = .token)

  # --- Write sample Projects records ----------------------------------------
  cli::cli_inform("Writing sample Projects records...")
  projects_data <- tibble::tibble(
    `Project Name` = c("Dashboard v2", "API Integration",
                        "Data Pipeline",  "Mobile App"),
    Budget   = c(12000, 8500, 25000, 50000),
    Status   = c("In Progress", "Planning", "Complete", "In Progress"),
    `Due Date` = as.Date(c(
      "2026-03-31", "2026-06-30", "2025-12-31", "2026-09-30"
    ))
  )
  air_write(projects_data, base_id, "Projects",
            typecast = TRUE, add_fields = "warn", .token = .token)

  # --- Summary ---------------------------------------------------------------
  cli::cli_inform(
    c(
      "v" = "Demo base created: {.val {name}} ({.val {base_id}})",
      "*" = "Tables: People ({nrow(people_data)} records), \\
             Projects ({nrow(projects_data)} records), Attachments (empty)",
      "i" = "Set as default with {.run air_set_base(\"{base_id}\")}",
      "i" = "Run {.fn air_demo} for an interactive walkthrough.",
      "!" = paste0(
        "Delete the base manually in the Airtable web UI when done: ",
        "{.url https://airtable.com}"
      )
    )
  )

  invisible(base_id)
}


#' Run an interactive airtable2 demo walkthrough
#'
#' Runs through the canonical airtable2 operations against a demo base,
#' printing results at each step. If no `base_id` is provided and none is set
#' as the session default, calls [air_demo_setup()] first.
#'
#' @param base_id Base ID to use. If `NULL`, checks the session default
#'   ([air_set_base()]) and `AIRTABLE_BASE_ID` env var; calls
#'   [air_demo_setup()] if nothing is found.
#' @param workspace_id Passed to [air_demo_setup()] if base creation is needed.
#' @param .token API token (see [air_set_token()]).
#'
#' @details
#' The walkthrough covers:
#' 1. Read all records from the People table
#' 2. Write a new record
#' 3. Upsert (update or insert by Name)
#' 4. Sync (diff-based create/update/delete)
#' 5. Left-join local data with the Airtable table
#' 6. View the base schema
#' 7. View API usage
#'
#' All operations are idempotent: upsert and sync operate by key (`Name`) so
#' running the demo multiple times will not accumulate duplicate records.
#'
#' @return Invisibly returns a list of results from each step.
#' @export
#'
#' @examples
#' \dontrun{
#' # Run with an existing demo base (set via air_set_base() or env var)
#' air_set_base("appXXXXXXXXXXXXXX")
#' air_demo()
#'
#' # Or create a new demo base first (needs AIRTABLE_WORKSPACE_ID)
#' air_demo(workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"))
#' }
air_demo <- function(
  base_id = NULL,
  workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
  .token = NULL
) {
  # --- Resolve base_id ------------------------------------------------------
  if (is.null(base_id)) {
    base_id <- tryCatch(
      resolve_base_id(NULL),
      error = function(e) NULL
    )
  }

  if (is.null(base_id) || !nzchar(base_id)) {
    cli::cli_inform(
      c(
        "i" = "No base set. Creating a demo base via {.fn air_demo_setup}.",
        "i" = "This requires {.envvar AIRTABLE_WORKSPACE_ID}."
      )
    )
    base_id <- air_demo_setup(workspace_id = workspace_id, .token = .token)
  }

  results <- list()

  # ---- Step 1: Read ----------------------------------------------------------
  cli::cli_h1("Step 1: Read all records from People")
  people <- air_read(base_id, "People", .token = .token)
  cli::cli_inform("Read {nrow(people)} record{?s}.")
  print(people)
  results$read <- people

  # ---- Step 2: Write a new record --------------------------------------------
  cli::cli_h1("Step 2: Write a new record")
  new_person <- tibble::tibble(
    Name   = "Demo User",
    Age    = 30L,
    Active = TRUE,
    Role   = "Analyst",
    Tags   = list(c("R", "Python")),
    Joined = Sys.Date(),
    Email  = "demo@example.com"
  )
  cli::cli_inform("Writing: {.val {new_person$Name}}")
  new_ids <- air_write(new_person, base_id, "People",
                       typecast = TRUE, add_fields = "warn", .token = .token)
  results$write <- new_ids

  # ---- Step 3: Upsert --------------------------------------------------------
  cli::cli_h1("Step 3: Upsert (update or insert by Name)")
  upsert_data <- tibble::tibble(
    Name   = c("Demo User", "New Contributor"),
    Age    = c(31L, 24L),
    Active = c(TRUE, TRUE),
    Role   = c("Engineer", "Designer"),
    Tags   = list("R", "Python"),
    Joined = list(Sys.Date(), Sys.Date()),
    Email  = c("demo@example.com", "newbie@example.com")
  )
  cli::cli_inform(
    "Upserting {nrow(upsert_data)} records (merge on {.field Name})..."
  )
  upsert_result <- air_upsert(
    upsert_data, base_id, "People",
    merge_on = "Name", typecast = TRUE, add_fields = "warn", .token = .token
  )
  results$upsert <- upsert_result

  # ---- Step 4: Sync ----------------------------------------------------------
  cli::cli_h1("Step 4: Sync (diff-based)")
  # Read what's there now and remove the demo records we just added, to show
  # sync deletes them.
  current <- air_read(base_id, "People", .token = .token)
  sync_data <- current[
    !current$Name %in% c("Demo User", "New Contributor"),
    setdiff(names(current), c("airtable_id", "airtable_created_time")),
    drop = FALSE
  ]
  cli::cli_inform(
    "Syncing {nrow(sync_data)} records (will delete demo rows added above)..."
  )
  sync_result <- air_sync(
    sync_data, base_id, "People",
    key = "Name", typecast = TRUE, add_fields = "warn", .token = .token
  )
  results$sync <- sync_result

  # ---- Step 5: Join ----------------------------------------------------------
  cli::cli_h1("Step 5: Left-join local data with Airtable table")
  local_scores <- tibble::tibble(
    Name  = c("Alice Chen", "Bob Okafor", "Carol Smith"),
    Score = c(98L, 85L, 92L)
  )
  cli::cli_inform("Joining local scores with People table on {.field Name}...")
  joined <- air_left_join(local_scores, base_id, "People",
                          by = "Name", .token = .token)
  show_cols <- intersect(c("Name", "Score", "Role", "Active"), names(joined))
  print(joined[show_cols])
  results$join <- joined

  # ---- Step 6: Schema --------------------------------------------------------
  cli::cli_h1("Step 6: View base schema")
  schema <- air_schema(base_id, .token = .token)
  cli::cli_inform("Tables: {.val {schema$table_name}}")
  print(schema)
  results$schema <- schema

  # ---- Step 7: API usage -----------------------------------------------------
  cli::cli_h1("Step 7: API usage")
  usage <- tryCatch(air_api_usage(), error = function(e) NULL)
  if (!is.null(usage)) {
    print(usage)
  } else {
    cli::cli_inform("API usage counter not available (counter disabled or workspace unknown).")
  }
  results["usage"] <- list(usage)

  cli::cli_rule("Demo complete")
  cli::cli_inform(
    c(
      "v" = "Base ID: {.val {base_id}}",
      "i" = "Clean up with: {.url https://airtable.com} (delete base manually)"
    )
  )

  invisible(results)
}
