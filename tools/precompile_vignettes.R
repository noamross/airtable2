# tools/precompile_vignettes.R
#
# Precompile vignettes from *.Rmd.orig -> *.Rmd so that the package ships with
# static, pre-rendered vignettes that require no live Airtable credentials at
# build time.
#
# ID obfuscation is applied automatically via the knitr hook defined in
# tools/knitr-hooks.R (which each *.Rmd.orig sources in its setup chunk).
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

orig_files <- list.files(
  "vignettes",
  pattern = "\\.Rmd\\.orig$",
  full.names = TRUE
)

if (length(orig_files) == 0) {
  message("No *.Rmd.orig files found in vignettes/. Nothing to precompile.")
  quit(save = "no", status = 0)
}

for (orig in orig_files) {
  out <- sub("\\.orig$", "", orig)
  message("Knitting: ", orig, " -> ", out)
  knitr::knit(input = orig, output = out)
  message("Done: ", out)
}

message("Vignette precompile complete.")
