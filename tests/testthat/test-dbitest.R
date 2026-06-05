# DBItest conformance placeholder for Stage 8A.
#
# DBItest requires a fully functional backend for driver/connection lifecycle
# tests. Airtable's constraints (no SQL, no table creation, no transactions,
# network-only) mean most DBItest suites are not applicable.
#
# TODO: Once mocking infrastructure supports DBItest's connection lifecycle
# probes (e.g. dbConnect/dbDisconnect without side effects), enable
# DBItest::test_driver() and DBItest::test_connection() here.

skip_if_not_installed("DBItest")

# DBItest conformance requires live or deeply mocked connections.
skip("DBItest conformance requires further mocking setup (Stage 8A TODO)")

ctx <- DBItest::make_context(
  drv = airtable2(),
  connect_args = list(token = "fake_token", base_id = "appTEST"),
  tweaks = DBItest::tweaks(
    constructor_name = "airtable2"
  ),
  name = "airtable2"
)

DBItest::test_driver(ctx)
DBItest::test_connection(ctx)
