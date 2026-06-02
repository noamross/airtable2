# Airtable API Notes & Known Issues

This document records unexpected or undocumented behaviors in the Airtable REST
API discovered during `airtable2` development. These may affect your usage of
both the package and the API directly.

---

## Workspace ID Cannot Be Discovered via API (2026-06-02)

The Airtable API provides **no endpoint** for non-enterprise accounts to list
or discover workspace IDs. The `/meta/workspaces` endpoint exists but returns
403 for non-enterprise PATs.
 
No other endpoint (whoami, list bases, get schema, create base response) returns
workspace information.

**How to find your workspace ID**: Open Airtable in a browser. Your workspace
URL looks like `https://airtable.com/wspXXXXXX/...` — the `wspXXXXXX` part is
your workspace ID.

You'll need this ID for `at_create_base()` and related functions.

---

## `/meta/bases` Rejects `pageSize` Parameter (2026-06-02)

The list-bases endpoint returns 422 if you include `pageSize` in the query
string. Despite paginating (via `offset`), the page size is fixed server-side
(up to 1000 per page). The `airtable2` package handles this internally.

---

## Creating a Checkbox Field Requires `options` (2026-06-02)

When creating tables or fields with type `"checkbox"`, you **must** include the
`options` object with `icon` and `color` keys. Omitting options produces:

```
INVALID_FIELD_TYPE_OPTIONS_FOR_CREATE: Failed schema validation: <Field>.options is missing
```

Example of valid options:
```r
air_field_template("Done", "checkbox",
  options = list(icon = "check", color = "greenBright"))
```

---

## `POST /meta/bases` Gives Unhelpful Error When `workspaceId` Is Missing (2026-06-02)

If you omit `workspaceId` from a create-base request, the API returns:

```json
{"error": {"type": "INVALID_REQUEST", "message": "Server error"}}
```

This should say "workspaceId is required" but instead gives a generic 422.

---

## Unchecked Checkboxes Return as `null` / Absent (2026-06-02)

When reading records, Airtable **omits** checkbox fields that are unchecked
rather than returning `false`. This means:

- A checked checkbox returns `true`
- An unchecked checkbox is **absent from the response** (not `false`)

In `airtable2`, this means unchecked checkboxes appear as `NA` rather than
`FALSE` in the returned tibble. If you need explicit `FALSE`, replace NAs:

```r
df$Active[is.na(df$Active)] <- FALSE
```

---

## Formula Field Options Key Is `formula`, Not `expression` (2026-06-02)

When creating a formula field via the API, the correct options key is `formula`:

```r
at_create_field(base_id, table_id, "MyFormula", "formula",
  options = list(formula = "UPPER({Name})"))
```

Using `expression` instead of `formula` will give a schema validation error.

---

## Some Field Types Cannot Be Created via API (2026-06-02)

The following field types cannot be created via the Meta API and return
`UNSUPPORTED_FIELD_TYPE_FOR_CREATE`:

- `lastModifiedTime`
- `lastModifiedBy`
- `createdTime`
- `createdBy`
- `autoNumber`

These must be created via the Airtable web UI or are generated automatically
when a base is created.

---

## `GET /meta/whoami` Does Not Return Scopes or Collaborations (2026-06-02)

Despite what some documentation suggests, the whoami endpoint only returns `id`
and `email`. Token scopes, workspace memberships, and collaborations are not
included in the response for PATs.
