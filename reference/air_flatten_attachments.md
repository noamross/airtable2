# Flatten an attachments list-column to a summary string

Flatten an attachments list-column to a summary string

## Usage

``` r
air_flatten_attachments(x, field = "filename", sep = NULL)
```

## Arguments

- x:

  A list-column where each element is a data frame or list of attachment
  objects.

- field:

  Which attachment field to extract (e.g., `"filename"`, `"url"`).
  Default `"filename"`.

- sep:

  Delimiter. Default `"; "`, overridable via
  `options(airtable2.delimiter = ...)` or the `AIRTABLE2_DELIMITER`
  environment variable. An explicit `sep` argument always takes
  precedence.

## Value

A character vector.
