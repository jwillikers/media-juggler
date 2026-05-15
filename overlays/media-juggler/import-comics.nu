#!/usr/bin/env nu

# ~/Projects/media-juggler/packages/media-juggler/import-comics.nu --output-directory ~/Downloads ~/Downloads/ComicTagger-x86_64.AppImage ...(^mc find --name '*.cbz' "jwillikers/media/Books/Books/Ryoko Kui" | lines | par-each {|l| "minio:" + $l})

# todo Support / prefer CBT, especially using zstd compression?

# todo Place the Calibre library and database in the temporary directory

use std assert
use std log
use media-juggler-lib *

# $env.NU_LOG_LEVEL = "DEBUG"

# Import my comic or manga file to my collection.
#
# This script performs several steps to process the comic or manga file.
#
# 1. Convert from EPUB to the CBZ format.
# 2. Fetch and add metadata in the ComicInfo.xml format.
# 3. Upload the file to object storage.
#
# Information that is not provided will be gleaned from the title of the EPUB file if possible.
#
# The final file is named according to Jellyfin's recommendation.
# The name will look like "<series> (<series-year>) #<issue> (<issue-year>).cbz".
#
def main [
  ...files: string # The paths to ACSM, EPUB, and CBZ files to convert, tag, and upload. Supports SSH paths.
  --comic-vine-issue-id: string # The Comic Vine issue id. Useful when nothing else works, but not recommended as it doesn't seem to verify the cover image.
  --default-language: string = "american english"
  --default-allowed-metadata-plugins: list<string> = ["Hardcover" "Open Library" "Wikidata"] # Calibre metadata plugins to allow by default. Try removing Kobo from this list if it hangs.
  # --default-allowed-metadata-plugins: list<string> = ["Hardcover" "Barnes & Noble" Google "Amazon.com" "Open Library" "Kobo Metadata"] # Calibre metadata plugins to allow by default. Try removing Kobo from this list if it hangs.
  # --default-allowed-metadata-plugins: list<string> = ["Hardcover" "Barnes & Noble" Google "Amazon.com" "Open Library"] # Calibre metadata plugins to allow by default. Try removing Kobo from this list if it hangs.
  # --ignore-epub-title # Don't use the EPUB title for the Comic Vine lookup
  --isbn: string
  # --jxl # Convert lossless PNG images to JXL
  # --interactive # Ask for input from the user
  --keep # Don't delete or modify the original input files
  --keep-tmp # Don't delete the temporary directory when there's an error
  --keep-acsm # Keep the ACSM file after conversion. These stop working for me before long, so no point keeping them around.
  # --issue: string # The issue number
  # --issue-year: string # The publication year of the issue
  --manga: string = "YesAndRightToLeft" # Whether the file is manga "Yes", right-to-left manga "YesAndRightToLeft", or not manga "No". Refer to https://anansi-project.github.io/docs/comicinfo/documentation#manga
  --metron-issue-id: string # The issue id on Metron.
  --destination: directory = "meerkat:/var/media/manga" # The directory under which to copy files. I have comics, manga, and manhwa subdirectories.
  # --series: string # The name of the series
  # --series-year: string # The initial publication year of the series, also referred to as the volume
  --skip-ocr # Don't attempt to parse the ISBN from images using OCR
  --skip-optimization # Don't attempt to perform expensive optimizations. This only skips PDF optimization at the moment, as it is the most expensive optimization.
  --skip-upload # Don't upload files to the server
  --title: string # The title of the comic or manga issue
  --use-rsync # Use rsync instead of scp to retrieve and copy files from a remote machine.
  --bookbrainz-edition-id: string # The BookBrainz Edition ID (only embedded in the metadata right now)
  --hardcover-edition-id: string # The Hardcover Edition ID (only embedded in the metadata right now)
  --hardcover-book-slug: string # The Hardcover Book Slug (only embedded in the metadata right now)
  --open-library-edition-id: string # The Open Library edition ID (only embedded in the metadata right now)
  # --open-library-work-id: string # The Open Library edition ID (only embedded in the metadata right now)
  --wikidata-work-id: string # The Wikidata work ID (only embedded in the metadata right now)
  --wikidata-edition-id: string # The Wikidata edition ID (only embedded in the metadata right now)
  --imprints: list<string> # Set the publisher/imprint. This is embedded in the ComicInfo.xml file and used for the publisher in EPUB and PDF metadata.
  --publishers: list<string> # Set the publisher in the metadata. Note that the imprint is preferred over this for EPUB and PDF metadata.
] {
  if ($files | is-empty) {
    log error "No files provided"
    exit 1
  }

  if ($files | length) > 1 and (
    ($comic_vine_issue_id | is-not-empty)
    or ($isbn | is-not-empty)
    or ($bookbrainz_edition_id  | is-not-empty)
    or ($metron_issue_id | is-not-empty)
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

  let comic_vine_issue_id = (
    if $comic_vine_issue_id != null and ($comic_vine_issue_id | str starts-with "4000-") {
      $comic_vine_issue_id | str replace "4000-" ""
    } else {
      $comic_vine_issue_id
    }
  )
  if ($comic_vine_issue_id | is-not-empty) and not (("4000-" + $comic_vine_issue_id) | is_identifier_valid comic_vine_issue_id) {
    log error $"Invalid Comic Vine issue id (ansi purple)($comic_vine_issue_id)(ansi reset). The Comic Vine issue id should be provided as an integer without a prefix or with a prefix of '4000-'"
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

  let cache_directory = [($nu.cache-dir | path dirname) "media-juggler" "import-comics"] | path join
  let optimized_files_cache_file = [$cache_directory optimized.json] | path join
  mkdir $cache_directory

  let config_file = [($nu.default-config-dir | path dirname) "media-juggler" "import-comics-config.json"] | path join
  let config: record = (
    try {
      open $config_file
    } catch {
      {}
    }
  )

  let default_language = (
    if ($default_language | is-not-empty) {
      $default_language
    } else if ($config | get --optional default_language | is-not-empty) {
      $config.default_language
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

  let results = $files | each {|original_file|

  let original_file = (
    if ($original_file | is_ssh_path) {
      $original_file
    } else {
      $original_file | path expand
    }
  )

  log info $"Importing the file (ansi purple)($original_file)(ansi reset)"

  let temporary_directory = (mktemp --directory "import-comics.XXXXXXXXXX")
  log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

  # try {

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
      if not ($original_file | path exists) {
        if not $keep_tmp {
          rm --force --recursive $temporary_directory
        }
        return {
          file: $original_file
          error: $"The file (ansi yellow)($original_file)(ansi reset) does not exist!"
        }
      }
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

  let original_comic_info = (
    let components = $original_file | split_ssh_path;
    let comic_info_file = (
      $components
      | update path (
        $components
        | get path
        | path parse
        | update stem {|s| $s.stem + "_ComicInfo"}
        | update extension xml
        | path join
      )
      | values | str join ":"
    );
    if ($original_file | is_ssh_path) {
      if ($comic_info_file | ssh_path_exists) {
        $comic_info_file
      }
    } else {
      if ($comic_info_file | path exists) {
        $comic_info_file
      }
    }
  )

  if ($original_comic_info | is-not-empty) {
    log debug $"Found Comic Info file (ansi yellow)($original_comic_info)(ansi reset)"
  }

  let comic_info = (
    if ($original_comic_info | is-not-empty) {
      let target = [$temporary_directory ($original_comic_info | path basename)] | path join
      if ($original_file | is_ssh_path) {
        log debug $"Downloading the file (ansi yellow)($original_comic_info)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        if $use_rsync {
          $original_comic_info | rsync $target "--mkpath"
        } else {
          $original_comic_info | scp $target --mkdir
        }
      } else {
        log debug $"Copying the file (ansi yellow)($original_file)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        cp $original_comic_info $target
      }
      $target
    } else {
      null
    }
  )

  let original_metron_info = (
    let components = $original_file | split_ssh_path;
    let metron_info_file = (
      $components
      | update path (
        $components
        | get path
        | path parse
        | update stem {|s| $s.stem + "_MetronInfo"}
        | update extension xml
        | path join
      )
      | values | str join ":"
    );
    if ($original_file | is_ssh_path) {
      if ($metron_info_file | ssh_path_exists) {
        $metron_info_file
      }
    } else {
      if ($metron_info_file | path exists) {
        $metron_info_file
      }
    }
  )

  if $original_metron_info != null {
    log debug $"Found Metron Info file (ansi yellow)($original_metron_info)(ansi reset)"
  }

  let metron_info = (
    if $original_metron_info != null {
      let target = [$temporary_directory ($original_metron_info | path basename)] | path join
      if ($original_file | is_ssh_path) {
        log debug $"Downloading the file (ansi yellow)($original_metron_info)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        if $use_rsync {
          $original_metron_info | rsync $target "--mkpath"
        } else {
          $original_metron_info | scp $target --mkdir
        }
      } else {
        log debug $"Copying the file (ansi yellow)($original_file)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        cp $original_metron_info $target
      }
      $target
    } else {
      null
    }
  )

  let original_opf = (
    let components = $original_file | split_ssh_path;
    let opf_file = (
      $components
      | update path (
        $components
        | get path
        | path parse
        | update stem {|s| $s.stem + "_metadata"}
        | update extension opf
        | path join
      )
      | values | str join ":"
    );
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

  if ($original_opf | is-not-empty) {
    log debug $"Found OPF metadata file (ansi yellow)($original_opf)(ansi reset)"
  }

  let opf = (
    if ($original_opf | is-not-empty) {
      # todo Is this right?
      let opf_file = ($original_file | split_ssh_path | get path | path dirname | path join "metadata.opf")
      if ($original_file | is_ssh_path) {
        let target = [$temporary_directory ($opf_file | path basename)] | path join
        log debug $"Downloading the file (ansi yellow)($original_opf)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        if $use_rsync {
          $original_opf | rsync $target "--mkpath"
        } else {
          $original_opf | scp $target --mkdir
        }
      } else {
          let target = [$temporary_directory ($opf_file | path basename)] | path join
          log debug $"Copying the file (ansi yellow)($original_opf)(ansi reset) to (ansi yellow)($target)(ansi reset)"
          cp $original_opf $target
      }
      [$temporary_directory ($opf_file | path basename)] | path join
    } else {
      null
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
          ($components.stem | str ends-with "cover") and $components.extension in $image_extensions
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

    # todo Incorporate the original cover file?
    # let cover = (
    #     if ($input_format == "pdf" and $original_cover != null) {
    #         if ($original_file | str starts-with "minio:") {
    #             ^mc cp $original_cover $"($temporary_directory)/($original_cover | path basename)"
    #         } else {
    #             cp $original_cover $"($temporary_directory)/($original_cover | path basename)"
    #         }
    #         $"($temporary_directory)/($original_cover | path basename)"
    #     } else {
    #       null
    #     }
    # )

  let original_comic_files = [$original_file] | append $original_comic_info | append $original_cover | append $original_opf
  log debug $"The original files for the comic are (ansi yellow)($original_comic_files)(ansi reset)"

  let output_format = (
    if $original_input_format == "pdf" {
      "pdf"
    } else {
      "cbz"
    }
  )

  let formats = (
    if $original_input_format == "acsm" {
      log debug "Converting the ACSM file to an EPUB"
      { epub: ($file | acsm_to_epub (pwd)) }
    } else if $original_input_format == "epub" {
      log debug "Importing the EPUB file"
      { epub: ($file | acsm_to_epub (pwd)) }
    } else if $original_input_format in ["cbz" "zip"] {
      { cbz: $file }
    } else if $original_input_format == "pdf" {
      { pdf: $file }
    } else {
      if not $keep_tmp {
        rm --force --recursive $temporary_directory
      }
      return {
        file: $original_file
        error: $"Unsupported input file type (ansi red_bold)($original_input_format)(ansi reset)"
      }
    }
  )

  let input_format = (
    if $original_input_format == "acsm" {
      "epub"
    } else if $original_input_format == "zip" {
      "cbz"
    } else {
      $original_input_format
    }
  )

  # Obtain IDs from existing EPUB, CBZ, or PDF metadata.
  # todo Need to determine preference for ComicInfo vs. MetronInfo.
  let existing_metadata = (
    $formats | get $input_format | extract_ebook_metadata $temporary_directory
  )

  # If no primary ids, i.e. ISBN, BookBrainz edition ID, and Wikidata item ID, are provided, try using the primary ids available in the metadata.
  # If an ISBN, BookBrainz edition ID, or Wikidata item ID are provided, we'll try to use those to look up the other IDs using the provided ones.
  # However, for the Comic Vine ID, we'll use it from the existing metadata unless it is provided on the command-line.
  # This is because Comic Vine IDs are only associated with other identifiers through Wikidata.
  # todo Handle merging existing data and IDs.
  let isbn = (
    if ($isbn | is-empty) and ($bookbrainz_edition_id | is-empty) and ($wikidata_edition_id | is-empty) {
      if ($isbn | is-empty) {
        if ($existing_metadata | is-not-empty) {
          let metadata_isbn = $existing_metadata | get --optional isbn
          if ($existing_metadata.isbn | is-not-empty) {
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
  let comic_vine_issue_id = (
    if ($comic_vine_issue_id | is-empty) {
      if ($existing_metadata | is-not-empty) {
        let ids = $existing_metadata | get --optional ids
        if ($ids | is-not-empty) {
          let comic_vine_issue_ids = $ids | where type == "comic_vine_issue_id"
          if ($comic_vine_issue_ids | is-not-empty) {
            # todo Warn if multiple
            $comic_vine_issue_ids | first
          }
        }
      }
    } else {
      $comic_vine_issue_id
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
              $original_file | hash_blake3
            } else if $checksum_type == "sha3-512" {
              $original_file | hash_sha3_512
            } else {
              log error $"This should never happen."
              exit 1
            }
          )
          let file_size = du $original_file | first | get physical
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
    if ($wikidata_edition_id | is-not-empty) and (($isbn | is-empty) or ($bookbrainz_edition_id | is-empty) or ($open_library_edition_id | is-empty) or ($comic_vine_issue_id | is-empty)) {
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
  let comic_vine_issue_id = (
    if ($comic_vine_issue_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let comic_vine_issue_ids = $wikidata_edition_identifiers | get --optional "Comic Vine ID"
      if ($comic_vine_issue_ids | is-empty) {
        log warning $"No Comic Vine issue IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($comic_vine_issue_ids | length) == 1 {
        $comic_vine_issue_ids | first
      } else {
        log warning $"Multiple Comic Vine issue IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($comic_vine_issue_ids)"
        null
      }
    } else {
      $comic_vine_issue_id
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
    if ($wikidata_edition_identifiers | is-empty) and ($wikidata_edition_id | is-not-empty) and (($isbn | is-empty) or ($bookbrainz_edition_id | is-empty) or ($open_library_edition_id | is-empty) or ($comic_vine_issue_id | is-empty)) {
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
  let comic_vine_issue_id = (
    if ($comic_vine_issue_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let comic_vine_issue_ids = $wikidata_edition_identifiers | get --optional "Comic Vine ID"
      if ($comic_vine_issue_ids | is-empty) {
        log warning $"No Comic Vine issue IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($comic_vine_issue_ids | length) == 1 {
        $comic_vine_issue_ids | first
      } else {
        log warning $"Multiple Comic Vine issue IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($comic_vine_issue_ids)"
        null
      }
    } else {
      $comic_vine_issue_id
    }
  )

  if ($existing_metadata | get --optional isbn | is-not-empty) {
    log debug $"Found the ISBN (ansi purple)($existing_metadata.isbn)(ansi reset) in the book's metadata"
  }

  log debug "Attempting to get the ISBN from the first ten and last ten pages of the book"
  let book_isbn_numbers = (
    $formats | get $input_format | isbn_from_pages $temporary_directory
  )
  if ($book_isbn_numbers | is-not-empty) and ($book_isbn_numbers | is-not-empty) {
    log debug $"Found ISBN numbers in the book's pages: (ansi purple)($book_isbn_numbers)(ansi reset)"
  }

  # Determine the most likely ISBN from the metadata and pages
  # todo Use isbntools to ensure that any discovered ISBNs are valid.
  let likely_isbn_from_pages_and_metadata = (
    if ($existing_metadata | get --optional isbn | is-not-empty) and ($book_isbn_numbers | is-not-empty) {
      if ($book_isbn_numbers | is-empty) {
        log debug $"No ISBN numbers found in the pages of the book. Using the ISBN from the book's metadata (ansi purple)($existing_metadata.isbn)(ansi reset)"
        $existing_metadata.isbn
      } else if $existing_metadata.isbn in $book_isbn_numbers {
        if ($book_isbn_numbers | length) == 1 {
          log debug "Found an exact match between the ISBN in the metadata and the ISBN in the pages of the book"
        } else if ($book_isbn_numbers | length) > 10 {
          if not $keep_tmp {
            rm --force --recursive $temporary_directory
          }
          return {
            file: $original_file
            error: $"Found more than 10 ISBN numbers in the pages of the book: (ansi purple)($book_isbn_numbers)(ansi reset)"
          }
        }
        $existing_metadata.isbn
      } else {
        # todo If only one number is available in the pages, should it be preferred?
        log warning $"The ISBN from the book's metadata, (ansi purple)($existing_metadata.isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
        if ($book_isbn_numbers | length) == 1 {
          log warning $"The ISBN from the book's metadata, (ansi purple)($existing_metadata.isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
          $book_isbn_numbers | first
        } else {
          if ($isbn | is-empty) {
            if not $keep_tmp {
              rm --force --recursive $temporary_directory
            }
            return {
              file: $original_file
              error: $"The ISBN from the book's metadata, (ansi purple)($existing_metadata.isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset). Use the `--isbn` flag to set the ISBN instead."
            }
          } else {
            log warning $"The ISBN from the book's metadata, (ansi purple)($existing_metadata.isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
          }
        }
      }
    } else if ($existing_metadata | get --optional isbn | is-not-empty) {
      log debug $"No ISBN numbers found in the pages of the book. Using the ISBN from the book's metadata (ansi purple)($existing_metadata.isbn)(ansi reset)"
      $existing_metadata.isbn
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
      if ($likely_isbn_from_pages_and_metadata | is-not-empty) {
        if $isbn == $likely_isbn_from_pages_and_metadata {
          log debug "The provided ISBN matches the one found using the book's metadata and pages"
        } else {
          log error $"The provided ISBN (ansi purple)($isbn)(ansi reset) does not match the one found using the book's metadata and pages (ansi purple)($likely_isbn_from_pages_and_metadata)(ansi reset)"
          # todo Allow skipping this check for when the ISBN in the book is incorrect.
          # todo make error
          if not $keep_tmp {
            rm --force --recursive $temporary_directory
          }
          return {
            file: $original_file
            error: $"The provided ISBN (ansi purple)($isbn)(ansi reset) does not match the one found using the book's metadata and pages (ansi purple)($likely_isbn_from_pages_and_metadata)(ansi reset)"
          }
        }
      } else if ($book_isbn_numbers | is-not-empty) and ($book_isbn_numbers | is-not-empty) {
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
    if $isbn !~ '^[0-9]{13}$' {
      log error $"The ISBN (ansi purple)($isbn)(ansi reset) does not contain exactly 13 integers"
      if not $keep_tmp {
        rm --force --recursive $temporary_directory
      }
      return {
        file: $original_file
        error: $"The ISBN (ansi purple)($isbn)(ansi reset) does not contain exactly 13-characters"
      }
    }
  }

  # todo Should existing metadata be merged with the fetched metadata?
  # Right now, existing metadata is completely ignored except for the Comic Info already embedded in a CBZ because ComicTagger will read that.

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

  # let bookbrainz_edition = (
  #   if ($isbn | is-not-empty) and ($bookbrainz_edition_id | is-empty) {
  #     let editions = $isbn | bookbrainz_search_editions_by_isbn
  #     if ($editions | is-empty) {
  #       # No editions found.
  #       log warning $"No Hardcover editions found for ISBN (ansi purple)($isbn)(ansi reset)"
  #       null
  #     } else if ($editions | length) == 1 {
  #       $editions | first
  #     } else {
  #       log warning $"Multiple Hardcover editions found for the ISBN (ansi purple)($isbn)(ansi reset): ($editions). Filtering on digital editions."
  #       # Reading format (1=Physical, 2=Audio, 3=Both, 4=Ebook)
  #       let digital_editions = $editions | where reading_format_id == 4
  #       if ($digital_editions | is-empty) {
  #         log warning $"No Hardcover ebook editions found for ISBN (ansi purple)($isbn)(ansi reset)"
  #         null
  #       } else if ($digital_editions | length) == 1 {
  #         $digital_editions | first
  #       } else {
  #         log warning $"Multiple Hardcover ebook editions found for ISBN (ansi purple)($isbn)(ansi reset): ($digital_editions)"
  #         null
  #       }
  #     }
  #   } else {
  #     $bookbrainz_edition_id
  #   }
  # )

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
    if ($wikidata_edition_identifiers | is-empty) and ($wikidata_edition_id | is-not-empty) and (($isbn | is-empty) or ($bookbrainz_edition_id | is-empty) or ($open_library_edition_id | is-empty) or ($comic_vine_issue_id | is-empty)) {
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
  let comic_vine_issue_id = (
    if ($comic_vine_issue_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let comic_vine_issue_ids = $wikidata_edition_identifiers | get --optional "Comic Vine ID"
      if ($comic_vine_issue_ids | is-empty) {
        log warning $"No Comic Vine issue IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($comic_vine_issue_ids | length) == 1 {
        $comic_vine_issue_ids | first
      } else {
        log warning $"Multiple Comic Vine issue IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($comic_vine_issue_ids)"
        null
      }
    } else {
      $comic_vine_issue_id
    }
  )

  # Print final identifiers
  log info $"(ansi green)Identifiers(ansi reset)"
  if ($isbn | is-not-empty) {
    log info $"(ansi green)ISBN(ansi reset): (ansi yellow)($isbn)(ansi reset)"
  } else {
    log warning $"Missing (ansi red)ISBN(ansi reset)"
  }
  if ($comic_vine_issue_id | is-not-empty) {
    log info $"(ansi green)Comic Vine issue ID(ansi reset): (ansi yellow)($comic_vine_issue_id)(ansi reset)"
  } else {
    log warning $"Missing (ansi red)Comic Vine issue ID(ansi reset)"
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
  let tag_result = (
    # Get Comic Vine metadata through the ComicVine API directly.
    let data = $comic_vine_issue_id | get_comic_vine_issue $cache_function;
    # todo Cache things to avoid rate-limiting.
    # Avoid rate-limiting
    sleep 1sec;
    let volume_data = $data.volume.id | into string | get_comic_vine_volume $cache_function;;
    let publication_date = (
      if ($data | get --optional store_date | is-empty) {
      } else {
        $data.store_date | into datetime
      }
    );
    let year = (
      if ($publication_date | is-empty) {
      } else {
        $publication_date | format date "%Y"
      }
    );
    let month = (
      if ($publication_date | is-empty) {
      } else {
        $publication_date | format date "%m"
      }
    );
    let day = (
      if ($publication_date | is-empty) {
      } else {
        $publication_date | format date "%d"
      }
    );
    # Rewrite credits to match ComicTagger's format.
    #  [[person, role, primary, language]; ["Some Person", Editor, false, ""]]
    let credits = (
      $data.person_credits | reduce --fold [] {|person credits_acc|
        $credits_acc | append (
          $person.role
          | split row ","
          | str trim
          | str capitalize
          | each {|role|
            {
              person: $person.name
              id: $person.id
              role: $role
              primary: false
              language: ""
            }
          }
        )
      }
    );
    let ids = (
      [
        [type id];
        [bookbrainz_edition_id $bookbrainz_edition_id]
        [comic_vine_issue_id (
          if ($comic_vine_issue_id | str starts-with "4000-") {
            $comic_vine_issue_id
          } else {
            "4000-" + $comic_vine_issue_id
          }
        )]
        [metron_issue_id $metron_issue_id]
        [hardcover_book_slug $hardcover_book_slug]
        [hardcover_edition_id $hardcover_edition_id]
        [open_library_edition_id $open_library_edition_id]
        [wikidata_item_id $wikidata_edition_id]
      ]
      | where {|it| $it.id | is-not-empty }
    );
    {
      result: {
        md: {
          issue_id: $data.id
          issue: $data.issue_number
          series: ($data.volume.name | use_unicode_in_title)
          title: (
            if ($data | get --optional name | is-not-empty) {
              $data.name | use_unicode_in_title
            }
          )
          description: $data.description
          volume: $volume_data.start_year
          issue_count: $volume_data.count_of_issues
          ids: $ids
          isbn: $isbn
          characters: ($data.character_credits | select --optional name id)
          language: $default_language
          manga: $manga
          genres: []
          tags: []
          publication_date: $publication_date
          year: $year
          month: $month
          day: $day
          # $volume_data.description
          publishers: [$volume_data.publisher.name]
          # $data.store_date
          # $data.cover_date
          credits: $credits
          series_id: $data.volume.id
          _cover_image: [0, "", $data.image.original_url]
        }
        status: "good_match"
      }
    }
  )
  log debug $"The Comic Vine API result is:\n(ansi green)($tag_result.result | to nuon)(ansi reset)\n"

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

  let comic_metadata = $tag_result.result.md
  let comic_metadata = (
    $comic_metadata
    | merge $wikidata_metadata
    # Prefer publishers from Comic Vine over Wikidata.
    # This is for consistency and to avoid comma's in the Publisher names causing problems, like Kodansha USA Publishing, LLC.
    | upsert publishers $comic_metadata.publishers
  )
  log debug $"The merged metadata is:\n(ansi green)($comic_metadata | to nuon)(ansi reset)\n"

  # If the input format is EPUB, optimize the images before generating the CBZ.
  # This avoids optimizing the same images twice.
  let optimized_file_hashes = (
    try {
      open $optimized_files_cache_file
    } catch {
      {sha256: []}
    }
  )
  let updated_optimized_file_hashes = (
    if $skip_optimization {
      $optimized_file_hashes
    } else {
      $optimized_file_hashes | update sha256 (
        $optimized_file_hashes.sha256 | append (
          if "epub" in $formats {
            # todo I might need to fix this to work with larger files
            let hash = open --raw $formats.epub | hash sha256
            if $hash not-in $optimized_file_hashes.sha256 {
              log debug "Optimizing the EPUB"
              open --raw ($formats.epub | polish_epub | optimize_images_in_zip) | hash sha256
            }
          }
        ) | uniq | sort
      )
    }
  )
  if $updated_optimized_file_hashes != $optimized_file_hashes {
    $updated_optimized_file_hashes | save --force $optimized_files_cache_file
  }
  let optimized_file_hashes = $updated_optimized_file_hashes
  let images_optimized = "epub" in $formats

  # Generate a CBZ from the EPUB format.
  # For input CBZ files, standardize their file names.
  let formats = (
    if "epub" in $formats {
      log debug "Generating a CBZ from the EPUB"
      $formats | insert cbz ($formats.epub | zip_archive_to_cbz --working-directory $temporary_directory)
    } else if "cbz" in $formats {
      log debug "Standardizing the image file names of the CBZ"
      $formats | update cbz ($formats.cbz | zip_archive_to_cbz --working-directory $temporary_directory)
    } else {
      $formats
    }
  )

  # Only calculate the pages after the CBZ has been generated and cleaned up.
  let comic_metadata = (
    if "cbz" in $formats {
      let number_of_pages = $formats.cbz | number_of_images_in_archive
      $comic_metadata | insert page_count $number_of_pages
    } else {
      $comic_metadata
    }
  )

  # Embed the ComicInfo.xml file in the CBZ.
  if "cbz" in ($formats | columns) {
    {
      archive: $formats.cbz
      comic_info: ($comic_metadata | into_comic_info_xml)
    } | inject_comic_info
  }

  log debug "Renaming the CBZ according to the updated metadata from ComicTagger"
  let formats = (
    $formats | update $output_format (
      let previous_file_name = $formats | get $output_format;
      let new_file_name = (
        $previous_file_name | path parse | update stem (
          if $manga == "No" {
            $"($comic_metadata.series) \(($comic_metadata.volume)\) #($comic_metadata.issue | fill --alignment right --width 3 --character '0') \(($comic_metadata.publication_date | date format '%Y')\)"
          } else {
            # Kavita will assume that the issue number is a chapter for manga libraries.
            # Add the letter v before the issue number instead of a hashtag so that it understands it is the volume number.
            # Also, leave off the year and volume to avoid confusing Kavita.
            $"($comic_metadata.series) - Volume ($comic_metadata.issue | fill --alignment right --width 3 --character '0')"
          }
        )
      ) | path join;
      if $new_file_name != $previous_file_name {
        mv --force $previous_file_name $new_file_name
      };
      $new_file_name
    )
  )
  log debug "Renamed the file according to the metadata from Comic Vine"

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

  # We keep the name of the series in the title to keep things organized.
  # Displaying only "Vol. 4" as the title can be confusing.
  log debug "Including the series as part of the title and making it consistent"
  let title = $comic_metadata | get --optional title
  let title = (
    if ($title | is-not-empty) {
      if $comic_metadata.title =~ "(?:(?:Vol.)|(?:Volume)|(?:Book\)\) .+: " {
        let subtitle = $comic_metadata.title | parse --regex "(?:(?:Vol.)|(?:Volume)|(?:Book\)\) .+: (?<subtitle>.*)"
        if ($subtitle | is-not-empty) {
          # todo What if we get multiple regex matches?
          $"($comic_metadata.series), Volume ($comic_metadata.issue): ($subtitle.subtitle | first)"
        } else {
          $"($comic_metadata.series), Volume ($comic_metadata.issue)"
        }
      } else if $comic_metadata.title =~ "(?:(?:Vol.)|(?:Volume)|(?:Book\)\) " {
        $"($comic_metadata.series), Volume ($comic_metadata.issue)"
      } else {
        $"($comic_metadata.series), Volume ($comic_metadata.issue)"
      }
    } else {
      $title | use_unicode_in_title
    }
  )
  log info $"The title is now (ansi yellow)($title)(ansi reset)"

  # todo Remove this variable.
  let comic_vine_id = (
    if ($comic_vine_issue_id | is-empty) {
      $comic_metadata.issue_id
    } else {
      $comic_vine_issue_id
    }
  )

  # PDFs must be optimized before embedding metadata, as the embedded metadata will be scrubbed.
  let updated_optimized_file_hashes = (
    if ($skip_optimization) {
      $optimized_file_hashes
    } else {
      $optimized_file_hashes | update sha256 (
        $optimized_file_hashes.sha256 | append (
          if "pdf" in $formats and not $skip_optimization {
            let hash = open --raw $formats.pdf | hash sha256
            if $hash not-in $optimized_file_hashes.sha256 {
              log debug "Optimizing the PDF"
              open --raw ($formats.pdf | optimize_pdf) | hash sha256
            }
          }
        ) | uniq | sort
      )
    }
  )
  if $updated_optimized_file_hashes != $optimized_file_hashes {
    $updated_optimized_file_hashes | save --force $optimized_files_cache_file
  }
  let optimized_file_hashes = $updated_optimized_file_hashes

  # Update the metadata in the PDF file.
  let formats = (
    if "pdf" in $formats {
      let args = (
        []
        | append (
          if ($isbn | is-not-empty) {
            $"--isbn=($isbn)"
          } else if ($comic_metadata | get --optional isbn | is-not-empty) {
            $"--isbn=($comic_metadata.isbn)"
          }
        )
        | append (
          if ($comic_metadata | get --optional series | is-not-empty) and ($comic_metadata | get --optional issue_count | is-not-empty) and $comic_metadata.issue_count > 1 {
            [$"--series=($comic_metadata.series | use_unicode_in_title)" $"--index=($comic_metadata.issue)"]
          }
        )
        | append (
          # Prefer publisher over imprint
          # todo Not sure if Kavita supports multiple publishers in the PDF metadata.
          if ($publishers | is-not-empty) {
            $"--publisher=($publishers | str join ',')"
          } else if ($comic_metadata | get --optional publishers | is-not-empty) {
            $"--publisher=($comic_metadata.publishers | str join ',')"
          } else if ($imprints | is-not-empty) {
            $"--publisher=($imprints | str join ',')"
          } else if ($comic_metadata | get --optional imprints | is-not-empty) {
            $"--publisher=($comic_metadata.imprints | str join ',')"
          }
        )
        | append (
          if ($comic_metadata | get --optional language | is-not-empty) {
            $"--language=($comic_metadata.language | into_language_code ietf_bcp_47)"
          } else {
            $"--language=($default_language | into_language_code ietf_bcp_47)"
          }
        )
        | append (
          if ($comic_metadata | get --optional description | is-not-empty) {
            $"--comments=($comic_metadata.description)"
          }
        )
        | append (
          if ($comic_metadata | get --optional genres | is-not-empty) {
            $"--tags=($comic_metadata.genres | str join ',')"
          }
        )
        | append (
          if ($bookbrainz_edition_id | is-not-empty) {
            $"--identifier=bookbrainz-edition:($bookbrainz_edition_id)"
          }
        )
        | append (
          if ($hardcover_edition_id | is-not-empty) {
            $"--identifier=hardcover-edition:($hardcover_edition_id)"
          }
        )
        | append (
          if ($hardcover_book_slug | is-not-empty) {
            $"--identifier=hardcover:($hardcover_book_slug)"
          }
        )
        | append (
          if ($wikidata_edition_id | is-not-empty) {
            $"--identifier=wikidata-edition:($wikidata_edition_id)"
          }
        )
        | append (
          if ($wikidata_work_id | is-not-empty) {
            $"--identifier=wikidata-work:($wikidata_work_id)"
          }
        )
        | append (
          let year = (
            if ($comic_metadata | get --optional year | is-not-empty) {
              $comic_metadata.year
            }
          );
          let month = (
            if ($comic_metadata | get --optional month | is-not-empty) {
              $comic_metadata.month
            }
          );
          let day = (
            if ($comic_metadata | get --optional day | is-not-empty) {
              $comic_metadata.day
            }
          );
          if ($comic_metadata | get --optional publication_date | is-not-empty) {
            $"--date=($comic_metadata.publication_date | date format "%Y-%m-%d")"
          } else if ($year | is-not-empty) and ($month | is-not-empty) and ($day | is-not-empty) {
            $"--date=($year)-($month)-($day)"
          } else if ($year | is-not-empty) {
            $"--date=($year)"
          }
        )
      );
      log debug $"Running (ansi yellow)^ebook-meta ($formats.pdf) ($args | str join ' ') --authors ($authors | str join "&") --identifier 'comicvine:($comic_vine_id)' --identifier 'comicvine-volume:($comic_metadata.series_id)'(ansi reset)";
      (
        ^ebook-meta
          $formats.pdf
          ...$args
          # Keep the title in PDFs for now, since Kavita doesn't really change it's behavior whether one is included or not.
          --title ($title | standardize_title)
          --tags ""
          # Remove the title sort field.
          # --title-sort ""
          --authors ($authors | str join "&")
          --identifier $"comicvine:($comic_vine_id)"
          --identifier $"comicvine-volume:($comic_metadata.series_id)"
      );
      # Now, delete the title so Kavita doesn't think it is a chapter title.
      # ebook-meta isn't capable of deleting the title...
      # ^exiftool -Title="" $input.book
      # Obtain a cover image which will be saved alongside the PDF
      # Since ComicVine has low limits on image file size, it's not the place to get high quality covers.
      # Prefer using the cover from the PDF and then fallback to using the one from ComicVine if that fails.
      # Eventually, Hardcover should be used for covers instead of ComicVine.
      let cover = (
        # Attempt to extract the existing cover from the PDF
        let cover = (
          {
            parent: $temporary_directory
            stem: "cover"
          } | path join
        );
        let result = (^ebook-meta --get-cover $cover $formats.pdf | complete);
        if $result.exit_code == 0 {
          $cover | rename_image_with_extension
        } else {
          # Get cover from Hardcover, which supports much better resolution than Comic Vine.
          let hardcover_cover_url = (
            if ($hardcover_edition_id | is-not-empty) {
              $hardcover_edition_id | hardcover_cover_art_url
            } else {
              null
            }
          )
          let cover = (
            {
              parent: $temporary_directory
              stem: "cover"
              extension: ($hardcover_cover_url | path parse | get extension)
            } | path join
          );
          if ($hardcover_cover_url | is-not-empty) {
            log debug $"Downloading Hardcover cover image: ($hardcover_cover_url)";
            try {
              http get --headers [User-Agent $user_agent] --raw $hardcover_cover_url | save --force $cover;
              log debug $"Downloaded cover (ansi yellow)($cover)(ansi reset)";
              $cover
            } catch {|error|
              log error $"Failed to downloaded cover from (ansi yellow)($hardcover_cover_url)(ansi reset): ($error)";
              null
            }
          } else {
            # Get cover from Comic Vine
            log debug $"Comic Vine cover image: ($comic_metadata._cover_image | to nuon)";
            let cover_url = $comic_metadata._cover_image | last;
            try {
              http get --headers [User-Agent $user_agent] --raw $cover_url | save --force $cover;
              log debug $"Downloaded cover (ansi yellow)($cover)(ansi reset)";
              $cover
            } catch {|error|
              log error $"Failed to downloaded cover from (ansi yellow)($cover_url)(ansi reset): ($error)";
              null
            }
          }
        }
      );
      if ($cover | is-not-empty) and not $skip_optimization {
        $cover | optimize_image;
      }
      $formats
      # | update pdf $formats.pdf
      # | insert comic_info $comic_info
      # | insert metron_info $metron_info
      | upsert_if_value cover $cover
    } else {
      $formats
    }
  )
  log debug "Finished renaming files";

  let updated_optimized_file_hashes = (
    if ($skip_optimization) {
      $optimized_file_hashes
    } else {
      $optimized_file_hashes | update sha256 (
        $optimized_file_hashes.sha256 | append (
          if "epub" in $formats {
            # Since the EPUB isn't saved, there's no need to bother with optimizing it further.

            # At this point, the images in the EPUB should be optimized.
            # Just optimize the compression.
            # Since we already cached the hash of this file, if nothing else has changed, we'll accidentally skip this part.
            # So, ignore any existing hash for the epub and optimize it anyway.
            # todo I could use a separate cache for that for just images optimized and use the normal cache here.
            # todo I might need to fix this to work with larger files
            # todo Expire the cache?
            # let hash = open --raw $formats.epub | hash sha256
            # if $hash not-in $optimized_file_hashes.sha256 {

              # Uncomment to optimize EPUB ZIP compression
              # log debug "Optimizing the EPUB ZIP compression"
              # open --raw ($formats.epub | optimize_zip_ect) | hash sha256
              # log debug "Skipping optimizing the EPUB ZIP compression since EPUBs aren't currently saved."
              # open --raw ($formats.epub) | hash sha256

            # }
          }
        ) | append (
          if "pdf" in $formats {
            # Just update the hash of the file with the updated metadata here.
            let hash = open --raw $formats.pdf | hash sha256
            if $hash not-in $optimized_file_hashes.sha256 {
              $hash
            }
          }
        ) | append (
          if "cbz" in $formats {
            let image_format = ($formats.cbz | get_image_extension)
            if ($image_format | is-empty) {
              if not $keep_tmp {
                rm --force --recursive $temporary_directory
              }
              return {
                file: $original_file
                error: "Failed to determine the image file format"
              }
            }

            # todo Detect if another lossless format, i.e. webp, is being used and if so, convert those to jxl as well.
            # if $image_format in ["png"] and $jxl {
            #   $formats.cbz | convert_to_lossless_jxl | optimize_zip_ect
            # # todo Someday, will it be possible to further optimize JXL?
            # } else if $image_format != "jxl" {
              if $images_optimized {
                # Just optimize the ZIP compression in this case
                let hash = open --raw $formats.cbz | hash sha256
                if $hash not-in $optimized_file_hashes.sha256 {
                  log debug "Optimizing the CBZ archive's ZIP compression"
                  open --raw ($formats.cbz | optimize_zip_ect) | hash sha256
                }
              } else {
                let hash = open --raw $formats.cbz | hash sha256
                if $hash not-in $optimized_file_hashes.sha256 {
                  log debug "Optimizing the CBZ"
                  open --raw ($formats.cbz | optimize_zip) | hash sha256
                }
              }
            # }
          }
        ) | uniq | sort
      )
    }
  )
  if $updated_optimized_file_hashes != $optimized_file_hashes {
    $updated_optimized_file_hashes | save --force $optimized_files_cache_file
  }
  let optimized_file_hashes = $updated_optimized_file_hashes

  # Authors
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
  let target_directory = (
    [$destination]
    | append $series_subdirectory
    | path join
  )
  log debug $"Target directory: ($target_directory)"
  let target_destination = (
    let components = ($formats | get $output_format | path parse);
    {
      parent: $target_directory
      stem: (
        $components.stem | use_unicode_in_title | sanitize_file_name
      )
      extension: $components.extension
    } | path join
  )
  log debug $"Target destination: ($target_destination)"
  let comic_info_target_destination = (
    if $output_format == "pdf" {
      let components = ($formats | get $output_format | path parse);
      {
        parent: $target_directory
        stem: (($components.stem | use_unicode_in_title | sanitize_file_name) + "_ComicInfo")
        extension: "xml"
      } | path join
    }
  )
  let metron_info_target_destination = (
    if $output_format == "pdf" {
      let components = ($formats | get $output_format | path parse);
      {
        parent: $target_directory
        stem: (($components.stem | use_unicode_in_title | sanitize_file_name) + "_MetronInfo")
        extension: "xml"
      } | path join
    }
  )
  let cover_target_destination = (
    if $output_format == "pdf" and "cover" in $formats and ($formats.cover | is-not-empty) {
      let components = ($formats | get $output_format | path parse);
      {
        parent: $target_directory
        stem: (($components.stem | use_unicode_in_title | sanitize_file_name) + "_cover")
        extension: ($formats.cover | path parse | get extension)
      } | path join
    }
  )

  if ($destination | is_ssh_path) {
    log info $"Uploading (ansi yellow)($formats | get $output_format)(ansi reset) to (ansi yellow)($target_destination)(ansi reset)"
    if $use_rsync {
      $formats | get $output_format | rsync $target_destination "--mkpath"
    } else {
      $formats | get $output_format | scp $target_destination --mkdir
    }
    if $output_format == "pdf" {
    #   log info $"Uploading (ansi yellow)($formats.comic_info)(ansi reset) to (ansi yellow)($comic_info_target_destination)(ansi reset)"
    #   if $use_rsync {
    #     $formats.comic_info | rsync $comic_info_target_destination "--mkpath"
    #   } else {
    #     $formats.comic_info | scp $comic_info_target_destination --mkdir
    #   }
    #   log info $"Uploading (ansi yellow)($formats.metron_info)(ansi reset) to (ansi yellow)($metron_info_target_destination)(ansi reset)"
    #   if $use_rsync {
    #     $formats.metron_info | rsync $metron_info_target_destination "--mkpath"
    #   } else {
    #     $formats.metron_info | scp $metron_info_target_destination --mkdir
    #   }
    #   if ($cover_target_destination | is-not-empty) {
    #     log info $"Uploading (ansi yellow)($formats.cover)(ansi reset) to (ansi yellow)($cover_target_destination)(ansi reset)"
    #     if $use_rsync {
    #       $formats.cover | rsync $cover_target_destination "--mkpath"
    #     } else {
    #       $formats.cover | scp $cover_target_destination --mkdir
    #     }
    #   }
    }
  } else {
    mkdir $destination
    mv --force ($formats | get $output_format) $destination
    if $output_format == "pdf" {
      mv --force $formats.comic_info $destination
      mv --force $formats.metron_info $destination
      if "cover" in $formats and ($formats.cover | is-not-empty) {
        mv --force $formats.cover $destination
      }
    }
  }

  if not $keep {
    log debug "Deleting the original file"
    let uploaded_paths = (
      [$target_destination]
      | append $comic_info_target_destination
      | append $metron_info_target_destination
      | append $cover_target_destination
    )
    log debug $"Uploaded paths: ($uploaded_paths)"
    if ($original_file | is_ssh_path) {
      if not $skip_upload {
        for original in $original_comic_files {
          if $original not-in $uploaded_paths {
            log info $"Deleting the file (ansi yellow)($original)(ansi reset)"
            $original | ssh rm
          }
        }
      }
    } else {
      if ($destination | is-not-empty) {
        for original in $original_comic_files {
          let output = [$destination ($original | path basename)] | path join
          if $original != $output {
            log info $"Deleting the file (ansi yellow)($original)(ansi reset)"
            rm --force $original
          }
        }
      } else {
        for original in $original_comic_files {
          rm --force $original
        }
      }
    }
    # Delete the EPUB exported by Calibre.
    if ($formats | get $input_format | is_ssh_path) or ($formats | get $input_format) == $original_file {
      # No need to delete this file.
    } else {
      rm --force ($formats | get $input_format)
    }
  }
  log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
  rm --force --recursive $temporary_directory
  {
    file: $original_file
  }
  # } catch {|err|
  #   if not $keep_tmp {
  #     rm --force --recursive $temporary_directory
  #   }
  #   log error $"Import of (ansi red)($original_file)(ansi reset) failed!\n($err.msg)\n"
  #   {
  #     file: $original_file
  #     error: $err.msg
  #   }
  # }
  }

  $results | to json | print

  let errors = $results | default null error | where error != null
  if ($errors | is-not-empty) {
    log error $"(ansi red)Failed to import the following files due to errors!(ansi reset)"
    $errors | get file | $"(ansi red)($in)(ansi reset)" | print --stderr
    exit 1
  }
}
