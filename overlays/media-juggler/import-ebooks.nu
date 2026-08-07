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
  type: string # Type of book, i.e. "book" or "light-novel"
  ...files: string # The paths to ACSM, EPUB, and PDF files to convert, tag, and upload. SSH style paths are supported.
  --destination: directory = "meerkat:/var/media" # The directory under which to copy files. I also have a light-novels subdirectory dedicated to light novels.
  --isbn: string # ISBN of the book
  # --identifiers: string # asin:XXXX
  --keep # Keep the original file
  --ereader: string # Create a copy of the comic book optimized for this specific e-reader, i.e. "Kobo Elipsa 2E"
  --ereader-subdirectory: string = "Books/Books" # The subdirectory on the e-reader in-which to copy
  --keep-tmp # Don't delete the temporary directory when there's an error
  --keep-acsm # Keep the ACSM file after conversion. These stop working for me before long, so no point keeping them around.
  --no-copy-to-ereader # Don't copy the E-Reader specific format to a mounted e-reader
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
  if ($type not-in ["book" "light-novel"]) {
    log error $"Invalid book type (ansi red)($type)(ansi reset). Must be one of: book, light-novel"
    exit 1
  }
  let destination = (
    if ($destination | is-not-empty) {
      [$destination $"($type)s"] | path join
    } else if ($config | get --optional destination | is-not-empty) {
      [$config.destination $"($type)s"] | path join
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

  let username = (^id --name --user)
  let ereader_disk_label = (
    if $ereader == null {
      ""
    } else {
      $ereader_profiles | where model == $ereader | first | get disk_label
    }
  )
  let ereader_mountpoint = (["/run/media" $username $ereader_disk_label] | path join)
  let ereader_target_directory = ([$ereader_mountpoint $ereader_subdirectory] | path join)
  if $ereader != null and not $no_copy_to_ereader {
    if (^findmnt --target $ereader_target_directory | complete | get exit_code) != 0 {
      ^udisksctl mount --block-device ("/dev/disk/by-label/" | path join $ereader_disk_label) --no-user-interaction
      # todo Parse the mountpoint from the output of this command
    }
    mkdir $ereader_target_directory
  }

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
  let isbn = $isbn | str replace --all "-" ""
  if $isbn != null {
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

  let book = (
    $formats | get $output_format
    | (
      let input = $in;
      if ($isbn | is-empty) {
        # Don't use Kobo unless we know the ISBN... or it will probably find something arbitrary and wrong instead of the actual book.
        let result = $input | fetch_book_metadata --allowed-plugins ["Hardcover" "Wikidata"] $temporary_directory
        if $result.opf == null {
          {
            book: $input
            cover: null
            opf: null
          }
        } else {
          let original_title = $existing_metadata | title_from_metadata
          let fetched_title = $result.opf | title_from_opf
          if $fetched_title == $original_title {
            $result
          } else {
            log warning $"The fetched title (ansi yellow)($fetched_title)(ansi reset) does not match the original title (ansi yellow)($original_title)(ansi reset). Ignoring metadata."
            {
              book: $input
              cover: null
              opf: null
            }
          }
        }
      } else {
        # todo output details of discovered metadata for verification
        let result = $input | fetch_book_metadata --isbn $isbn $temporary_directory
        if ($result.opf | is-empty) {
          {
            book: $input
            cover: null
            opf: null
          }
        } else {
          let fetched_isbn = $result.opf | from_opf_xml | get --optional isbn
          if ($fetched_isbn | is-empty) {
            log warning "No ISBN in retrieved metadata!"
            $result
          } else if $fetched_isbn == $isbn {
            $result
          } else {
            log info "Fetched ISBN doesn't match the ISBN used to search! Will attempt another search with only the Hardcover and Wikidata metadata sources"
            let result = $input | fetch_book_metadata --allowed-plugins ["Hardcover" "Wikidata"] --isbn $isbn $temporary_directory
            if $result.opf == null {
              {
                book: $input
                cover: null
                opf: null
              }
            } else {
              let fetched_isbn = $result.opf | from_opf_xml | get --optional isbn
              if $fetched_isbn == null or ($fetched_isbn | is-empty) {
                log warning "No ISBN in retrieved metadata!"
                $result
              } else if $fetched_isbn == $isbn {
                $result
              } else {
                log warning "No metadata found!"
                {
                  book: $input
                  cover: null
                  opf: null
                }
              }
            }
          }
        }
      }
    )
    | (
      let input = $in;
      log debug $"input: ($input)";
      $input | update opf (
        if ($input | get --optional opf | is-not-empty) and ($existing_metadata | get --optional opf | is-not-empty) {
          # todo Should probably have a better way of merging metadata
          $existing_metadata.opf | merge $input.opf
        } else if ($input | get --optional opf | is-not-empty) {
          $input.opf
        } else if ($existing_metadata | get --optional opf | is-not-empty) {
          $existing_metadata.opf
        } else {
          log error "No metadata!"
        }
      ) | update cover (
        if ($cover | is-not-empty) {
          $cover
        } else {
          $input.cover
        }
      )
    )
    | export_book_to_directory ($formats | get $output_format | path dirname)
    | embed_book_metadata
  )

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
          let hash = $book.book | open --raw | hash sha256
          if $hash not-in $optimized_file_hashes.sha256 {
            log debug "Optimizing the EPUB"
            $book.book | polish_epub | optimize_zip | open --raw | hash sha256
          }
        }
      ) | append (
        if $output_format == "pdf" {
          let hash = $book.book | open --raw | hash sha256
          if $hash not-in $optimized_file_hashes.sha256 {
            log debug "Optimizing the PDF"
            let pdf_optimization_directory = [$temporary_directory "pdf_optimization"] | path join
            let optimized_pdf = (
              $book.book
              | optimize_pdf $pdf_optimization_directory
            )
            if ($optimized_pdf | is-not-empty) {
              mv --force $optimized_pdf $book.book
              if not ($keep_tmp) {
                rm --force --recursive $pdf_optimization_directory
              }
              open --raw $book.book | hash sha256
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

    # todo Function and test case for this.
    let authors = (
      $book.opf
      | open
      | from xml
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "creator"
      | where attributes.role == "aut"
      | par-each {|creator| $creator | get content | first | get content}
      | str trim --char ','
      | str trim
      | where {|author| not ($author | is-empty)}
      | sort
    )
    log debug $"Authors: ($authors)"

    let series = (
      $book.opf
      | open
      | from xml
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "meta"
      | where attributes.name == "calibre:series"
      | get attributes.content
      | str trim
      | where {|series| not ($series | is-empty)}
    )
    let series = (
      if ($series | length) == 1 {
        # todo Include series year in series folder name.
        log debug $"Series: ($series | first)"
        # $series | first | $in + $" \(($comic_metadata.volume)\) [($output_format)]"
        $series | first | use_unicode_in_title | sanitize_file_name | $in + $" [($output_format)]"
      } else if ($series | length) > 1 {
        log info $"Multiple series found in the metadata: (ansi yellow)($series)(ansi reset). Ignoring series."
      } else {

      }
    )
    # Remove disambiguation for light novels.
    # todo Do this for the title as well.
    let series = (
      if ($series | is-empty) {
      } else {
        $series | str replace --all " (Light Novel)" ""
      }
    )

    let authors_subdirectory = $authors | str join ", "
    let target_subdirectory = (
      if ($series | is-empty) {
        $authors_subdirectory
      } else {
        $series
      }
    )
    let target_directory = [$destination $target_subdirectory] | path join
    log debug $"Target directory: ($target_directory)"
    let target_destination = (
      let components = $book.book | path parse;
      {
        parent: $target_directory
        stem: ($components.stem | use_unicode_in_title | sanitize_file_name)
        extension: $components.extension
      } | path join
    )
    log debug $"Target destination: ($target_destination)"
    # todo Remove sidecar opf.
    let opf_target_destination = (
      if $output_format == "pdf" {
        let components = $book.book | path parse;
        {
          parent: $target_directory
          stem: (($components.stem | use_unicode_in_title | sanitize_file_name) + "_metadata")
          extension: "opf"
        } | path join
      }
    )
    let cover_target_destination = (
      if $output_format == "pdf" {
        let components = $book.book | path parse;
        {
          parent: $target_directory
          stem: (($components.stem | use_unicode_in_title | sanitize_file_name) + "_cover")
          extension: ($book.cover | path parse | get extension)
        } | path join
      }
    )
    if $skip_upload {
      mkdir $target_subdirectory
      if $output_format == "pdf" {
        mv $book.book $book.cover $book.opf $target_subdirectory
      } else {
        mv $book.book $target_subdirectory
      }
    } else {
      log info $"Uploading (ansi yellow)($book.book)(ansi reset) to (ansi yellow)($target_destination)(ansi reset)"
      if $use_rsync {
        $book.book | rsync $target_destination "--mkpath"
      } else {
        $book.book | scp $target_destination --mkdir
      }
      if $output_format == "pdf" {
        log info $"Uploading (ansi yellow)($book.opf)(ansi reset) to (ansi yellow)($opf_target_destination)(ansi reset)"
        if $use_rsync {
          $book.opf | rsync $target_destination "--mkpath"
        } else {
          $book.opf | scp $target_destination --mkdir
        }
        log info $"Uploading (ansi yellow)($book.cover)(ansi reset) to (ansi yellow)($cover_target_destination)(ansi reset)"
        if $use_rsync {
          $book.cover | rsync $target_destination "--mkpath"
        } else {
          $book.cover | scp $target_destination --mkdir
        }
      }
    }

    if not $keep {
      let uploaded_paths = (
        [$target_destination]
        | append $cover_target_destination
        | append $opf_target_destination
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

  if $ereader != null and not $no_copy_to_ereader {
    if (^findmnt --target $ereader_target_directory | complete | get exit_code) == 0 {
      ^udisksctl unmount --block-device ("/dev/disk/by-label/" | path join $ereader_disk_label) --no-user-interaction
    }
  }

  $results | to json | print

  let errors = $results | default null error | where error != null
  if ($errors | is-not-empty) {
    log error $"(ansi red)Failed to import the following files due to errors!(ansi reset)"
    $errors | get file | $"(ansi red)($in)(ansi reset)" | print --stderr
    exit 1
  }
}
