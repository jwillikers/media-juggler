# Functions for ebooks, including EPUB and OPF metadata

use std log

use archives.nu *
use comics.nu *
use constants.nu *
use identifiers.nu *
use images.nu *
use metadata.nu *
use optimization.nu *
use utils.nu *

# Convert an Adobe Digital Editions ACSM file, an LCPL, or an LCPDF to an EPUB or PDF file.
#
# todo Check exit status of Calibre commands here.
export def acsm_lcp_to_ebook [
  working_directory: directory # The scratch-space directory to use
]: [path -> path] {
  let input_file = $in
  log info "Closing running instance of Calibre"

  ^calibre --shutdown-running-calibre

  log info $"Importing the eBook file (ansi yellow)($input_file)(ansi reset) into Calibre. This may take a bit..."
  let book_id = (
    ^calibredb add --automerge overwrite -- $input_file
      # todo Keep output and print in case of error?
      # err> /dev/null
    | lines --skip-empty
    | last
    | parse --regex '.* book ids: (?P<book_id>\w+)'
    | get book_id
    | first
  )
  log info $"Successfully imported into Calibre as id (ansi purple_bold)($book_id)(ansi reset)"

  let epub = {parent: $working_directory stem: $book_id extension: "epub"} | path join
  let pdf = {parent: $working_directory stem: $book_id extension: "pdf"} | path join
  rm --force $epub $pdf

  log debug $"Exporting the ebook from Calibre to (ansi yellow)($working_directory)/($book_id)(ansi reset)"
  (
    ^calibredb export
      --dont-asciiize
      --dont-save-cover
      --dont-save-extra-files
      --dont-write-opf
      --progress
      --template '{id}'
      --single-dir
      --to-dir $working_directory
      -- $book_id
      # err> /dev/null
  )
  let output_file = (
    if ($epub | path exists) and ($pdf | path exists) {
      error make {
        msg: "book exported by Calibre resulted in both an EPUB and a PDF file"
        labels: [
            {text: "epub" span: (metadata $epub).span}
            {text: "pdf" span: (metadata $pdf).span}
        ]
        help: $"clear the book from Calibre and import one format at a time"
      }
    } else if ($epub | path exists) {
      $epub
    } else if ($pdf | path exists) {
      $pdf
    } else {
      error make {
        msg: "book exported by Calibre is neither an EPUB nor a PDF file"
        labels: [
            {text: "epub" span: (metadata $epub).span}
            {text: "pdf" span: (metadata $pdf).span}
        ]
        help: $"neither the ($epub) nor ($pdf) file exist after being exported from Calibre. Perhaps the book failed to import?"
      }
    }
  )
  log debug $"The ebook was exported from Calibre to (ansi yellow)($output_file)(ansi reset)"

  if ($output_file | path parse | get extension) == "epub" {
    log debug $"Removing EPUB format for book '($book_id)' in Calibre"
    ^calibredb remove_format $book_id EPUB
  } else if ($output_file | path parse | get extension) == "pdf" {
    log debug $"Removing the PDF format for book '($book_id)' in Calibre"
    ^calibredb remove_format $book_id PDF
  }
  let available_formats = (
    ^calibredb list
      --fields "formats"
      --for-machine
      --search $"id:($book_id)"
  )
  if ($available_formats | is-empty) {
    log debug $"Removing book '($book_id)' in Calibre"
    ^calibredb remove $book_id
  }
  $output_file
}

# Check book metadata for errors
export def validate_book_metadata [
  metadata_source: string # Source of the metadata, either "hardcover", "comic vine"
  type: string # Type of work of the associated metadata, either "comic" or "book"
]: [
  record -> record<valid: bool, errors: list>
] {
  let book_metadata = $in
  if $metadata_source not-in ["comic vine" "hardcover"] {
    error make {
      msg: "validate_book_metadata: invalid metadata_source is not 'comic vine' or 'hardcover'"
      labels: [
        {text: "metadata_source" span: (metadata $metadata_source).span}
      ]
      help: "pass either 'comic vine' or 'hardcover' as the metadata_source argument to validate_book_metadata"
    }
  }
  if $type not-in ["comic" "book"] {
    error make {
      msg: "validate_book_metadata: invalid type is not 'comic' or 'book'"
      labels: [
        {text: "type" span: (metadata $type).span}
      ]
      help: "pass either 'comic' or 'book' as the type argument to validate_book_metadata"
    }
  }
  let edition_id = (
    if $metadata_source == "comic vine" {
      let comic_vine_issue_ids = $book_metadata.ids | where type == "comic_vine_issue_id"
      if ($comic_vine_issue_ids | is-empty) {
        error make {
          msg: "validate_book_metadata: missing Comic Vine issue id when metadata source is Comic Vine"
          labels: [
            {text: "book_metadata.ids" span: (metadata $book_metadata.ids).span}
          ]
          help: "populate the book_metadata.ids table with the Comic Vine issue id"
        }
      } else if ($comic_vine_issue_ids | length) > 1 {
        error make {
          msg: "validate_book_metadata: multiple Comic Vine issue ids when metadata source is Comic Vine"
          labels: [
            {text: "book_metadata.ids" span: (metadata $book_metadata.ids).span}
          ]
          help: "remove the duplicate Comic Vine issue id from the book_metadata.ids table"
        }
      } else {
        $comic_vine_issue_ids.id | first
      }
    } else if $metadata_source == "hardcover" {
      let hardcover_edition_ids = $book_metadata.ids | where type == "hardcover_edition_id"
      if ($hardcover_edition_ids | is-empty) {
        error make {
          msg: "validate_book_metadata: missing Hardcover edition id when metadata source is Hardcover"
          labels: [
            {text: "book_metadata.ids" span: (metadata $book_metadata.ids).span}
          ]
          help: "populate the book_metadata.ids table with the Hardcover edition id"
        }
      } else if ($hardcover_edition_ids | length) > 1 {
        error make {
          msg: "validate_book_metadata: multiple Hardcover edition ids when metadata source is Hardcover"
          labels: [
            {text: "book_metadata.ids" span: (metadata $book_metadata.ids).span}
          ]
          help: "remove the duplicate Hardcover edition id from the book_metadata.ids table"
        }
      } else {
        $hardcover_edition_ids.id | first
      }
    }
  )
  let hardcover_book_slug = (
    if $metadata_source == "hardcover" {
      let hardcover_book_slugs = $book_metadata.ids | where type == "hardcover_book_slug"
      if ($hardcover_book_slugs | is-empty) {
        error make {
          msg: "validate_book_metadata: missing Hardcover book slug when metadata source is Hardcover"
          labels: [
            {text: "book_metadata.ids" span: (metadata $book_metadata.ids).span}
          ]
          help: "populate the book_metadata.ids table with the Hardcover book slug"
        }
      } else if ($hardcover_book_slugs | length) > 1 {
        error make {
          msg: "validate_book_metadata: multiple Hardcover book slug when metadata source is Hardcover"
          labels: [
            {text: "book_metadata.ids" span: (metadata $book_metadata.ids).span}
          ]
          help: "remove the duplicate Hardcover book slug from the book_metadata.ids table"
        }
      } else {
        $hardcover_book_slugs.id | first
      }
    }
  )
  let edition_id_link = (
    if $metadata_source == "comic vine" {
      ('https://comicvine.gamespot.com/issue/4000-' + $edition_id) | ansi link --text $edition_id
    } else if $metadata_source == "hardcover" {
      ('https://hardcover.app/editions/' + $edition_id) | ansi link --text $edition_id
    }
  )
  let edition_type_string = (
    if $metadata_source == "comic vine" {
      "Comic Vine issue"
    } else if $metadata_source == "hardcover" {
      "Hardcover edition"
    }
  )
  let checks = [
    [condition message];
    [
      {|| $book_metadata | get --optional credits | is-empty}
      {||
        $"There are no contributors for the ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the contributors for the edition and retry."
      }
    ]
    [
      {|| ($book_metadata | get --optional credits | is-not-empty) and ($book_metadata.credits | all {|credit| $credit.role != "Writer"})}
      {|| (
        $"There are no authors set for the ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the authors for the edition and retry."
      )}
    ]
    [
      {|| $metadata_source == "hardcover" and ($book_metadata | get --optional forms_of_creative_work | is-empty) or ($book_metadata.forms_of_creative_work | first) == "unknown"}
      {|| $"Book category is not set for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the book category for the book and retry."}
    ]
    [
      {|| $type == "comic" and $metadata_source == "hardcover" and ($book_metadata | get --optional forms_of_creative_work | is-not-empty) and ($book_metadata | get --optional forms_of_creative_work.0) not-in ["graphic novel" "manga volume" "manhua volume" "manhwa volume"]}
      {|| $"Book category is set not set to 'Graphic Novel' for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Correct the book category for the book or move the edition to the correct book and retry."}
    ]
    [
      {|| $type == "comic" and $metadata_source == "hardcover" and ($book_metadata | get --optional credits | is-not-empty) and ($book_metadata | get --optional credits | is-not-empty) and ($book_metadata.credits | all {|credit| $credit.role != "Artist"})}
      {|| $"There is no illustrator set for the graphic novel ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the illustrator for the edition and retry."}
    ]
    [
      {|| $type == "book" and $metadata_source == "hardcover" and ($book_metadata | get --optional forms_of_creative_work | is-not-empty) and ($book_metadata.forms_of_creative_work | first) == "light novel" and ($book_metadata | get --optional credits | is-not-empty) and ($book_metadata.credits | all {|credit| $credit.role != "Artist"})}
      {|| $"There is no illustrator set for the light novel ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the illustrator for the edition and retry."}
    ]
    [
      {|| $type == "comic" and $metadata_source == "comic_vine" and ($book_metadata | get --optional credits | is-not-empty) and ($book_metadata.credits | all {|credit| $credit.role not-in ["Artist" "Colorist" "Inker" "Penciller"]})}
      {|| $"There is no 'Artist', 'Colorist', 'Inker', or 'Penciller' set for the ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the illustrator for the edition and retry."}
    ]
    # todo Should Comic Vine issue metadata also be required to have a cover artist?
    [
      {|| $type == "comic" and $metadata_source == "hardcover" and ($book_metadata | get --optional credits | is-not-empty) and ($book_metadata.credits | all {|credit| $credit.role != "Cover Artist"})}
      {|| $"There is no cover artist set for the graphic novel ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the cover artist for the edition and retry."}
    ]
    [
      {|| $type == "book" and $metadata_source == "hardcover" and ($book_metadata | get --optional forms_of_creative_work | is-not-empty) and ($book_metadata.forms_of_creative_work | first) == "light novel" and ($book_metadata | get --optional credits | is-not-empty) and ($book_metadata.credits | all {|credit| $credit.role != "Cover Artist"})}
      {|| $"There is no cover artist set for the light novel ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the illustrator for the edition and retry."}
    ]
    [
      {|| $metadata_source == "hardcover" and ($book_metadata | get --optional literary_type | is-empty) or $book_metadata.literary_type == "unknown"}
      {|| $"Literary type is not set for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the literary type for the book and retry."}
    ]
    [
      {|| $type == "comic" and $metadata_source == "hardcover" and ($book_metadata | get --optional literary_type | is-not-empty) and $book_metadata.literary_type != "fiction"}
      {|| $"Literary type is not set to 'fiction' for the graphic novel Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the literary type to 'fiction' for the book and retry."}
    ]
    [
      {|| $type == "book" and $metadata_source == "hardcover" and ($book_metadata | get --optional forms_of_creative_work | is-not-empty) and ($book_metadata.forms_of_creative_work | first) == "light novel" and ($book_metadata | get --optional literary_type | is-not-empty) and $book_metadata.literary_type != "fiction"}
      {|| $"Literary type is not set to 'fiction' for the light novel Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the literary type to 'fiction' for the book and retry."}
    ]
    [
      {|| $metadata_source == "hardcover" and ($book_metadata | get --optional _cover_image.2 | is-empty)}
      {|| $"There is no cover image set for the ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the cover for the edition and retry."}
    ]
    [
      {|| $metadata_source == "hardcover" and ($book_metadata | get --optional publication_date | is-empty)}
      {|| $"There is no release date set for the ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the release date for the edition and retry."}
    ]
    [
      {|| $metadata_source == "hardcover" and ($book_metadata | get --optional language | is-empty)}
      {|| $"There is no language set for the ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the language for the edition and retry."}
    ]
    [
      {|| ($book_metadata | get --optional publishers | is-empty)}
      {||
        # I'm not sure if it is actually possible to not have a publisher set in Comic Vine.
        $"There is no publisher set for the ($edition_type_string) (ansi yellow)($edition_id_link)(ansi reset). Set the publisher for the edition and retry."
      }
    ]
    [
      {||
        (
          $metadata_source == "hardcover"
          and ($book_metadata | get --optional series | is-not-empty)
          and ($book_metadata | get --optional primary_series_author | is-empty)
        )
      }
      {||
        $"There is no series author set for the featured series (ansi yellow)($book_metadata.series)(ansi reset). Set the author of the series on Hardcover."
      }
    ]
  ]
  let error_messages = (
    $checks | reduce --fold [] {|check acc|
      if (do $check.condition) {
        $acc | append (do $check.message)
      } else {
        $acc
      }
    }
  )
  {
    valid: ($error_messages | is-empty)
    errors: $error_messages
  }
}

# Parse metadata from exiftool's JSON output for a PDF file
export def from_pdf_metadata []: [
  record -> record
] {
  let metadata = $in

  let publication_date = (
    let date = $metadata | get --optional "Date";
    if ($date | is-not-empty) {
      $date | into datetime
    }
  )
  let language = (
    let language_code = $metadata | get --optional Language;
    if ($language_code | is-not-empty) {
      if ($language_code | str length) == 2 {
        $language_code | from_language_code # iso_639_1
      } else if ($language_code | str length) == 3 {
        $language_code | from_language_code # iso_639_3
      } else {
        # todo Support type parameter in from_language_code
        # $language_code | from_language_code ietf_bcp_47
      }
    }
  )
  # ISBN can come from Isbn, ISBN, or Identifier table
  # Both Subject and Keywords fields should be parsed into allowed tags and genres
  # exiftool doesn't parse IdentifierScheme correctly, so I can't parse the fields properly.
  # Author or Creator field for writers and how are multiple split?
  # Author is split with " & "
  # Creator is a proper list
  let credits = (
    if ($metadata | get --optional Creator | is-not-empty) {
      $metadata.Creator | each {|creator|
        {
          person: $creator
          role: "Writer"
          primary: true
          language: ""
        }
      }
    }
  )
  (
    {}
    | upsert_if_present "series" $metadata "Series"
    | upsert_if_present "issue" $metadata "SeriesSeries_index"
    | upsert_if_present "description" $metadata "Description"
    | upsert_if_present "publication_date" $metadata "Date"
    | upsert_if_present "page_count" $metadata "PageCount"
    | upsert_if_present "publisher" $metadata "Publisher"
    | upsert_if_present "isbn" $metadata "Isbn"
    | upsert_if_present "isbn" $metadata "ISBN"
    | upsert_if_value "language" $language
    | upsert_if_value "credits" $credits
  )
}

# Parse metadata from an EPUB's content.opf XML file
#
# Note that currently, namespace information is dropped by Nushell.
# https://github.com/nushell/nushell/issues/11523
#
# todo Fallback to getting publisher from creator role.
export def from_opf_xml [
  identifier_schemes: table = $opf_identifier_schemes
  roles_map: table = [
    [opf_roles role];
    # Kavita treats the illustrator as Inker.
    [["adapter" "adp"] "Adapter"]
    [["artist" "art" "illustrator" "ill"] "Artist"]
    [["author" "aut"] "Writer"]
    [["book designer" "bkd"] "Book Designer"]
    [["book jacket designer" "bjd"] "Book Jacket Designer"]
    [["book producer" "bkp"] "Book Producer"]
    [["cartographer" "ctg"] "Cartographer"]
    [["colorist" "clr"] "Colorist"]
    [["commentator for written text" "cwt"] "Commentator"]
    [["composer" "cmp"] "Composer"]
    [["consultant" "csl"] "Consultant"]
    [["cover designer" "cov"] "Cover Designer"]
    [["distributor" "dst"] "Distributor"]
    [["creator" "cre"] "Creator"]
    [["designer" "dsr"] "Designer"]
    [["editor" "edt"] "Editor"]
    [["inker" "ink"] "Inker"]
    [["letter" "ltr"] "Letterer"]
    [["narrator" "nrt"] "Narrator"]
    [["originator" "org"] "Originator"]
    [["photographer" "pht"] "Photographer"]
    [["penciller" "pnc"] "Penciller"]
    [["proofreader" "pfr"] "Proofreader"]
    [["publisher" "pbl"] "Publisher"]
    [["translator" "trl"] "Translator"]
    [["writer of foreword" "wfw"] "Foreword"]
    [["writer of introduction" "win"] "Introduction"]
    [["writer of preface" "wpr"] "Preface"]
  ]
]: [
  record -> record
] {
  let opf = $in
  let unique_identifier_id = (
    if $opf.tag == "package" {
      $opf.attributes | get --optional unique-identifier
    }
  )
  let opf = (
    if $opf.tag == "package" {
      $opf.content | where tag == "metadata" | first
    } else {
      $opf
    }
  )
  if ($opf | get --optional tag) != "metadata" {
    error make {
      msg: "missing metadata tag in OPF metadata"
      labels: [
        {text: "opf" span: (metadata $opf).span}
      ]
      help: "add the missing metadata element to the OPF metadata"
    }
  }

  let metadata_content = $opf | get content

  # If and when Nushell actually includes namespaces, fail here.
  # The code will need to be updated to use the namespaced tags.
  # https://github.com/nushell/nushell/issues/11523
  if ($metadata_content | where tag == "dc:title" | is-not-empty) {
    error make {
      msg: "namespaces are now available in the 'from xml' Nushell command"
      labels: [
        {text: "metadata_content" span: (metadata $metadata_content).span}
      ]
      help: "update the tags to include the 'dc:' namespace in the from_opf_xml function"
    }
  }

  # https://www.w3.org/TR/epub-33/#sec-opf-dccreator
  let credits = (
    let creators = $metadata_content | where tag == creator;
    if ($creators | is-not-empty) {
      let meta = $metadata_content | where tag == meta
      # The order of the creators is important.
      $creators | reduce --fold [] {|it acc|
        # Check for refines first, then fallback to role attribute.
        let id = $it | get --optional attributes.id
        let meta_refines_role_items = (
          if ($id | is-empty) {

          } else {
            if ($meta | is-not-empty) {
              $meta | where {|i| ($i | get --optional attributes.refines) == $"#($id)" and ($i | get --optional attributes.property) == "role" and ($i | get --optional attributes.scheme) == "marc:relators" and ($i | get --optional content.0.content | is-not-empty)}
            }
          }
        )
        if ($id | is-empty) and ($meta_refines_role_items | is-empty) {
          let opf_role = $it | get --optional attributes.role
          let role = (
            if ($opf_role | is-empty) {
              "Writer"
            } else {
              let roles = $roles_map | where {|i| $opf_role in $i.opf_roles}
              if ($roles | is-empty) {
                error make {
                  msg: "role from OPF metadata missing in roles_map"
                  labels: [
                    {text: "opf_role" span: (metadata $opf_role).span}
                    {text: "roles_map" span: (metadata $roles_map).span}
                  ]
                  help: $"add the missing role (ansi yellow)($opf_role)(ansi reset) to the roles_map table"
                }
              } else if ($roles | length) > 1 {
                error make {
                  msg: "duplicate roles for role in roles_map"
                  labels: [
                    {text: "role" span: (metadata $opf_role).span}
                    {text: "roles_map" span: (metadata $roles_map).span}
                  ]
                  help: $"remove the duplicate role (ansi yellow)($opf_role)(ansi reset) from the roles_map table"
                }
              } else {
                $roles.role | first
              }
            }
          )
          $acc | append [
            [creator role primary language];
            [
              ($it.content.0.content)
              $role
              ($role == "Writer")
              ""
            ]
          ]
        } else {
          $meta_refines_role_items | reduce --fold $acc {|role_it role_acc|
            let roles = $roles_map | where {|i| $role_it.content.0.content in $i.opf_roles}
            if ($roles | is-empty) {
              error make {
                msg: "role from OPF metadata missing in roles_map"
                labels: [
                  {text: "role" span: (metadata $role_it.content.0.content).span}
                  {text: "roles_map" span: (metadata $roles_map).span}
                ]
                help: $"add the missing role (ansi yellow)($role_it.content.0.content)(ansi reset) to the roles_map table"
              }
            } else if ($roles | length) > 1 {
              error make {
                msg: "duplicate roles for role in roles_map"
                labels: [
                  {text: "role" span: (metadata $role_it.content.0.content).span}
                  {text: "roles_map" span: (metadata $roles_map).span}
                ]
                help: $"remove the duplicate role (ansi yellow)($role_it.content.0.content)(ansi reset) from the roles_map table"
              }
            } else {
              $role_acc | append [
                [creator role primary language];
                [
                  ($it.content.0.content)
                  ($roles.role | first)
                  (($roles.role | first) == "Writer")
                  ""
                ]
              ]
            }
          }
        }
      }
    }
  )

  let series = (
    let meta = $metadata_content | where tag == meta;
    if ($meta | is-not-empty) {
      # EPUB 3.2 series tag
      if ($meta | any {|it| ($it | get --optional attributes.property) == "belongs-to-collection"}) {
        let belongs_to_collection_items = $meta | where {|it| ($it | get --optional attributes.property) == "belongs-to-collection"}
        $belongs_to_collection_items | reduce --fold [] {|it acc|
          let id = $it.attributes | get --optional id
          if ($id | is-empty) {
            $acc | append [[name position]; [($it.content.0.content) null]]
          } else {
            let refines_group_position_for_id_items = $meta | where {|it| ($it | get --optional attributes.refines) == $"#($id)" and ($it | get --optional attributes.property) == "group-position"}
            if ($refines_group_position_for_id_items | is-empty) {
              $acc | append [[name position]; [($it.content.0.content) null]]
            } else {
              if (($refines_group_position_for_id_items | length) > 1) {
                log warning $"Multiple group-position attributes for id ($id): ($refines_group_position_for_id_items). Ignoring all but the first."
              }
              $acc | append [
                [name position];
                [
                  ($it.content.0.content)
                  ($refines_group_position_for_id_items | first | get content | first | get content)
                ]
              ]
            }
          }
        }
      } else {
        # Fallback to Calibre series tag
        let series = $meta | where {|it| ($it.attributes | get --optional name) == "calibre:series"}
        let series_name = (
          if ($series | is-not-empty) {
            $series | first | get attributes.content
          }
        )
        let series_indices = $meta | where {|it| ($it.attributes | get --optional name) == "calibre:series_index"}
        let series_position = (
          if ($series_indices | is-not-empty) {
            $series_indices | first | get attributes.content
          }
        )
        if ($series_name | is-not-empty) {
          if ($series_position | is-empty) {
            [
              [name position];
              [$series_name null]
            ]
          } else {
            [
              [name position];
              [$series_name $series_position]
            ]
          }
        }
      }
    }
  )

  # The metadata structure for series only supports one series right now.
  let single_series = (
    if ($series | is-empty) {
    } else if ($series | length) > 1 {
      # Maintain the order as parsed, but place the series with a position at the end.
      let series = $series | sort-by --custom {|a b| ($a | get --optional position | is-not-empty) and ($b | get --optional position | is-empty)}
      log warning $"Multiple series parsed from OPF metadata: ($series). Ignoring all but the first one."
      # This ensures when there are multiple series, one with a position is preferred over the series without positions.
      $series | first
    } else {
      $series | first
    }
  )

  # todo Handle multiple publishers?
  let publisher = (
    let publishers = $metadata_content | where tag == publisher;
    if ($publishers | is-not-empty) {
      $publishers | get content | first | get content | flatten | uniq | first
    }
  )

  let language = (
    let languages = $metadata_content | where tag == language;
    if ($languages | is-not-empty) {
      $languages | get content | first | get content | flatten | uniq | first
    }
  )
  let language = (
    let language_code = $language;
    if ($language_code | is-not-empty) {
      if ($language_code | str length) == 2 {
        $language_code | from_language_code # iso_639_1
      } else if ($language_code | str length) == 3 {
        $language_code | from_language_code # iso_639_3
      } else {
        $language_code | from_language_code
      }
    }
  )

  let title = (
    let titles = $metadata_content | where tag == title;
    if ($titles | is-not-empty) {
      $titles | get content | first | get content | flatten | uniq | first
    }
  )

  let description = (
    let descriptions = $metadata_content | where tag == description;
    if ($descriptions | is-not-empty) {
      $descriptions | get content | first | get content | flatten | uniq | first
    }
  )

  let publication_date = (
    let dates = $metadata_content | where tag == date;
    if ($dates | is-not-empty) {
      let date = $dates | get content | first | get content | flatten | uniq | first
      if ($date | is-not-empty) {
        $date | into datetime
      }
    }
  )

  let genres = (
    let genres = $metadata_content | where tag == subject;
    if ($genres | is-not-empty) {
      $genres | get content | flatten | get content | uniq | sanitize_genres_or_tags $genre_allowlist
    }
  )

  let ids = (
    let ids = $metadata_content | where tag == identifier;
    if ($ids | is-not-empty) {
      let unique_identifiers = $ids | where {|it|
        ($it.attributes | get --optional id) == $unique_identifier_id
      }
      $identifier_schemes | reduce --fold [] {|identifier_schemes_and_type acc|
        let matching_ids = $ids | where {|it|
          (
            (
              ($it.attributes | get --optional scheme | is-not-empty)
              and ($it.attributes.scheme | str upcase) in $identifier_schemes_and_type.schemes
            )
            or (
              ($it.attributes | get --optional "opf:scheme" | is-not-empty)
              and ($it.attributes | get "opf:scheme" | str upcase) in $identifier_schemes_and_type.schemes
            )
            or (
              ($it.attributes | get --optional id | is-not-empty)
              and (
                $metadata_content
                # A where doesn't work here since the closure can't access $it.
                | reduce --fold [] {|meta_it inner_acc|
                  if (
                    $meta_it.tag == "meta"
                    and ($meta_it.attributes | get --optional refines) == $"#($it.attributes.id)"
                    and ($meta_it.attributes | get --optional property) == "identifier-type"
                    and (
                      (
                        ($meta_it.attributes | get --optional "scheme" | is-not-empty)
                        and ($meta_it.attributes | get --optional scheme | str upcase) in $identifier_schemes_and_type.schemes
                      )
                      or (
                        ($meta_it | get --optional content.0.content | is-not-empty)
                        and ($meta_it | get --optional content.0.content | str upcase) in $identifier_schemes_and_type.schemes
                      )
                    )
                  ) {
                    $inner_acc | append $meta_it
                  } else {
                    $inner_acc
                  }
                }
                | is-not-empty
              )
            )
          )
        }
        if ($matching_ids | is-empty) {
          $acc
        } else {
          let id = $matching_ids | get content | first | get content | first
          let id = (
            if $id =~ '^(?:urn:uuid:)?[a-f0-9]{8}(?:-[a-f0-9]{4}){4}[a-f0-9]{8}$' {
              (
                $id
                | parse --regex '^(?:urn:uuid:)?(?P<uuid>[a-f0-9]{8}(?:-[a-f0-9]{4}){4}[a-f0-9]{8})$'
                | get uuid
                | first
              )
            } else {
              $id
            }
          )
          # Ignore multiple ids of the same type.
          # todo Warn if there are multiple, distinct IDs for the same scheme.
          $acc | append {
            type: $identifier_schemes_and_type.type
            id: (
              # if ($identifier_schemes_and_type.type == "comic_vine_issue_id") {
              #   if ($id | str starts-with "4000-") {
              #     $id
              #   } else {
              #     "4000-" + $id
              #   }
              # } else if ($identifier_schemes_and_type.type == "comic_vine_volume_id") {
              #   if ($id | str starts-with "4050-") {
              #     $id
              #   } else {
              #     "4050-" + $id
              #   }
              # } else {
                $id
              # }
            )
          }
        }
      } | append (
        if ($unique_identifiers | is-not-empty) {
          if ($unique_identifiers | length) > 1 {
            error make {
              msg: "multiple unique identifiers"
              labels: [{text: "unique_identifiers" span: (metadata $unique_identifiers).span}]
              help: $"remove duplicate unique identifiers where the type attribute is (ansi yellow)($unique_identifier_id)(ansi reset)"
            }
          } else {
            let id = $unique_identifiers | get content | first | get content | first
            if $id =~ '^(?:urn:uuid:)?[a-f0-9]{8}(?:-[a-f0-9]{4}){4}[a-f0-9]{8}$' {
              {
                type: "epub_uuid"
                id: (
                  $id
                  | parse --regex '^(?:urn:uuid:)?(?P<epub_uuid>[a-f0-9]{8}(?:-[a-f0-9]{4}){4}[a-f0-9]{8})$'
                  | get epub_uuid
                  | first
                )
              }
            } else if (
              (
                ($id | str replace "urn:isbn:" "" | str replace "isbn:" "" | str replace "ISBN:" "" | str replace --all "-" "" | str length) == 13
                and ($id | str replace "urn:isbn:" "" | str replace "isbn:" "" | str replace "ISBN:" "" | str replace --all "-" "" | validate_isbn)
              )
            ) {
              # Ignore an obvious ISBN as that will be parsed separately.
            } else {
              error make {
                msg: "unknown unique identifier type"
                labels: [
                  {text: "unique_identifiers" span: (metadata $unique_identifiers).span}
                  {text: "id" span: (metadata $id).span}
                ]
                help: $"add support for the unknown id (ansi yellow)($id)(ansi reset)"
              }
            }
          }
        }
      ) | uniq
    }
  )

  # todo get title sort from meta calibre:title_sort?

  let isbn = (
    let ids = $metadata_content | where tag == identifier;
    if ($ids | is-not-empty) {
      let isbns = $ids | where {|it|
        (
          (
            ($it.attributes | get --optional scheme | is-not-empty)
            and $it.attributes.scheme =~ "(?i)isbn"
          )
          or (
            ($it.attributes | get --optional "opf:scheme" | is-not-empty)
            and ($it.attributes | get "opf:scheme") =~ "(?i)isbn"
          )
          or (
            ($it.attributes | get --optional id | is-not-empty)
            and (
              $metadata_content
              # A where doesn't work here since the closure can't access $it.
              | reduce --fold [] {|meta_it acc|
                if (
                  $meta_it.tag == "meta"
                  and ($meta_it.attributes | get --optional refines) == $"#($it.attributes.id)"
                  and ($meta_it.attributes | get --optional property) == "identifier-type"
                  # https://ns.editeur.org/onix/en/5
                  and ($meta_it.attributes | get --optional scheme) == "onix:codelist5"
                  and ($meta_it.content | first | get --optional content ) == "15"
                ) {
                  $acc | append ($meta_it)
                } else {
                  $acc
                }
              } | is-not-empty
            )
          )
          or ($it | get --optional content.0.content) =~ '^urn:isbn:[0-9]{13}$'
          or (
            ($it | get --optional content.0.content | is-not-empty)
            and ($it.content.0.content | str replace "urn:isbn:" "" | str replace "isbn:" "" | str replace "ISBN:" "" | str replace --all "-" "" | str length) == 13
            and ($it.content.0.content | str replace "urn:isbn:" "" | str replace "isbn:" "" | str replace "ISBN:" "" | str replace --all "-" "" | validate_isbn)
          )
        )
      }
      # <dc:identifier id="pub-identifier">urn:isbn:9781506704197</dc:identifier>
      # <meta property="identifier-type" refines="#pub-identifier" scheme="onix:codelist5">15</meta>
      # log debug $"ids.content: ($ids.content | to json)"
      # log debug $"isbns: ($isbns)"
      let isbns = (
        if ($isbns | is-not-empty) {
          (
            $isbns
            | get content
            | first
            | get content
            | flatten
            | uniq
            | (
              let input = $in;
              if ($input | is-empty) {

              } else {
                $input | str replace --all "-" ""
              }
            )
            | each {|isbn|
              if ($isbn =~ '^urn:isbn:[0-9]{13}$') {
                $isbn | parse --regex '^urn:isbn:(?P<isbn>[0-9]{13})$' | get isbn | first
              } else if (
                ($isbn | str replace "urn:isbn:" "" | str replace "isbn:" "" | str replace "ISBN:" "" | str replace --all "-" "" | str length) == 13
                and ($isbn | str replace "urn:isbn:" "" | str replace "isbn:" "" | str replace "ISBN:" "" | str replace --all "-" "" | validate_isbn)
              ) {
                $isbn | str replace "urn:isbn:" "" | str replace "isbn:" "" | str replace "ISBN:" "" | str replace --all "-" ""
              } else {
                $isbn
              }
            }
          )
        }
      )
      # todo Make sure that isbns isn't empty?
      if ($isbns | length) > 1 {
        error make {
          msg: "multiple isbns found in OPF metadata"
          labels: [{text: "isbns" span: (metadata $isbns).span}]
          help: $"remove duplicate ISBNs (ansi yellow)($isbns)(ansi reset) from the OPF metadata"
        }
      } else if ($isbns | length) == 1 {
        $isbns | first
      }
    }
  )

  (
    {}
    | upsert_if_value "credits" $credits
    # todo Should we attempt to parse multiple publishers from PDF metadata?
    | upsert_if_value "publishers" [$publisher]
    | upsert_if_value "genres" $genres
    | upsert_if_value "language" $language
    | upsert_if_value "title" $title
    | upsert_if_value "description" $description
    | upsert_if_value "publication_date" $publication_date
    | upsert_if_value "ids" $ids
    | upsert_if_value "series" ($single_series | get --optional name)
    | upsert_if_value "issue" ($single_series | get --optional position)
    | upsert_if_value "isbn" $isbn
  )
}

# Output metadata in the format used by an EPUB's content.opf XML file
#
# https://www.w3.org/TR/epub/
export def to_opf_xml [
  language_codes_map: table = $iso_language_codes_map
  identifier_schemes: table = $opf_identifier_schemes
  roles_map: record = $opf_roles_map
]: [
  record -> record
] {
  let metadata = $in

  # todo I should probably just work with the metadata content field instead.
  # [[tag, attributes, content]; []]
  let opf_metadata = []

  # title
  let opf_metadata = (
    if ($metadata | get --optional title | is-empty) {
      $opf_metadata
    } else {
      $opf_metadata | append (
        [
          [tag, attributes, content];
          [
            "dc:title"
            {}
            [
              [tag, attributes, content];
              [null, null, $metadata.title]
            ]
          ]
        ]
      )
    }
  )

  # language
  # todo Handle language missing from map.
  let opf_metadata = (
    if ($metadata | get --optional language | is-empty) {
      $opf_metadata
    } else {
      $opf_metadata | append (
        [
          [tag, attributes, content];
          [
            "dc:language"
            {}
            [
              [tag, attributes, content];
              [null, null, ($metadata.language | into_language_code iso_639_3 $language_codes_map)]
            ]
          ]
        ]
      )
    }
  )

  # description
  let opf_metadata = (
    if ($metadata | get --optional description | is-empty) {
      $opf_metadata
    } else {
      $opf_metadata | append (
        [
          [tag, attributes, content];
          [
            "dc:description"
            {}
            [
              [tag, attributes, content];
              [null, null, $metadata.description]
            ]
          ]
        ]
      )
    }
  )

  # date
  let opf_metadata = (
    if ($metadata | get --optional publication_date | is-empty) {
      $opf_metadata
    } else {
      $opf_metadata | append (
        [
          [tag, attributes, content];
          [
            "dc:date"
            {}
            [
              [tag, attributes, content];
              # "2023-05-01T05:00:00+00:00"
              [null, null, ($metadata.publication_date | date to-timezone "UTC" | format date '%FT%H:%M:%S%Z')]
            ]
          ]
        ]
      )
    }
  )

  # publisher
  # Prefer imprint when present.
  let publishers = (
    if ($metadata | get --optional imprints | is-not-empty) {
      $metadata.imprints
    } else {
      $metadata.publishers
    }
  )
  let opf_metadata = $opf_metadata | append (
    $publishers | reduce --fold [] {|publisher acc|
      $acc | append [
        [tag, attributes, content];
        [
          "dc:publisher"
          {}
          [
            [tag, attributes, content];
            [null, null, $publisher]
          ]
        ]
      ]
    }
  )

  # unique-identifier field order of preference:
  # This must match the ID specified in the ncx/toc.ncx file.
  # book_id which equates to the unique publisher id originally embedded in an ebook.
  # ISBN
  # Hardcover
  # Wikidata
  # BookBrainz
  let unique_identifier = (
    let epub_uuids = $metadata.ids | where type == epub_uuid;
    if ($epub_uuids | length) == 1 {
      "bookid"
    } else {
      if ($epub_uuids | length) > 1 {
        log error $"Multiple EPUB UUIDs exist: ($epub_uuids)"
      } else {
        if ($metadata | get --optional isbn | is-empty) {
          let hardcover_edition_ids = $metadata.ids | where type == hardcover_edition_id
          if ($hardcover_edition_ids | length) == 1 {
            "hardcover-edition-identifier"
          } else {
            if ($hardcover_edition_ids | length) > 1 {
              log error $"Multiple hardcover edition ids exist: ($hardcover_edition_ids)"
            } else {
              let wikidata_edition_ids = $metadata.ids | where type == wikidata_edition_id
              if ($wikidata_edition_ids | length) == 1 {
                "wikidata-edition-identifier"
              } else {
                if ($wikidata_edition_ids | length) > 1 {
                  log error $"Multiple wikidata edition ids exist: ($wikidata_edition_ids)"
                } else {
                  let bookbrainz_edition_ids = $metadata.ids | where type == bookbrainz_edition_id
                  if ($bookbrainz_edition_ids | length) == 1 {
                    "bookbrainz-edition-identifier"
                  } else {
                    if ($bookbrainz_edition_ids | length) > 1 {
                      log error $"Multiple BookBrainz edition ids exist: ($bookbrainz_edition_ids)"
                    } else {
                      log error "No unique book identifier available!"
                    }
                  }
                }
              }
            }
          }
        } else {
          "isbn-identifier"
        }
      }
    }
  )

  # https://www.w3.org/TR/epub-33/#sec-opf-dcidentifier
  # Don't allow multiple identifiers of the same type.
  if ($metadata.ids | get --optional type | uniq --repeated | is-not-empty) {
    error make {
      msg: "multiple identifiers for a single type are not allowed"
      labels: [{text: "metadata.ids" span: (metadata $metadata.ids).span}]
      help: $"remove duplicate identifiers of the types (ansi yellow)($metadata.ids | get --optional type | uniq --repeated)(ansi reset)"
    }
  }
  let opf_metadata = $opf_metadata | append (
    $metadata.ids | reduce --fold [] {|id acc|
      # for each type, add each scheme
      let schemes = $identifier_schemes | where type == $id.type
      # log debug $"schemes: ($schemes)"
      if ($id.type == "epub_uuid") {
        $acc
      } else if ($schemes | is-empty) {
        error make {
          msg: "missing OPF schemes for type"
          labels: [
            {text: "id.type" span: (metadata $id.type).span}
            {text: "identifier_schemes" span: (metadata $identifier_schemes).span}
          ]
          help: $"add the missing OPF scheme for the type (ansi yellow)($id.type)(ansi reset) to the identifier_schemes table"
        }
      } else if ($schemes | length) > 1 {
        error make {
          msg: "multiple OPF schemes for type"
          labels: [
            {text: "id.type" span: (metadata $id.type).span}
            {text: "identifier_schemes" span: (metadata $identifier_schemes).span}
          ]
          help: $"remove the duplicate OPF schemes for the type (ansi yellow)($id.type)(ansi reset) to the identifier_schemes table"
        }
      } else {
        $schemes | first | get schemes | reduce --fold $acc {|scheme inner_acc|
          $inner_acc | append [
            [tag, attributes, content];
            [
              "dc:identifier"
              {
                # Include the "opf:scheme" field for compatibility.
                # "opf:scheme": $scheme
                "id": $"($scheme | str downcase)-identifier"
              }
              [
                [tag, attributes, content];
                [null, null, (
                  if $id.type in ["bookbrainz_edition_id" "musicbrainz_release_id"] {
                    $"urn:uuid:($id.id)"
                  } else {
                    ($id.id | into string)
                  }
                )]
              ]
            ]
            [
              "meta"
              {
                refines: $"#($scheme | str downcase)-identifier"
                property: "identifier-type"
                # scheme: "($scheme | str downcase)"
              }
              [
                [tag, attributes, content];
                [null, null, $scheme]
              ]
            ]
          ]
        }
      }
    } | append (
      if ($metadata | get --optional isbn | is-empty) {
      } else {
        [
          [tag, attributes, content];
          [
            "dc:identifier"
            {
              # Kavita requires the opf:scheme key in order to properly parse the ISBN.
              "opf:scheme": "ISBN"
              id: "isbn-identifier"
            }
            [
              [tag, attributes, content];
              [null, null, $"urn:isbn:($metadata.isbn)"]
            ]
          ]
          # https://ns.editeur.org/onix/en/5
          # ISBN-13
          [
            "meta"
            {
              refines: "#isbn-identifier"
              property: "identifier-type"
              scheme: "onix:codelist5"
            }
            [
              [tag, attributes, content];
              [null, null, "15"]
            ]
          ]
        ]
      }
    ) | append (
      if ($metadata | get --optional ids | where type == "epub_uuid" | is-empty) {
      } else {
        let epub_uuids = $metadata | get --optional ids | where type == "epub_uuid"
        if ($epub_uuids | is-empty) {
        } else if ($epub_uuids | length) > 1 {
          error make {
            msg: "multiple EPUB UUIDs"
            labels: [
              {text: "epub_uuids" span: (metadata $epub_uuids).span}
            ]
            help: $"remove the duplicate EPUB UUIDs (ansi yellow)($epub_uuids)(ansi reset) from the OPF metadata"
          }
        } else {
          [
            [tag, attributes, content];
            [
              "dc:identifier"
              {
                id: "bookid"
              }
              [
                [tag, attributes, content];
                [null, null, $"urn:uuid:($epub_uuids.id | first)"]
              ]
            ]
          ]
        }
      }
    )
  )

  # Kavita supports url: fields as weblinks
  let opf_metadata = $opf_metadata | append (
    $metadata.ids | reduce --fold [] {|id acc|
      let url = (
        if $id.type in ["epub_uuid" "hardcover_book_slug"] {
          ""
        } else if $id.type == "hardcover_edition_id" {
          if "hardcover_book_slug" in ($metadata | get --optional ids.type) {
            $id.id | identifier_into_url $id.type --hardcover-book-slug ($metadata.ids | where type == "hardcover_book_slug" | get id | first)
          } else {
            $id.id | identifier_into_url $id.type
          }
        } else if $id.type == "comic_vine_issue_id" {
          let i = (
            if ($id.id | str starts-with "4000-") {
              $id.id
            } else {
              "4000-" + $id.id
            }
          )
          $i | identifier_into_url $id.type
        } else if $id.type == "comic_vine_volume_id" {
          let i = (
            if ($id.id | str starts-with "4050-") {
              $id.id
            } else {
              "4050-" + $id.id
            }
          )
          $i | identifier_into_url $id.type
        } else {
          $id.id | identifier_into_url $id.type
        }
      )
      if ($url | is-empty) {
        $acc
      } else {
        $acc | append [
          [tag, attributes, content];
          [
            "dc:identifier"
            {}
            [
              [tag, attributes, content];
              [null, null, $"url:($url)"]
            ]
          ]
        ]
      }
    }
  )

  # series
  # Only a single series is supported.
  # todo Sort series name?
  let opf_metadata = (
    if ($metadata | get --optional series | is-empty) {
      $opf_metadata
    } else {
      $opf_metadata | append (
        [
          [tag, attributes, content];
          [
            "meta"
            {
              name: "calibre:series"
              content: $metadata.series
            }
            []
          ]
          # Epub 3.2
          # https://www.w3.org/TR/epub-33/#sec-collection-type
          [
            "meta"
            {
              property: "belongs-to-collection"
              id: "series-id-1"
            }
            [
              [tag, attributes, content];
              [null null $metadata.series]
            ]
          ]
        ]
      )
    }
  )
  let opf_metadata = (
    if ($metadata | get --optional issue | is-empty) {
      $opf_metadata
    } else {
      $opf_metadata | append (
        [
          [tag, attributes, content];
          [
            "meta"
            {
              name: "calibre:series_index"
              content: ($metadata.issue | into string)
            }
            []
          ]
          # Epub 3.2
          [
            "meta"
            {
              refines: "#series-id-1"
              property: "group-position"
            }
            [
              [tag, attributes, content];
              [null null ($metadata.issue | into string)]
            ]
          ]
        ]
      )
    }
  )

  # genres
  let opf_metadata = $opf_metadata | append (
    $metadata | get --optional genres | reduce --fold [] {|genre acc|
      $acc | append [
        [tag, attributes, content];
        [
          "dc:subject"
          {}
          [
            [tag, attributes, content];
            [null, null, $genre]
          ]
        ]
      ]
    }
  )

  # modified
  # This field is required.
  let opf_metadata = (
    $opf_metadata | append (
      [
        [tag, attributes, content];
        [
          "meta"
          {property: "dcterms:modified"}
          [
            [tag, attributes, content];
            [null null (date now | date to-timezone "UTC" | format date '%FT%H:%M:%SZ')]
          ]
        ]
      ]
    )
  )

  # Sort the fields to be as deterministic as possible.
  let opf_metadata = (
    if ($opf_metadata | is-empty) {
      []
    } else {
      $opf_metadata | sort-by tag content.content
    }
  )

  # The order of creators is important.
  # https://www.w3.org/TR/epub-33/#sec-opf-dccreator
  let opf_metadata = $opf_metadata | append (
    let credits = $metadata | get --optional credits;
    if ($credits | is-empty) {
    } else {
      $credits | sort-by --custom {|a b|
        # Place writers first, followed by artists and illustrators.
        # Place editors last.
        if ($a.role == "Writer") and ($b.role == "Writer") {
          $a.primary
        } else if "Writer" in [$a.role $b.role] {
          $a.role == "Writer"
        } else {
          if ($a.role in ["Artist" "Illustrator"]) and ($b.role in ["Artist" "Illustrator"]) {
            $a.primary
          } else if $a.role in ["Artist" "Illustrator"] or $b.role in ["Artist" "Illustrator"] {
            $a.role in ["Artist" "Illustrator"]
          } else {
            if ($a.role == "Editor") and ($b.role == "Editor") {
              $a.primary
            } else if "Editor" in [$a.role $b.role] {
              $b.role == "Editor"
            } else {
              false
            }
          }
        }
      # todo If we ever have ID, we should group by that instead.
      } | group-by --to-table person | get items | each {|it|
        {
          person: ($it.person | first)
          roles: ($it.role | uniq)
          primary: ($it.primary | any {|i| $i})
          language: ($it.language | first)
          # id: ($it.id | first)
        }
      } | enumerate | reduce --fold [] {|credit acc|
        # log debug $"credit: ($credit)"
        if ($credit.item.roles | any {|role| ($roles_map | get --optional $role | is-not-empty)}) {
          $acc | append (
            [
              [tag, attributes, content];
              [
                "dc:creator"
                {
                  # role: aut
                  # todo Add sort name?
                  # file-as: "Umino, Chica"
                  id: $"id-creator-($credit.index)"
                }
                [
                  [tag, attributes, content];
                  [null, null, $credit.item.person]
                ]
              ]
            ]
          ) | append (
            $credit.item.roles
            | reduce --fold [] {|role role_acc|
              let r = $roles_map | get --optional $role
              if ($r | is-empty) {
                $role_acc
              } else {
                $role_acc | append [
                  [tag, attributes, content];
                  [
                    "meta"
                    {
                      refines: $"#id-creator-($credit.index)"
                      property: "role"
                      scheme: "marc:relators"
                    }
                    [
                      [tag, attributes, content];
                      [null, null, $r]
                    ]
                  ]
                ]
              }
            }
          )
        } else {
          $acc
        }
      }
    }
  )

  let attributes = {version: "3.0"}
  let attributes = (
    if ($unique_identifier | is-empty) {
      $attributes
    } else {
      $attributes | merge {"unique-identifier": $unique_identifier}
    }
  )
  {
    "tag": "package"
    attributes: $attributes,
    content: [
      [tag, attributes, content];
      [
        "metadata"
        {
          "xmlns:calibre": "http://calibre.kovidgoyal.net/2009/metadata"
          "xmlns:dc": "http://purl.org/dc/elements/1.1/"
          "xmlns:opf": "http://www.idpf.org/2007/opf"
        }
        $opf_metadata
      ]
    ]
  }
}

# Use epubcheck to check if an EPUB is valid
export def epubcheck []: [path -> bool] {
  let epub = $in
  let result = do { ^epubcheck --failonwarnings --json - $epub } | complete
  if ($result.exit_code != 0) {
    let messages = $result.stdout | from json | get messages
    if ($messages | is-empty) {
      # This shouldn't happen, but throw an error if it does anyway.
      error make {
        msg: "non-zero exit code while validating EPUB with epubcheck"
        labels: [
          {text: "result.exit_code" span: (metadata $result.exit_code).span}
        ]
        help: $"error validating the EPUB file (ansi yellow)($epub)(ansi reset):\nstderr: ($result.stderr)\nstdout: ($result.stdout)\n"
      }
    } else {
      # The 'opf:scheme' attribute is required for Kavita, so ignore related error messages.
      if ($messages | all {|it| $it.ID == "RSC-005" and $it.message == 'Error while parsing file: attribute "opf:scheme" not allowed here; expected attribute "id"' }) {
        true
      } else {
        error make {
          msg: "non-zero exit code while validating EPUB with epubcheck"
          labels: [
            {text: "result.exit_code" span: (metadata $result.exit_code).span}
          ]
          help: $"error validating the EPUB file (ansi yellow)($epub)(ansi reset):\nstderr: ($result.stderr)\nmessages: ($messages | where {|it| not ($it.ID == 'RSC-005' and $it.message == 'Error while parsing file: attribute "opf:scheme" not allowed here; expected attribute "id"')})\n"
        }
      }
    }
  } else {
    true
  }
}

# Find the package OPF file in an EPUB.
export def find_opf_in_epub []: [
  path -> path
] {
  let epub = $in
  # Apparently the OPF can just reside at the top-level too...
  # let opf_directories = ["OPS" "OEBPS"]
  let opf_files_in_epub = $epub | list_files_in_archive_with_extensions ["opf"]
  if ($opf_files_in_epub | is-empty) {
    log error $"No OPF files found in (ansi yellow)($epub)(ansi reset)"
    return null
  }
  let opf_files = $opf_files_in_epub | path parse
  # let opf_files = $opf_files_in_epub | path parse | where parent in $opf_directories
  # if ($opf_files | is-empty) {
  #   log warning $"No OPF file found in (ansi yellow)($epub)(ansi reset)"
  #   return null
  # }
  if ($opf_files | length) > 1 {
    log warning $"Multiple OPF files found in (ansi yellow)($epub)(ansi reset): (ansi yellow)($opf_files | path join | str join ' ')(ansi reset). Using only the first."
  }
  $opf_files | path join | first
}

# Find the NCX file in an EPUB.
export def find_ncx_in_epub []: [
  path -> path
] {
  let epub = $in
  # Apparently the OPF can just reside at the top-level too...
  # let opf_directories = ["OPS" "OEBPS"]
  let opf_files_in_epub = $epub | list_files_in_archive_with_extensions ["ncx"]
  if ($opf_files_in_epub | is-empty) {
    log error $"No NCX files found in (ansi yellow)($epub)(ansi reset)"
    return null
  }
  let opf_files = $opf_files_in_epub | path parse
  # let opf_files = $opf_files_in_epub | path parse | where parent in $opf_directories
  # if ($opf_files | is-empty) {
  #   log warning $"No OPF file found in (ansi yellow)($epub)(ansi reset)"
  #   return null
  # }
  if ($opf_files | length) > 1 {
    log warning $"Multiple NCX files found in (ansi yellow)($epub)(ansi reset): (ansi yellow)($opf_files | path join | str join ' ')(ansi reset). Using only the first."
  }
  $opf_files | path join | first
}

# Find a specific file in the content of an EPUB.
#
# Only looks in the OPS and OEBPS directories and their subdirectories.
export def find_file_in_epub [
  file: string # The name of the file to find.
]: [
  path -> path
] {
  let epub = $in
  let content_directories = ["OPS" "OEBPS"]
  let file_components = $file | path parse
  let extension = $file_components | get extension
  let files_with_extension_in_epub = $epub | list_files_in_archive_with_extensions [$extension]
  if ($files_with_extension_in_epub | is-empty) {
    log debug $"No ($extension) files found in (ansi yellow)($epub)(ansi reset)"
    return null
  }
  let content_files_with_extension = $files_with_extension_in_epub | path parse | where {|$it| ($it.parent | is-not-empty) and ($it.parent | path split | is-not-empty) and ($it.parent | path split | first) in $content_directories}
  if ($content_files_with_extension | is-empty) {
    log debug $"No ($extension) files found in directories ($content_directories) in the EPUB (ansi yellow)($epub)(ansi reset)"
    return null
  }
  let matching_files = $content_files_with_extension | where {|it| $it.stem == $file_components.stem}
  if ($matching_files | is-empty) {
    log debug $"No file found matching the (ansi yellow)($file)(ansi reset) in (ansi yellow)($epub)(ansi reset). Files matching extension: ($content_files_with_extension)"
    return null
  }
  if ($matching_files | length) > 1 {
    log warning $"Multiple matching files found in (ansi yellow)($epub)(ansi reset): (ansi yellow)($matching_files | path join | str join ' ')(ansi reset). Using only the first."
  }
  $matching_files | path join | first
}

# Extract the metadata from an eBook.
#
# This uses ebook-meta for PDF and ePUB files.
# I should probably use exiftool for PDFs and just parse the metadata.opf file out of EPUBs directly.
export def extract_ebook_metadata [
  working_directory: directory # The scratch-space directory to use
]: [
  path -> record
] {
  let file = $in
  let file_type = $file | path parse | get extension | str downcase
  let metadata = (
    if $file_type == "cbz" {
      # todo Eventually support MetronInfo.xml.
      let metadata_file = $file | extract_file_from_archive "ComicInfo.xml" $working_directory
      let metadata = (
        if ($metadata_file | is-not-empty) {
          open $metadata_file
        }
      )
      rm $metadata_file
      $metadata
    } else if $file_type == "epub" {
      let opf_file = $file | find_opf_in_epub
      if ($opf_file | is-empty) {
        log error $"No OPF file found in (ansi yellow)($file)(ansi reset)"
        return null
      }
      let metadata_file = $file | extract_file_from_archive $opf_file $working_directory
      let metadata = (
        if ($metadata_file | is-not-empty) {
          open $metadata_file | from xml
        }
      )
      rm $metadata_file
      $metadata
    } else if $file_type == "pdf" {
      # To get the identifiers from the PDF, we need to use ebook-meta instead of exiftool.
      # ^exiftool -json $file | from json | first
      let metadata_file = mktemp
      log debug $"Running (ansi yellow)^ebook-meta --to-opf '($metadata_file)' ($file)(ansi reset)"
      let result = do { ^ebook-meta --to-opf $metadata_file $file } | complete
      if ($result.exit_code != 0) {
        error make {
          msg: "non-zero exit code while saving ebook metadata from PDF to OPF file with ebook-meta"
          labels: [
            {text: "result.exit_code" span: (metadata $result.exit_code).span}
          ]
          help: $"error extracting the OPF metadata to the file (ansi yellow)($metadata_file)(ansi reset) from the PDF file (ansi yellow)($file)(ansi reset): ($result.stderr)"
        }
      }
      let metadata = (
        open $metadata_file | from xml
      )
      # log debug $"metadata: ($metadata | to nuon)"
      rm $metadata_file
      $metadata
    }
  )
  # log debug $"metadata: ($metadata)"
  if ($metadata | is-not-empty) {
    if "ComicInfo" in ($metadata | get --optional tag) {
      $metadata | from_comic_info_xml
    } else if "package" in ($metadata | get --optional tag) {
      $metadata | from_opf_xml
    }
  }
}

# Embed metadata in an ebook
#
# Supports cbz, epub, and pdf file formats.
export def embed_ebook_metadata [
  file: path # The file in which to embed the OPF metadata
  working_directory: directory
  # todo Support embedding a cover.
  # --cover: path # Cover file to embed in the ebook.
]: [record -> path] {
  let book_metadata = $in
  let file_type = $file | path parse | get extension | str downcase

  let metadata = (
    if $file_type == "cbz" {
      # todo Support MetronInfo
      {
        archive: $file
        comic_info: ($book_metadata | into_comic_info_xml)
      } | inject_comic_info
    } else if $file_type == "epub" {
      let opf_file = $file | find_opf_in_epub
      if ($opf_file | is-empty) {
        log error $"No OPF file found in (ansi yellow)($file)(ansi reset)"
        return null
      }
      let metadata_file = $file | extract_file_from_archive $opf_file $working_directory
      let metadata = (
        if ($metadata_file | is-not-empty) {
          open $metadata_file | from xml
        }
      )
      if ($metadata.attributes | get --optional xmlns | is-not-empty) {
        error make {
          msg: "namespaces are now available in the 'from xml' Nushell command"
          labels: [
            {text: "metadata.attributes" span: (metadata $metadata.attributes).span}
          ]
          help: "remove the code that adds the xmlns attribute in the embed_ebook_metadata function"
        }
      }
      let opf_metadata = $book_metadata | to_opf_xml
      let metadata = (
        $metadata
        | update attributes (
          # Nushell is absolutely borked when it comes to xml namespaces.
          # We have to add back the namespace that it drops when reading the XML.
          # https://github.com/nushell/nushell/issues/11523
          $metadata.attributes | merge {
            xmlns: "http://www.idpf.org/2007/opf"
          } | merge (
            # Include the unique-identifier attribute at the top-level.
            if ($opf_metadata | get --optional attributes.unique-identifier | is-empty) {
              {}
            } else {
              {"unique-identifier": $opf_metadata.attributes.unique-identifier}
            }
          # Drop disallowed lang attribute
          ) | reject --optional lang
        )
        # Drop the existing metadata section in the OPF.
        | update content (
          (
            $metadata.content | where tag != "metadata"
            | prepend (
              $opf_metadata
              | get content
              | where tag == "metadata"
              | first
            )
          )
        )
      )
      # log debug $"embed_ebook_metadata: metadata: ($metadata | to json)"
      $metadata | to xml --indent 2 | "<?xml version="1.0" encoding=\"utf-8\"?>\n" + $in | save --force $metadata_file
      # Remove kobo.js script reference in the OEBPS/nav.xhtml file.
      # <!-- kobo-style -->
      # <script xmlns="http://www.w3.org/1999/xhtml" type="text/javascript" src="../js/kobo.js"/>
      let nav_xhtml = $file | find_file_in_epub nav.xhtml
      let nav_xhtml = (
        if ($nav_xhtml | is-not-empty) {
          $file | extract_file_from_archive $nav_xhtml $working_directory
        }
      )
      if ($nav_xhtml | is-not-empty) {
        # We don't want to use namespace information, so we just do a string replace here.
        (
          open $nav_xhtml
          | str replace "\n<!-- kobo-style -->\n<script xmlns=\"http://www.w3.org/1999/xhtml\" type=\"text/javascript\" src=\"../js/kobo.js\"/>\n" ""
          | save --force $nav_xhtml
        )
      }
      # Some EPUBs are malformed and contain a toc.ncx file which doesn't use the same id as the one belonging to the unique-identifier attribute in the OPF.
      # <meta name="dtb:uid" content="978..."/>
      let toc_ncx = $file | find_ncx_in_epub
      let toc_ncx = (
        if ($toc_ncx | is-not-empty) {
          $file | extract_file_from_archive $toc_ncx $working_directory
        }
      )
      if ($toc_ncx | is-not-empty) {
        let unique_identifier_id = $opf_metadata.attributes.unique-identifier
        let metadata_content = $opf_metadata.content | where tag == "metadata" | first | get content
        let ids = $metadata_content | where tag == "dc:identifier"
        let unique_identifier = (
          $ids | where {|it|
            ($it.attributes | get --optional id) == $unique_identifier_id
          }
          | get content
          | first
          | get content
          | first
        )
        # We don't want to use namespace information, so we just do a string replace here.
        (
          open $toc_ncx
          # Note that this might need tweaked if it doesn't exactly match.
          | str replace --regex '<meta name="dtb:uid" +content=".*" */>' $"<meta name=\"dtb:uid\" content=\"($unique_identifier)\" />"
          | str replace --regex '<meta content=".*" +name="dtb:uid" */>' $"<meta name=\"dtb:uid\" content=\"($unique_identifier)\" />"
          | save --force $toc_ncx
        )
      }
      cd $working_directory
      if ($nav_xhtml | is-not-empty) {
        $file | add_file_to_archive ($nav_xhtml | path relative-to $working_directory)
      }
      if ($toc_ncx | is-not-empty) {
        $file | add_file_to_archive ($toc_ncx | path relative-to $working_directory)
      }
      let result = (
        $file
        | add_file_to_archive ($metadata_file | path relative-to $working_directory)
      )
      cd -
      if ($result | is-empty) {
        log error $"Error adding the file (ansi yellow)($metadata_file | path relative-to $working_directory)(ansi reset) to the EPUB (ansi yellow)($file)(ansi reset) while in the directory (ansi yellow)($working_directory)(ansi reset)"
        return null
      }
      rm $metadata_file
    } else if $file_type == "pdf" {
      # To get the identifiers from the PDF, we need to use ebook-meta instead of exiftool.
      # ^exiftool -json $file | from json | first
      # ebook-meta doesn't work when I try to give it an OPF file as input.
      # let opf_file = mktemp --suffix .opf
      # $book_metadata | to_opf_xml | to xml | save --force $opf_file
      # log debug $"Running (ansi yellow)^ebook-meta --to-opf '($metadata_file)' ($file)(ansi reset)"
      # log debug $"Running (ansi yellow)^ebook-meta '($file)' --from-opf '($opf_file)'(ansi reset)"
      # let result = do { ^ebook-meta $file --from-opf $opf_file } | complete
      # if ($result.exit_code != 0) {
      #   error make {
      #     msg: "non-zero exit code while embedding ebook metadata in PDF with ebook-meta"
      #     labels: [
      #       {text: "result.exit_code" span: (metadata $result.exit_code).span}
      #     ]
      #     help: $"error embedding the ebook metadata opf file (ansi yellow)($opf_file)(ansi reset) in the PDF file (ansi yellow)($file)(ansi reset): ($result.stderr)"
      #   }
      # }
      # rm $opf_file

      # todo Make a dedicated function for this.
      let args = (
        []
        | append (
          if ($book_metadata | get --optional isbn | is-not-empty) {
            $"--isbn=($book_metadata.isbn)"
          }
        )
        | append (
          if ($book_metadata | get --optional series | is-not-empty) and ($book_metadata | get --optional issue_count | is-not-empty) and $book_metadata.issue_count > 1 {
            [
              $"--series=($book_metadata.series | use_unicode_in_title)"
            ] | append (
              if ($book_metadata | get --optional issue | is-not-empty) {
                [
                  $"--index=($book_metadata.issue)"
                ]
              }
            )
          }
        )
        | append (
          # Prefer imprints over publishers.
          # todo Not sure if Kavita supports multiple publishers in the PDF metadata.
          if ($book_metadata | get --optional imprints | is-not-empty) {
            $"--publisher=($book_metadata.imprints | str join ',')"
          } else if ($book_metadata | get --optional publishers | is-not-empty) {
            $"--publisher=($book_metadata.publishers | str join ',')"
          }
        )
        | append (
          if ($book_metadata | get --optional language | is-not-empty) {
            $"--language=($book_metadata.language | into_language_code ietf_bcp_47)"
          # todo Default language
          # } else {
          #   $"--language=($default_language | into_language_code ietf_bcp_47)"
          }
        )
        | append (
          if ($book_metadata | get --optional description | is-not-empty) {
            $"--comments=($book_metadata.description)"
          }
        )
        | append (
          if ($book_metadata | get --optional genres | is-not-empty) {
            $"--tags=($book_metadata.genres | str join ',')"
          }
        )
        | append (
          $book_metadata | get --optional ids | reduce --fold [] {|id acc|
            # for each type, add each scheme
            let schemes = $opf_identifier_schemes | where type == $id.type
            # log debug $"schemes: ($schemes)"
            if ($id.type == "epub_uuid") {
              $acc
            } else if ($schemes | is-empty) {
              error make {
                msg: "missing OPF schemes for type"
                labels: [
                  {text: "id.type" span: (metadata $id.type).span}
                  {text: "opf_identifier_schemes" span: (metadata $opf_identifier_schemes).span}
                ]
                help: $"add the missing OPF scheme for the type (ansi yellow)($id.type)(ansi reset) to the identifier_schemes table"
              }
            } else if ($schemes | length) > 1 {
              error make {
                msg: "multiple OPF schemes for type"
                labels: [
                  {text: "id.type" span: (metadata $id.type).span}
                  {text: "opf_identifier_schemes" span: (metadata $opf_identifier_schemes).span}
                ]
                help: $"remove the duplicate OPF schemes for the type (ansi yellow)($id.type)(ansi reset) to the identifier_schemes table"
              }
            } else {
              $schemes | first | get schemes | reduce --fold $acc {|scheme inner_acc|
                $inner_acc | append [
                  $"--identifier=($scheme | str downcase):($id.id)"
                ]
              }
            }
          }
        )
        | append (
          let year = (
            if ($book_metadata | get --optional year | is-not-empty) {
              $book_metadata.year
            }
          );
          let month = (
            if ($book_metadata | get --optional month | is-not-empty) {
              $book_metadata.month
            }
          );
          let day = (
            if ($book_metadata | get --optional day | is-not-empty) {
              $book_metadata.day
            }
          );
          if ($book_metadata | get --optional publication_date | is-not-empty) {
            $"--date=($book_metadata.publication_date | format date "%Y-%m-%d")"
          } else if ($year | is-not-empty) and ($month | is-not-empty) and ($day | is-not-empty) {
            $"--date=($year)-($month)-($day)"
          } else if ($year | is-not-empty) {
            $"--date=($year)"
          }
        )
      );
      let authors = (
        let credits = $book_metadata | get credits;
        # todo Get actual primary creators from BookBrainz. This is too inaccurate.
        let writers = $credits | where role in ["Writer"] | get person;
        if ($writers | is-empty) {
          let authors = $credits | where role in ["Artist" "Inker" "Penciller"] | get person;
          if ($authors | is-empty) {
            $credits | where role == "Other" | get person
          } else {
            $authors
          } | sort | uniq
        } else {
          $writers | sort | uniq
        }
      );
      log debug $"Running (ansi yellow)^ebook-meta ($file) ($args | str join ' ') --title ($book_metadata | get title | standardize_title) --authors ($authors | str join "&")'(ansi reset)";
      (
        ^ebook-meta
          $file
          ...$args
          # Keep the title in PDFs for now, since Kavita doesn't really change it's behavior whether one is included or not.
          --title ($book_metadata | get title | standardize_title)
          --authors ($authors | str join "&")
      );
    }
  )
  $file
}

# Fetch metadata for an ebook
export def fetch-ebook-metadata [
  ...args: string
  # Remove Comicvine because it can cause trouble, although it does have entries for some Light Novels apparently.
  --allowed-plugins: list<string> = ["Hardcover" "Wikidata"] # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
  # --allowed-plugins: list<string> = [Google "Amazon.com"] # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
  --authors: list<string> # A list of authors to use
  --cover: path # Path to which to download the cover
  --identifiers: list<string> # A list of identifiers
  --isbn: string # The ISBN of the book
  --title: string # The title to use
]: nothing -> record<opf: record, cover: path> {
  let allowed_plugins = (
    if ($allowed_plugins | is-empty) {
      null
    } else {
      $allowed_plugins | each {|plugin| $"--allowed-plugin=($plugin)"}
    }
  )
  let authors = (
    if $authors == null {
      null
    } else {
      $authors | str join "&" | $"--authors=($in)"
    }
  )
  let identifiers = (
    if $identifiers == null {
      null
    } else {
      $identifiers | par-each {|identifier| $"--identifier=($identifier)"}
    }
  )
  let isbn = (
    if $isbn == null {
      null
      # log error "fetch-ebook-metadata currently requires that an ISBN be provided to avoid pulling in the wrong data."
      # exit 1
    } else {
      $"--isbn=($isbn)"
    }
  )
  let title = (
    if $title == null {
      null
    } else {
      $"--title=($title)"
    }
  )
  let cover_arg = (
    if ($cover | is-empty) {
      null
    } else {
      $"--cover=($cover)"
    }
  )
  let args = (
    $args
    | append "--opf"
    | append $allowed_plugins
    | append $authors
    # todo Cover hangs indefinitely in certain cases?
    | append $cover_arg
    | append $identifiers
    | append $isbn
    | append $title
  )
  if ($cover | is-not-empty) and ($cover | path exists) {
    log debug $"pre cover: ($cover) ($cover | get_image_dimensions)"
  }
  # let result = ^fetch-ebook-metadata ...$args | complete
  # let opf = $result.stdout | from xml
  log debug $"Running: fetch-ebook-metadata ($args | str join ' ')"
  let opf = (
    let result = (^fetch-ebook-metadata ...$args | complete);
    if $result.exit_code == 0 {
      mut output = []
      for line  in ($result.stdout | lines) {
        $output = $output | append $line
        if $line == "</package>" {
          break
        }
      }
      let xml = $output | reduce --fold "" {|line, acc| $acc + $line + "\n"}
      # log debug $"xml: '($xml)'"
      $xml | from xml
    } else if ($result.stderr | lines --skip-empty | last) == "No results found" {
      log debug $"(ansi red)No metadata found!(ansi reset)"
      null
    } else {
      log error $"fetch-ebook-metadata failed with the exit code (ansi red)($result.exit_code)(ansi reset): ($result.stderr)"
      null
    }
  )
  if ($cover | is-not-empty) and ($cover | path exists) {
    log debug $"post cover: ($cover) ($cover | get_image_dimensions)"
  }
  {
    opf: $opf,
    cover: (
      if ($cover | is-not-empty) and ($cover | path exists) {
        $cover | rename_image_with_extension
      } else {
        null
      }
    )
  }
}

export def extract_book_metadata [
  working_directory: directory
]: path -> record<opf: record, cover: path> {
  let book = $in
  log debug $"book: ($book)"
  let opf_file = mktemp --suffix ".xml" --tmpdir
  # let opf_file = (
  #   {
  #     parent: $working_directory
  #     # stem: ($book | path parse | get stem)
  #     # stem: "metadata"
  #     extension: "opf"
  #   } | path join
  # )
  log debug $"opf: ($opf_file)"
  let cover_file = (
    {
      parent: $working_directory,
      stem: ([($book | path parse | get stem) "-extracted-cover"] | str join),
    } | path join
  )
  # log debug $"pre cover_file: ($cover_file) ($cover_file | get_image_dimensions)";
  log debug $"Running (ansi yellow)^ebook-meta --get-cover '($cover_file)' --to-opf '($opf_file)' ($book)(ansi reset)"
  (
    ^ebook-meta
    --get-cover $cover_file
    --to-opf $opf_file
    $book
  )
  log debug $"post cover_file: ($cover_file) ($cover_file | get_image_dimensions)";
  # todo Remove title == "Untitled" and creator == "Unknown"?
  let opf = $opf_file | open
  rm $opf_file
  {
    opf: $opf
    cover: ($cover_file | rename_image_with_extension)
  }
}

# Fetch metadata for an eBook with Calibre.
export def fetch_book_metadata [
  working_directory: directory
  --allowed-plugins: list<string> = ["Hardcover" "Open Library" "Wikidata"]
  --authors: list<string>
  --identifiers: list<string>
  --isbn: string
  --skip-optimization # Skip optimizing the downloaded cover image
  --title: string
]: path -> record<book: path, cover: path, opf: record> {
  let book = $in
  # todo Check for metadata.opf and cover.ext files
  # todo Use ComicInfo.xml as well here?
  # Prefer metadata.opf and cover.ext over embedded metadata and cover
  let current = (
    $book
    | extract_book_metadata $working_directory
    | (
      let input = $in;
      let metadata_opf = $book | path dirname | path join "metadata.opf";
      if ($metadata_opf | path exists) {
        $input | update opf (
          $input | merge (open $metadata_opf | from xml)
        )
      } else {
        $input
      }
    )
    | (
      let input = $in;
      let covers = (
        ls ($book | path dirname)
        | get name
        | where {|f|
          let components = $f | path parse
          $components.stem == (($book | path parse | get stem) + "-cover") and $components.extension in $image_extensions
        }
      );
      if ($covers | is-empty) {
        $input
      } else if ($covers | length) > 1 {
        log error $"Found multiple files looking for the cover image file:\n($covers)\n"
        exit 1
      } else {
        if ($covers | first | path exists) {
          $input | update cover ($covers | first)
        } else {
          $input
        }
      }
    )
  )
  # log debug $"current: ($current | to nuon)"
  log debug $"current.cover ($current.cover) ($current.cover | get_image_dimensions)"
  let all_opf_identifiers = (
    $current.opf
    | get content
    | where tag == "metadata"
    | first
    | get content
    | where tag == "identifier"
  )
  let isbn = (
    if ($isbn | is-empty) and ($all_opf_identifiers | is-not-empty) {
      let all_opf_isbn = (
        $all_opf_identifiers
        | where {|it| ($it.attributes | get --optional scheme) == "ISBN"}
      )
      if ($all_opf_isbn | is-empty) {
        null
      } else {
        $all_opf_isbn
        | first
        | get content
        | first
        | get content
      }
    } else {
      $isbn
    }
  )
  # if $isbn == null {
  #   log error "fetch_book_metadata currently requires an ISBN to avoid pulling in the wrong data."
  #   exit 1
  # }
  let identifiers = (
    # todo Merge identifiers?
    if ($isbn | is-empty) and ($all_opf_identifiers | is-not-empty) {
      let all_opf_non_isbn = (
        $all_opf_identifiers
        | where {|it| ($it.attributes | get --optional scheme) != "ISBN"}
      )
      if ($all_opf_non_isbn | is-empty) {
        null
      } else {
        $all_opf_non_isbn
        | par-each {|identifier|
          let scheme = $identifier.attributes.scheme;
          let id = $identifier.content | get first | get content;
          { $"($scheme):($id)" }
        }
      }
    } else {
      $identifiers
    }
  )
  let identifier_flags = (
    if $identifiers == null {
      null
    } else {
      $identifiers | par-each {|identifier| $"--identifier=($identifier)" }
    }
  )
  let isbn_flag = (
    if $isbn == null {
      null
    } else {
      $"--isbn=($isbn)"
    }
  )
  let title = (
    if $title == null {
      $current.opf
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "title"
      | first
      | get content
      | first
      | get content
    } else {
      $title
    }
  )
  let title_flag = (
    if $title == null {
      null
    } else {
      $"--title=($title)"
    }
  )
  let authors = (
    if $authors == null {
      $current.opf
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "creator"
      | where attributes.role == "aut"
      | par-each {|creator| $creator | get content | first | get content }
      | sort
    } else {
      $authors
    }
  )
  let authors_flag = (
    if $authors == null {
      null
    } else {
      $"--authors=($authors | str join '&')"
    }
  )
  let args = (
    # [ --opf ]
    []
    | (
      let input = $in;
      $input
      | append $isbn_flag
      | append $authors_flag
      | append $title_flag
      | append $identifier_flags
      # | append (
      #   if $isbn == null {
      #     $authors_flag
      #   }
      # )
      # | append (
      #   if $isbn == null {
      #     $title_flag
      #   }
      # )
      # | append (
      #   if $isbn == null {
      #     $identifier_flags
      #   }
      # )
    )
  )
  let updated = (
    # Prefer using the current cover if there is one
    # todo I should probably prefer the highest resolution cover if it is similar to the current one.
    log debug $"current.cover: ($current.cover | to nuon) ($current.cover | get_image_dimensions)";
    if ($current.cover | is-empty) {
      # log debug $"Running (ansi yellow)fetch-ebook-metadata --allowed(ansi reset)";
      (
        fetch-ebook-metadata
        --allowed-plugins $allowed_plugins
        --cover (
          {
            parent: $working_directory
            stem: ($book | path parse | get stem | $"($in)-fetched-cover")
            extension: ""
          } | path join
        )
        ...$args
      )
    } else {
      fetch-ebook-metadata --allowed-plugins $allowed_plugins ...$args
    }
  )
  # todo Check if cover is empty or not found?
  let cover_file = (
    if ($current.cover | is-empty) {
      # Always update a downloaded cover image regardless of --skip-optimization flag.
      $updated.cover | optimize_image
    } else {
      if $skip_optimization {
        $current.cover
      } else {
        $current.cover | optimize_image
      }
    }
  )
  # log debug $"cover_file: ($cover_file | to nuon) ($cover_file | get_image_dimensions)";
  {
    book: $book
    opf: $updated.opf
    cover: $cover_file
  }
}

# Export the book, OPF, and cover files to a directory named after the book
export def export_book_to_directory [
  working_directory: path
]: [
  record<book: path, cover: path, opf: record>
  ->
  record<book: path, cover: path, opf: path>
] {
  let input = $in
  let title = (
    $input.opf
    | get content
    | where tag == "metadata"
    | first
    | get content
    | where tag == "title"
    | first
    | get content
    | first
    | get content
  )
  # todo Handle missing title?
  let sanitized_title_for_filename = $title | sanitize_file_name | use_unicode_in_title
  let target_directory = [$working_directory $sanitized_title_for_filename] | path join
  mkdir $target_directory
  let opf = (
    {
      parent: $target_directory
      stem: "metadata"
      extension: "opf"
    } | path join
  )
  (
    $input.opf
    | to xml
    | save --force $opf
  )
  let cover = (
    if ($input | get --optional cover | is-empty) {
      null
    } else {
      $input.cover
      | path parse
      | update parent $target_directory
      | update stem "cover"
      | path join
    }
  )
  let book = (
    $input.book
    | path parse
    | update parent $target_directory
    | update stem $sanitized_title_for_filename
    | path join
  )
  let cover_dimensions = $cover | get_image_dimensions
  log debug $"cover: ($cover) ($cover_dimensions)"
  let input_cover_dimensions = $input.cover | get_image_dimensions
  log debug $"input.cover: ($input.cover) ($input_cover_dimensions)"
  if ($cover | is-not-empty) {
    mv $input.cover $cover
  }
  log debug $"Renaming book from (ansi yellow)($input.book)(ansi reset) to (ansi yellow)($book)(ansi reset)"
  mv $input.book $book
  log debug $"Exported book contents to the directory (ansi purple)($target_directory)(ansi reset)";
  {
    book: $book
    opf: $opf
    cover: $cover
  }
}

# Convert a copy for my primary e-reader:
# Kobo Elipsa 2E: 1404x1872 (Gamma 1.8).
# todo I'm not sure this is even really necessary
# Using the correct resolution does seem to result in much faster page loads.
# Although, maybe that's due to using webp?
# I should verify.
export def convert_for_ereader [
    ereader: string
    working_directory: directory
]: path -> path {
    let file = $in
    let suffix = ("_" + ($ereader | str replace --all " " "_" | str downcase))
    let components = ($file | path parse)
    let input_format = $components.extension

    let image_format = (
      if $input_format in ["cbz" "epub" "zip"] {
        let image_extension = ($file | get_image_extension);
        if ($image_extension == null) {
          log error "Failed to determine the image file format"
          exit 1
        }
        $image_extension
      } else {
        null
      }
    )

    # Use KCC because it won't look right when converting jpegs with cbconvert 1.1.0.
    let components = ($file | path parse);
    let temp = (
        {
            parent: $working_directory,
            stem: $components.stem,
            extension: $components.extension
        }
        | path join
    )
    cp $file $temp
    let components = ($temp | path parse);
    let kcc_output = (
        {
            parent: $components.parent,
            stem: ($components.stem + "_kcc0"),
            extension: $components.extension
        }
        | path join
    )
    let output = (
        {
            parent: $components.parent,
            stem: ($components.stem + $suffix),
            extension: $components.extension
        }
        | path join
    )
    log debug $"Running command: flatpak run --command=kcc-c2e io.github.ciromattia.kcc --profile KoE --manga-style --forcecolor --format CBZ --output '($temp)' --targetsize 10000 --upscale '($temp)'"
    (^flatpak run --command=kcc-c2e io.github.ciromattia.kcc --profile KoE --manga-style --forcecolor --format CBZ --output $temp --targetsize 10000 --upscale $temp)
    mv $kcc_output $output
    rm $temp
    $output
    # The output is always a CBZ file.
    $components | update stem ($components.stem + $suffix) | update extension "cbz" | path join
}
