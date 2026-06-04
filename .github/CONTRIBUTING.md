# Contributing to airtable2

airtable2 is developed for internal use.
Users and contributors are welcome, but with limited capacity we will prioritize internal needs.
We do not expect to publish on CRAN or R-Multiverse in the near future.

Note that airtable2 is also developed with heavy contribution of LLMs, indeed, it is a test bed for experimenting with AI-assisted development.

## Developing agasinst the limits of the Airtable API

Airtable's API has several limitations that contributors should be aware of, particularly for Free or Team-tier accounts.

Free accounts have a limit of 1000 API calls per month per workspace.  This can rack of very quickly in development and testing.  As such, live testing of the API is off by default and only internal and mocked tests are run. Set the environmental variable AIRTABLE_TEST_LIVE=true and provide both an AIRTABLE_API_KEY (a personal access token with all permissions) and
an AIRTABLE_WORKSPACE_ID for a workspace in which testing occurs.  We recommend setting up a dedicated free workspace for testing.

Several key features are only available in the API for Enterprise accounts. Notably, _deleting_ workspaces, bases, tables, or even columns can not be done by API in basic an team accounts.
After a session you may want to clean these up manually.  Tests produce create two bases that have accumulating tables and fields.  These bases can be deleted and will be re-created as needed.  Some test produce new bases each time, leading to an accumulation of many bases in a workspace. Setting AIRTABLE_TEST_SCHEMA=false will skip any tests that create new bases,
which can be helpful for accumulating these while you are developing something else, as one must go through and delete each one manually after testing. Alternatively, you can simply
delete the whole testing workspace and set a new AIRTABLE_WORKSPACE_ID (giving your API key access to the new workspace) for a future session.

When submitting a PR, no live tests are run without approval of a reviewer.  Other tests tests and reviews must pass before first, then a live test is run before approving for merge.

## Code of Conduct

Please note that the airtable2 project is released with a
[Contributor Code of Conduct](CODE_OF_CONDUCT.md). By contributing to this
project you agree to abide by its terms.
