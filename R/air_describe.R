#' Generate descriptive metadata
#'
#' Creates a data.frame that describes the base.
#'
#' Descriptive metadata provides information about the base as a whole: who
#' created it, why, when, keywords, what license governs data use, etc.
#' Descriptive metadata facilitates data reuse by providing a point of contact
#' for future users, as well as attributes that allow the data to be entered
#' into searchable catalogs or archives.
#'
#' All Airtable plans have a limited capacity for storing revision history and
#' contribution. Users may also be removed from an organizational account or
#' provide an anonymized (or no-longer-functioning) email when creating their
#' airtable credentials. These factors make it difficult for future users to
#' determine who to contact for questions related to a particular base. This
#' functions provides a durable alternative to the ephemeral metadata features
#' built into Airtable.
#'
#'
#' @details See  \href{https://www.dublincore.org/resources/userguide/creating_metadata/}{dublin core} or \href{https://datacite-metadata-schema.readthedocs.io/en/4.7/}{datacite} for inspiration for additional attributes.
#'
#' @param title String. Title is a property that refers to the name or names by
#' which a resource is formally known.
#' @param creator String. Person or people who created the base
#' @param primary_contact String.  Person or entity primarily responsible for
#' making the content of a resource
#' @param email String. Email of primary_contact
#' @param description String. This property refers to the description of
#' the content of a resource. The description is a potentially rich source of
#' indexable terms and assist the users in their selection of an appropriate
#' resource.
#' @param contributor String. An entity (person, organization, etc.) responsible for making contributions to the resource.
#' @param identifier String. An unambiguous reference to the resource within a given context, likely a persistent identifier (DOI, etc.).
#' @param license String. A legal document giving official permission to do something with the resource. "CC BY 4.0" See \href{https://spdx.org/licenses/}{SPDX License List}
#' @param ... String. Additional descriptive metadata elements. See details.
#' Additional elements can be added as name pair values e.g.
#' \code{isPartOf = "https://doi.org/00.00000/MyPaper01", isReferencedBy = "https://doi.org/10.48321/MyDMP01"}
#' @param created String. Date the base was created
#'
#' @return tibble with descriptive metadata
#' @export
#' @examples
#'
#' air_describe(title = "My Awesome Base" ,
#'  primary_contact= "Base Creator/Maintainer",
#'  email = "email@@example.com",
#'  base_description = "This base contains my awesome data
#'  from a project studying XXX in YYY. Data in the base were collected
#'  from 1900-01-01 to 1990-01-01 by researchers at Some Long Term Project.",
#'  is_part_of = "https://doi.org/10.48321/MyDMP01",
#'  isReferencedBy = "https://doi.org/10.5072/zenodo_sandbox.1062705"
#'  )
#'
#'
air_describe <- function(title = NA_character_,
                                          creator= NA_character_,
                                          created=NA_character_,
                                          primary_contact=NA_character_,
                                          email = NA_character_,
                                          description = NA_character_,
                                          contributor = NA_character_,
                                          identifier =NA_character_,
                                          license = NA_character_,...){
  desc_table <- tibble::tibble(title = title,
                               creator= creator,
                               created=created,
                               primary_contact=primary_contact,
                               email = email,
                               description = description,
                               contributor = contributor,
                               identifier =identifier,
                               license = license,
                               ...)

  # make desc_key first column
  out <- tibble::tibble(desc_key = 1:nrow(desc_table),desc_table)

  return(out)
}

#' Seed the _description table from the output of air_describe
#'
#' Takes a descriptive metadata table and upserts it into a
#' designated table within the same base.  Run this **once** to initialise the
#' descriptive metadata store, then edit the table in Airtable.
#'
#' @inheritParams air_read
#' @param desc_table Name of the table to store metadata in.
#'   Default `"_description"`.
#' @param desc_dataframe Data.frame with descriptive metadata for the base.
#' @return Invisible upsert result.
#' @examples
#' \dontrun{
#' # Initialise the _description table
#' air_describe_init("appXXXXXX")
#'
#' # Use a custom table name
#' air_describe_init("appXXXXXX", desc_table = "descriptive_metadata")
#' }
#' @export
air_describe_init <- function(base_id, desc_table = "_description", desc_dataframe, .token = NULL) {
  check_string(base_id)
  check_string(desc_table)

  # Create the table with all needed fields if it doesn't exist.
  # Creating all fields upfront avoids a write-after-create race where
  # Airtable hasn't propagated new fields before the first upsert hits them.
  existing <- at_get_schema(base_id, token = .token)
  table_exists <- any(vapply(existing, function(t) t$name == desc_table, logical(1)))
  if (!table_exists) {
    cli_inform("Creating {.val {desc_table}} table...")
    tf <- function(nm) list(name = nm, type = "singleLineText")
    # typed_list <-
    at_create_table(
      name    = desc_table,
      fields  = lapply(names(desc_dataframe), tf),
      base_id = base_id,
      token   = .token
    )
  }

  air_upsert(
    data       = desc_dataframe,
    base_id    = base_id,
    table      = desc_table,
    merge_on   = "desc_key",
    typecast   = TRUE,
    add_fields = if (table_exists) "yes" else "warn",
    .token     = .token
  )
}
