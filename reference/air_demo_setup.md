# Set up a demo Airtable base for exploration

Creates a new Airtable base with tables and sample records that exercise
all the key field types and airtable2 features. The demo base is themed
around **BollardsForArt**, a fictional creative-arts advocacy nonprofit
that installs unauthorized public art, fights for arts funding, runs
community workshops, and tracks their campaigns and artists.

## Usage

``` r
air_demo_setup(
  workspace_id = Sys.getenv("AIRTABLE_WORKSPACE_ID"),
  name = "bollardsforart_demo",
  .token = NULL
)
```

## Arguments

- workspace_id:

  Workspace ID (defaults to AIRTABLE_WORKSPACE_ID env var). Find yours
  in the browser URL: `https://airtable.com/wspXXXXX/...`

- name:

  Base name (default: `"bollardsforart_demo"`).

- .token:

  API token (see
  [`air_set_token()`](https://noamross.github.io/airtable2/reference/air_set_token.md)).

## Value

The base ID (invisibly). Prints a summary of what was created.

## Details

The demo base contains:

- **Artists** table: text, number, checkbox, single/multi-select, date,
  email (15+ rows with diverse international artists)

- **Projects** table: text, number, date, single-select, attachments,
  linked records to Artists (15+ rows with imaginative installation
  names)

- **Supporters** table: text, email, date – starts empty;
  [`air_demo()`](https://noamross.github.io/airtable2/reference/air_demo.md)
  step 3 bulk-writes 120 records to demonstrate the progress bar over 12
  batches

- **Grants** table: text, number, date, single-select, linked records to
  Projects (15+ rows of funding sources and applications)

Fields include descriptions (column metadata) set via
[`at_update_field()`](https://noamross.github.io/airtable2/reference/at_update_field.md).
Project records have image attachments uploaded via
[`at_upload_attachment()`](https://noamross.github.io/airtable2/reference/at_upload_attachment.md).
Linked-records fields connect Projects to Artists and Grants to
Projects.

This function creates a real Airtable base and consumes several API
calls. The base cannot be deleted via the API on free/team-tier
accounts; clean up manually via the Airtable web interface.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires AIRTABLE_WORKSPACE_ID and AIRTABLE_API_KEY env vars
base_id <- air_demo_setup()
air_set_base(base_id)
air_read("Artists")
} # }
```
