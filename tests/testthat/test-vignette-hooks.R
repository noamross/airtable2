test_that("setup_vignette_hooks() installs obfuscate_ids output hook", {
  # Source the hooks file to get setup_vignette_hooks()
  source(test_path("../../tools/knitr-hooks.R"))

  # Call setup function
  setup_vignette_hooks()

  # Verify the output hook is set (knitr::knit_hooks$get returns NULL for unset hooks)
  # We test it by exercising the hook logic directly
  hook_fn <- knitr::knit_hooks$get("output")
  expect_true(is.function(hook_fn))
})

test_that("obfuscate_ids hook replaces app IDs", {
  source(test_path("../../tools/knitr-hooks.R"))
  setup_vignette_hooks()

  hook_fn <- knitr::knit_hooks$get("output")

  input <- "[1] \"appABCDEFGHIJKLMN\""
  result <- hook_fn(input, list(obfuscate_ids = TRUE))
  expect_equal(result, "[1] \"app...\"")
})

test_that("obfuscate_ids hook replaces wsp, tbl, rec, viw prefixes", {
  source(test_path("../../tools/knitr-hooks.R"))
  setup_vignette_hooks()

  hook_fn <- knitr::knit_hooks$get("output")
  opts <- list(obfuscate_ids = TRUE)

  expect_equal(
    hook_fn("[1] \"wspABCDEFGHIJKLMN\"", opts),
    "[1] \"wsp...\""
  )
  expect_equal(
    hook_fn("[1] \"tblABCDEFGHIJKLMN\"", opts),
    "[1] \"tbl...\""
  )
  expect_equal(
    hook_fn("[1] \"recABCDEFGHIJKLMN\"", opts),
    "[1] \"rec...\""
  )
  expect_equal(
    hook_fn("[1] \"viwABCDEFGHIJKLMN\"", opts),
    "[1] \"viw...\""
  )
})

test_that("obfuscate_ids hook does NOT replace short strings (< 5 trailing chars)", {
  source(test_path("../../tools/knitr-hooks.R"))
  setup_vignette_hooks()

  hook_fn <- knitr::knit_hooks$get("output")
  opts <- list(obfuscate_ids = TRUE)

  # bare prefix only — should not be replaced
  expect_equal(hook_fn("app", opts), "app")

  # prefix + 4 chars — should not be replaced (need >= 5)
  expect_equal(hook_fn("app1234", opts), "app1234")

  # prefix + exactly 5 chars — should be replaced
  result <- hook_fn("app12345", opts)
  expect_equal(result, "app...")
})

test_that("obfuscate_ids hook passes through unchanged when option is FALSE", {
  source(test_path("../../tools/knitr-hooks.R"))
  setup_vignette_hooks()

  hook_fn <- knitr::knit_hooks$get("output")
  opts <- list(obfuscate_ids = FALSE)

  input <- "[1] \"appABCDEFGHIJKLMN\""
  result <- hook_fn(input, opts)
  expect_equal(result, input)
})

test_that("setup_vignette_hooks() sets obfuscate_ids default chunk option to TRUE", {
  source(test_path("../../tools/knitr-hooks.R"))
  setup_vignette_hooks()

  expect_true(knitr::opts_chunk$get("obfuscate_ids"))
})
