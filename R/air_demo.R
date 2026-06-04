# Demo base setup and interactive walkthrough ----------------------------------

#' Set up a demo Airtable base for exploration
#'
#' Creates a new Airtable base with tables and sample records that exercise
#' all the key field types and airtable2 features. The demo base is themed
#' around **BollardsForArt**, a fictional creative-arts advocacy nonprofit that
#' installs unauthorized public art, fights for arts funding, runs community
#' workshops, and tracks their campaigns and artists.
#'
#' @param workspace_id Workspace ID (defaults to AIRTABLE_WORKSPACE_ID env var).
#'   Find yours in the browser URL: `https://airtable.com/wspXXXXX/...`
#' @param name Base name (default: `"bollardsforart_demo"`).
#' @param .token API token (see [air_set_token()]).
#'
#' @details
#' The demo base contains:
#' - **Artists** table: text, number, checkbox, single/multi-select, date, email
#'   (15+ rows with diverse international artists)
#' - **Projects** table: text, number, date, single-select, attachments,
#'   linked records to Artists (15+ rows with imaginative installation names)
#' - **Grants** table: text, number, date, single-select, linked records to
#'   Projects (15+ rows of funding sources and applications)
#'
#' Fields include descriptions (column metadata) set via [at_update_field()].
#' Project records have image attachments uploaded via [at_upload_attachment()].
#' Linked-records fields connect Projects to Artists and Grants to Projects.
#'
#' This function creates a real Airtable base and consumes several API calls.
#' The base cannot be deleted via the API on free/team-tier accounts; clean up
#' manually via the Airtable web interface.
#'
#' @return The base ID (invisibly). Prints a summary of what was created.
#' @export
#'
#' @examples
#' \dontrun{
#' # Requires AIRTABLE_WORKSPACE_ID and AIRTABLE_API_KEY env vars
#' base_id <- air_demo_setup()
#' air_set_base(base_id)
#' air_read("Artists")
#' }
air_demo_setup <- function(
  workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
  name = "bollardsforart_demo",
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
      "i" = "Theme: BollardsForArt — creative-arts advocacy nonprofit.",
      "i" = "This uses several API calls and creates a real base."
    )
  )

  # --- Build Artists table config (created with the base) --------------------
  artists_fields <- list(
    list(name = "Name",         type = "singleLineText"),
    list(name = "Age",          type = "number",
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
          list(name = "Guerilla Muralist"),
          list(name = "Kinetic Sculptor"),
          list(name = "Sound Installation Designer"),
          list(name = "Community Arts Agitator"),
          list(name = "Concrete Poet"),
          list(name = "Site-Specific Weaver"),
          list(name = "Light & Shadow Artist"),
          list(name = "Street Typographer")
        )
      )
    ),
    list(
      name = "Disciplines",
      type = "multipleSelects",
      options = list(
        choices = list(
          list(name = "Mural"),
          list(name = "Sculpture"),
          list(name = "Sound"),
          list(name = "Textile"),
          list(name = "Poetry"),
          list(name = "Light"),
          list(name = "Community"),
          list(name = "Street Art")
        )
      )
    ),
    list(name = "Member Since", type = "date",
         options = list(dateFormat = list(name = "iso"))),
    list(name = "Email",        type = "email")
  )

  # --- Build Projects table config (created with the base) ------------------
  projects_fields <- list(
    list(name = "Project Name", type = "singleLineText"),
    list(name = "Budget",       type = "number",
         options = list(precision = 2L)),
    list(
      name = "Status",
      type = "singleSelect",
      options = list(
        choices = list(
          list(name = "Proposed"),
          list(name = "In Progress"),
          list(name = "Installed"),
          list(name = "Dismantled"),
          list(name = "On Hold")
        )
      )
    ),
    list(name = "Installation Date", type = "date",
         options = list(dateFormat = list(name = "iso"))),
    list(name = "Files",        type = "multipleAttachments")
  )

  # --- Build Grants table config (created with the base) --------------------
  grants_fields <- list(
    list(name = "Grant Name",   type = "singleLineText"),
    list(name = "Amount",       type = "number",
         options = list(precision = 2L)),
    list(
      name = "Status",
      type = "singleSelect",
      options = list(
        choices = list(
          list(name = "Identified"),
          list(name = "Applied"),
          list(name = "Awarded"),
          list(name = "Rejected"),
          list(name = "Reporting")
        )
      )
    ),
    list(name = "Deadline",     type = "date",
         options = list(dateFormat = list(name = "iso"))),
    list(name = "Funder",       type = "singleLineText")
  )

  # Create the base with all three tables
  cli::cli_inform("Creating base and tables...")
  new_base <- at_create_base(
    name = name,
    workspace_id = workspace_id,
    tables = list(
      list(name = "Artists",  fields = artists_fields),
      list(name = "Projects", fields = projects_fields),
      list(name = "Grants",   fields = grants_fields)
    ),
    token = .token
  )
  base_id <- new_base$id

  # --- Identify created tables -----------------------------------------------
  created_tables <- new_base$tables %||% list()
  artists_tbl  <- Find(function(t) t$name == "Artists",  created_tables)
  projects_tbl <- Find(function(t) t$name == "Projects", created_tables)
  grants_tbl   <- Find(function(t) t$name == "Grants",   created_tables)

  # --- Add linked-records field: Lead Artist on Projects --------------------
  if (!is.null(artists_tbl) && !is.null(projects_tbl)) {
    cli::cli_inform(
      "Adding linked-records field {.field Lead Artist} to Projects..."
    )
    tryCatch(
      at_create_field(
        name     = "Lead Artist",
        table_id = projects_tbl$id,
        type     = "multipleRecordLinks",
        base_id  = base_id,
        options  = list(
          linkedTableId = artists_tbl$id,
          isReversed    = FALSE
        ),
        token = .token
      ),
      error = function(e) {
        cli::cli_warn(
          "Could not create Lead Artist linked field: {conditionMessage(e)}"
        )
      }
    )
  }

  # --- Add linked-records field: Funded Projects on Grants ------------------
  if (!is.null(projects_tbl) && !is.null(grants_tbl)) {
    cli::cli_inform(
      "Adding linked-records field {.field Funded Projects} to Grants..."
    )
    tryCatch(
      at_create_field(
        name     = "Funded Projects",
        table_id = grants_tbl$id,
        type     = "multipleRecordLinks",
        base_id  = base_id,
        options  = list(
          linkedTableId = projects_tbl$id,
          isReversed    = FALSE
        ),
        token = .token
      ),
      error = function(e) {
        cli::cli_warn(
          "Could not create Funded Projects linked field: {conditionMessage(e)}"
        )
      }
    )
  }

  # --- Write sample Artists records -----------------------------------------
  cli::cli_inform("Writing sample Artists records...")
  artists_data <- tibble::tibble(
    Name           = c(
      "Zara Okonkwo",         "Dmitri Volkov",       "Sun-Li Park",
      "Fatima El-Rashid",     "Carlos Mendes",       "Ingrid Holmås",
      "Kofi Asante",          "Priya Nair",          "Tomasz Wierzbicki",
      "Amara Diallo",         "Hiroshi Nakamura",    "Beatriz Santos",
      "Rashida Osei",         "Lukaš Novaček",  "Miriam Khoury"
    ),
    Age            = c(34L, 41L, 28L, 36L, 45L, 29L, 38L, 32L, 44L,
                       27L, 51L, 33L, 39L, 25L, 47L),
    Active         = c(TRUE,  TRUE,  TRUE,  TRUE,  FALSE, TRUE,  TRUE,
                       TRUE,  FALSE, TRUE,  TRUE,  TRUE,  FALSE, TRUE, TRUE),
    Role           = c(
      "Guerilla Muralist",          "Kinetic Sculptor",
      "Sound Installation Designer","Community Arts Agitator",
      "Concrete Poet",              "Site-Specific Weaver",
      "Street Typographer",         "Light & Shadow Artist",
      "Guerilla Muralist",          "Sound Installation Designer",
      "Kinetic Sculptor",           "Community Arts Agitator",
      "Concrete Poet",              "Light & Shadow Artist",
      "Site-Specific Weaver"
    ),
    Disciplines    = list(
      c("Mural", "Street Art"),
      c("Sculpture", "Community"),
      c("Sound", "Community"),
      c("Community", "Street Art"),
      c("Poetry", "Mural"),
      c("Textile", "Community"),
      c("Street Art", "Poetry"),
      c("Light", "Sculpture"),
      c("Mural", "Street Art"),
      c("Sound", "Light"),
      c("Sculpture", "Mural"),
      c("Community", "Textile"),
      "Poetry",
      c("Light", "Street Art"),
      c("Textile", "Sculpture")
    ),
    `Member Since` = as.Date(c(
      "2019-03-12", "2018-07-01", "2022-01-20", "2020-09-15", "2016-04-08",
      "2021-11-03", "2019-06-25", "2023-02-14", "2017-08-30", "2022-05-11",
      "2015-12-05", "2020-03-28", "2018-10-19", "2023-07-07", "2016-01-22"
    )),
    Email          = c(
      "zara@bollardsforart.org",     "dmitri@bollardsforart.org",
      "sunli@bollardsforart.org",    "fatima@bollardsforart.org",
      "carlos@bollardsforart.org",   "ingrid@bollardsforart.org",
      "kofi@bollardsforart.org",     "priya@bollardsforart.org",
      "tomasz@bollardsforart.org",   "amara@bollardsforart.org",
      "hiroshi@bollardsforart.org",  "beatriz@bollardsforart.org",
      "rashida@bollardsforart.org",  "lukas@bollardsforart.org",
      "miriam@bollardsforart.org"
    )
  )
  artist_ids <- air_write(artists_data, "Artists", base_id,
                          typecast = TRUE, add_fields = "warn", .token = .token)

  # --- Write sample Projects records ----------------------------------------
  cli::cli_inform("Writing sample Projects records...")

  # Picsum stable image URLs keyed by project seed
  project_seeds <- c(
    "night-bloom",    "listening-wall",   "fugitive-geom",
    "concrete-chant", "meridian-pulse",   "rust-and-bloom",
    "echo-chamber",   "sky-anchors",      "tide-grammars",
    "hidden-clocks",  "soft-machines",    "border-crossings",
    "grief-garden",   "signal-fire",      "radiant-commons"
  )
  picsum_urls <- paste0("https://picsum.photos/seed/", project_seeds, "/640/480")

  projects_data <- tibble::tibble(
    `Project Name`      = c(
      "Night Bloom at Pier 7",          "The Listening Wall",
      "Fugitive Geometries",            "Concrete Chant",
      "Meridian Pulse",                 "Rust & Bloom",
      "Echo Chamber / Camara de Eco",   "Sky Anchors",
      "Tide Grammars",                  "Hidden Clocks",
      "Soft Machines",                  "Border Crossings",
      "Grief Garden",                   "Signal Fire",
      "The Radiant Commons"
    ),
    Budget              = c(
       4200, 11500, 8750,  2300, 15000,
       6400,  9800, 3100, 12000,  5500,
       7200, 14000, 3800,  6900, 20000
    ),
    Status              = c(
      "Installed",    "In Progress", "Proposed",
      "Installed",    "In Progress", "Installed",
      "On Hold",      "Installed",   "Proposed",
      "In Progress",  "Dismantled",  "Installed",
      "Proposed",     "In Progress", "Installed"
    ),
    `Installation Date` = as.Date(c(
      "2024-06-21", "2025-03-15", NA,
      "2023-09-08", "2025-07-01", "2024-11-02",
      NA,           "2024-04-18", NA,
      "2025-01-10", "2022-08-05", "2023-12-14",
      NA,           "2025-05-20", "2024-09-30"
    )),
    Files               = lapply(picsum_urls, function(u) {
      list(list(url = u))
    })
  )
  project_ids <- air_write(projects_data, "Projects", base_id,
                           typecast = TRUE, add_fields = "warn", .token = .token)

  # --- Upload project images as proper attachments --------------------------
  # Demonstrate at_upload_attachment by downloading the first project's image
  # to a temp file and uploading it as a binary attachment.
  cli::cli_inform("Uploading sample project image attachment...")
  .demo_upload_image(
    base_id      = base_id,
    table_id     = projects_tbl$id %||% "Projects",
    project_ids  = project_ids,
    image_url    = picsum_urls[[1L]],
    .token       = .token
  )

  # --- Write sample Grants records ------------------------------------------
  cli::cli_inform("Writing sample Grants records...")
  grants_data <- tibble::tibble(
    `Grant Name`  = c(
      "NEA Our Town",                "NYSCA Individual Artist",
      "Kresge Arts in Detroit",      "Creative Capital Award",
      "Pollock-Krasner Foundation",  "MAP Fund",
      "Rasmuson Foundation",         "Joan Mitchell Foundation",
      "Herb Alpert Award",           "United States Artists",
      "Andy Warhol Foundation",      "Foundation for Contemporary Arts",
      "ArtPlace America",            "Surdna Foundation Arts",
      "Tiny Spark Community Arts"
    ),
    Amount        = c(
       75000,  15000, 25000, 50000,  20000,
       30000,  10000, 40000, 35000,  50000,
       60000,   8000, 45000, 22000,   5000
    ),
    Status        = c(
      "Awarded",    "Applied",    "Awarded",  "Identified", "Applied",
      "Awarded",    "Rejected",   "Awarded",  "Identified", "Applied",
      "Reporting",  "Awarded",    "Applied",  "Identified", "Awarded"
    ),
    Deadline      = as.Date(c(
      "2025-04-01", "2025-09-15", "2025-06-30", "2026-01-31", "2025-11-01",
      "2025-08-15", "2025-03-01", "2025-10-31", "2026-02-28", "2025-07-15",
      "2025-05-15", "2025-12-01", "2026-03-31", "2025-08-01", "2025-06-01"
    )),
    Funder        = c(
      "National Endowment for the Arts",
      "New York State Council on the Arts",
      "Kresge Foundation",
      "Creative Capital",
      "Pollock-Krasner Foundation",
      "MAP Fund",
      "Rasmuson Foundation",
      "Joan Mitchell Foundation",
      "Herb Alpert Foundation",
      "United States Artists",
      "Andy Warhol Foundation",
      "Foundation for Contemporary Arts",
      "ArtPlace America",
      "Surdna Foundation",
      "Tiny Spark"
    )
  )
  air_write(grants_data, "Grants", base_id,
            typecast = TRUE, add_fields = "warn", .token = .token)

  # --- Add field descriptions -----------------------------------------------
  # Retrieve the schema to get field IDs, then patch descriptions
  cli::cli_inform("Adding field descriptions...")
  tryCatch({
    schema <- at_get_schema(base_id)

    .describe_field <- function(table_name, field_name, description) {
      tbl <- Find(function(t) t$name == table_name, schema)
      if (is.null(tbl)) return(invisible(NULL))
      fld <- Find(function(f) f$name == field_name, tbl$fields)
      if (is.null(fld)) return(invisible(NULL))
      tryCatch(
        at_update_field(
          base_id     = base_id,
          table_id    = tbl$id,
          field_id    = fld$id,
          description = description,
          token       = .token
        ),
        error = function(e) {
          cli::cli_warn(
            "Could not set description for {.field {field_name}}: {conditionMessage(e)}"
          )
        }
      )
    }

    # Artists field descriptions
    .describe_field("Artists", "Name",
      "Full name of the artist as they wish to be credited in public materials.")
    .describe_field("Artists", "Role",
      "Primary artistic practice or role within BollardsForArt campaigns.")
    .describe_field("Artists", "Disciplines",
      "All artistic disciplines the artist works across.")
    .describe_field("Artists", "Active",
      "Whether the artist is currently active in BollardsForArt projects.")
    .describe_field("Artists", "Member Since",
      "Date the artist joined the BollardsForArt collective.")
    .describe_field("Artists", "Email",
      "Contact email for project coordination and grant applications.")

    # Projects field descriptions
    .describe_field("Projects", "Project Name",
      "The public-facing title of the art installation or campaign.")
    .describe_field("Projects", "Budget",
      "Total budget in USD approved or estimated for the project.")
    .describe_field("Projects", "Status",
      "Current lifecycle stage of the project.")
    .describe_field("Projects", "Installation Date",
      "Date the work was or is scheduled to be installed in public space.")
    .describe_field("Projects", "Files",
      "Reference images, documentation photos, or design files for the project.")

    # Grants field descriptions
    .describe_field("Grants", "Grant Name",
      "Name of the grant program or award.")
    .describe_field("Grants", "Amount",
      "Dollar amount of the grant, either awarded or applied for.")
    .describe_field("Grants", "Status",
      "Current status of the grant application or relationship.")
    .describe_field("Grants", "Deadline",
      "Application deadline or next reporting due date.")
    .describe_field("Grants", "Funder",
      "Name of the funding organization or foundation.")

  }, error = function(e) {
    cli::cli_warn(
      "Could not add field descriptions: {conditionMessage(e)}"
    )
  })

  # --- Summary ---------------------------------------------------------------
  base_url <- paste0("https://airtable.com/", base_id)
  cli::cli_inform(
    c(
      "v" = "Demo base created: {.val {name}} ({.val {base_id}})",
      "*" = "Artists: {nrow(artists_data)} records",
      "*" = "Projects: {nrow(projects_data)} records (with image attachments)",
      "*" = "Grants: {nrow(grants_data)} records",
      "i" = "Set as default with {.run air_set_base(\"{base_id}\")}",
      "i" = "Open in browser: {.url {base_url}}",
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
#' Runs through the canonical airtable2 operations against a BollardsForArt
#' demo base, printing results at each step. If no `base_id` is provided and
#' none is set as the session default, calls [air_demo_setup()] first.
#'
#' @param base_id Base ID to use. If `NULL`, checks the session default
#'   ([air_set_base()]) and `AIRTABLE_BASE_ID` env var; calls
#'   [air_demo_setup()] if nothing is found.
#' @param workspace_id Passed to [air_demo_setup()] if base creation is needed.
#' @param .token API token (see [air_set_token()]).
#'
#' @details
#' The BollardsForArt walkthrough covers:
#' 1. Read all records from the Artists table
#' 2. Write a new artist record
#' 3. Upsert (update or insert by Name)
#' 4. Sync (diff-based create/update/delete)
#' 5. Left-join local data with the Airtable table
#' 6. View the base schema (including field descriptions)
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
  # --- Resolve base_id -------------------------------------------------------
  if (is.null(base_id)) {
    base_id <- tryCatch(
      resolve_base_id(NULL),
      error = function(e) NULL
    )
  }

  if (is.null(base_id) || !nzchar(base_id)) {
    cli::cli_inform(
      c(
        "i" = "No base set. Creating a BollardsForArt demo base via {.fn air_demo_setup}.",
        "i" = "This requires {.envvar AIRTABLE_WORKSPACE_ID}."
      )
    )
    base_id <- air_demo_setup(workspace_id = workspace_id, .token = .token)
  }

  results <- list()

  # ---- Step 1: Read ----------------------------------------------------------
  cli::cli_h1("Step 1: Read all records from Artists")
  artists <- air_read("Artists", base_id, .token = .token)
  cli::cli_inform("Read {nrow(artists)} artist record{?s}.")
  print(artists)
  results$read <- artists

  # ---- Step 2: Write a new record -------------------------------------------
  cli::cli_h1("Step 2: Write a new artist record")
  new_artist <- tibble::tibble(
    Name           = "Demo Artist",
    Age            = 30L,
    Active         = TRUE,
    Role           = "Community Arts Agitator",
    Disciplines    = list(c("Community", "Street Art")),
    `Member Since` = Sys.Date(),
    Email          = "demo@bollardsforart.org"
  )
  cli::cli_inform("Writing: {.val {new_artist$Name}}")
  new_ids <- air_write(new_artist, "Artists", base_id,
                       typecast = TRUE, add_fields = "warn", .token = .token)
  results$write <- new_ids

  # ---- Step 3: Upsert -------------------------------------------------------
  cli::cli_h1("Step 3: Upsert (update or insert by Name)")
  upsert_data <- tibble::tibble(
    Name        = c("Demo Artist", "New Collaborator"),
    Age         = c(31L, 26L),
    Active      = c(TRUE, TRUE),
    Role        = c("Community Arts Agitator", "Guerilla Muralist"),
    Disciplines = list(c("Community", "Street Art"), "Mural"),
    `Member Since` = list(Sys.Date(), Sys.Date()),
    Email       = c("demo@bollardsforart.org", "new@bollardsforart.org")
  )
  cli::cli_inform(
    "Upserting {nrow(upsert_data)} records (merge on {.field Name})..."
  )
  upsert_result <- air_upsert(
    upsert_data, "Artists",
    merge_on = "Name", base_id = base_id,
    typecast = TRUE, add_fields = "warn", .token = .token
  )
  results$upsert <- upsert_result

  # ---- Step 4: Sync ---------------------------------------------------------
  cli::cli_h1("Step 4: Sync (diff-based)")
  # Remove demo records to show sync deletes them.
  current <- air_read("Artists", base_id, .token = .token)
  sync_data <- current[
    !current$Name %in% c("Demo Artist", "New Collaborator"),
    setdiff(names(current), c("airtable_id", "airtable_created_time")),
    drop = FALSE
  ]
  cli::cli_inform(
    "Syncing {nrow(sync_data)} records (will delete demo rows added above)..."
  )
  sync_result <- air_sync(
    sync_data, "Artists",
    key = "Name", base_id = base_id,
    typecast = TRUE, add_fields = "warn", .token = .token
  )
  results$sync <- sync_result

  # ---- Step 5: Join ---------------------------------------------------------
  cli::cli_h1("Step 5: Left-join local data with Artists table")
  local_scores <- tibble::tibble(
    Name  = c("Zara Okonkwo", "Dmitri Volkov", "Sun-Li Park"),
    Score = c(98L, 85L, 92L)
  )
  cli::cli_inform(
    "Joining local scores with Artists table on {.field Name}..."
  )
  joined <- air_left_join(local_scores, "Artists", base_id,
                          by = "Name", .token = .token)
  show_cols <- intersect(c("Name", "Score", "Role", "Active"), names(joined))
  print(joined[show_cols])
  results$join <- joined

  # ---- Step 6: Schema -------------------------------------------------------
  cli::cli_h1("Step 6: View base schema (with field descriptions)")
  schema <- air_schema(base_id, .token = .token)
  cli::cli_inform("Tables: {.val {schema$table_name}}")
  print(schema)
  results$schema <- schema

  # ---- Step 7: API usage ----------------------------------------------------
  cli::cli_h1("Step 7: API usage")
  usage <- tryCatch(air_api_usage(), error = function(e) NULL)
  if (!is.null(usage)) {
    print(usage)
  } else {
    cli::cli_inform(
      "API usage counter not available (counter disabled or workspace unknown)."
    )
  }
  results["usage"] <- list(usage)

  # ---- Done -----------------------------------------------------------------
  base_url <- paste0("https://airtable.com/", base_id)
  cli::cli_rule("Demo complete")
  cli::cli_inform(
    c(
      "v" = "Base ID: {.val {base_id}}",
      "i" = "Open in browser: {.url {base_url}}",
      "i" = "Clean up: {.url https://airtable.com} (delete base manually)"
    )
  )

  invisible(results)
}


# --- Internal helpers ---------------------------------------------------------

#' Download an image URL to a temp file and upload as an Airtable attachment
#'
#' Separated into its own function so it can be mocked in tests without making
#' real HTTP requests.
#'
#' @param base_id Base ID.
#' @param table_id Table ID.
#' @param project_ids Character vector of created record IDs.
#' @param image_url URL of the image to download and upload.
#' @param .token API token.
#' @return Invisible NULL.
#' @noRd
.demo_upload_image <- function(base_id, table_id, project_ids, image_url,
                                .token = NULL) {
  tryCatch({
    if (length(project_ids) == 0L) return(invisible(NULL))
    tmp_img <- tempfile(fileext = ".jpg")
    on.exit(unlink(tmp_img), add = TRUE)
    httr2::request(image_url) |> httr2::req_perform(path = tmp_img)
    at_upload_attachment(
      base_id   = base_id,
      table_id  = table_id,
      record_id = project_ids[[1L]],
      field_id  = "Files",
      file      = tmp_img,
      token     = .token
    )
  }, error = function(e) {
    cli::cli_warn("Could not upload sample attachment: {conditionMessage(e)}")
  })
  invisible(NULL)
}
