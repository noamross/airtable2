# 

## 

title: “Special Field Types in airtable2” output:
rmarkdown::html_vignette vignette: \> % % % —

``` r

library(airtable2)
```

## Overview

Most Airtable fields map naturally to R atomic vectors: text becomes
`character`, numbers become `numeric`, checkboxes become `logical`, and
dates become `Date` or `POSIXct`. A handful of field types, however,
carry structured data that cannot fit in a single scalar value per row.

airtable2 represents these as **list-columns** in the returned tibble —
one list element per row. Each list-column is wrapped in a lightweight
S3 class so that the data round-trips faithfully through read/write
cycles and displays compactly in the tibble header and in the
RStudio/Positron data viewer.

The six special types are:

| Airtable field type    | R S3 class          | Pillar type tag |
|------------------------|---------------------|-----------------|
| Multiple select        | `air_multiselect`   | `sel[]`         |
| Linked records         | `air_links`         | `lnk[]`         |
| Attachments            | `air_attachments`   | `att[]`         |
| Single collaborator    | `air_collaborator`  | `collab`        |
| Multiple collaborators | `air_collaborators` | `collabs`       |
| Barcode                | `air_barcode`       | `barcode`       |

When you print a tibble that contains these columns, pillar uses the
registered `pillar_shaft` and `type_sum` methods to show a one-line
summary per cell and the short tag in the column header. The full
structured data is always preserved in the list-column and can be
written back with
[`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md)
or
[`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
unchanged.

If you want a plain, flat data frame instead, see [Section
7](#air_simplify) for
[`air_simplify()`](https://noamross.github.io/airtable2/reference/air_simplify.md),
or the type-specific flatteners described throughout this vignette.

For the general workflow — authentication, reading, writing, syncing —
see the [Getting Started
vignette](https://noamross.github.io/airtable2/articles/airtable2.md).

------------------------------------------------------------------------

## 1. Multi-select fields (`air_multiselect`)

Airtable’s *Multiple select* field lets each record carry zero or more
selection options.
[`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)
returns these as an `air_multiselect` list-column, where each element is
a character vector of selected options (or `NULL` for an empty
selection).

``` r

# Suppose a "Projects" table has a "Tags" multiple-select field.
projects <- air_read("appXXXXXX", "Projects")
projects
#> # A tibble: 4 × 4
#>   airtable_id  airtable_created_time name         tags
#>   <chr>        <dttm>                <chr>        <sel[]>
#> 1 recAAAAAAAA  2024-01-10 09:00:00   Alpha        R, data, analysis
#> 2 recBBBBBBBB  2024-01-11 10:30:00   Beta         data
#> 3 recCCCCCCCC  2024-01-12 14:00:00   Gamma        NA
#> 4 recDDDDDDDD  2024-01-13 08:15:00   Delta        R, reporting
```

The `sel[]` tag in the column header indicates an `air_multiselect`
list-column. Each cell shows the selections joined with `", "` for
display, but the underlying list element is a character vector:

``` r

# Look at the raw list element for the first row
projects$tags[[1]]
#> [1] "R"        "data"     "analysis"

# NULL for a row with no selection
projects$tags[[3]]
#> NULL
```

### Flattening to a character vector

[`air_flatten_multiselect()`](https://noamross.github.io/airtable2/reference/air_flatten_multiselect.md)
collapses each element to a delimited string, giving one character value
per row:

``` r

air_flatten_multiselect(projects$tags)
#> [1] "R, data, analysis" "data"              NA                  "R, reporting"

# Use a different delimiter
air_flatten_multiselect(projects$tags, sep = " | ")
#> [1] "R | data | analysis" "data"                NA                    "R | reporting"
```

This is useful for export to CSV or for passing to string-based tools.

### Expanding back to a list-column

[`air_expand_multiselect()`](https://noamross.github.io/airtable2/reference/air_expand_multiselect.md)
is the inverse: it splits delimited strings back into character vectors,
ready to write to Airtable:

``` r

flat_tags <- c("R, data, analysis", "data", NA, "R, reporting")
air_expand_multiselect(flat_tags)
#> [[1]]
#> [1] "R"        "data"     "analysis"
#>
#> [[2]]
#> [1] "data"
#>
#> [[3]]
#> NULL
#>
#> [[4]]
#> [1] "R"         "reporting"
```

### Round-tripping through write

Because
[`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md)
and
[`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md)
strip the `air_*` class before sending data to the API, you can pass the
original `air_multiselect` list-column directly without any conversion:

``` r

# Modify one row's tags and write back
projects$tags[[3]] <- list("reporting") # was NULL
air_upsert(projects, "appXXXXXX", "Projects", merge_on = "name")
```

------------------------------------------------------------------------

## 2. Linked records (`air_links`)

Airtable’s *Link to another record* field connects rows across tables.
On read, each cell contains a character vector of record IDs (strings
like `"recXXXXXXXXXXXXXX"`). airtable2 wraps these in an `air_links`
list-column.

``` r

projects <- air_read("appXXXXXX", "Projects")
projects
#> # A tibble: 3 × 4
#>   airtable_id  name    owner_ids
#>   <chr>        <chr>   <lnk[]>
#> 1 recAAAAAAAA  Alpha   recPPPPPPPP
#> 2 recBBBBBBBB  Beta    [2 records]
#> 3 recCCCCCCCC  Gamma   NA
```

A single linked record is shown as the ID; multiple are shown as
`[N records]`; an empty link field is `NA`.

The linked field stores only record IDs, not the values from the linked
table. To retrieve the actual data you need to read the linked table
separately and join.

### Flattening links

[`air_flatten_links()`](https://noamross.github.io/airtable2/reference/air_flatten_links.md)
collapses the ID vectors to delimited strings (it is a thin wrapper
around
[`air_flatten_multiselect()`](https://noamross.github.io/airtable2/reference/air_flatten_multiselect.md)):

``` r

air_flatten_links(projects$owner_ids)
#> [1] "recPPPPPPPP"                NA             "recQQQQQQQQ, recRRRRRRRR"
```

### Joining to resolve linked records

Use
[`air_left_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md),
[`air_inner_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md),
or
[`air_full_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md)
to fetch the linked table and join it with a local data frame in a
single step. The `by` argument maps the column(s) to join on.

A common pattern is to first flatten the links to get one row per linked
record, then join to the linked table:

``` r

# Read the "People" table that Projects links to
people <- air_read("appXXXXXX", "People")

# Flatten: one row per (project, person) pair
project_owners <- tidyr::unnest(projects, cols = owner_ids, keep_empty = TRUE)
project_owners
#> # A tibble: 4 × 3
#>   airtable_id  name    owner_ids
#>   <chr>        <chr>   <chr>
#> 1 recAAAAAAAA  Alpha   recPPPPPPPP
#> 2 recBBBBBBBB  Beta    recQQQQQQQQ
#> 3 recBBBBBBBB  Beta    recRRRRRRRR
#> 4 recCCCCCCCC  Gamma   NA

# Join on the record ID to get person names
dplyr::left_join(
  project_owners,
  dplyr::select(people, airtable_id, person_name = name),
  by = c("owner_ids" = "airtable_id")
)
#> # A tibble: 4 × 4
#>   airtable_id  name    owner_ids    person_name
#>   <chr>        <chr>   <chr>        <chr>
#> 1 recAAAAAAAA  Alpha   recPPPPPPPP  Alice
#> 2 recBBBBBBBB  Beta    recQQQQQQQQ  Bob
#> 3 recBBBBBBBB  Beta    recRRRRRRRR  Carol
#> 4 recCCCCCCCC  Gamma   NA           NA
```

You can also use
[`air_left_join()`](https://noamross.github.io/airtable2/reference/air_left_join.md)
if the join key is shared by name:

``` r

# air_left_join fetches the remote table and merges in one call
air_left_join(
  project_owners,
  "appXXXXXX",
  "People",
  by = c("owner_ids" = "airtable_id")
)
```

### Re-linking records after a restore

A known limitation: linked records are stored by record ID, and IDs are
assigned by Airtable and cannot be set on create. If you dump a base
with
[`air_dump()`](https://noamross.github.io/airtable2/reference/air_dump.md)
and restore it to a new base with
[`air_restore()`](https://noamross.github.io/airtable2/reference/air_restore.md),
the records get new IDs, so all `air_links` columns in the restored base
point to the old IDs and the links are broken.

[`air_restore()`](https://noamross.github.io/airtable2/reference/air_restore.md)
handles this automatically by default (`restore_linked_fields = TRUE`):
after inserting all records it remaps the old record IDs to the new ones
using the insertion-order mapping and writes the link values back. If
you need manual control (e.g. merging data from multiple sources), the
[Metadata and Backup
vignette](https://noamross.github.io/airtable2/articles/metadata-backup.md)
has a worked example using a natural key.

------------------------------------------------------------------------

## 3. Attachments (`air_attachments`)

Airtable’s *Attachments* field holds one or more files per record. On
read, each cell is a list of attachment objects, each with at minimum:

- `filename` — the original file name
- `url` — a temporary Airtable-hosted download URL
- `size` — file size in bytes
- `type` — MIME type

airtable2 wraps these in an `air_attachments` list-column.

> **Important:** Airtable attachment URLs are temporary and expire after
> a short time (typically a few hours). Always re-fetch records before
> downloading if significant time has passed since the last
> [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)
> call.

``` r

projects <- air_read("appXXXXXX", "Projects")
projects
#> # A tibble: 3 × 4
#>   airtable_id  name    docs
#>   <chr>        <chr>   <att[]>
#> 1 recAAAAAAAA  Alpha   brief.pdf
#> 2 recBBBBBBBB  Beta    report.docx +1
#> 3 recCCCCCCCC  Gamma   NA
```

The `att[]` tag marks the column as `air_attachments`. A single
attachment shows its filename; multiple attachments show
`first_file.ext +N`; an empty field is `NA`.

Inspect a single row’s attachment metadata directly:

``` r

projects$docs[[2]]
#> [[1]]
#> [[1]]$id
#> [1] "attXXXXXXXXXXXXXX"
#> [[1]]$filename
#> [1] "report.docx"
#> [[1]]$url
#> [1] "https://dl.airtable.com/..."
#> [[1]]$size
#> [1] 42816
#> [[1]]$type
#> [1] "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
#>
#> [[2]]
#> [[2]]$filename
#> [1] "notes.txt"
#> ...
```

### Flattening attachment metadata

[`air_flatten_attachments()`](https://noamross.github.io/airtable2/reference/air_flatten_attachments.md)
extracts one field from each attachment object and collapses to a
delimited string:

``` r

# Default: filenames
air_flatten_attachments(projects$docs)
#> [1] "brief.pdf"           "report.docx, notes.txt" NA

# Extract URLs instead
air_flatten_attachments(projects$docs, field = "url")
#> [1] "https://dl.airtable.com/..." "https://..." NA
```

### Downloading attachments with `air_read_attachments()`

[`air_read_attachments()`](https://noamross.github.io/airtable2/reference/air_read_attachments.md)
fetches all attachments for a given field and returns a flat tibble with
one row per file. The `dest` argument controls the output format:

- `"meta"` — **not a valid value here**;
  [`air_read_attachments()`](https://noamross.github.io/airtable2/reference/air_read_attachments.md)
  always downloads content. Use
  [`air_flatten_attachments()`](https://noamross.github.io/airtable2/reference/air_flatten_attachments.md)
  on the list-column if you only need metadata.
- `"blob"` — download files as raw byte vectors stored in a `blob`
  list-column
- `"file"` — write files to disk under `dir/`; returns a `local_path`
  column

``` r

# Download as raw bytes (in-memory)
blobs <- air_read_attachments(
  base_id = "appXXXXXX",
  table = "Projects",
  field = "docs",
  dest = "blob"
)
blobs
#> # A tibble: 3 × 6
#>   airtable_id  filename       url                    size    type           blob
#>   <chr>        <chr>          <chr>                 <int>    <chr>          <list>
#> 1 recAAAAAAAA  brief.pdf      https://dl.airtable…  18432    application/… <raw[18432]>
#> 2 recBBBBBBBB  report.docx    https://dl.airtable…  42816    application/… <raw[42816]>
#> 3 recBBBBBBBB  notes.txt      https://dl.airtable…   1024    text/plain    <raw[1024]>
```

``` r

# Save files to disk: one sub-directory per record
files <- air_read_attachments(
  base_id = "appXXXXXX",
  table = "Projects",
  field = "docs",
  dest = "file",
  dir = "downloads/"
)
files
#> # A tibble: 3 × 6
#>   airtable_id  filename     url                  size  type          local_path
#>   <chr>        <chr>        <chr>               <int>  <chr>         <chr>
#> 1 recAAAAAAAA  brief.pdf    https://…           18432  application/… downloads/brief.pdf
#> 2 recBBBBBBBB  report.docx  https://…           42816  application/… downloads/report.docx
#> 3 recBBBBBBBB  notes.txt    https://…            1024  text/plain    downloads/notes.txt
```

You can also control the attachment mode directly in
[`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md)
using the `attachments` argument. This downloads files as part of the
initial read and augments the attachment objects in the list-column with
a `content` (blob) or `local_path` (file) field:

``` r

# Download attachments to disk while reading
projects <- air_read(
  "appXXXXXX",
  "Projects",
  attachments = "file",
  attachment_dir = "downloads/"
)
# Now each attachment object in projects$docs has a $local_path entry
projects$docs[[1]][[1]]$local_path
#> [1] "downloads/recAAAAAAAA/brief.pdf"
```

### Parallel downloads

By default, airtable2 downloads attachments in parallel using
[`httr2::req_perform_parallel()`](https://httr2.r-lib.org/reference/req_perform_parallel.html)
(up to 5 concurrent). You can control this with:

- The `parallel` argument: `TRUE` to force on, `FALSE` to force
  sequential
- The `airtable2.parallel` option: `options(airtable2.parallel = FALSE)`
- The `AIRTABLE2_PARALLEL` environment variable:
  `AIRTABLE2_PARALLEL=false`

``` r

# Force sequential downloads (useful for debugging or strict rate limiting)
air_read_attachments(
  "appXXXXXX",
  "Projects",
  "docs",
  dest = "file",
  dir = "downloads/",
  parallel = FALSE
)
```

### Uploading attachments with `air_write_attachments()`

[`air_write_attachments()`](https://noamross.github.io/airtable2/reference/air_write_attachments.md)
uploads files to an existing attachment field. It takes a data frame
with `airtable_id` and `file_path` columns:

``` r

to_upload <- data.frame(
  airtable_id = c("recAAAAAAAA", "recBBBBBBBB"),
  file_path = c("outputs/alpha_summary.pdf", "outputs/beta_report.docx")
)

air_write_attachments(
  base_id = "appXXXXXX",
  table = "Projects",
  field = "docs",
  data = to_upload
)
#> Uploading 2 attachments...
#> Upload complete.
```

Note that uploads **add** attachments to a record; they do not replace
existing ones. Use
[`air_sync_attachments()`](https://noamross.github.io/airtable2/reference/air_sync_attachments.md)
if you want to avoid duplicates.

### Diff-based sync with `air_sync_attachments()`

[`air_sync_attachments()`](https://noamross.github.io/airtable2/reference/air_sync_attachments.md)
compares the filenames in your local data with those already in
Airtable, uploading only files that are not already present. This avoids
duplicate uploads on repeated runs:

``` r

local_files <- data.frame(
  project_name = c("Alpha", "Alpha", "Beta"),
  file_path = c(
    "outputs/alpha_summary.pdf",
    "outputs/alpha_data.csv",
    "outputs/beta_report.docx"
  )
)

air_sync_attachments(
  base_id = "appXXXXXX",
  table = "Projects",
  field = "docs",
  data = local_files,
  key = "project_name" # column in both local_files and the Airtable table
)
#> Attachment sync: 2 uploaded, 1 skipped.
```

### Stable preview URLs and the temporary-URL caveat

The `url` field in each attachment object is **temporary**: Airtable
generates a signed `airtableusercontent.com` URL that expires
approximately two hours after the API call. Never save this URL to a
database or share it as a permanent link — it will stop working shortly
after you fetch it.

The function
[`air_attachment_preview_url()`](https://noamross.github.io/airtable2/reference/air_attachment_preview_url.md)
always returns `NA_character_`. This is intentional and correct.
Airtable does not expose stable viewer URLs through the REST API. The
stable URL — the one hosted on `airtable.com` rather than
`airtableusercontent.com` — can only be obtained by opening the
attachment in the Airtable web app and copying the address bar URL.

``` r

# The url field in each attachment expires after ~2 hours:
projects$Files[[1]][[1]]$url
#> [1] "https://v5.airtableusercontent.com/v3/..."  # <- expires soon

# air_attachment_preview_url() always returns NA — this is correct behaviour:
air_attachment_preview_url(projects$Files[[1]][[1]])
#> [1] NA
#> i Airtable does not expose stable viewer URLs through the REST API.
#> i To get a permanent shareable link: open the record in the Airtable web app,
#>   click the attachment, and copy the URL from your browser's address bar.
#>   That URL (from airtable.com) does not expire.
```

**Workaround for a stable link:** navigate to the record in the Airtable
web app, click the attachment thumbnail to open the viewer, and copy the
URL from your browser’s address bar. That URL originates from
`airtable.com` and does not expire.

------------------------------------------------------------------------

## 4. Collaborator fields (`air_collaborator` / `air_collaborators`)

Airtable has two collaborator field types:

- **Collaborator** (`collaborator`) — a single workspace member. Also
  used for the built-in *Created by* and *Last modified by* fields.
- **Multiple collaborators** (`multipleCollaborators`) — zero or more
  workspace members.

Each collaborator object has three fields: `id` (Airtable user ID),
`email`, and `name`.

Single-collaborator fields become an `air_collaborator` list-column
(type tag `collab`). Multi-collaborator fields become an
`air_collaborators` list-column (type tag `collabs`).

``` r

tasks <- air_read("appXXXXXX", "Tasks")
tasks
#> # A tibble: 3 × 5
#>   airtable_id  title         assigned_to            reviewers
#>   <chr>        <chr>         <collab>               <collabs>
#> 1 recAAAAAAAA  Write tests   Alice <alice@co.com>   Bob <bob@co.com>
#> 2 recBBBBBBBB  Review PR     Bob <bob@co.com>       Alice <alice@co.com> +1
#> 3 recCCCCCCCC  Deploy        NA                     NA
```

``` r

# Single collaborator: a named list
tasks$assigned_to[[1]]
#> $id
#> [1] "usrXXXXXXXXXXXXXX"
#> $email
#> [1] "alice@co.com"
#> $name
#> [1] "Alice"
```

### Flattening collaborators

[`air_flatten_collaborator()`](https://noamross.github.io/airtable2/reference/air_flatten_collaborator.md)
converts each collaborator to a formatted string. The `format` argument
is a glue-style template with access to `id`, `email`, and `name`:

``` r

# Default: "Name <email>"
air_flatten_collaborator(tasks$assigned_to)
#> [1] "Alice <alice@co.com>" "Bob <bob@co.com>"     NA

# Just the name
air_flatten_collaborator(tasks$assigned_to, format = "{name}")
#> [1] "Alice" "Bob"   NA

# Just the ID
air_flatten_collaborator(tasks$assigned_to, format = "{id}")
#> [1] "usrXXXXXXXXXXXXXX" "usrYYYYYYYYYYYYYY" NA
```

### Expanding strings back to collaborator list-columns

[`air_expand_collaborator()`](https://noamross.github.io/airtable2/reference/air_expand_collaborator.md)
parses formatted strings back into named lists. The `pattern` argument
is a regex with two capture groups (name, email):

``` r

strings <- c("Alice <alice@co.com>", "Bob <bob@co.com>", NA)
air_expand_collaborator(strings)
#> [[1]]
#> $name
#> [1] "Alice"
#> $email
#> [1] "alice@co.com"
#>
#> [[2]]
#> $name
#> [1] "Bob"
#> $email
#> [1] "bob@co.com"
#>
#> [[3]]
#> NULL
```

When writing collaborator values back to Airtable, pass the `id` field —
the API identifies users by their Airtable user ID, not by name or
email.

------------------------------------------------------------------------

## 5. Barcode fields (`air_barcode`)

Airtable’s *Barcode* field stores a scanned barcode value alongside its
symbology (e.g., QR code, EAN-13, Code 128). Each row’s value is a named
list with:

- `text` — the decoded barcode string
- `type` — the barcode symbology (may be absent)

``` r

inventory <- air_read("appXXXXXX", "Inventory")
inventory
#> # A tibble: 3 × 4
#>   airtable_id  item         barcode
#>   <chr>        <chr>        <barcode>
#> 1 recAAAAAAAA  Widget A     9780201379624 (EAN13)
#> 2 recBBBBBBBB  Widget B     https://example.com/p/456 (QR)
#> 3 recCCCCCCCC  Widget C     NA
```

``` r

inventory$barcode[[1]]
#> $text
#> [1] "9780201379624"
#> $type
#> [1] "EAN13"
```

There is no dedicated `air_flatten_barcode()` function. Use
[`air_simplify()`](https://noamross.github.io/airtable2/reference/air_simplify.md)
(described in the next section) or extract fields manually:

``` r

# Extract just the barcode text
vapply(inventory$barcode, function(b) b$text %||% NA_character_, character(1))
#> [1] "9780201379624"               "https://example.com/p/456"   NA
```

------------------------------------------------------------------------

## 6. `air_simplify()` — the kitchen-sink flattener

[`air_simplify()`](https://noamross.github.io/airtable2/reference/air_simplify.md)
processes every list-column in a tibble at once, converting each to its
simplest character representation using the appropriate type-specific
flattener. It is the quickest way to get a fully flat, all-atomic data
frame for export or display:

``` r

projects <- air_read("appXXXXXX", "Projects")

# Before: list-columns with air_* classes
str(projects$tags)
#>  air_multiselect [1:4] ...

flat <- air_simplify(projects)
flat
#> # A tibble: 4 × 4
#>   airtable_id  name    tags                owner_ids
#>   <chr>        <chr>   <chr>               <chr>
#> 1 recAAAAAAAA  Alpha   R, data, analysis   recPPPPPPPP
#> 2 recBBBBBBBB  Beta    data                recQQQQQQQQ, recRRRRRRRR
#> 3 recCCCCCCCC  Gamma   NA                  NA
#> 4 recDDDDDDDD  Delta   R, reporting        NA

# After: plain character columns
str(flat$tags)
#>  chr [1:4] "R, data, analysis" "data" NA "R, reporting"
```

When a schema is available (passed as the `schema` argument),
[`air_simplify()`](https://noamross.github.io/airtable2/reference/air_simplify.md)
uses the field type to pick the right flattener. Without a schema, it
falls back to a generic `paste(format(v), collapse = ", ")` for each
list element.

``` r

# at_get_schema() returns all tables; find the one named "Projects"
all_tables <- at_get_schema("appXXXXXX")
projects_table <- Filter(function(t) t$name == "Projects", all_tables)[[1]]
schema <- projects_table$fields
flat <- air_simplify(projects, schema = schema)
```

### When to use `air_simplify()` vs. the type-specific flatteners

- Use
  **[`air_simplify()`](https://noamross.github.io/airtable2/reference/air_simplify.md)**
  when you want a quick flat snapshot of the whole table, e.g., to
  export to CSV or to inspect data interactively.
- Use **type-specific flatteners**
  ([`air_flatten_multiselect()`](https://noamross.github.io/airtable2/reference/air_flatten_multiselect.md),
  [`air_flatten_links()`](https://noamross.github.io/airtable2/reference/air_flatten_links.md),
  [`air_flatten_attachments()`](https://noamross.github.io/airtable2/reference/air_flatten_attachments.md),
  [`air_flatten_collaborator()`](https://noamross.github.io/airtable2/reference/air_flatten_collaborator.md))
  when you need control over delimiters, output format, or want to work
  with individual columns in a pipeline.
- Avoid
  [`air_simplify()`](https://noamross.github.io/airtable2/reference/air_simplify.md)
  before writing data back to Airtable. The original `air_*`
  list-columns round-trip correctly; flattened strings do not (you would
  need
  [`air_expand_multiselect()`](https://noamross.github.io/airtable2/reference/air_expand_multiselect.md)
  etc. to convert them back).

------------------------------------------------------------------------

## See also

- [Getting Started
  vignette](https://noamross.github.io/airtable2/articles/airtable2.md)
  — authentication,
  [`air_read()`](https://noamross.github.io/airtable2/reference/air_read.md),
  [`air_write()`](https://noamross.github.io/airtable2/reference/air_write.md),
  [`air_upsert()`](https://noamross.github.io/airtable2/reference/air_upsert.md),
  [`air_sync()`](https://noamross.github.io/airtable2/reference/air_sync.md).
- [Metadata and Backup
  vignette](https://noamross.github.io/airtable2/articles/metadata-backup.md)
  —
  [`air_dump()`](https://noamross.github.io/airtable2/reference/air_dump.md),
  [`air_restore()`](https://noamross.github.io/airtable2/reference/air_restore.md),
  schema operations, best practices for archiving bases.
- [`?air_read`](https://noamross.github.io/airtable2/reference/air_read.md)
  — the `attachments` and `attachment_dir` arguments for downloading
  content at read time.
- [`?air_read_attachments`](https://noamross.github.io/airtable2/reference/air_read_attachments.md),
  [`?air_write_attachments`](https://noamross.github.io/airtable2/reference/air_write_attachments.md),
  [`?air_sync_attachments`](https://noamross.github.io/airtable2/reference/air_sync_attachments.md)
  — dedicated attachment helpers.
- [`?air_left_join`](https://noamross.github.io/airtable2/reference/air_left_join.md)
  — joining local data frames with remote Airtable tables.
