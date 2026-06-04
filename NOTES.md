
**REFACTOR PHASE I: COMPLETE**

We are going to do a major refactor of this package, sufficient that we may rename it to airtable2

First it should wrap all API functions of the AirTable web API that are available to non-enterprise plans: https://airtable.com/developers/web/api/ .
We only have a team-level plan so that's the priority. Existing functions that do hit the enterprise level can be updated.

The current version uses httr, we will upgrade everything to httr2.  It should have robust testing.

It should have near drop-in level replacements for all current functionality built over new base API wrapper functions.  We want the same functionality and for it to be easy to swap,
but the new package should have consistent API design and ergonomics.

It should be smart about API limitations and pagination to improve speed of bulk processes.

One priority is good upload functionality - upsert, which has its own API point, and sync - uploading a news verison of a table smartly upserting, deleting, and leaving as-is as needed.
When upserting or syncing, you should be able to add a column (e.g. have columns not previously in the data), and have it work, maybe emitting a warning or an error if an argument isn't added.

There should be a function to create a table template/specification from a tibble or data frame.

It should be easy to create and change a base by pushing data up to it.

We will create a DBI-compliant interface for interacting with AirTable as much as possible given it is not an SQL interface. It should be similar in design to the RD1 package I recently wrote (https://github.com/noamross/RD1). It should have the option of mounting a base, or a whole workspace with bases as schema.  This is really because I want to view the whole workpace in the Positron/Rstudio connection pane and browse tables.

There should be good and sensible options for dealing with special types, including the airtable record (generally airtable_id in any data frame pulled), attachments, linked records,
multi-select, and complex types like users. Consider list-columns, but with special print methods or different outputs in connection pane previews.  Previews should limit themselves
to a single call rather than paginating.

Review all outstanding issues and PRs at https://github.com/One-Health-Research-Consulting/airtabler/, determine how the above will or will not address them, and add outstanding issues
or finishing/incorporating PRs into your plan. 

Include testing in your iterative development. Skip internet-connection based testing on CRAN.  

AIRTABLE_API_KEY with all scopes for a free workspace has been added to .Renviron. If your testing requires access to more workspaces or features in higher-level plans, request and
include a plan for safety and security.  Add httr2/testthat v3 mocking as appropriate, but CI can make use of a free workspace token like the current one just for testing so it's not
a super high priority to test without a token.

Make use of your skills: /r-package-development, /testing-r-packages, /cli, /tdd-workflow

Review the current code, make a plan for all of this in this directory, lay out several phases of work, ask for approval, make sure you are set up to save memory frequently at checkpoints in incorporate new requests. 


---

**REFACTOR PHASE I: LARGELY COMPLETE**

You are taking over from a previous chat, still cleaning up some last items from previous phase 3. Look at the following list of TODOs, integrate them
into the plan in AGENTS.md, then proceed with the plan. As you proceed, update AGENTS.md and .agents/ files. 

Check R/zzz.R to ensure all new pillar_shaft and type_sum methods are being correctly registered with s3_register().
Run the tests in tests/testthat/test-types.R and test-dbi.R to verify the new pillar display and label attributes.
Run all tests and fix failing ones.

Implement as much of the DBI suite as makes sense, noting you can't actually run SQL.  Get rid of the extra methods.  Consolidate down
the help files for the DBI connection methods to one for connection with a description describing its limitations. 
Implement as much of the DBItest suite as makes sense.
Look at ~/Projects/Other/RD1 to see strategies for testing the connection pane, it seems to be broken. 

Implement labels. Data fetched via low and high-level APIs, DBI, and especially in preview pane, should have $label attributes that 
display in the data explorer panes in RStudio and Positron. These should be the description fields from the base schema.
Look at ~/Projects/Other/RD1 for implementation of budgets and anything undone in the connection pane. 

Add an air_browse() function to open a browser with a given workspace, base, table, or view.

Add buttons to the RStudio connection pane: browse to the table or workspace, create a new base in the workspace (launch a dialog for a name and description).  We can fit up to four
workspace/base-level operations, consider functions at this level and list good options. 

air_dump and air_restore should have csv options that flatten and unflatten fields.

Add an startup message in case airtabler and airtable2 are loaded in the same session warning that many function names overlap. 

Functions that can take either a base or a workspace, like those in connections, should have the argument `id` and resolve if it is a base or a workspace
by its contents wspXXXXXXXXXXXX for workspace, appXXXXXXXXXXXX for base. Note there are tblXXXXXXXXXXXX for tables and viwXXXXXXXXXXXX for views.
Look at ?airtabler::air_get_id_from_url for similar utilies. Have the reverse functions (internal) to support air_browse()
Functions that take workspace or base ids should also take connection objects and extract the relevant id.
Uploading functions (air_write/upsert/sync) should have the data frame to be uploaded as their first argument.  Uploading arguments (at_upload/update*) should have their upload object first.  at_create_* should have the name of the new thing first. 
Review function signatures for consistency in ordering and names. For instance some have a period before token, some don't. Ensure progress bar arguments are consistent.

Use @inheritParams to document common arguments. However, note they don't mean the same thing everywhere - attachments and attachment_dir should have different descriptions for uploads
and downloads.
Consolidate some help files, like air_dump and air_restore into one file. Also the air_*_template and at_create_field.  The DBI methods.
Do not generate help for internal functions like air_req.

Connection objects should have nice show method that show the name and description and a {cli}-clickable URL to go to the workspace or base.

For functions that paginate, (air_read/write/upsert/sync, etc.) add {cli} progress bars that appear after a few seconds and show progress, changing to show if they are moving between steps (uploading/upserting/deleting).  Whether there is a progress bar should be an argument and fall back to an option (airtable2.progress.bar) or env var (AIRTABLE2_PROGRESS_BAR).

Add view support. Wrap the low-level view API endpoints listing and metadata records. 
For connections, have include_views = FALSE as an argument.  TRUE includes grid-type views so they display in the connection pane with the name table:view.
Internally we handle views by fetching the table filtered to the view's records and fields and sorted as it is. 

Make sure air_write and similar write functions can add a new column if they have new data. Give them all an argument that errors by default if they don't match the columns of
the existing table, but when turned off just adds new columns.  It should still error if they have columns with the same name and a different type. 

Make airtable() and at() alias's for the airtable2() driver.

Review upsert/sync functions to ensure the minimum number of API calls are made and they upload efficiently. They should also be able to add columns to the data with the same options, though this will require
uploading for every record.  Add air_join functions, which adds new columns/fields only, by adding new field(s) to the table and uploading only the new fields that match by airtable_id or primary key. This can be air_left_join(table = "Airtable Table Name or ID", df = df, by = c("airtable_id", "primary_key")), air_inner_join, which also deletes the airtable's rows, air_outer_join, which adds new rows with non-matching keys and the new columns. These can all be described in one help file. 

Do a review of functionality across similar functions in https://github.com/One-Health-Research-Consulting/airtabler/ (and open PRs) and check that we have all the equivalent
functionality (aside from things that cover other services/software like ODK, excel, and deposits)

Run covr::package_coverage and identify areas to cover with more tests. Be sure that test coverage is high for both live and mocked tests.

Generate a couple of bases of false data to live in the workspace you have access to that I use for user-testing of all the ergonomics of the package.
They should contain all relevant types so we can see how they print, have connection methods, table and column-level descriptive metadata, etc.
They will be used for the vignettes.  You should generate the schema and data and store them as data in the package, so you have a set-up function that 
uploads them to the workspace.  This will be exported so it can be used for the vignette.  At least one table should be long enough for pagination. There should
be some links between records. In these data and in all examples in the package, have the norm of snake_case column names.

Write a vignette, the README.md, CONTRIBUTING.md, NEWS.md and other package-level documentation to be read on the web.  DO NOT COMMIT, these will have considerable human revision.

The vignette should be a fairly comprehensive walk-through of high-level functions. Suggest walking through running the code rather than just reading.
Start by telling them to set up a token and tell them how and where (https://airtable.com/create/tokens). The vignette will walk them through all functions on a new
AirTable, so suggest they make a token with sufficient scopes, under a new free workspace with only permissions for that workspace in case they want to protect any other work from it.
Have them open a browser window with the workspace open so they can watch changes. Have them run the fake data set-up function and see the bases created, then open the bases to see
them change as you run through functions.  Have a section for RStudio/Positron users about the connection pane. Walk them through read, write, upsert, sync, etc. to see changes in the database in
the browser and pane, click on the preview button to view databases. Have them fetch the metadata and then upload it as a new table.  Have them run a few low-level functions like updating
a field and at_whoami.

A second vignette should walk thorugh attachments (including uploading and downloading), other special types and conversions (multi-select), and cross-reference fields, including how you
can programatically link records. Show printing of these types, and how you can upload the simpler forms (delimited strings for multi-select, emails, names, or ids for collaborators, etc.). 

Another short one can be about best practices: schema/meta data, download and restore. 

Create a function, air_demo(), which prints a message to open a browser and position it so you can see the console and browser at the same time, if interactive, waits for the user to hit enter, then creates new databases,
air_browses to them, and plays a demo of most of the functions in both the vignettes, printing out the commands as they run with a little pause between each. If credentials are not available, print an error an abort with a long message about how to set them up. It should detect if you are in RStudio/Positron and if so,
open connections panes as well. (And update the pane when changes occur).  In the README, say something like, "For a tour of functions in the package, walk through the introduction vignette or run `air_demo()` once you have set up your credentials. In the vignette, after the first paragraph, add a similar line. "We recommend walking through the code in this
vignette line-by-line with a browser open to the AirTable database, or run `air_demo()`. air_demo() can have an argument `autoplay=TRUE`, to ask whether to have the user hit enter 
for each next step or just proceed after a pause. Actually, can be a prompt for the user by default, so NULL by default for a prompt, TRUE for play, FALSE for user hits enter for each next step. Asked after the credential check/error.  Make this work as if a screen recording of the console and browser side by side were being made for the demo.  Print at the end that
the user needs to delete the databases.  For the demo functions run, just have a script in inst/demo and function that parses it, prints each line, pauses and runs, wrapped around that is the function that prompts the user and checks credentials. At the start and end of the demo use the counter accessor to print the API calls made.

Review the package for best
practices from devguide.ropensci.org. Run pkgcheck::pkgcheck() and fix issues found there. 

Skip the claude skill, a good LLM should do well enough with documentation.

As always keep the docs in AGENTS.md and under .agents/ up-to-date periodically with each step you implement.

---

**ADDITIONAL TODOs: COMPLETE**

Enable and document a workflow of setting workspace ID as an environment variable, so base/table lookups by name default to that.
If something errors because the base cannot be found, have the error emit a clear message indicating the missing base and suggesting the user set the environment variable,
printing current workspace name/base if used, current user name of token. 
Implement a probe function to (SAFELY!) test what current token permissions are and what workspaces and bases can be accessed. Something like at_sitrep().  Suggest it in error messages.

---

**ADDITIONAL TODOs: COMPLETE**
rename at_token_check to at_sitrep(). Model its messages after usethis::git_sitrep() and usethis::proj_sitrep().  Be sure to mention it in the vignette and show it in the air_demo()

Allow for parallel uploads and downloads when uploading or downloading attachmentss using httr2's req_perform_parallel(), for both blobs and files (using the paths= argument so all files
aren't held in memory if not needed). Have arguments for parallelism in attachment functions
and to pass through to other fetching and uploading functions, falling back to an option/environent variable.  Definitely make some tests for this, including many small files and a few big files conditions, to ensure that throttling works properly in this situation and we don't get 429s.  Test multipart uploads, in parallel and not.

---
**ADDITIONAL TODOs: THIS IS NEXT**

Below are a series of areas to address. Note that several different agents and models of different quality and capability have recently worked on the code so there may be inconsistencies in the current code base.

First, we must address a very important issue - the AirTable API has a limit of 1000 calls/per month per workspace on a free plan, which we have already passed. I have changed to a new workspace in the interim, but we don't have an infinite limit for testing  so we need the following:
 - I have added the environmental AIRTABLE_TEST_LIVE=false to .Renviron. Change the tests so this must be TRUE for any tests that hit the API, otherwise we use mocked tests.
 - For current iterations, mocked tests only as much as possible, and request a change in that variable for live testing. Favor fetching the API response models from the docs over making calls.
 - Implement an internal API counter for the package of API calls for a workspace per month. We cannot fetch the total count, but implement a per-workspace. Do this by putting a count file under
    file.path(tools::R_user_dir("airtable2", "data"), "{WORKSPACE_NAME}") which records the count and the most recent API hit time.  Until we know better, restart it at 00:00 UTC at the start of
    the month.  Include this count "X API calls since start of month", in workspace-level print/how functions. Create an accessor function to fetch this, which should return a list of
    the count and `since` time and `last`, time, with of course a has a nice cli print function. 
 - Audit both test functions and main functions for efficient use of API calls. What doesn't have to repeat, shouldn't. Batched endpoints for creating, deleting, updating records should be used.
 - Can we cache more? We can make use of httr2::req_cache, but data may change upstream. The only specific check we can do is on the individual table - we can get the most recent modified
   record by making a call to https://airtable.com/developers/web/api/list-records, sorting and filtering to get the most recent record. See if there are any likely applications in the pacakage. 


Following that, here are big next steps:

Critical next phase is consolidation.  Defer additional documentation and features. Run all tests. Note issues below and fix them, using test-driven development, but with mocked tests,
and then surgical live tests with approval.
Check function documentation, implementation, and description in the AGENTS.md, ./.agents/architecture.md, ./.agents/decisions.md are consistent and tests actually cover what they describe and should.  Check that completed items in AGENTS.md are truly completed and tested in both live and mocked environments.  Answer
outstanding questions and remove them from agent documentations if complete. Identify any functionality gaps with  `airtabler` (within scope) and add to TODO in the AGENTS.md file. Review all function signatures for consistency in argument naming and meaning, consistent patterns where data to upload is first argument for upload function, table to be operated on or donwloaded from is the first argument for download and join functions, etc.  Identify untested functionality. Run covr::package_coverage to identify untested code paths, and make useful tests for them, not just ones that increase coverage. DRY out code.  Use dupree::dupree_package(".") to identify potential duplicate code. 

Now here is a list of important specifics to address:

at_sitrep should have a nice {cli} print function.  It prints scopes as NULL.  It does not show visible workspaces, or message that workspaces can't be identified. Can workspaces be
identified?

bases in a default workspace are not being listed in at_sitrep or the connection pane.

There should be a basic function list bases in a workspace.

> air_connect('apprLj9o1ETSoCD4q')
<AirtableConnection>
  Base:   apprLj9o1ETSoCD4q
  Base ID:apprLj9o1ETSoCD4q
  URL:    https://airtable.com/apprLj9o1ETSoCD4q
  Valid:  TRUE
> x <- air_connect('apprLj9o1ETSoCD4q')
> dbListTables(x)
Error in `httr2::req_perform()` at airtable2/R/client.R:65:3:
! HTTP 403 Forbidden.

The connection pane should show the full base name AND the full base name and ID. e.g. "AirTable Base: airtable_test_schema (appTNgO9vXM5j7KsI)" or "AirTable Workspace: airtable2 (wspNeeRLIGP7YAfO8)", or just "AirTable Workspace (wspNeeRLIGP7YAfO8)" if you don't have the workspace name but the ID was provided by the user. 

air_connect() as well as other functions that take base id or workspace id should just take id or connnection object and resolve what it is, falling back to the set base/workspace default option/env var. The pane should not open and connect should fail if the workspace or base isn't available is not available with current credentials.

The connection object print method should use cli.  All print methods that include bases or workspaces should use cli for consistent formatting. When printing a workspace or base,
print both like "Base: airtable_test_schema (appTNgO9vXM5j7KsI)",or "AirTable Workspace: airtable2 (wspNeeRLIGP7YAfO8)", or just "AirTable Workspace (wspNeeRLIGP7YAfO8)". Similarly is there is a reason to print a table or view.  All of these should use cli hyperlink support if available to make a clickable link to the Airtable interface in the browser.

air_browse() should use the default workspace or base ID.  It should allow for full names as well as IDs. All similar functions should that take base or workspace id should do this, too.
Make a common function for resolving this which all these functions all.

The DBI interface should have some more capabilities: dbWriteTable, dbReadTable, dbRemoveTable - most whole-table operations that don't require passing sql SELECT or similar. 
These are currently documented as not working for the connection.

Testing should work in an arbitrary workspace whether or not the test databases are already set up.  Add a truncated hash of the workspace ID to the testing database names to prevent
name collisions if someone is working in their workspace that has other stuff going on.

We need full download and upload tests for air_dump and air_restore: Pull a base, upload it with a new name, check for identical data (though record ids will be different)

---

**ADDITIONAL TODOs: FUTURE**

Make a plan for documentation updates given the following. Review current package-level documentation to see what we already have and may be re-organized. Consider carefully what goes where (user-, developer-, agent-facing) to
avoid redundancy, make sure agent-facing docs are compact for efficiency, and human-facing docs being mostly self-contained. Consider
where API limitations and snafus are needed for installation, setup for use, and development.  README should have minimum required startup
plus high-level features and a few examples. Main getting started vignette should have more info on credentials and API limitations as 
user, then robust walkthrough that is mirrorred in the demo.  CONTRIBUTING should have more API snafus at high level for setup and
notes for later. 

- [ ] Add `\dontrun{}` examples to remaining low-level `at_*` functions
- [ ] Add content to package-level help file.
- [ ] Create `README.md` (currently just a stub.)
- [ ] `air_demo()` + `air_demo_setup()` (generate demo workspace with all types)
- [ ] Vignettes: Getting Started, Special Types/Attachments/Linking Records, Metadata/Backup
- [ ] `NEWS.md`, expand `CONTRIBUTING.md`

Consolidate all the AGENTS documentation in anticipation of moving from using AGENTS as the primary status checker to switching to GitHub issues. AGENTS.md will be committed (by the user). .agents/ will not, and will remain gitignored for local cross-agent memory and skill storage.

Do not lose unimplemented features/steps and status, move them to .agents/todo.md

Make AGENTS.md much smaller, fixed instructions for the repository, referring to other documentation. Emphasize that agents should use generic AGENTS.md and files under ./agents (gitignored, create and use in local sessions)
for memory and tracking over provider-specific memory to enable handoff between agents in different sessions. Things like decisions.md, todo.md, architecture.md, etc. Once items are no longer interim, they can move to comitted, both developer- and agent- facing docs
Avoid repetition.  Consolidate stable and decisions, architecture, etc. into compact sections of CONTRIBUTING.md and make them suitable for both human and agentic use.  Extended sections can be collapsed in <details> sections. 
Add .github/copilot-instructions.md for and REVIEW.md for GitHub have it refer to the other agentic and CONTRIBUTING docs.

Move the airtable API quirks reference into a details section of CONTRIBUTING.md for both human and agentic use. Make sure CONTRIBUTING has a TOC to make it easy to find sections. Focus human-centric and contributing stuff at the top, agentic at the bottom (with easy to grep, compact and under <details>)

Implement a pkgdown site with LLM.txt/md and refer to it in the README and package-level docs help file so other agents find that as the primary source of documentation.

