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
#' - **Supporters** table: text, email, date  --  starts empty; [air_demo()] step 3
#'   bulk-writes 120 records to demonstrate the progress bar over 12 batches
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
      "i" = "Theme: BollardsForArt \u2014 creative-arts advocacy nonprofit.",
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

  # --- Build Supporters table config (created with the base) ---------------
  supporters_fields <- list(
    list(name = "Name",   type = "singleLineText"),
    list(name = "Email",  type = "email"),
    list(name = "Joined", type = "date",
         options = list(dateFormat = list(name = "iso"))),
    list(name = "City",   type = "singleLineText")
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
      list(name = "Artists",    fields = artists_fields),
      list(name = "Projects",   fields = projects_fields),
      list(name = "Supporters", fields = supporters_fields),
      list(name = "Grants",     fields = grants_fields)
    ),
    token = .token
  )
  base_id <- new_base$id

  # --- Invite user to open base in browser -----------------------------------
  base_url <- paste0("https://airtable.com/", base_id)
  cli::cli_inform("Base created: {.url {base_url}}")

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
        options  = list(linkedTableId = artists_tbl$id),
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
        options  = list(linkedTableId = projects_tbl$id),
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
      "Fatima El-Rashid",     "Carlos Mendes",       "Ingrid Holm\u00e5s",
      "Kofi Asante",          "Priya Nair",          "Tomasz Wierzbicki",
      "Amara Diallo",         "Hiroshi Nakamura",    "Beatriz Santos",
      "Rashida Osei",         "Luka\u0161 Nova\u010dek",  "Miriam Khoury"
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
      "*" = "Supporters: (empty \u2014 filled by {.fn air_demo} step 3)",
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
#' Runs through canonical airtable2 operations against a BollardsForArt demo
#' base, pausing at each step so you can watch changes appear in the browser.
#' If no `base_id` is provided and none is set as the session default, calls
#' [air_demo_setup()] first.
#'
#' @param base_id Base ID to use. If `NULL`, checks the session default
#'   ([air_set_base()]) and `AIRTABLE_BASE_ID` env var; calls
#'   [air_demo_setup()] if nothing is found.
#' @param workspace_id Passed to [air_demo_setup()] if base creation is needed.
#' @param .token API token (see [air_set_token()]).
#'
#' @details
#' Open the Airtable base in a browser alongside the console. The walkthrough
#' pauses with `<Enter>` prompts whenever you need to switch to a different
#' table, and sleeps two seconds between steps so changes can appear.
#'
#' Steps covered:
#' 1. Read all Artists with a progress bar
#' 2. Write one new artist; read back showing `airtable_created_time`
#' 3. Write 120 community supporters in 12 batches  --  progress bar is clearly
#'    visible; read back over 2 pages to demonstrate read pagination
#' 4. Bulk-upsert 30 artists with a progress bar
#' 5. Sync back to the original 15 with a progress bar (watch deletions)
#' 6. Upsert a new `Engagement Score` column into Artists from R
#' 7. Upload an image attachment to a Project record
#' 8. Link artists to projects via `multipleRecordLinks`
#' 9. Left-join Airtable columns into a local R tibble
#' 10. View the base schema
#' 11. Seed a `_metadata` table with [air_meta_init()], edit table/column names
#'     as rows in Airtable, then apply with [air_meta_sync()]
#' 12. Connect via the DBI interface: [DBI::dbConnect()], [DBI::dbListTables()],
#'     [DBI::dbReadTable()], [DBI::dbWriteTable()]
#' 13. View API usage
#'
#' All operations keyed on `Name` are idempotent; re-running will not
#' accumulate duplicate records.
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
    base_id <- tryCatch(resolve_base_id(NULL), error = function(e) NULL)
  }

  setup_called <- FALSE
  if (is.null(base_id) || !nzchar(base_id)) {
    cli::cli_inform(c(
      "i" = "No base set. Creating a BollardsForArt demo base via {.fn air_demo_setup}.",
      "i" = "This requires {.envvar AIRTABLE_WORKSPACE_ID}."
    ))
    base_id <- air_demo_setup(workspace_id = workspace_id, .token = .token)
    setup_called <- TRUE
  }

  # --- Invite user to open the base in the browser --------------------------
  base_url <- paste0("https://airtable.com/", base_id)
  if (!setup_called) {
    cli::cli_inform(c(
      "i" = "Demo base: {.url {base_url}}",
      "i" = paste0(
        "Open that URL in your browser and arrange the browser and this ",
        "console side by side so you can watch changes happen in real time."
      ),
      "i" = "Navigate to the {.strong Artists} table to start."
    ))
  } else {
    cli::cli_inform("Navigate to the {.strong Artists} table to start.")
  }
  .demo_wait("  Press <Enter> to begin the demo... ")

  results <- list()

  # ---- Step 1: Read with progress bar --------------------------------------
  cli::cli_h1("Step 1: Read all Artists (with progress bar)")
  .demo_code('air_read("Artists", base_id, progress = TRUE)')
  .demo_sleep()
  artists <- air_read("Artists", base_id, progress = TRUE, .token = .token)
  .demo_print(artists, c("Name", "Role", "Active", "Member Since"))
  results$read <- artists

  # ---- Step 2: Write one new artist ----------------------------------------
  .demo_sleep()
  cli::cli_h1("Step 2: Write one new artist")
  cli::cli_inform(
    "Watch {.strong Artists} \u2014 {.val Demo Artist} will appear with today's created time."
  )
  .demo_code('air_write(new_artist, "Artists", base_id, typecast = TRUE)')
  .demo_wait()
  air_write(
    tibble::tibble(
      Name          = "Demo Artist",
      Role          = "Community Arts Agitator",
      Active        = TRUE,
      `Member Since` = Sys.Date()
    ),
    "Artists", base_id, typecast = TRUE, .token = .token
  )
  .demo_sleep()
  after_write <- air_read("Artists", base_id, .token = .token)
  .demo_print(after_write, c("Name", "Role", "airtable_created_time"))
  results$write <- after_write

  # ---- Step 3: Write 120 supporters (progress bar over many batches) ------
  .demo_sleep()
  cli::cli_h1("Step 3: Write 120 community supporters (with progress bar)")
  cli::cli_inform(c(
    "i" = "Switch to the {.strong Supporters} table.",
    "i" = paste0(
      "Watch the table and the console \u2014 120 records will be written ",
      "in 12 batches of 10, making the progress bar clearly visible."
    )
  ))
  .demo_code('air_write(.demo_supporters(), "Supporters", base_id, progress = TRUE)')
  .demo_wait("  Press <Enter> (switching to Supporters table)... ")
  supporter_ids <- tryCatch(
    air_write(
      .demo_supporters(), "Supporters", base_id,
      typecast = TRUE, progress = TRUE, .token = .token
    ),
    error = function(e) {
      cli::cli_warn("Could not write supporters: {conditionMessage(e)}")
      character()
    }
  )
  if (length(supporter_ids) > 0L) {
    .demo_sleep()
    cli::cli_inform(
      "Reading back all 120 supporters across 2 pages of 100 (watch the progress bar)..."
    )
    .demo_code('air_read("Supporters", base_id, progress = TRUE)')
    supporters <- air_read("Supporters", base_id, progress = TRUE, .token = .token)
    .demo_print(supporters, c("Name", "City", "Joined"))
    results$supporters <- supporters
  }

  # ---- Step 4: Bulk upsert 30 artists with progress bar -------------------
  .demo_sleep()
  cli::cli_h1("Step 4: Bulk-upsert 30 artists (with progress bar)")
  cli::cli_inform(
    "Watch {.strong Artists} \u2014 15 rows update, ~15 new rows appear."
  )
  .demo_code('air_upsert(artists_30, "Artists", merge_on = "Name", progress = TRUE)')
  .demo_wait()
  results$upsert <- air_upsert(
    .demo_artists(), "Artists",
    merge_on = "Name", base_id = base_id,
    typecast = TRUE, progress = TRUE, .token = .token
  )
  .demo_sleep()
  after_upsert <- air_read("Artists", base_id, .token = .token)
  .demo_print(after_upsert, c("Name", "Role", "airtable_created_time"))

  # ---- Step 5: Sync back to original 15 with progress bar -----------------
  .demo_sleep()
  cli::cli_h1("Step 5: Sync back to original 15 (with progress bar)")
  cli::cli_inform(
    "Watch {.strong Artists} \u2014 the extra rows will be deleted."
  )
  .demo_code('air_sync(original_artists, "Artists", key = "Name", progress = TRUE)')
  .demo_wait()
  orig <- artists[setdiff(names(artists), c("airtable_id", "airtable_created_time"))]
  results$sync <- air_sync(
    orig, "Artists",
    key = "Name", base_id = base_id,
    typecast = TRUE, progress = TRUE, .token = .token
  )

  # ---- Step 6: Upsert a new column from R ----------------------------------
  .demo_sleep()
  cli::cli_h1("Step 6: Push a new column from R into Airtable")
  cli::cli_inform(
    "Watch {.strong Artists} \u2014 an {.field Engagement Score} column will appear."
  )
  .demo_code('air_upsert(scores, "Artists", merge_on = "Name", add_fields = "yes")')
  .demo_wait()
  air_upsert(
    .demo_scores(), "Artists",
    merge_on = "Name", base_id = base_id,
    add_fields = "yes", typecast = TRUE, .token = .token
  )
  .demo_sleep()
  after_score <- air_read("Artists", base_id, .token = .token)
  .demo_print(after_score, c("Name", "Engagement Score", "airtable_created_time"))

  # ---- Step 7: Attachments  --  read existing, then add one via URL -----------
  .demo_sleep()
  cli::cli_h1("Step 7: Attachments")
  cli::cli_inform(c(
    "i" = "Switch to the {.strong Projects} table.",
    "i" = paste0(
      "Watch the {.field Files} column \u2014 a second image will be added ",
      "to the first project via {.fn air_upsert}."
    )
  ))
  .demo_wait("  Press <Enter> (switching to Projects table)... ")
  .demo_code('projects <- air_read("Projects", base_id)')
  projects <- air_read("Projects", base_id, .token = .token)
  .demo_print(projects, c("Project Name", "Files", "airtable_created_time"))

  if (nrow(projects) > 0L) {
    first_proj  <- projects$`Project Name`[[1L]]
    new_img_url <- "https://picsum.photos/seed/demo-attach2/640/480"
    .demo_code(
      'air_upsert(\n  tibble(Project Name = first_proj, Files = list(list(url = new_img_url))),\n  "Projects", merge_on = "Project Name"\n)'
    )
    cli::cli_inform(
      "Adding second image to {.val {first_proj}} via URL attachment..."
    )
    tryCatch(
      air_upsert(
        tibble::tibble(
          `Project Name` = first_proj,
          Files          = list(list(list(url = new_img_url)))
        ),
        "Projects", base_id,
        merge_on = "Project Name", typecast = TRUE, .token = .token
      ),
      error = function(e) cli::cli_warn("Could not add attachment: {conditionMessage(e)}")
    )
    .demo_sleep()
    after_att <- air_read("Projects", base_id, .token = .token)
    if (!is.null(first_proj) && "Project Name" %in% names(after_att)) {
      row1 <- after_att[after_att$`Project Name` == first_proj, ]
      n_att <- length(row1$Files[[1L]])
      cli::cli_inform(
        "{.val {first_proj}} now has {n_att} attachment{?s} \u2014 check the {.field Files} column in the browser."
      )
    }
  }
  results$projects <- projects

  # ---- Step 8: Link artists to projects ------------------------------------
  .demo_sleep()
  cli::cli_h1("Step 8: Link artists to projects")
  cli::cli_inform(
    "Watch {.strong Projects} \u2014 {.field Lead Artist} cells will populate."
  )
  .demo_code('air_upsert(link_data, "Projects", merge_on = "Project Name")')
  .demo_wait()
  artists_now <- air_read("Artists", base_id, .token = .token)
  n_link <- min(5L, nrow(artists_now), nrow(projects))
  link_data <- tibble::tibble(
    `Project Name` = projects$`Project Name`[seq_len(n_link)],
    `Lead Artist`  = lapply(
      artists_now$airtable_id[seq_len(n_link)],
      function(id) new_air_links(list(id))
    )
  )
  results$links <- air_upsert(
    link_data, "Projects",
    merge_on = "Project Name", base_id = base_id,
    typecast = TRUE, .token = .token
  )
  .demo_sleep()
  linked <- air_read("Projects", base_id, .token = .token)
  .demo_print(linked, c("Project Name", "Lead Artist", "airtable_created_time"))

  # ---- Step 9: Left-join Airtable data into a local R tibble --------------
  .demo_sleep()
  cli::cli_h1("Step 9: Left-join local data with Artists")
  cli::cli_inform(
    "Joining local workshop hours with Artists \u2014 Role and Active pulled from Airtable."
  )
  .demo_code('air_left_join(local_hours, "Artists", base_id, by = "Name")')
  local_hours <- tibble::tibble(
    Name            = c("Zara Okonkwo", "Dmitri Volkov", "Sun-Li Park",
                        "Fatima El-Rashid", "Carlos Mendes", "Ingrid Holm\u00e5s"),
    `Workshop Hours` = c(12L, 8L, 15L, 10L, 6L, 14L)
  )
  joined <- air_left_join(local_hours, "Artists", base_id, by = "Name", .token = .token)
  .demo_print(joined, c("Name", "Workshop Hours", "Role", "Active"))
  results$join <- joined

  # ---- Step 10: Schema -------------------------------------------------------
  .demo_sleep()
  cli::cli_h1("Step 10: Field metadata")
  .demo_code("air_meta(base_id)")
  schema <- air_meta(base_id, .token = .token)
  .demo_print(schema, c("table_name", "field_name", "field_type"))
  results$schema <- schema

  # ---- Step 11: air_meta_init + air_meta_sync ---------------------------------
  .demo_sleep()
  cli::cli_h1("Step 11: Seed and sync field metadata")
  cli::cli_inform(c(
    "i" = paste0(
      "Watch the base navigation \u2014 a new {.strong _metadata} table is about ",
      "to appear, seeded from the live schema."
    )
  ))
  .demo_code("air_meta_init(base_id)")
  .demo_wait("  Press <Enter> to create and seed _metadata... ")
  air_meta_init(base_id, .token = .token)

  cli::cli_inform(c(
    "i" = "Switch to the {.strong _metadata} table \u2014 every field in the base",
    "i" = "is now a row you can edit directly in Airtable.",
    "i" = paste0(
      "We will rename the {.strong Grants} table to ",
      "{.strong Grants & Funding} and rename the {.field Age} column to ",
      "{.field Age (years)} by editing rows here, then calling {.fn air_meta_sync}."
    )
  ))
  .demo_wait("  Press <Enter> once you are viewing _metadata... ")

  # Read _metadata back so we can upsert the edits into it
  meta_now  <- air_read("_metadata", base_id, .token = .token)
  .demo_print(meta_now, c("table_name", "field_name", "field_type", "description"))

  meta_edit <- meta_now
  grants_rows <- !is.na(meta_edit$table_name) & meta_edit$table_name == "Grants"
  age_row     <- !is.na(meta_edit$field_name) &
                 meta_edit$table_name == "Artists" & meta_edit$field_name == "Age"
  if (any(grants_rows)) {
    meta_edit$table_name[grants_rows] <- "Grants & Funding"
  }
  if (any(age_row)) {
    meta_edit$field_name[age_row]  <- "Age (years)"
    meta_edit$description[age_row] <- "Age of the artist in whole years."
  }

  edit_rows <- if (length(grants_rows) && length(age_row)) grants_rows | age_row else logical(0)
  cli::cli_inform(
    "Watch {.strong _metadata} \u2014 {sum(edit_rows)} rows updating..."
  )
  .demo_wait()
  if (any(edit_rows)) {
    air_upsert(
      meta_edit[edit_rows, ], "_metadata", base_id,
      merge_on = "meta_key", add_fields = "warn", typecast = TRUE, .token = .token
    )
  }

  .demo_sleep()
  cli::cli_inform(c(
    "i" = "Applying schema changes with {.fn air_meta_sync}...",
    "i" = paste0(
      "Watch the base navigation \u2014 {.strong Grants} will become ",
      "{.strong Grants & Funding}."
    )
  ))
  .demo_code("air_meta_sync(base_id)")
  .demo_wait()
  air_meta_sync(base_id, .token = .token)
  cli::cli_inform(
    "Done \u2014 {.strong Grants} is now {.strong Grants & Funding} and {.field Age (years)} is the new column name in Artists."
  )
  results$meta_sync <- meta_edit

  # ---- Step 12: DBI interface -----------------------------------------------
  .demo_sleep()
  cli::cli_h1("Step 12: DBI interface")
  cli::cli_inform(c(
    "i" = "Switch back to the {.strong Artists} table.",
    "i" = paste0(
      "airtable2 implements the DBI interface \u2014 {.fn dbConnect}, ",
      "{.fn dbListTables}, {.fn dbReadTable}, and {.fn dbWriteTable} all work."
    )
  ))
  .demo_wait("  Press <Enter> (switching back to Artists)... ")

  .demo_code("con <- DBI::dbConnect(airtable2::airtable2(), base_id = base_id)")
  con <- tryCatch(
    DBI::dbConnect(airtable2(), base_id = base_id, .token = .token),
    error = function(e) {
      cli::cli_warn("Could not open DBI connection: {conditionMessage(e)}")
      NULL
    }
  )

  if (!is.null(con)) {
    .demo_code("DBI::dbListTables(con)")
    tbls <- tryCatch(DBI::dbListTables(con),
                     error = function(e) { cli::cli_warn("dbListTables: {conditionMessage(e)}"); character() })
    cli::cli_inform("Tables: {.val {tbls}}")

    .demo_code('DBI::dbListFields(con, "Artists")')
    flds <- tryCatch(DBI::dbListFields(con, "Artists"),
                     error = function(e) { cli::cli_warn("dbListFields: {conditionMessage(e)}"); character() })
    cli::cli_inform("Artists fields: {.val {flds}}")

    .demo_code('DBI::dbReadTable(con, "Artists")')
    .demo_sleep()
    artists_dbi <- tryCatch(DBI::dbReadTable(con, "Artists"), error = function(e) NULL)
    if (!is.null(artists_dbi)) {
      .demo_print(artists_dbi, c("Name", "Role", "Active", "Engagement Score"))
    }

    .demo_code('DBI::dbWriteTable(con, "Artists", new_row, append = TRUE)')
    cli::cli_inform("Watch {.strong Artists} \u2014 a DBI-written row will appear.")
    .demo_wait()
    new_dbi_row <- tibble::tibble(
      Name = "DBI Artist", Role = "Street Typographer", Active = TRUE,
      `Member Since` = Sys.Date()
    )
    tryCatch(
      DBI::dbWriteTable(con, "Artists", new_dbi_row, append = TRUE),
      error = function(e) cli::cli_warn("dbWriteTable: {conditionMessage(e)}")
    )

    .demo_code("DBI::dbDisconnect(con)")
    DBI::dbDisconnect(con)
    results$dbi_con <- TRUE
  }

  # ---- Step 13: API usage ---------------------------------------------------
  .demo_sleep()
  cli::cli_h1("Step 13: API usage")
  .demo_code("air_api_usage()")
  usage <- tryCatch(air_api_usage(), error = function(e) NULL)
  if (!is.null(usage)) {
    print(usage)
  } else {
    cli::cli_inform("API usage not available (counter disabled or workspace unknown).")
  }
  results["usage"] <- list(usage)

  # ---- Done -----------------------------------------------------------------
  cli::cli_rule("Demo complete")
  cli::cli_inform(c(
    "v" = "Base ID: {.val {base_id}}",
    "i" = "Open in browser: {.url {base_url}}",
    "i" = "Clean up: {.url https://airtable.com} (delete base manually)"
  ))

  in_ide <- Sys.getenv("RSTUDIO") == "1" || Sys.getenv("POSITRON") == "1"
  if (in_ide) {
    cli::cli_inform("Opening base in the Connections pane via {.fn air_pane}.")
    tryCatch(
      air_pane(base = base_id, .token = .token),
      error = function(e) {
        cli::cli_warn("Could not open connection pane: {conditionMessage(e)}")
      }
    )
  }

  invisible(results)
}


# --- Internal helpers ---------------------------------------------------------

#' Pause for Enter in interactive sessions
#' @noRd
.demo_wait <- function(prompt = "  Press <Enter> to continue... ") {
  if (interactive()) readline(prompt = prompt)
  invisible(NULL)
}

#' Two-second pause between demo steps
#' @noRd
.demo_sleep <- function() Sys.sleep(2)

#' Print a narrow slice of a data frame (up to 4 columns)
#' @noRd
.demo_print <- function(df, cols) {
  print(df[intersect(cols, names(df))])
}

#' Echo an R expression as a code block before it runs
#' @noRd
.demo_code <- function(code) {
  cli::cli_code(code)
}

#' Generate 120 BollardsForArt supporter records procedurally (4 columns)
#'
#' LCM(20 firsts, 26 lasts) = 260 > 120, so all 120 Name values are unique.
#' @noRd
.demo_supporters <- function() {
  firsts <- c(
    "Ada", "Ben", "Cara", "Dan", "Eli", "Flo", "Gil", "Hana", "Ira", "Joy",
    "Kai", "Lena", "Max", "Nia", "Omar", "Paz", "Quinn", "Ren", "Sage", "Tae"
  )
  lasts <- c(
    "Adeyemi", "Berg", "Chen", "Dubois", "Evans", "Ferreira", "Gao", "Hansen",
    "Ibrahim", "Johansson", "Kim", "Lopez", "Musa", "Nguyen", "Olsen",
    "Petersen", "Qian", "Russo", "Silva", "Torres", "Ueda", "Vasquez",
    "Wang", "Xavier", "Yamamoto", "Zaitsev"
  )
  cities <- c(
    "Detroit", "Oakland", "Philadelphia", "New Orleans", "Baltimore",
    "Cleveland", "Memphis", "Atlanta", "Louisville", "St. Louis"
  )
  n <- 120L
  idx <- seq_len(n)
  tibble::tibble(
    Name   = paste(
      firsts[(idx - 1L) %% length(firsts) + 1L],
      lasts[(idx - 1L)  %% length(lasts) + 1L]
    ),
    Email  = paste0(
      tolower(firsts[(idx - 1L) %% length(firsts) + 1L]),
      idx, "@community.bollardsforart.org"
    ),
    Joined = as.Date("2020-01-01") + (idx - 1L) * 11L,
    City   = cities[(idx - 1L) %% length(cities) + 1L]
  )
}

#' Generate 30 BollardsForArt artist records procedurally (4 columns)
#' @noRd
.demo_artists <- function() {
  first <- c(
    "Zara",    "Dmitri",  "Sun-Li",  "Fatima",  "Carlos",
    "Ingrid",  "Kofi",    "Priya",   "Tomasz",  "Amara",
    "Hiroshi", "Beatriz", "Rashida", "Luka\u0161",   "Miriam",
    "Xavier",  "Aisha",   "Piotr",   "Yuki",    "Leila",
    "Nadia",   "Elan",    "Rosa",    "Obi",     "Cleo",
    "Sven",    "Tamar",   "Felix",   "Yara",    "Joaquin"
  )
  last <- c(
    "Okonkwo",   "Volkov",      "Park",        "El-Rashid",  "Mendes",
    "Holm\u00e5s",    "Asante",      "Nair",        "Wierzbicki", "Diallo",
    "Nakamura",  "Santos",      "Osei",        "Nova\u010dek",    "Khoury",
    "Fontaine",  "Bakr",        "Kowalski",    "Tanaka",     "Ahmadi",
    "Petrov",    "Reyes",       "Abramowitz",  "Okafor",     "Marchetti",
    "Lindqvist", "Cohen",       "M\u00fcller",      "Hassan",     "Lima"
  )
  roles <- c(
    "Guerilla Muralist",          "Kinetic Sculptor",
    "Sound Installation Designer","Community Arts Agitator",
    "Concrete Poet",              "Site-Specific Weaver",
    "Light & Shadow Artist",      "Street Typographer"
  )
  n <- length(first)
  tibble::tibble(
    Name          = paste(first, last),
    Role          = roles[(seq_len(n) - 1L) %% length(roles) + 1L],
    Active        = rep(c(TRUE, TRUE, FALSE), length.out = n),
    `Member Since` = as.Date("2015-01-01") + (seq_len(n) - 1L) * 87L
  )
}

#' Local engagement scores for 8 artists (used for upsert + join demos)
#' @noRd
.demo_scores <- function() {
  tibble::tibble(
    Name               = c(
      "Zara Okonkwo",    "Dmitri Volkov",  "Sun-Li Park",
      "Fatima El-Rashid","Carlos Mendes",  "Ingrid Holm\u00e5s",
      "Kofi Asante",     "Priya Nair"
    ),
    `Engagement Score` = c(98L, 85L, 92L, 88L, 74L, 95L, 81L, 90L)
  )
}

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
  if (length(project_ids) == 0L) return(FALSE)
  tryCatch({
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
    TRUE
  }, error = function(e) {
    cli::cli_warn("Could not upload sample attachment: {conditionMessage(e)}")
    FALSE
  })
}
