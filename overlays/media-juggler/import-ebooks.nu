#!/usr/bin/env nu

use std log
use media-juggler-lib *

# Import my EBooks to my collection.
#
# Input files can be in the ACSM, EPUB, and PDF formats.
#
# This script performs several steps to process the ebook file.
#
# 1. Fetch and add metadata to the EPUB and PDF formats.
# 2. Upload the file to object storage.
#
# Information that is not provided will be gleaned from the title of the EPUB file if possible.
#
# The final file is named according to Jellyfin's recommendation.
#
# This ends up like this for an EPUB: "<authors>/<title>.epub".
# For a PDF, the book is stored in its own directory with the metadata.opf and cover.ext files: "<authors>/<title>/<title>.pdf".
#
# I'm considering grouping books by series like this:
# The path for a book in a series will look like "<authors>/<series>/<series-position> - <title>.epub".
# The path for a standalone book will look like "<authors>/<title>.epub".
#
def main [
  ...files: string # The paths to ACSM, EPUB, and PDF files to convert, tag, and upload. SSH style paths are supported.
  --destination: directory = "meerkat:/var/media" # The directory under which to copy files. I also have a light-novels subdirectory dedicated to light novels.
  --isbn: string # ISBN of the book
  # --identifiers: string # asin:XXXX
  --keep # Keep the original file
  # --ereader: string # Create a copy of the comic book optimized for this specific e-reader, i.e. "Kobo Elipsa 2E"
  # --ereader-subdirectory: string = ".books" # The subdirectory on the e-reader in-which to copy
  --keep-tmp # Don't delete the temporary directory when there's an error
  --keep-acsm # Keep the ACSM file after conversion. These stop working for me before long, so no point keeping them around.
  --no-copy-to-ereader # Don't copy the E-Reader specific format to a mounted e-reader
  --replace-cover # Replace the cover image in an ebook with the image from Hardcover.
  --skip-upload # Don't upload files to the server
  --title: string # The title of the book
  --use-rsync
  --bookbrainz-edition-id: string # The BookBrainz Edition ID (only embedded in the metadata right now)
  --hardcover-edition-id: string # The Hardcover Edition ID (only embedded in the metadata right now)
  --hardcover-book-slug: string # The Hardcover Book Slug (only embedded in the metadata right now)
  --open-library-edition-id: string # The Open Library edition ID (only embedded in the metadata right now)
  # --open-library-work-id: string # The Open Library edition ID (only embedded in the metadata right now)
  --wikidata-work-id: string # The Wikidata work ID (only embedded in the metadata right now)
  --wikidata-edition-id: string # The Wikidata edition ID (only embedded in the metadata right now)
] {
  if ($files | is-empty) {
    log error "No files provided"
    exit 1
  }

  if ($files | length) > 1 and (
    ($isbn | is-not-empty)
    or ($bookbrainz_edition_id  | is-not-empty)
    or ($open_library_edition_id  | is-not-empty)
    or ($hardcover_edition_id | is-not-empty)
    or ($hardcover_book_slug | is-not-empty)
    or ($open_library_edition_id | is-not-empty)
    or ($wikidata_edition_id | is-not-empty)
    or ($wikidata_work_id | is-not-empty)
  ) {
    log error "Setting identifiers for multiple files is not allowed as it will result in overwriting the final file"
    exit 1
  }

  if ($isbn | is-not-empty) and not ($isbn | validate_isbn) {
    log error $"The ISBN (ansi red)($isbn)(ansi reset) is invalid"
    exit 1
  }
  if ($bookbrainz_edition_id | is-not-empty) and not ($bookbrainz_edition_id | is_identifier_valid bookbrainz_edition_id) {
    log error $"Invalid BookBrainz edition ID (ansi purple)($bookbrainz_edition_id)(ansi reset)"
    exit 1
  }
  if ($hardcover_edition_id | is-not-empty) and not ($hardcover_edition_id | is_identifier_valid hardcover_edition_id) {
    log error $"The Hardcover edition ID (ansi purple)($hardcover_edition_id)(ansi reset) is not an integer"
    exit 1
  }
  if (($hardcover_edition_id | is-empty) or ($hardcover_book_slug | is-empty)) and ($env | get --optional MEDIA_JUGGLER_HARDCOVER_API_TOKEN | is-empty) {
    log error "The environment variable MEDIA_JUGGLER_HARDCOVER_API_TOKEN must be set to a Hardcover API key if --hardcover-book-slug and --hardcover-api-key are not provided."
    exit 1
  }
  if ($hardcover_book_slug | is-not-empty) and not ($hardcover_book_slug | is_identifier_valid hardcover_book_slug) {
    log error $"The Hardcover book slug (ansi purple)($hardcover_book_slug)(ansi reset) is most likely invalid since it is an integer"
    exit 1
  }
  if ($open_library_edition_id | is-not-empty) and not ($open_library_edition_id | is_identifier_valid open_library_edition_id) {
    log error $"Invalid Open Library edition ID (ansi purple)($open_library_edition_id)(ansi reset)"
    exit 1
  }
  if ($wikidata_edition_id | is-not-empty) and not ($wikidata_edition_id | is_identifier_valid wikidata_item_id) {
    log error $"The Wikidata edition ID (ansi purple)($wikidata_edition_id)(ansi reset) must be formatted as the letter 'Q' followed by an integer"
    exit 1
  }
  if ($wikidata_work_id | is-not-empty) and not ($wikidata_work_id | is_identifier_valid wikidata_item_id) {
    log error $"The Wikidata work ID (ansi purple)($wikidata_work_id)(ansi reset) must be formatted as the letter 'Q' followed by an integer"
    exit 1
  }

  let cache_directory = [($nu.cache-dir | path dirname) "media-juggler" "import-ebooks"] | path join
  let optimized_files_cache_file = [$cache_directory optimized.json] | path join
  mkdir $cache_directory
  let cover_art_directory = [$cache_directory "covers"] | path join
  mkdir $cover_art_directory

  let config_file = [($nu.default-config-dir | path dirname) "media-juggler" "import-ebooks-config.json"] | path join
  let config: record = (
    try {
      open $config_file
    } catch {
      {}
    }
  )

  let keep = (
    if ($keep | is-not-empty) {
      $keep
    } else if ($config | get --optional keep | is-not-empty) {
      $config.keep
    }
  )
  let use_rsync = (
    if ($use_rsync | is-not-empty) {
      $use_rsync
    } else if ($config | get --optional use_rsync | is-not-empty) {
      $config.use_rsync
    }
  )
  let destination = (
    if ($destination | is-not-empty) {
      $destination
    } else if ($config | get --optional destination | is-not-empty) {
      $config.destination
    }
  )
  if ($destination | is-empty) {
    log error "Missing destination!"
    exit 1
  }

  let destination = (
    if ($destination | is_ssh_path) {
      $destination # todo expand path?
    } else {
      if ($destination | is-empty) {
        "." | path expand
      } else {
        $destination
      }
    }
  )
  if not ($destination | is_ssh_path) {
    mkdir $destination
  }

  # let username = (^id --name --user)
  # let ereader_disk_label = (
  #   if $ereader == null {
  #     ""
  #   } else {
  #     $ereader_profiles | where model == $ereader | first | get disk_label
  #   }
  # )
  # let ereader_mountpoint = (["/run/media" $username $ereader_disk_label] | path join)

  # let original_file = $files | first
  let results = $files | each {|original_file|

  let original_file = (
    if ($original_file | is_ssh_path) {
      $original_file
    } else {
      $original_file | path expand
    }
  )

  log info $"Importing the file (ansi purple)($original_file)(ansi reset)"

  let temporary_directory = (mktemp --directory --tmpdir-path (pwd) "import-ebooks.XXXXXXXXXX")
  log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

    # try {

    # todo Add support for input files from Calibre using the Calibre ID number?
  let file = (
    if ($original_file | is_ssh_path) {
      let file = $original_file
      let target = [$temporary_directory ($file | path basename)] | path join
      log debug $"Downloading the file (ansi yellow)($file)(ansi reset) to (ansi yellow)($target)(ansi reset)"
      if $use_rsync {
        $file | rsync $target "--mkpath"
      } else {
        $file | scp $target --mkdir
      }
      $target
    } else {
      if $keep {
        let target = [$temporary_directory ($original_file | path basename)] | path join
        log debug $"Copying the file (ansi yellow)($original_file)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        cp $original_file $target
        $target
      } else {
        $original_file
      }
    }
  )

  let original_input_format = $file | path parse | get extension

  let original_opf = (
    let opf_file = ($original_file | split_ssh_path | get path | path dirname | path join "metadata.opf");
    if ($original_file | is_ssh_path) {
      if ($opf_file | ssh_path_exists) {
        $opf_file
      }
    } else {
      if ($opf_file | path exists) {
        $opf_file
      }
    }
  )

  if $original_opf != null {
    log debug $"Found OPF metadata file (ansi yellow)($original_opf)(ansi reset)"
  }

  let opf = (
    if $original_opf != null {
      let target = [$temporary_directory ($original_opf | path basename)] | path join
      if ($original_opf | is_ssh_path) {
        log debug $"Downloading the file (ansi yellow)($original_opf)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        if $use_rsync {
          $original_opf | rsync $target "--mkpath"
        } else {
          $original_opf | scp $target --mkdir
        }
      } else {
        log debug $"Copying the file (ansi yellow)($original_opf)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        cp $original_opf $target
      }
      $target
    }
  )

  let original_cover = (
    if ($original_file | is_ssh_path) {
      let file = $original_file
      let server = $file | split_ssh_path | get server
      let covers = (
        $"($file | path dirname | escape_special_glob_characters | str replace '[:]' ':')/cover.*"
        | ssh glob "--no-dir" "--no-symlink"
        | where {|f|
          let components = ($f | path parse);
          $components.stem == "cover" and $components.extension in $image_extensions
        }
        | each {|file|
          $"($server):($file)"
        }
      )
      if not ($covers | is-empty) {
        if ($covers | length) > 1 {
          if not $keep_tmp {
            rm --force --recursive $temporary_directory
          }
          return {
            file: $original_file
            error: $"Found multiple files looking for the cover image file:\n($covers)\n"
          }
        } else {
          $covers | first
        }
      }
    } else {
      let covers = (glob $"($original_file | path dirname | escape_special_glob_characters)/cover.{($image_extensions | str join ',')}")
      if not ($covers | is-empty) {
        if ($covers | length) > 1 {
          if not $keep_tmp {
            rm --force --recursive $temporary_directory
          }
          return {
            file: $original_file
            error: $"Found multiple files looking for the cover image file:\n($covers)\n"
          }
        } else {
          $covers | first
        }
      }
    }
  )

  if $original_cover != null {
    log debug $"Found the cover file (ansi yellow)($original_cover)(ansi reset)"
  }

  # todo Extract the cover from metadata?
  let cover = (
    if $original_cover != null {
      let target = [$temporary_directory ($original_cover | path basename)] | path join
      if ($original_cover | is_ssh_path) {
        log debug $"Downloading the file (ansi yellow)($original_cover)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        if $use_rsync {
          $original_cover | rsync $target "--mkpath"
        } else {
          $original_cover | scp $target --mkdir
        }
      } else {
        log debug $"Copying the file (ansi yellow)($original_cover)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        cp $original_cover $target
      }
      $target
    }
  )
  let cover = (
    if ($cover | is-not-empty) {
      $cover | optimize_image
    } else {
      $cover
    }
  )

  let original_book_files = [($original_file | split_ssh_path | get path)] | append $original_cover | append $original_opf
  log debug $"The original files for the book are (ansi yellow)($original_book_files)(ansi reset)"

  let input_format = (
    if $original_input_format == "acsm" {
      "epub"
    } else {
      $original_input_format
    }
  )

  let output_format = (
    if $input_format == "pdf" {
      "pdf"
    } else {
      "epub"
    }
  )

  let formats = (
    if $input_format == "acsm" {
      let epub = ($file | acsm_to_epub (pwd))
      { book: $epub }
    } else if $input_format == "epub" {
      log debug "Importing the EPUB file"
      { epub: ($file | acsm_to_epub (pwd)) }
    } else if $input_format == "pdf" {
      { book: $file }
    } else {
      rm --force --recursive $temporary_directory
      return {
        file: $original_file
        error: $"Unsupported input file type (ansi red_bold)($input_format)(ansi reset)"
      }
    }
  )

  let existing_metadata = $formats | get $input_format | extract_ebook_metadata $temporary_directory
  log debug $"existing_metadata: ($existing_metadata)"

  # If no primary ids, i.e. ISBN, BookBrainz edition ID, and Wikidata item ID, are provided, try using the primary ids available in the metadata.
  # If an ISBN, BookBrainz edition ID, or Wikidata item ID are provided, we'll try to use those to look up the other IDs using the provided ones.
  # However, for the Comic Vine ID, we'll use it from the existing metadata unless it is provided on the command-line.
  # This is because Comic Vine IDs are only associated with other identifiers through Wikidata.
  # todo Handle merging existing data and IDs.
  let isbn = (
    if ($isbn | is-empty) and ($bookbrainz_edition_id | is-empty) and ($wikidata_edition_id | is-empty) {
      if ($isbn | is-empty) {
        if ($existing_metadata | is-not-empty) {
          if ($existing_metadata | get --optional isbn | is-not-empty) {
            $existing_metadata.isbn
          }
        }
      } else {
        $isbn
      }
    } else {
      $isbn
    }
  )
  let bookbrainz_edition_id = (
    if ($isbn | is-empty) and ($bookbrainz_edition_id | is-empty) and ($bookbrainz_edition_id | is-empty) {
      if ($bookbrainz_edition_id | is-empty) {
        if ($existing_metadata | is-not-empty) {
          let ids = $existing_metadata | get --optional ids
          if ($ids | is-not-empty) {
            let bookbrainz_edition_ids = $ids | where type == "bookbrainz_edition_id"
            if ($bookbrainz_edition_ids | is-not-empty) {
              # todo Warn if multiple
              $bookbrainz_edition_ids | first
            }
          }
        }
      } else {
        $bookbrainz_edition_id
      }
    } else {
      $wikidata_edition_id
    }
  )
  let wikidata_edition_id = (
    if ($isbn | is-empty) and ($bookbrainz_edition_id | is-empty) and ($wikidata_edition_id | is-empty) {
      if ($wikidata_edition_id | is-empty) {
        if ($existing_metadata | is-not-empty) {
          let ids = $existing_metadata | get --optional ids
          if ($ids | is-not-empty) {
            let wikidata_edition_ids = $ids | where type == "wikidata_edition_id"
            if ($wikidata_edition_ids | is-not-empty) {
              # todo Warn if multiple
              $wikidata_edition_ids | first
            }
          }
        }
      } else {
        $wikidata_edition_id
      }
    } else {
      $wikidata_edition_id
    }
  )

  # First, try to locate the release based on its hash if no Wikidata id is specified.
  let wikidata_edition_id = (
    if $original_input_format != "acsm" and ($wikidata_edition_id | is-empty) {
      # BLAKE3 and SHA3-512 checksums are currently supported.
      ["blake3" "sha3-512"] | reduce --fold "" {|checksum_type acc|
        if ($acc | is-empty) {
          let checksum = (
            if $checksum_type == "blake3" {
              $file | hash_blake3
            } else if $checksum_type == "sha3-512" {
              $file | hash_sha3_512
            } else {
              log error $"This should never happen."
              exit 1
            }
          )
          let file_size = du $file | first | get physical
          let editions = $checksum | wikidata_search_editions_by_checksum $checksum_type $file_size
          if ($editions | is-empty) {
            # No editions found.
            log debug $"No Wikidata editions found for the ($checksum_type | str upcase) (ansi purple)($checksum)(ansi reset)"
            null
          } else if ($editions | length) == 1 {
            log info $"Found Wikidata edition (ansi green)($editions | first)(ansi reset) for the ($checksum_type | str upcase) checksum"
            $editions | first
          } else {
            log warning $"Multiple Wikidata editions found for the ($checksum_type | str upcase) (ansi purple)($checksum)(ansi reset): ($editions)"
            null
          }
        } else {
          return $acc
        }
      }
    } else {
      $wikidata_edition_id
    }
  )
  let wikidata_edition_identifiers = (
    if ($wikidata_edition_id | is-not-empty) and (($isbn | is-empty) or ($bookbrainz_edition_id | is-empty) or ($open_library_edition_id | is-empty)) {
      $wikidata_edition_id | wikidata_get_edition_identifiers
    }
  )
  let isbn = (
    if ($isbn | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let isbns = $wikidata_edition_identifiers | get --optional "ISBN-13"
      if ($isbns | is-empty) {
        log warning $"No ISBN-13s found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($isbns | length) == 1 {
        $isbns | first
      } else {
        log warning $"Multiple ISBN-13s found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($isbns)"
        null
      }
    } else {
      $isbn
    }
  )
  let bookbrainz_edition_id = (
    if ($bookbrainz_edition_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let bookbrainz_edition_ids = $wikidata_edition_identifiers | get --optional "BookBrainz edition ID"
      if ($bookbrainz_edition_ids | is-empty) {
        log warning $"No BookBrainz edition IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($bookbrainz_edition_ids | length) == 1 {
        $bookbrainz_edition_ids | first
      } else {
        log warning $"Multiple BookBrainz edition IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($bookbrainz_edition_ids)"
        null
      }
    } else {
      $bookbrainz_edition_id
    }
  )
  let open_library_edition_id = (
    if ($open_library_edition_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let open_library_edition_ids = $wikidata_edition_identifiers | get --optional "Open Library ID"
      if ($open_library_edition_ids | is-empty) {
        log warning $"No OpenLibrary Book IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($open_library_edition_ids | length) == 1 {
        $open_library_edition_ids | first
      } else {
        log warning $"Multiple OpenLibrary Book IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($open_library_edition_ids)"
        null
      }
    } else {
      $open_library_edition_id
    }
  )

  # Get missing identifiers based on provided identifiers.
  # todo Search Open Library to.

  # If BookBrainz ID is provided and any identifiers are missing, attempt to get them from BookBrainz.
  let bookbrainz_edition_identifiers = (
    if ($bookbrainz_edition_id | is-not-empty) and (($isbn | is-empty) or ($wikidata_edition_id | is-empty) or ($open_library_edition_id | is-empty)) {
      $bookbrainz_edition_id | bookbrainz_get_edition_identifiers
    }
  )
  let isbn = (
    if ($isbn | is-empty) and ($bookbrainz_edition_identifiers | is-not-empty) {
      let isbns = $bookbrainz_edition_identifiers | where type == "ISBN-13"
      if ($isbns | is-empty) {
        log warning $"No ISBN-13s found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset)"
        null
      } else if ($isbns | length) == 1 {
        $isbns.value | first
      } else {
        log warning $"Multiple ISBN-13s found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset): ($isbns.value)"
        null
      }
    } else {
      $isbn
    }
  )
  let wikidata_edition_id = (
    if ($wikidata_edition_id | is-empty) and ($bookbrainz_edition_identifiers | is-not-empty) {
      let wikidata_edition_ids = $bookbrainz_edition_identifiers | where type == "Wikidata Edition ID"
      if ($wikidata_edition_ids | is-empty) {
        log warning $"No Wikidata Edition IDs found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset)"
        null
      } else if ($wikidata_edition_ids | length) == 1 {
        $wikidata_edition_ids.value | first
      } else {
        log warning $"Multiple Wikidata Edition IDs found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset): ($wikidata_edition_ids.value)"
        null
      }
    } else {
      $wikidata_edition_id
    }
  )
  let open_library_edition_id = (
    if ($open_library_edition_id | is-empty) and ($bookbrainz_edition_identifiers | is-not-empty) {
      let open_library_edition_ids = $bookbrainz_edition_identifiers | where type == "OpenLibrary Book ID"
      if ($open_library_edition_ids | is-empty) {
        log warning $"No OpenLibrary Book IDs found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset)"
        null
      } else if ($open_library_edition_ids | length) == 1 {
        $open_library_edition_ids.value | first
      } else {
        log warning $"Multiple OpenLibrary Book IDs found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset): ($open_library_edition_ids.value)"
        null
      }
    } else {
      $open_library_edition_id
    }
  )

  # If Wikidata ID is provided and any identifiers are missing, attempt to get them from Wikidata.
  # The Wikidata ID will be empty here if a wikidata ID wasn't found via a file checksum or BookBrainz.
  let wikidata_edition_identifiers = (
    if ($wikidata_edition_identifiers | is-empty) and ($wikidata_edition_id | is-not-empty) and (($isbn | is-empty) or ($bookbrainz_edition_id | is-empty) or ($open_library_edition_id | is-empty)) {
      $wikidata_edition_id | wikidata_get_edition_identifiers
    } else {
      $wikidata_edition_identifiers
    }
  )
  let isbn = (
    if ($isbn | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let isbns = $wikidata_edition_identifiers | get --optional "ISBN-13"
      if ($isbns | is-empty) {
        log warning $"No ISBN-13s found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($isbns | length) == 1 {
        $isbns | first
      } else {
        log warning $"Multiple ISBN-13s found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($isbns)"
        null
      }
    } else {
      $isbn
    }
  )
  let bookbrainz_edition_id = (
    if ($bookbrainz_edition_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let bookbrainz_edition_ids = $wikidata_edition_identifiers | get --optional "BookBrainz edition ID"
      if ($bookbrainz_edition_ids | is-empty) {
        log warning $"No BookBrainz edition IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($bookbrainz_edition_ids | length) == 1 {
        $bookbrainz_edition_ids | first
      } else {
        log warning $"Multiple BookBrainz edition IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($bookbrainz_edition_ids)"
        null
      }
    } else {
      $bookbrainz_edition_id
    }
  )
  let open_library_edition_id = (
    if ($open_library_edition_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let open_library_edition_ids = $wikidata_edition_identifiers | get --optional "Open Library ID"
      if ($open_library_edition_ids | is-empty) {
        log warning $"No OpenLibrary Book IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($open_library_edition_ids | length) == 1 {
        $open_library_edition_ids | first
      } else {
        log warning $"Multiple OpenLibrary Book IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($open_library_edition_ids)"
        null
      }
    } else {
      $open_library_edition_id
    }
  )

  log debug "Attempting to get the ISBN from the first ten and last ten pages of the book"
  let book_isbn_numbers = (
    $formats | get $input_format | isbn_from_pages $temporary_directory
  )
  if ($book_isbn_numbers | is-not-empty) and ($book_isbn_numbers | is-not-empty) {
    log debug $"Found ISBN numbers in the book's pages: (ansi purple)($book_isbn_numbers)(ansi reset)"
  }

  # Determine the most likely ISBN from the metadata and pages
  let likely_isbn_from_pages_and_metadata = (
    if ($existing_metadata | get --optional isbn | is-not-empty) and ($book_isbn_numbers | is-not-empty) {
      if ($book_isbn_numbers | is-empty) {
        log debug $"No ISBN numbers found in the pages of the book. Using the ISBN from the book's metadata (ansi purple)($existing_metadata | get --optional isbn)(ansi reset)"
        $existing_metadata | get --optional isbn
      } else if ($existing_metadata | get --optional isbn) in $book_isbn_numbers {
        if ($book_isbn_numbers | length) == 1 {
          log debug "Found an exact match between the ISBN in the metadata and the ISBN in the pages of the book"
        } else if ($book_isbn_numbers | length) > 10 {
          rm --force --recursive $temporary_directory
          return {
            file: $original_file
            error: $"Found more than 10 ISBN numbers in the pages of the book: (ansi purple)($book_isbn_numbers)(ansi reset)"
          }
        }
        $existing_metadata | get --optional isbn
      } else {
        # todo If only one number is available in the pages, should it be preferred?
        log warning $"The ISBN from the book's metadata, (ansi purple)($existing_metadata | get --optional isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
        if ($book_isbn_numbers | length) == 1 {
          log warning $"The ISBN from the book's metadata, (ansi purple)($existing_metadata | get --optional isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
          $book_isbn_numbers | first
        } else {
          if ($isbn | is-empty) {
            rm --force --recursive $temporary_directory
            return {
              file: $original_file
              error: $"The ISBN from the book's metadata, (ansi purple)($existing_metadata | get --optional isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset). Use the `--isbn` flag to set the ISBN instead."
            }
          } else {
            log warning $"The ISBN from the book's metadata, (ansi purple)($existing_metadata | get --optional isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
          }
        }
      }
    } else if ($existing_metadata | get --optional isbn | is-not-empty) {
      log debug $"No ISBN numbers found in the pages of the book. Using the ISBN from the book's metadata (ansi purple)($existing_metadata | get --optional isbn)(ansi reset)"
      $existing_metadata | get --optional isbn
    } else if ($book_isbn_numbers | is-not-empty) and ($book_isbn_numbers | is-not-empty) {
      if ($book_isbn_numbers | length) == 1 {
        log debug $"Found a single ISBN in the pages of the book: (ansi purple)($book_isbn_numbers | first)(ansi reset)"
        $book_isbn_numbers | first
      } else if ($book_isbn_numbers | length) > 10 {
        log warning $"Found more than 10 ISBN numbers in the pages of the book: (ansi purple)($book_isbn_numbers)(ansi reset)"
      } else {
        log warning $"Found multiple ISBN numbers in the pages of the book: (ansi purple)($book_isbn_numbers)(ansi reset)"
      }
    } else {
      log debug "No ISBN numbers found in the metadata or pages of the book"
    }
  )

  let isbn = (
    if ($isbn | is-empty) {
      if ($likely_isbn_from_pages_and_metadata | is-empty) {
        log warning $"Unable to determine the ISBN from metadata or the pages of the book"
      } else {
        $likely_isbn_from_pages_and_metadata
      }
    } else {
      if $likely_isbn_from_pages_and_metadata != null {
        if $isbn == $likely_isbn_from_pages_and_metadata {
          log debug "The provided ISBN matches the one found using the book's metadata and pages"
        } else {
          log warning $"The provided ISBN (ansi purple)($isbn)(ansi reset) does not match the one found using the book's metadata and pages (ansi purple)($likely_isbn_from_pages_and_metadata)(ansi reset)"
        }
      } else if $book_isbn_numbers != null and ($book_isbn_numbers | is-not-empty) {
        if $isbn in $book_isbn_numbers {
          log debug $"The provided ISBN is among those found in the book's pages: (ansi purple)($book_isbn_numbers)(ansi reset)"
        } else {
          log warning $"The provided ISBN is not among those found in the book's pages: (ansi purple)($book_isbn_numbers)(ansi reset)"
        }
      }
      $isbn
    }
  )
  let isbn = (
    if ($isbn | is-not-empty) {
      $isbn | str replace --all "-" ""
    }
  )
  if ($isbn | is-not-empty) {
    log debug $"The ISBN is (ansi purple)($isbn)(ansi reset)"
    if ($isbn | str length) != 13 {
      log error $"The ISBN (ansi purple)($isbn)(ansi reset) does not contain exactly 13-characters"
      if not $keep_tmp {
        rm --force --recursive $temporary_directory
      }
      return {
        file: $original_file
        error: $"The ISBN (ansi purple)($isbn)(ansi reset) does not contain exactly 13-characters"
      }
    }
  }

  # At this point, we should have an ISBN.
  let hardcover_edition = (
    if ($isbn | is-not-empty) and (($hardcover_edition_id | is-empty) or ($hardcover_book_slug | is-empty)) {
      let editions = $isbn | hardcover_search_editions_by_exact_field isbn_13
      if ($editions | is-empty) {
        # No editions found.
        log warning $"No Hardcover editions found for ISBN (ansi purple)($isbn)(ansi reset)"
        null
      } else if ($editions | length) == 1 {
        $editions | first
      } else {
        log warning $"Multiple Hardcover editions found for the ISBN (ansi purple)($isbn)(ansi reset): ($editions). Filtering on digital editions."
        # Reading format (1=Physical, 2=Audio, 3=Both, 4=Ebook)
        let digital_editions = $editions | where reading_format_id == 4
        if ($digital_editions | is-empty) {
          log warning $"No Hardcover ebook editions found for ISBN (ansi purple)($isbn)(ansi reset)"
          null
        } else if ($digital_editions | length) == 1 {
          $digital_editions | first
        } else {
          log warning $"Multiple Hardcover ebook editions found for ISBN (ansi purple)($isbn)(ansi reset): ($digital_editions)"
          null
        }
      }
    } else {
      # No ISBN, so not searching
    }
  )
  let hardcover_book_slug = (
    if ($hardcover_book_slug | is-empty) {
      if ($hardcover_edition | is-not-empty) {
        $hardcover_edition.book.slug
      }
    } else {
      $hardcover_book_slug
    }
  )
  let hardcover_edition_id = (
    if ($hardcover_edition_id | is-empty) {
      if ($hardcover_edition | is-not-empty) {
        $hardcover_edition.id | into string
      }
    } else {
      $hardcover_edition_id
    }
  )


  # Search for a BookBrainz edition by ISBN
  let bookbrainz_edition_id = (
    if ($isbn | is-empty) and ($bookbrainz_edition_id | is-not-empty) {
      let editions = $isbn | bookbrainz_search_editions_by_isbn
      if ($editions | is-empty) {
        # No editions found.
        log warning $"No BookBrainz editions found for ISBN (ansi purple)($isbn)(ansi reset)"
        null
      } else if ($editions | length) == 1 {
        $editions | first
      } else {
        log warning $"Multiple BookBrainz editions found for the ISBN (ansi purple)($isbn)(ansi reset): ($editions). Filtering on ebooks."
        # formatId 3 == ebook
        let digital_editions = $editions | where formatId == 3
        if ($digital_editions | is-empty) {
          log warning $"No BookBrainz ebook editions found for ISBN (ansi purple)($isbn)(ansi reset)"
          null
        } else if ($digital_editions | length) == 1 {
          $digital_editions | first
        } else {
          log warning $"Multiple BookBrainz ebook editions found for ISBN (ansi purple)($isbn)(ansi reset): ($digital_editions)"
          null
        }
      }
    } else {
      $bookbrainz_edition_id
    }
  )

  # Incorporate any missing identifiers from BookBrainz.
  let bookbrainz_edition_identifiers = (
    if ($bookbrainz_edition_identifiers | is-empty) and ($bookbrainz_edition_id | is-not-empty) and (($wikidata_edition_id | is-empty) or ($open_library_edition_id | is-empty)) {
      $bookbrainz_edition_id | bookbrainz_get_edition_identifiers
    } else {
      $bookbrainz_edition_identifiers
    }
  )
  let wikidata_edition_id = (
    if ($wikidata_edition_id | is-empty) and ($bookbrainz_edition_identifiers | is-not-empty) {
      let wikidata_edition_ids = $bookbrainz_edition_identifiers | where type == "Wikidata Edition ID"
      if ($wikidata_edition_ids | is-empty) {
        log warning $"No Wikidata Edition IDs found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset)"
        null
      } else if ($wikidata_edition_ids | length) == 1 {
        $wikidata_edition_ids.value | first
      } else {
        log warning $"Multiple Wikidata Edition IDs found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset): ($wikidata_edition_ids.value)"
        null
      }
    } else {
      $wikidata_edition_id
    }
  )
  let open_library_edition_id = (
    if ($open_library_edition_id | is-empty) and ($bookbrainz_edition_identifiers | is-not-empty) {
      let open_library_edition_ids = $bookbrainz_edition_identifiers | where type == "OpenLibrary Book ID"
      if ($open_library_edition_ids | is-empty) {
        log warning $"No OpenLibrary Book IDs found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset)"
        null
      } else if ($open_library_edition_ids | length) == 1 {
        $open_library_edition_ids.value | first
      } else {
        log warning $"Multiple OpenLibrary Book IDs found for the BookBrainz edition (ansi purple)($bookbrainz_edition_id)(ansi reset): ($open_library_edition_ids.value)"
        null
      }
    } else {
      $open_library_edition_id
    }
  )

  # Query Wikidata by ISBN if there is no Wikidata edition ID.
  let wikidata_edition_id = (
    if ($isbn | is-not-empty) and ($wikidata_edition_id | is-empty) {
      let editions = $isbn | wikidata_search_editions_by_isbn
      if ($editions | is-empty) {
        # No editions found.
        log warning $"No Wikidata editions found for ISBN (ansi purple)($isbn)(ansi reset)"
        null
      } else if ($editions | length) == 1 {
        $editions | first
      } else {
        log warning $"Multiple Wikidata editions found for the ISBN (ansi purple)($isbn)(ansi reset): ($editions)"
        null
      }
    } else {
      $wikidata_edition_id
    }
  )

  # Pull BookBrainz, Comic Vine, and Open Library identifiers from Wikidata.
  let wikidata_edition_identifiers = (
    if ($wikidata_edition_identifiers | is-empty) and ($wikidata_edition_id | is-not-empty) and (($isbn | is-empty) or ($bookbrainz_edition_id | is-empty) or ($open_library_edition_id | is-empty)) {
      $wikidata_edition_id | wikidata_get_edition_identifiers
    } else {
      $wikidata_edition_identifiers
    }
  )
  let isbn = (
    if ($isbn | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let isbns = $wikidata_edition_identifiers | get --optional "ISBN-13"
      if ($isbns | is-empty) {
        log warning $"No ISBN-13s found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($isbns | length) == 1 {
        $isbns | first
      } else {
        log warning $"Multiple ISBN-13s found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($isbns)"
        null
      }
    } else {
      $isbn
    }
  )
  let bookbrainz_edition_id = (
    if ($bookbrainz_edition_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let bookbrainz_edition_ids = $wikidata_edition_identifiers | get --optional "BookBrainz edition ID"
      if ($bookbrainz_edition_ids | is-empty) {
        log warning $"No BookBrainz edition IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($bookbrainz_edition_ids | length) == 1 {
        $bookbrainz_edition_ids | first
      } else {
        log warning $"Multiple BookBrainz edition IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($bookbrainz_edition_ids)"
        null
      }
    } else {
      $bookbrainz_edition_id
    }
  )
  let open_library_edition_id = (
    if ($open_library_edition_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let open_library_edition_ids = $wikidata_edition_identifiers | get --optional "Open Library ID"
      if ($open_library_edition_ids | is-empty) {
        log warning $"No OpenLibrary Book IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($open_library_edition_ids | length) == 1 {
        $open_library_edition_ids | first
      } else {
        log warning $"Multiple OpenLibrary Book IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($open_library_edition_ids)"
        null
      }
    } else {
      $open_library_edition_id
    }
  )

  # Print final identifiers
  log info $"(ansi green)Identifiers(ansi reset)"
  if ($isbn | is-not-empty) {
    log info $"(ansi green)ISBN(ansi reset): (ansi yellow)($isbn)(ansi reset)"
  } else {
    log warning $"Missing (ansi red)ISBN(ansi reset)"
  }
  if ($bookbrainz_edition_id | is-not-empty) {
    log info $"(ansi green)BookBrainz edition ID(ansi reset): (ansi yellow)($bookbrainz_edition_id)(ansi reset)"
  } else {
    log warning $"Missing (ansi red)BookBrainz edition ID(ansi reset)"
  }
  if ($wikidata_edition_id | is-not-empty) {
    log info $"(ansi green)Wikidata edition ID(ansi reset): (ansi yellow)($wikidata_edition_id)(ansi reset)"
  } else {
    log warning $"Missing (ansi red)Wikidata edition ID(ansi reset)"
  }
  if ($open_library_edition_id | is-not-empty) {
    log info $"(ansi green)Open Library edition ID(ansi reset): (ansi yellow)($open_library_edition_id)(ansi reset)"
  } else {
    log warning $"Missing (ansi red)Open Library edition ID(ansi reset)"
  }
  if ($hardcover_book_slug | is-not-empty) {
    log info $"(ansi green)Hardcover book slug(ansi reset): (ansi yellow)($hardcover_book_slug)(ansi reset)"
  } else {
    log warning $"Missing (ansi red)Hardcover book slug(ansi reset)"
  }
  if ($hardcover_edition_id | is-not-empty) {
    log info $"(ansi green)Hardcover edition ID(ansi reset): (ansi yellow)($hardcover_edition_id)(ansi reset)"
  } else {
    log warning $"Missing (ansi red)Hardcover edition ID(ansi reset)"
  }

  let cache_function = {|type, id, update_function, filename_suffix|
    let filename = (
      if ($filename_suffix | is-not-empty) {
        $"($id)_($filename_suffix).json"
      } else {
        $"($id).json"
      }
    )
    let cached_file = [$cache_directory $type $filename] | path join
    try {
      let data = open $cached_file
      if ($data | is-empty) {
        rm $cached_file
        error make {
          msg: "empty cached file"
          labels: [
              {text: "cached_file" span: (metadata $cached_file).span}
          ]
          help: $"the empty ($cached_file) has been deleted. Try re-running."
        }
      }
      # The integer duration must be converted to a Nushell duration when loading a release from a JSON file.
      # if $type == "release" {
      #   $data | update tracks (
      #     $data.tracks | each {|track|
      #       $track | update duration ($track.duration | into duration)
      #     }
      #   ) | (
      #     let input = $in;
      #     if "chapters" in $input.book {
      #       $input | update book.chapters (
      #         $input.book.chapters | each {|chapter|
      #           $chapter | update start ($chapter.start | into duration) | update length ($chapter.length | into duration)
      #         }
      #       )
      #     } else {
      #       $input
      #     }
      #   )
      # } else {
        $data
      # }
    } catch {
      let result = do $update_function $type $id
      mkdir ($cached_file | path dirname)
      if ($result | is-not-empty) {
        $result | save --force $cached_file
      } else {
        error make {
          msg: "empty or null result"
          labels: [
              {text: "result" span: (metadata $result).span}
          ]
          help: "try re-running when the service is available"
        }
      }
      $result
    }
  }

  log debug "Fetching metadata"
  # todo Add support for getting metadata from BookBrainz.
  # BookBrainz metadata
  # Edition
  # translated Works -> original Works
  # Edition series preferred over Work Series

  let comic_metadata = (
    $hardcover_edition_id | fetch_and_parse_hardcover_edition id $cache_function
  )
  log debug $"The metadata from Hardcover is:\n(ansi green)($comic_metadata | to nuon)(ansi reset)\n"

  # Check for missing or invalid metadata from Hardcover
  if ($comic_metadata | get --optional credits | is-empty) {
    log error $"There are no contributors for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the contributors for the edition, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"There are no contributors for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the contributors for the edition, remove the cached response, and retry."
    }
  }
  if ($comic_metadata.credits | all {|credit| $credit.role != "Writer"}) {
    log error $"There are no authors set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the authors for the edition, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"There are no authors set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the authors for the edition, remove the cached response, and retry."
    }
  }
  if ($comic_metadata | get --optional forms_of_creative_work | is-empty) or ($comic_metadata.forms_of_creative_work | first) == "unknown" {
    log error $"Book category is not set for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the book category for the book, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"Book category is not set for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the book category for the book, remove the cached response, and retry."
    }
  } else if ($comic_metadata.forms_of_creative_work | first) == "graphic novel" {
    log error $"Book category is set to the invalid type 'Graphic Novel' for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Correct the book category for the book or move the edition to the correct book, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"Book category is set to 'Graphic Novel' for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Correct the book category for the book or move the edition to the correct book, remove the cached response, and retry."
    }
  }
  if ($comic_metadata.forms_of_creative_work | first) == "light novel" and ($comic_metadata.credits | all {|credit| $credit.role != "Artist"}) {
    # There should always be an illustrator set for light novels.
    log error $"There is no illustrator set for the light novel Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the illustrator for the edition, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"There is no illustrator set for the light novel Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the illustrator for the edition, remove the cached response, and retry."
    }
  }
  if ($comic_metadata.forms_of_creative_work | first) == "light novel" and ($comic_metadata.credits | all {|credit| $credit.role != "Cover Artist"}) {
    # There should almost always be a Cover Artist set, too.
    log error $"There is no cover artist set for the light novel Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the cover artist for the edition, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"There is no cover artist set for the light novel Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the cover artist for the edition, remove the cached response, and retry."
    }
  }
  if ($comic_metadata | get --optional literary_type | is-empty) or $comic_metadata.literary_type == "unknown" {
    log error $"Literary type is not set for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the literary type for the book, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"Literary type is not set for the Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the literary type for the book, remove the cached response, and retry."
    }
  }
  if ($comic_metadata.forms_of_creative_work | first) == "light novel" and $comic_metadata.literary_type == "nonfiction" {
    log error $"Literary type is not set to fiction for the light novel Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the literary type to fiction for the book, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"Literary type is not set to fiction for the light novel Hardcover book (ansi yellow)(('https://hardcover.app/books/' + $hardcover_book_slug) | ansi link --text $hardcover_book_slug)(ansi reset). Set the literary type to fiction for the book, remove the cached response, and retry."
    }
  }
  if ($comic_metadata | get --optional _cover_image.2 | is-empty) {
    log error $"There is no cover image set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the cover for the edition, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"There is no cover image set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the cover for the edition, remove the cached response, and retry."
    }
  }
  if $comic_metadata._cover_image.3 < 1000 or $comic_metadata._cover_image.4 < 1000 {
    if $replace_cover {
      log error $"The cover appears to be low quality for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Aborting to avoid using a low quality cover in the ebook as the --replace-cover was passed. Upload a high quality cover for the edition, remove the cached response, and retry."
      if not $keep_tmp {
        rm --force --recursive $temporary_directory
      }
      return {
        file: $original_file
        error: $"The cover appears to be low quality for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Upload a high quality cover for the edition, remove the cached response, and retry."
      }
    } else {
      log warning $"The cover appears to be low quality for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Upload a high quality cover for the edition, remove the cached response, and retry."
      sleep 30sec
    }
  }
  if ($comic_metadata | get --optional publication_date | is-empty) {
    log error $"There is no release date set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the release date for the edition, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"There is no release date set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the release date for the edition, remove the cached response, and retry."
    }
  }
  if ($comic_metadata | get --optional language | is-empty) {
    log error $"There is no language set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the language for the edition, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"There is no language set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the language for the edition, remove the cached response, and retry."
    }
  }
  if ($comic_metadata | get --optional publishers | is-empty) {
    log error $"There is no publisher set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the publisher for the edition, remove the cached response, and retry."
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: $"There is no publisher set for the Hardcover edition (ansi yellow)(('https://hardcover.app/editions/' + $hardcover_edition_id) | ansi link --text $hardcover_edition_id)(ansi reset). Set the publisher for the edition, remove the cached response, and retry."
    }
  }

  # Get the genres from Wikidata
  let wikidata_metadata = (
    if ($wikidata_edition_id | is-not-empty) {
      (
        $wikidata_edition_id
        | fetch_wikidata_edition_and_works_metadata $cache_function
        | parse_wikidata_edition_and_works_metadata
        | process_wikidata_edition_and_works_metadata "en" $cache_function
      )
    }
  )
  log debug $"The Wikidata metadata is:\n(ansi green)($wikidata_metadata | to nuon)(ansi reset)\n"

  let ids = (
    []
    | append (
      if ($bookbrainz_edition_id | is-not-empty) {
        [[type id]; [bookbrainz_edition_id $bookbrainz_edition_id]]
      }
    )
    | append (
      if ($hardcover_book_slug | is-not-empty) {
        [[type id]; [hardcover_book_slug $hardcover_book_slug]]
      }
    )
    | append (
      if ($hardcover_edition_id | is-not-empty) {
        [[type id]; [hardcover_edition_id $hardcover_edition_id]]
      }
    )
    | append (
      if ($open_library_edition_id | is-not-empty) {
        [[type id]; [open_library_edition_id $open_library_edition_id]]
      }
    )
    | append (
      if ($wikidata_edition_id | is-not-empty) {
        [[type id]; [wikidata_item_id $wikidata_edition_id]]
      }
    )
  )

  # Use genres from Wikidata.
  let comic_metadata = $comic_metadata | merge (
    if ($wikidata_metadata | get --optional genres | is-empty) {
      {}
    } else {
      {genres: ($wikidata_metadata | get --optional genres)}
    }
  ) | merge (
    if ($comic_metadata | get --optional forms_of_creative_work | is-empty) {
      {
        forms_of_creative_work: ($wikidata_metadata | get --optional forms_of_creative_work)
      }
    } else {
      {}
    }
  ) | merge (
    if ($comic_metadata | get --optional ids | is-empty) and ($wikidata_metadata | get --optional ids | is-empty) {
      {ids: $ids}
    } else if ($comic_metadata | get --optional ids | is-empty) {
      {ids: ($ids | append $wikidata_metadata.ids | uniq)}
    } else if ($wikidata_metadata | get --optional ids | is-empty) {
      {ids: ($ids | append $comic_metadata.ids | uniq)}
    } else {
      {
        ids: (
          $ids | append $wikidata_metadata.ids | append $comic_metadata.ids | uniq
        )
      }
    }
  )
  let comic_metadata = (
    let ids = ($existing_metadata | get --optional ids);
    if ($ids | is-empty) {
      $comic_metadata
    } else {
      let epub_uuids = $ids | where type == "epub_uuid"
      if ($epub_uuids | is-empty) {
        $comic_metadata
      } else if ($epub_uuids | length) > 1 {
        error make {
          msg: "multiple EPUB uuids"
          labels: [
              {text: "epub_uuids" span: (metadata $epub_uuids).span}
          ]
          help: $"remove extra EPUB uuids ($epub_uuids)"
        }
      } else {
        $comic_metadata | update ids (
          $comic_metadata.ids | append ($epub_uuids | first)
        )
      }
    }
  )
  log debug $"The merged metadata is:\n(ansi green)($comic_metadata | to nuon)(ansi reset)\n"


  let form_subdirectory = (
    if ("light novel" in ($comic_metadata | get --optional forms_of_creative_work)) {
      "light-novels"
    } else {
      # todo I should probably create a separate library for fiction and non-fiction.
      "books"
    }
  )

  # Get the original OPF file for debugging purposes.
  # let opf_file = $formats | get $output_format | find_opf_in_epub
  # let opf_file = $formats | get $output_format | extract_file_from_archive $opf_file $temporary_directory
  # log debug $"epub_opf:\n\n($opf_file | open | from xml | to json)"
  # exit 1

  # Embed the updated metadata in the ebook.
  log info "Embedding the metadata in the ebook"
  $comic_metadata | embed_ebook_metadata ($formats | get $output_format) $temporary_directory

  if ($replace_cover) {
    let cover_image_url = $comic_metadata | get --optional _cover_image.2
    if not ($cover_image_url) {
      log error $"Unable to replace cover as there is no cover art set for the Hardcover edition ($hardcover_edition_id)."
      exit 1
    }
    let cover_image = $cover_image_url | download_file $cover_art_directory
    # todo Embed cover image in EPUB manually and only use ebook-meta for PDFs.
    # todo Compare quality of existing cover and downloaded cover and warn or abort as necessary.
    log info "Replacing cover image in the ebook"
    log debug $"Running '^ebook-meta --cover ($cover_image) ($formats | get $output_format)'"
    let result = do {^ebook-meta --cover $cover_image ($formats | get $output_format)} | complete
    if $result.exit_code != 0 {
      log error $"Error running '^ebook-meta --cover ($cover_image) ($formats | get $output_format)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      exit 1
    }
    log info "Replaced the cover image in the ebook"
  }

  log debug "Renaming the file according to its metadata"
  let formats = (
    $formats | update $output_format (
      let previous_file_name = $formats | get $output_format;
      let new_file_name = (
        # todo Should normalized series naming be used?
        # I'm thinking I'll just go with Hardcover's titles.
        $previous_file_name | path parse | update stem (
            # Kavita will assume that the issue number is a chapter for manga libraries.
            # Add the letter v before the issue number instead of a hashtag so that it understands it is the volume number.
            # Also, leave off the year and volume to avoid confusing Kavita.
            # $"($comic_metadata.series) - Volume ($comic_metadata.issue | fill --alignment right --width 3 --character '0')" | use_unicode_in_title | sanitize_file_name
            $comic_metadata.title | use_unicode_in_title | sanitize_file_name
        )
      ) | path join;
      if $new_file_name != $previous_file_name {
        mv --force $previous_file_name $new_file_name
      };
      $new_file_name
    )
  )
  log debug "Renamed the file according to its metadata"

  # Authors are considered to be creators with the role of "Writer" in the ComicVine metadata
  let authors = (
    let credits = $comic_metadata | get credits;
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
  )
  if ($authors | is-empty) {
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      error: "No authors found in Comic Vine metadata!"
    }
  }
  log debug $"The authors are (ansi purple)'($authors)'(ansi reset)"

  let optimized_file_hashes = (
    try {
      open $optimized_files_cache_file
    } catch {
      {sha256: []}
    }
  )

  let updated_optimized_file_hashes = (
    $optimized_file_hashes | update sha256 (
      $optimized_file_hashes.sha256 | append (
        if $output_format == "epub" {
          # todo I might need to fix this to work with larger files
          let hash = $formats | get $output_format | open --raw | hash sha256
          if $hash not-in $optimized_file_hashes.sha256 {
            log debug "Optimizing the EPUB"
            $formats | get $output_format | polish_epub | optimize_zip | open --raw | hash sha256
          }
        }
      ) | append (
        if $output_format == "pdf" {
          let hash = $formats | get $output_format | open --raw | hash sha256
          if $hash not-in $optimized_file_hashes.sha256 {
            log debug "Optimizing the PDF"
            let pdf_optimization_directory = [$temporary_directory "pdf_optimization"] | path join
            let optimized_pdf = (
              $formats | get $output_format
              | optimize_pdf $pdf_optimization_directory
            )
            if ($optimized_pdf | is-not-empty) {
              mv --force $optimized_pdf ($formats | get $output_format)
              if not ($keep_tmp) {
                rm --force --recursive $pdf_optimization_directory
              }
              open --raw ($formats | get $output_format) | hash sha256
            }
          }
        }
      ) | uniq | sort
    )
  )

  if $updated_optimized_file_hashes != $optimized_file_hashes {
    $updated_optimized_file_hashes | save --force $optimized_files_cache_file
  }
  let optimized_file_hashes = $updated_optimized_file_hashes

  # Verify the EPUB file with epubcheck
  if $output_format == "epub" and not ($formats | get $output_format | epubcheck) {
    log error $"Error running epubcheck on the EPUB file (ansi yellow)($formats | get $output_format)(ansi reset)"
    exit 1
  }

  # todo How to handle nested series and subseries?
  let series_subdirectory = (
    # We still use a series subdirectory even if the series is only one issue long, in order to support multiple formats.
    # Kavita dislikes multiple formats in the same directory.
    # if "series" in $comic_metadata and ($comic_metadata.series | is-not-empty) and "issue_count" in $comic_metadata and ($comic_metadata.issue_count | is-not-empty) and $comic_metadata.issue_count > 1 {
    if "series" in $comic_metadata and ($comic_metadata.series | is-not-empty) and "issue_count" in $comic_metadata and ($comic_metadata.issue_count | is-not-empty) {
      # Kavita doesn't like multiple formats being in the same directory.
      (
        $comic_metadata.series
        | use_unicode_in_title
        | sanitize_file_name
        | $in + $" \(($comic_metadata.volume)\) [($output_format)]"
      )
    # Kavita needs series to be in their own directories.
    # So, if this is a oneshot, put it in its own directory.
    } else {
      (
        $formats
        | get $output_format
        | path parse
        | get stem
        | use_unicode_in_title
        | sanitize_file_name
        | $in + $" \(($comic_metadata.publication_date | format date '%Y')\) [($output_format)]"
      )
    }
  )

    let authors_subdirectory = $authors | str join ", "
    let target_subdirectory = (
      # If it is a oneshot, put it in its own subdirectory inside a directory for the author.
      # todo Maybe I should just put these at the top-level as I do for comics?
      if "series" in $comic_metadata and ($comic_metadata.series | is-not-empty) and "issue_count" in $comic_metadata and ($comic_metadata.issue_count | is-not-empty) {
        $series_subdirectory
      } else {
        [$authors_subdirectory $series_subdirectory] | path join
      }
    )
    let target_directory = [$destination $form_subdirectory $target_subdirectory] | path join
    log debug $"Target directory: ($target_directory)"
    let target_destination = (
      let components = $formats | get $output_format | path parse;
      {
        parent: $target_directory
        stem: ($components.stem | use_unicode_in_title | sanitize_file_name)
        extension: $components.extension
      } | path join
    )
    log debug $"Target destination: ($target_destination)"
    # let cover_target_destination = (
    #   if $output_format == "pdf" {
    #     let components = $formats | get $output_format | path parse;
    #     {
    #       parent: $target_directory
    #       stem: (($components.stem | use_unicode_in_title | sanitize_file_name) + "_cover")
    #       extension: ($book.cover | path parse | get extension)
    #     } | path join
    #   }
    # )
    if $skip_upload {
      mkdir $target_subdirectory
      mv ($formats | get $output_format) $target_subdirectory
    } else {
      log info $"Uploading (ansi yellow)($formats | get $output_format)(ansi reset) to (ansi yellow)($target_destination)(ansi reset)"
      if $use_rsync {
        $formats | get $output_format | rsync $target_destination "--mkpath"
      } else {
        $formats | get $output_format | scp $target_destination --mkdir
      }
    }

    if not $keep {
      let uploaded_paths = (
        [$target_destination]
        # | append $cover_target_destination
      )
      log debug $"Uploaded paths: ($uploaded_paths)"
      if ($original_file | is_ssh_path) {
        if not $skip_upload {
          for original in $original_book_files {
            if $original not-in $uploaded_paths {
              log info $"Deleting the file (ansi yellow)($original)(ansi reset)"
              $original | ssh rm
            }
          }
        }
      } else {
        if $destination != null {
          for original in $original_book_files {
            let output = [$destination ($original | path basename)] | path join
            if $original != $output {
              log info $"Deleting the file (ansi yellow)($original)(ansi reset)"
              rm --force $original
            }
          }
        } else {
          for original in $original_book_files {
            rm --force $original
          }
        }
      }
    }
    log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
    rm --force --recursive $temporary_directory
    {
      file: $original_file
    }
  }

    # } catch {|err|
    #     rm --force --recursive $temporary_directory
    #     log error $"Import of (ansi red)($original_file)(ansi reset) failed!\n($err.msg)\n"
    #     {
    #         file: $original_file
    #         error: $err.msg
    #     }
    # }
  # let ereader_target_directory = ([$ereader_mountpoint $ereader_subdirectory $form_subdirectory] | path join)
  # if $ereader != null and not $no_copy_to_ereader {
  #   if (^findmnt --target $ereader_target_directory | complete | get exit_code) != 0 {
  #     ^udisksctl mount --block-device ("/dev/disk/by-label/" | path join $ereader_disk_label) --no-user-interaction
  #     # todo Parse the mountpoint from the output of this command
  #   }
  #   mkdir $ereader_target_directory
  # }

  $results | to json | print

  let errors = $results | default null error | where error != null
  if ($errors | is-not-empty) {
    log error $"(ansi red)Failed to import the following files due to errors!(ansi reset)"
    $errors | get file | $"(ansi red)($in)(ansi reset)" | print --stderr
    exit 1
  }
}
