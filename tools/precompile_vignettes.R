# tools/precompile_vignettes.R
#
# Precompile vignettes from vignettes-src/*.Rmd -> vignettes/*.Rmd so that the
# package ships with static, pre-rendered vignettes that require no live
# Airtable credentials at build time.
#
# ID obfuscation is applied automatically via the knitr hook defined in
# tools/knitr-hooks.R (which each source vignette sources in its setup chunk).
#
# Usage:
#   AIRTABLE_TEST_LIVE=true Rscript tools/precompile_vignettes.R
#
# Only runs when AIRTABLE_TEST_LIVE=true to prevent accidental live API calls.

if (!identical(Sys.getenv("AIRTABLE_TEST_LIVE", "false"), "true")) {
  message(
    "Skipping vignette precompile: AIRTABLE_TEST_LIVE is not 'true'.\n",
    "Set AIRTABLE_TEST_LIVE=true and re-run to actually precompile."
  )
  quit(save = "no", status = 0)
}

src_files <- list.files(
  "vignettes-src",
  pattern = "\\.Rmd$",
  full.names = TRUE
)

if (length(src_files) == 0) {
  message("No .Rmd files found in vignettes-src/. Nothing to precompile.")
  quit(save = "no", status = 0)
}

for (src in src_files) {
  out <- file.path("vignettes", basename(src))
  message("Knitting: ", src, " -> ", out)
  knitr::knit(input = src, output = out)
  message("Done: ", out)
}

message("Vignette precompile complete.")
