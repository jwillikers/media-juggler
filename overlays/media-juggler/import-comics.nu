#!/usr/bin/env nu

# ~/Projects/media-juggler/packages/media-juggler/import-comics.nu --output-directory ~/Downloads ~/Downloads/ComicTagger-x86_64.AppImage ...(^mc find --name '*.cbz' "jwillikers/media/Books/Books/Ryoko Kui" | lines | par-each {|l| "minio:" + $l})

# todo Support / prefer CBT, especially using zstd compression?

# todo Place the Calibre library and database in the temporary directory

use std assert
use std log
use media-juggler-lib *

# $env.NU_LOG_LEVEL = "DEBUG"

# Publishers excluded from ComicTagger matches.
let excluded_publishers = [
  "Azbooka"
  "Carlsen Verlag"
  "Crunchyroll SA"
  "Crunchyroll SAS"
  "Daewon C.I."
  "Dargaud"
  "Darkwood"
  "Delcourt"
  "Editorial Ivrea"
  "Edizioni BD"
  "Edizioni Star Comics"
  "Egmont Ehapa Verlag "
  "Europe Comics"
  "Éditions Glénat "
  "Image"
  "Jademan"
  "Japonica Polonica Fantastica"
  "Ki-oon"
  "Kodansha"
  "Kurokawa"
  "Milky Way Ediciones"
  "M&C"
  "NBM"
  "Norma Editorial"
  "Pika Édition"
  "Planeta DeAgostini"
  "Scary Go Round"
  "Schibsted"
  "Shueisha"
  "Shogakukan"
  "Siam Inter"
  "Soleil"
  "Square Enix"
  "Tong Li Publishing Co."
  "Tokyopop GmbH"
]

# Tag CBZ file with ComicTagger using Comic Vine
export def tag_cbz [
  comictagger: path
  --comic-vine-issue-id: string # The Comic Vine issue id. Useful when nothing else works.
  # --excluded-publishers: list<string> # A list of publishers to exclude
  --interactive # Ask for input from the user
]: path -> record {
  let cbz = $in
  let args = (
    [] | append (
      if $comic_vine_issue_id != null {
        $"--id=($comic_vine_issue_id)"
      }
    )
  )
  let result = (
    if $interactive {
      (
        ^$comictagger
        --cv-use-series-start-as-volume
        --filename-parser "original"
        --interactive
        --no-cr
        --no-gui
        --online
        --parse-filename
        --publisher-filter ...$excluded_publishers
        --save
        --tags-write "CIX"
        --use-publisher-filter
        $cbz
      )
      (
        ^$comictagger
        --json
        --print
        --no-gui
        --tags-read "CIX"
        $cbz
      ) | from json
    } else {
      (
        ^$comictagger
        --cv-use-series-start-as-volume
        --filename-parser "original"
        --json
        --no-cr
        --no-gui
        --online
        --parse-filename
        --publisher-filter ...$excluded_publishers
        --save
        --tags-read "CR,CIX"
        --tags-write "CIX"
        --use-publisher-filter
        ...$args
        $cbz
      )
      | from json
    }
  )
  { cbz: $cbz, result: $result }
}

# Rename the comic according to the ComicInfo metadata
export def comictagger_rename_cbz [
  --comictagger: path # ComicTagger executable
]: path -> path {
  let cbz = $in
  log debug $"ComicTagger rename command: ^($comictagger) --no-cr --no-gui --rename --tags-read 'CIX' --template '{series} \({volume}\) #{issue} \({year}\)' ($cbz)";
  (
    do {
      (
        ^$comictagger
        --no-cr
        --no-gui
        --rename
        --tags-read "CIX"
        --template '{series} ({volume}) #{issue} ({year})'
        $cbz
      )
    }
    | complete
    | get stdout
    | lines --skip-empty
    | last
    | (
      let output = $in;
      log debug $"ComicTagger rename output: ($output)";
      if $output == "Filename is already good!" {
        $cbz
      } else {
        let new_name = (
          $output
          | parse --regex 'renamed \'(?P<original>.+\.cbz)\' -> \'(?P<renamed>.+\.cbz)\''
          | get renamed
          | first
          | (
            let filename = $in;
            ($cbz | path parse | get parent) | path join $filename
          )
        )
        log debug $"Renamed (ansi yellow)($cbz)(ansi reset) to (ansi yellow)($new_name)(ansi reset)"
        $new_name
      }
    )
  )
}

# Update ComicInfo metadata with ComicTagger
export def comictagger_update_metadata [
  metadata: string # Key and values to update in the metadata in a YAML-like syntax
  --comictagger: path # ComicTagger executable
]: path -> path {
  let cbz = $in
  (
    ^$comictagger
    --metadata $metadata
    --no-cr
    --no-gui
    --quiet
    --save
    --tags-read "CIX"
    --tags-write "CIX"
    $cbz
  )
  $cbz
}

# Import my comic or manga file to my collection.
#
# This script performs several steps to process the comic or manga file.
#
# 1. Decrypt the ACSM file.
# 2. Convert from EPUB to the CBZ format.
# 4. Fetch and add metadata in the ComicInfo.xml format.
# 5. Upload the file to object storage.
#
# Information that is not provided will be gleaned from the title of the EPUB file if possible.
#
# The final file is named according to Jellyfin's recommendation.
# The name will look like "<series> (<series-year>) #<issue> (<issue-year>).cbz".
#
def main [
  comictagger: path = "./ComicTagger-x86_64.AppImage" # Temporarily required until the Nix package is available
  ...files: string # The paths to ACSM, EPUB, and CBZ files to convert, tag, and upload. Supports SSH paths.
  --archive-pdf # Archive input PDF files under the --archival-path instead of uploading them to the primary bucket. This will cause a high quality CBZ file to be generated and uploaded to the primary storage server.
  --clear-comictagger-cache # Clear the ComicTagger cache to force it to pull in updated data
  --comic-vine-issue-id: string # The Comic Vine issue id. Useful when nothing else works, but not recommended as it doesn't seem to verify the cover image.
  --ereader: string # Create a copy of the comic book optimized for this specific e-reader, i.e. "Kobo Elipsa 2E"
  --ereader-subdirectory: string = "Books/Manga" # The subdirectory on the e-reader in-which to copy
  # --ignore-epub-title # Don't use the EPUB title for the Comic Vine lookup
  --isbn: string
  --jxl # Convert lossless PNG images to JXL
  --interactive # Ask for input from the user
  --keep # Don't delete or modify the original input files
  --keep-tmp # Don't delete the temporary directory when there's an error
  --keep-acsm # Keep the ACSM file after conversion. These stop working for me before long, so no point keeping them around.
  # --issue: string # The issue number
  --issue-year: string # The publication year of the issue
  --manga: string = "YesAndRightToLeft" # Whether the file is manga "Yes", right-to-left manga "YesAndRightToLeft", or not manga "No". Refer to https://anansi-project.github.io/docs/comicinfo/documentation#manga
  --archival-path: string = "meerkat:/var/media/archive/books/" # The archival path where files will be archived. The file will be uploaded under a subdirectory named after the author and series.
  --no-copy-to-ereader # Don't copy the E-Reader specific format to a mounted e-reader
  --destination: directory = "meerkat:/var/media/books" # The directory under which to copy files.
  # --series: string # The name of the series
  # --series-year: string # The initial publication year of the series, also referred to as the volume
  --skip-ocr # Don't attempt to parse the ISBN from images using OCR
  --skip-optimization # Don't attempt to perform expensive optimizations. This only skips PDF optimization at the moment, as it is the most expensive optimization.
  --skip-upload # Don't upload files to the server
  --title: string # The title of the comic or manga issue
  --upload-ereader-cbz # Upload the E-Reader specific format to the server
  --use-rsync
  --bookbrainz-edition-id: string # The BookBrainz Edition ID (only embedded in the metadata right now)
  --hardcover-edition-id: string # The Hardcover Edition ID (only embedded in the metadata right now)
  --hardcover-book-slug: string # The Hardcover Book Slug (only embedded in the metadata right now)
  --wikidata-work-id: string # The Hardcover Edition ID (only embedded in the metadata right now)
  --wikidata-edition-id: string # The Hardcover Edition ID (only embedded in the metadata right now)
  --imprint: string # Set the publisher/imprint. This is embedded in the ComicInfo.xml file and used for the publisher in EPUB and PDF metadata.
  --publisher: string # Set the publisher in the metadata. Note that the imprint is preferred over this for EPUB and PDF metadata.
] {
  if ($files | is-empty) {
    log error "No files provided"
    exit 1
  }

  if $comic_vine_issue_id != null and ($files | length) > 1 {
    log error "Setting the comic vine issue id for multiple files is not allowed as it will result in overwriting the final file"
    exit 1
  }

  if $isbn != null and ($files | length) > 1 {
    log error "Setting the ISBN for multiple files is not allowed as it will result in overwriting the final file"
    exit 1
  }

  if $bookbrainz_edition_id != null and ($files | length) > 1 {
    log error "Setting the BookBrainz Edition ID for multiple files is not allowed as it will result in overwriting the final file"
    exit 1
  }

  if $hardcover_edition_id != null and ($files | length) > 1 {
    log error "Setting the Hardcover Edition ID for multiple files is not allowed as it will result in overwriting the final file"
    exit 1
  }

  if $wikidata_edition_id != null and ($files | length) > 1 {
    log error "Setting the Wikidata Edition ID for multiple files is not allowed as it will result in overwriting the final file"
    exit 1
  }

  if $wikidata_work_id != null and ($files | length) > 1 {
    log error "Setting the Wikidata Work ID for multiple files is not allowed as it will result in overwriting the final file"
    exit 1
  }

  if $hardcover_book_slug != null and ($files | length) > 1 {
    log error "Setting the Hardcover Book Slug for multiple files is not allowed as it will result in overwriting the final file"
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

  if $clear_comictagger_cache {
    log debug "Clearing the ComicTagger cache"
    rm --force --recursive ([($nu.cache-dir | path dirname) "ComicTagger"] | path join)
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
    let comic_info_file = ($original_file | split_ssh_path | get path | path dirname | path join "ComicInfo.xml");
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

  if $original_comic_info != null {
    log debug $"Found Comic Info file (ansi yellow)($original_comic_info)(ansi reset)"
  }

  let comic_info = (
    if $original_comic_info != null {
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

  let original_opf = (
    let opf_file = ($original_file | split_ssh_path | get path | path dirname | path join "metadata.opf");
    if ($original_file | is_ssh_path) {
      if ($opf_file | ssh_path_exists).exit_code == 0 {
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
      let opf_file = ($original_file | split_ssh_path | get path | path dirname | path join "ComicInfo.xml")
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
        $"($file | path dirname | escape_special_glob_characters)/cover.*"
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

  let original_comic_files = [($original_file | split_ssh_path | get path)] | append $original_comic_info | append $original_cover | append $original_opf
  log debug $"The original files for the comic are (ansi yellow)($original_comic_files)(ansi reset)"

  let output_format = (
    if $original_input_format == "pdf" and not $archive_pdf {
      "pdf"
    } else {
      "cbz"
    }
  )

  let formats = (
    if $original_input_format == "acsm" {
      log debug "Decrypting and converting the ACSM file to the EPUB"
      { epub: ($file | acsm_to_epub (pwd)) }
    } else if $original_input_format == "epub" {
      { epub: $file }
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
    } else {
      $original_input_format
    }
  )

  # Generate a CBZ from the PDF format which may be used to extract the ISBN.
  let formats = (
    if "pdf" in $formats {
      log debug "Generating a CBZ from the PDF"
      $formats | insert cbz ($formats.pdf | cbconvert --format "jpeg" --quality 90)
    } else {
      $formats
    }
  )

  log debug "Attempting to get the ISBN from existing metadata"
  let metadata_isbn = (
    $file | get_metadata $temporary_directory | isbn_from_metadata
  )
  if $metadata_isbn != null {
    log debug $"Found the ISBN (ansi purple)($metadata_isbn)(ansi reset) in the book's metadata"
  }

  log debug "Attempting to get the ISBN from the first ten and last ten pages of the book"
  let book_isbn_numbers = (
    let isbn_numbers = $file | isbn_from_pages $temporary_directory;
    if not $skip_ocr and ($isbn_numbers | is-empty) {
      log debug "ISBN not detected in text. Attempting to ISBN from images using OCR."
      # Check images for the ISBN if text doesn't work out.
      if "cbz" in $formats {
        let isbn_from_cbz = $formats.cbz | isbn_from_pages $temporary_directory
        if ($isbn_from_cbz | is-not-empty) {
          $isbn_from_cbz
        }
      } else if "epub" in $formats {
        let isbn_from_epub = $formats.epub | isbn_from_pages $temporary_directory
        if ($isbn_from_epub | is-not-empty) {
          $isbn_from_epub
        }
      }
    } else {
      $isbn_numbers
    }
  )
  if $book_isbn_numbers != null and ($book_isbn_numbers | is-not-empty) {
    log debug $"Found ISBN numbers in the book's pages: (ansi purple)($book_isbn_numbers)(ansi reset)"
  }

  # Determine the most likely ISBN from the metadata and pages
  let likely_isbn_from_pages_and_metadata = (
    if $metadata_isbn != null and $book_isbn_numbers != null {
      if ($book_isbn_numbers | is-empty) {
        log debug $"No ISBN numbers found in the pages of the book. Using the ISBN from the book's metadata (ansi purple)($metadata_isbn)(ansi reset)"
        $metadata_isbn
      } else if $metadata_isbn in $book_isbn_numbers {
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
        $metadata_isbn
      } else {
        # todo If only one number is available in the pages, should it be preferred?
        log warning $"The ISBN from the book's metadata, (ansi purple)($metadata_isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
        if ($book_isbn_numbers | length) == 1 {
          log warning $"The ISBN from the book's metadata, (ansi purple)($metadata_isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
          $book_isbn_numbers | first
        } else {
          if $isbn == null {
            if not $keep_tmp {
              rm --force --recursive $temporary_directory
            }
            return {
              file: $original_file
              error: $"The ISBN from the book's metadata, (ansi purple)($metadata_isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset). Use the `--isbn` flag to set the ISBN instead."
            }
          } else {
            log warning $"The ISBN from the book's metadata, (ansi purple)($metadata_isbn)(ansi reset) not among the ISBN numbers found in the books pages: (ansi purple)($book_isbn_numbers)(ansi reset)."
          }
        }
      }
    } else if $metadata_isbn != null {
      log debug $"No ISBN numbers found in the pages of the book. Using the ISBN from the book's metadata (ansi purple)($metadata_isbn)(ansi reset)"
      $metadata_isbn
    } else if $book_isbn_numbers != null and ($book_isbn_numbers | is-not-empty) {
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
    if $isbn == null {
      if $likely_isbn_from_pages_and_metadata == null {
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
  if $isbn != null {
    log debug $"The ISBN is (ansi purple)($isbn)(ansi reset)"
  }

  # todo Should existing metadata be merged with the fetched metadata?
  # Right now, existing metadata is completely ignored except for the Comic Info already embedded in a CBZ because ComicTagger will read that.

  # Fetch ebook metadata using the ISBN
  let formats = (
    if $isbn != null {
      log debug $"Fetching book metadata for the ISBN (ansi purple)($isbn)(ansi reset)";
      $formats | update $input_format (
        $formats
        | get $input_format
        | fetch_book_metadata --isbn $isbn $temporary_directory
        | export_book_to_directory ($formats | get $input_format | path dirname)
        | embed_book_metadata
        | get book
      )
    } else {
      $formats
    }
  )
  log debug $"import-comics: formats: ($formats)"

  # Rename input file according to metadata
  let formats = (
    $formats
    | update $input_format (
      if $comic_vine_issue_id == null {
        let target = $formats | get $input_format | comic_file_name_from_metadata $temporary_directory --issue-year $issue_year
        if ($formats | get $input_format) != $target {
          log debug $"import-comics: Renaming (ansi yellow)($formats | get $input_format)(ansi reset) to (ansi yellow)($target)(ansi reset)"
          mv --force ($formats | get $input_format) $target
        }
        $target
      } else {
        $formats | get $input_format
      }
    )
  )
  let formats = (
    if $input_format == "pdf" and "cbz" in $formats {
      let target = $formats | get $input_format | path parse | update extension cbz | path join
      log debug $"import-comics: target: ($target)";
      if $formats.cbz != $target {
        # Rename the CBZ according to the name of the PDF
        log debug $"import-comics: Renaming (ansi yellow)($formats.cbz)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        mv --force $formats.cbz $target
        $formats | update cbz $target
      } else {
        $formats
      }
    } else {
      $formats
    }
  )
  log debug $"import-comics: formats: ($formats)"

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
  )
  if $updated_optimized_file_hashes != $optimized_file_hashes {
    $updated_optimized_file_hashes | save --force $optimized_files_cache_file
  }
  let optimized_file_hashes = $updated_optimized_file_hashes
  let images_optimized = "epub" in $formats

  # Generate a CBZ from the EPUB and PDF formats
  let formats = (
    if "epub" in $formats {
      log debug "Generating a CBZ from the EPUB"
      $formats | insert cbz ($formats.epub | epub_to_cbz --working-directory $temporary_directory)
    } else if "pdf" in $formats {
      log debug "Updating the CBZ for the PDF"
      let cbz = (
        $formats.cbz
        | (
        let archive = $in;
        if $comic_info != null {
          {
            archive: $archive,
            comic_info: (open $comic_info),
          }
          | inject_comic_info
          } else {
            $archive
          }
        )
      )
      if $comic_info != null {
        log debug $"Removing the sidecar ComicInfo file (ansi yellow)($comic_info)(ansi reset)"
        rm $comic_info
      }
      $formats | update cbz $cbz
    } else {
      $formats
    }
  )

  log debug $"Fetching and writing metadata to (ansi yellow)($formats.cbz)(ansi reset) with ComicTagger"
  let tag_result = (
    $formats.cbz | tag_cbz $comictagger --comic-vine-issue-id $comic_vine_issue_id
  )
  log debug $"The ComicTagger result is:\n(ansi green)($tag_result.result | to nuon)(ansi reset)\n"

  if ($tag_result.result.status == "match_failure") {
    # todo Add stderr from ComicTagger here
    # todo Use make error?
    log error $"Failed to tag ($original_file)"
    if not $keep_tmp {
      rm --force --recursive $temporary_directory
    }
    return {
      file: $original_file
      # todo Add stderr from ComicTagger here
      error: "ComicTagger failed to match the comic!"
    }
  }

  log debug "Renaming the CBZ according to the updated metadata from ComicTagger"
  let formats = $formats | (
    let format = $in;
    $format | update cbz ($format.cbz | comictagger_rename_cbz --comictagger $comictagger)
  )
  log debug "Renamed the CBZ according to the updated metadata from ComicTagger"

  let comic_metadata = ($tag_result.result | get md)

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
  let title = (
    if $title == null {
      $comic_metadata
      | (
        let metadata = $in;
        # todo Handle issue_title?
        # If the volume is most likely just a single issue, just use the series as the name
        if $metadata.issue_count == 1 and (((date now) - ($metadata.volume | into string | into datetime)) | format duration yr) > 2yr {
          if $metadata.title == null or $metadata.title == $metadata.series {
            $metadata.series
          } else {
            if ($metadata.title | str starts-with $"($metadata.series): ") {
              $metadata.title
            } else {
              $"($metadata.series): ($metadata.title)"
            }
          }
        } else {
          let sanitized_title = (
            if $metadata.title == null {
              null
            } else {
              # todo Use a regex here so that this ignores incorrect series and issue information?
              if ($metadata.title | str starts-with $"($metadata.series), Vol. ($metadata.issue): ") {
                $metadata.title | str replace $"($metadata.series), Vol. ($metadata.issue): " ""
              } else if ($metadata.title | str starts-with $"($metadata.series), Vol. ($metadata.issue)") {
                $"Volume ($metadata.issue)"
              } else {
                $metadata.title
              }
            }
          )
          if $sanitized_title == null or $sanitized_title =~ 'Volume [0-9]+' or $sanitized_title =~ 'Vol. [0-9]+' {
            $"($metadata.series), Vol. ($metadata.issue)"
          } else {
            $"($metadata.series), Vol. ($metadata.issue): ($sanitized_title)"
          }
        }
      )
    } else {
      $title
    }
  )
  let title = (
    let imprint = (
      let imprint = (
        if ($imprint | is-not-empty) {
          $imprint
        } else {
          if ("imprint" in $comic_metadata) {
            $comic_metadata.imprint
          }
        }
      );
      if ($imprint | is-not-empty) {
        $imprint | str downcase
      }
    );
    let publisher = (
      let publisher = (
        if ($publisher | is-not-empty) {
          $publisher
        } else {
          if ("publisher" in $comic_metadata) {
            $comic_metadata.publisher
          }
        }
      );
      if ($publisher | is-not-empty) {
        $publisher | str downcase
      }
    );
    # Kodansha names everything using the Volume word on its website.
    if "kodansha" in [$imprint $publisher] {
      $title | str replace ", Vol. " ", Volume "
    } else {
      $title
    }
  )
  let title = $title | use_unicode_in_title

  let previous_title = ($comic_metadata | get title)
  log info $"Rewriting the title from (ansi yellow)'($previous_title)'(ansi reset) to (ansi yellow)'($title)'(ansi reset)"
  # let sanitized_title = $title | str replace --all '"' '\"'
  # todo Read from YAML file to ensure proper string escaping of single / double quotes?
  # let metadata_yaml = $"manga: \"($manga)\", title: \"($sanitized_title)\""
  # let metadata_yaml = (
  #   if $isbn != null {
  #     $metadata_yaml
  #   } else {
  #     $metadata_yaml + $", GTIN: \"($isbn)\""
  #   }
  # )
  # $formats.cbz | comictagger_update_metadata $metadata_yaml --comictagger $comictagger

  # Attempt to get book metadata in order to obtain the ISBN
  # todo Interactively confirm this ISBN to ensure there are no hiccups, like a different issue from the same series
  let $isbn = (
    if $isbn == null {
      log debug "Attempting to get the ISBN from the fetched metadata"
      log debug $"Fetching book metadata using title (ansi yellow)($title)(ansi reset) and authors (ansi yellow)($authors)(ansi reset)"
      # Kobo Metadata is not working well for getting the right issue number.
      let fetched = (
        fetch-ebook-metadata --allowed-plugins ["Google"] --authors $authors --title $title | get opf
      )
      if ($fetched | is-not-empty) {
        let fetched_isbn_for_google = $fetched | isbn_from_opf
        log debug $"Fetched ISBN: (ansi purple)($fetched_isbn_for_google)(ansi reset)"
        let fetched_title_for_google = $fetched | title_from_opf
        log debug $"Fetched title from Google: (ansi purple)($fetched_title_for_google)(ansi reset)"

        # Use the ISBN from Google ISBN to look it up
        let fetched = fetch-ebook-metadata --isbn $fetched_isbn_for_google | get opf
        if ($fetched | is-not-empty) {
          let fetched_isbn = $fetched | isbn_from_opf
          log debug $"Fetched ISBN: (ansi purple)($fetched_isbn)(ansi reset)"
          let fetched_title = $fetched | title_from_opf
          log debug $"Fetched title: (ansi purple)($fetched_title)(ansi reset)"
          let fetched_series = $fetched | series_from_opf
          log debug $"Fetched series: (ansi purple)($fetched_series)(ansi reset)"
          let fetched_issue = $fetched | issue_from_opf
          log debug $"Fetched issue: (ansi purple)($fetched_issue)(ansi reset)"

          if $fetched_isbn != null and $fetched_isbn == $fetched_isbn_for_google and $fetched_series == $comic_metadata.series and $fetched_issue == $comic_metadata.issue {
            log debug $"Found the ISBN (ansi purple)($fetched_isbn)(ansi reset) from the fetched metadata"
            $fetched_isbn
          } else if $fetched_isbn_for_google != null and $fetched_title_for_google == $title {
            log debug $"Found the ISBN (ansi purple)($fetched_isbn_for_google)(ansi reset) from the fetched metadata"
            $fetched_isbn_for_google
          }
        }
      }
    } else {
      $isbn
    }
  )

  # Obtain metadata using Calibre
  let comic_vine_id = (if $comic_vine_issue_id == null { $comic_metadata.issue_id } else { $comic_vine_issue_id });
  let fetched_from_calibre = (
    if $input_format in ["epub" "pdf"] {
      $formats | get $input_format | (
        fetch_book_metadata
        # Use Comic Vine to ensure series information is correct.
        --allowed-plugins ["Comicvine"]
        # todo Get the EPUB metadata from sources besides Comic Vine as well?
        # I think it probably isn't necessary at this point.
        # This still doesn't actually use Comic Vine, but it does still en up working.
        # --allowed-plugins ["Comicvine" "Kobo Metadata" Goodreads Google "Google Images" "Amazon.com" Edelweiss "Open Library" "Big Book Search"]
        --authors $authors
        --identifiers [$"comicvine:($comic_vine_id)" $"comicvine-volume:($comic_metadata.series_id)"]
        --isbn $isbn
        --title $title
        $temporary_directory
      )
    }
  )

  # todo?
  # Get the authors from Calibre if they are missing in the Comic Vine metadata.
  # let authors = (
  #   if ($authors | is-empty) {
  #     $fetched_from_calibre.opf
  #     | get content
  #     | where tag == "metadata"
  #     | first
  #     | get content
  #     | where tag == "creator"
  #     | where attributes.role == "aut"
  #     | par-each {|creator| $creator | get content | first | get content }
  #     | sort
  #   } else {
  #     $authors
  #   }
  # )

  # Add the ISBN to the ComicInfo
  log info "Updating the ComicInfo"
  (
    $formats.cbz
    | extract_comic_info_xml $temporary_directory
    # todo Determine BlackAndWhite automatically.
    # | upsert_comic_info {BlackAndWhite: $}
    | (
      let info = $in;
      if $isbn == null {
        $info
      } else {
        $info | upsert_comic_info {tag: "GTIN", value: $isbn}
      }
    )
    | upsert_comic_info {tag: "Manga", value: $manga}
    | upsert_comic_info {tag: "Title", value: $title}
    | upsert_comic_info {tag: "Format", value: "Digital"}
    | (
      let input = $in;
      if "language" in $comic_metadata and ($comic_metadata.language | is-not-empty) {
        if ($comic_metadata.language | str downcase) in ["eng" "english"] {
          $input | upsert_comic_info {tag: "LanguageISO", value: "en"}
        } else {
          $input | upsert_comic_info {tag: "LanguageISO", value: $comic_metadata.language}
        }
      } else {
        $input | upsert_comic_info {tag: "LanguageISO", value: "en"}
      }
    )
    | (
      let input = $in;
      if ($imprint | is-not-empty) {
        $input | upsert_comic_info {tag: "Imprint", value: $imprint}
      } else {
        $input
      }
    )
    | (
      let input = $in;
      if ($publisher | is-not-empty) {
        $input | upsert_comic_info {tag: "Publisher", value: $publisher}
      } else {
        $input
      }
    )
    | (
      let input = $in;
      let bookbrainz_url = (
        if ($bookbrainz_edition_id | is-not-empty) {
          $"https://bookbrainz.org/edition/($bookbrainz_edition_id)"
        } else {
          ""
        }
      );
      let comic_vine_url = (
        if ($comic_vine_id | is-not-empty) {
          $"https://comicvine.gamespot.com/issue/4000-($comic_vine_id)"
        } else {
          ""
        }
      );
      let hardcover_url = (
        # todo Since the book slug URL can change, figure out how to use this with just the edition id?
        if ($hardcover_edition_id | is-not-empty) and ($hardcover_book_slug | is-not-empty) {
          $"https://hardcover.app/books/($hardcover_book_slug)/editions/($hardcover_edition_id)"
        } else {
          ""
        }
      );
      let wikidata_url = (
        # To avoid ambiguity, only include one wikidata link, preferring the edition id if possible.
        if ($wikidata_edition_id | is-not-empty) {
          $"https://www.wikidata.org/wiki/($wikidata_edition_id)"
        } else if ($wikidata_work_id | is-not-empty) {
          $"https://www.wikidata.org/wiki/($wikidata_work_id)"
        } else {
          ""
        }
      );
      let urls = $"($bookbrainz_url) ($comic_vine_url) ($hardcover_url) ($wikidata_url)" | str trim | str replace --all --regex '\w{2,}' ' ';
      if ($urls | is-empty) {
        $input
      } else {
        $input | upsert_comic_info {
          tag: "Web",
          value: $urls,
        }
      }
    )
    # todo Incorporate Comic Vine issue id and series id in Notes section of ComicInfo.xml or sidecar metadata.opf
    # This will allow easily updating the metadata in the future without having to redo all the lookup work.
    | {
      archive: $formats.cbz
      comic_info: $in
    }
    | inject_comic_info
  )

  # PDFs must be optimized before embedding metadata, as the embedded metadata will be scrubbed.
  let updated_optimized_file_hashes = (
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
  )
  if $updated_optimized_file_hashes != $optimized_file_hashes {
    $updated_optimized_file_hashes | save --force $optimized_files_cache_file
  }
  let optimized_file_hashes = $updated_optimized_file_hashes

  let formats = (
    # Update the metadata in the EPUB and rename it to match the filename of the CBZ
    if "epub" in $formats {
      # Update the metadata in the EPUB file.
      let epub = (
        $fetched_from_calibre
        | export_book_to_directory ($formats | get "epub" | path dirname)
        | embed_book_metadata
        | (
          let input = $in;
          (
            let args = (
              []
              | append (
                if $isbn != null {
                  $"--isbn=($isbn)"
                }
              )
              | append (
                if "series" in $comic_metadata and ($comic_metadata.series | is-not-empty) and "issue_count" in $comic_metadata and ($comic_metadata.issue_count | is-not-empty) and $comic_metadata.issue_count > 1 {
                  [$"--series=($comic_metadata.series)" $"--index=($comic_metadata.issue)"]
                }
              )
              | append (
                if ($imprint | is-not-empty) {
                  $"--publisher=($imprint)"
                } else if ($publisher | is-not-empty) {
                  $"--publisher=($publisher)"
                } else if "imprint" in $comic_metadata and ($comic_metadata.imprint | is-not-empty) {
                  $"--publisher=($comic_metadata.imprint)"
                } else if "publisher" in $comic_metadata and ($comic_metadata.publisher | is-not-empty) {
                  $"--publisher=($comic_metadata.publisher)"
                }
              )
              | append (
                if "language" in $comic_metadata and ($comic_metadata.language | is-not-empty) {
                  if ($comic_metadata.language | str downcase) in ["eng" "english"] {
                    "--language=en"
                  } else {
                    $"--language=($comic_metadata.language)"
                  }
                } else {
                  "--language=en"
                }
              )
              | append (
                if "description" in $comic_metadata and ($comic_metadata.description | is-not-empty) {
                  $"--comments=($comic_metadata.description)"
                }
              )
              | append (
                if "genres" in $comic_metadata and ($comic_metadata.genres | is-not-empty) {
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
                  if "year" in $comic_metadata and ($comic_metadata.year | is-not-empty) {
                    $comic_metadata.year
                  }
                );
                let month = (
                  if "month" in $comic_metadata and ($comic_metadata.month | is-not-empty) {
                    $comic_metadata.month
                  }
                );
                let day = (
                  if "day" in $comic_metadata and ($comic_metadata.day | is-not-empty) {
                    $comic_metadata.day
                  }
                );
                if ($year | is-not-empty) and ($month | is-not-empty) and ($year | is-not-empty) {
                  $"--date=($year)-($month)-($day)"
                } else if ($year | is-not-empty) {
                  $"--date=($year)"
                }
              )
            );
            ^ebook-meta
              $input.book
              ...$args
              --authors ($authors | str join "&")
              --title $title
              --identifier $"comicvine:($comic_vine_id)"
              --identifier $"comicvine-volume:($comic_metadata.series_id)"
          );
          $input
        )
        | get book
      )
      let stem = ($formats.cbz | path parse | get stem)
      let renamed_epub = ({ parent: ($epub | path parse | get parent), stem: $stem, extension: "epub" } | path join)
      if $epub != $renamed_epub {
        mv --force $epub $renamed_epub
      }
      $formats | update epub $renamed_epub
    # Rename the PDF
    } else if "pdf" in $formats {
      let stem = ($formats.cbz | path parse | get stem)
      let renamed_pdf = ({ parent: ($formats.pdf | path parse | get parent), stem: $stem, extension: "pdf" } | path join)
      if $formats.pdf != $renamed_pdf {
        log debug $"Renaming the PDF from ($formats.pdf) to ($renamed_pdf)";
        mv --force $formats.pdf $renamed_pdf
      }
      # Update the metadata in the PDF file.
      let updated_pdf = (
        $fetched_from_calibre
        | update book ($renamed_pdf)
        | export_book_to_directory ($renamed_pdf | path dirname)
        | embed_book_metadata
        | (
          let input = $in;
          (
            let args = (
              []
              | append (
                if $isbn != null {
                  $"--isbn=($isbn)"
                }
              )
              | append (
                if "series" in $comic_metadata and ($comic_metadata.series | is-not-empty) and "issue_count" in $comic_metadata and ($comic_metadata.issue_count | is-not-empty) and $comic_metadata.issue_count > 1 {
                  [$"--series=($comic_metadata.series)" $"--index=($comic_metadata.issue)"]
                }
              )
              | append (
                if ($imprint | is-not-empty) {
                  $"--publisher=($imprint)"
                } else if ($publisher | is-not-empty) {
                  $"--publisher=($publisher)"
                } else if "imprint" in $comic_metadata and ($comic_metadata.imprint | is-not-empty) {
                  $"--publisher=($comic_metadata.imprint)"
                } else if "publisher" in $comic_metadata and ($comic_metadata.publisher | is-not-empty) {
                  $"--publisher=($comic_metadata.publisher)"
                }
              )
              | append (
                if "language" in $comic_metadata and ($comic_metadata.language | is-not-empty) {
                  if ($comic_metadata.language | str downcase) in ["eng" "english"] {
                    "--language=en"
                  } else {
                    $"--language=($comic_metadata.language)"
                  }
                } else {
                  "--language=en"
                }
              )
              | append (
                if "description" in $comic_metadata and ($comic_metadata.description | is-not-empty) {
                  $"--comments=($comic_metadata.description)"
                }
              )
              | append (
                if "genres" in $comic_metadata and ($comic_metadata.genres | is-not-empty) {
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
                  if "year" in $comic_metadata and ($comic_metadata.year | is-not-empty) {
                    $comic_metadata.year
                  }
                );
                let month = (
                  if "month" in $comic_metadata and ($comic_metadata.month | is-not-empty) {
                    $comic_metadata.month
                  }
                );
                let day = (
                  if "day" in $comic_metadata and ($comic_metadata.day | is-not-empty) {
                    $comic_metadata.day
                  }
                );
                if ($year | is-not-empty) and ($month | is-not-empty) and ($year | is-not-empty) {
                  $"--date=($year)-($month)-($day)"
                } else if ($year | is-not-empty) {
                  $"--date=($year)"
                }
              )
            );
            ^ebook-meta
              $input.book
              ...$args
              --authors ($authors | str join "&")
              --title $title
              --identifier $"comicvine:($comic_vine_id)"
              --identifier $"comicvine-volume:($comic_metadata.series_id)"
          );
          $input
        )
        | get book
      )
      # For some reason the PDF ends up with a different name when updating the metadata.
      # todo Fix that.
      if $updated_pdf != $renamed_pdf {
        log debug $"Renaming the PDF from ($updated_pdf) to ($renamed_pdf)";
        mv --force $updated_pdf $renamed_pdf
      }
      let comic_info = $formats.cbz | extract_comic_info $temporary_directory;
      log debug "Extracted ComicInfo.xml";
      log debug $"Cover image: ($comic_metadata._cover_image | to nuon)";
      let cover_url = $comic_metadata._cover_image | last;
      let cover = (
        let cover = (
          {
            parent: $temporary_directory
            stem: "cover"
            extension: ($cover_url | path parse | get extension)
          } | path join
        );
        try {
          http get --headers [User-Agent $user_agent] --raw $cover_url | save --force $cover;
          log debug $"Downloaded cover (ansi yellow)($cover)(ansi reset)";
          $cover
        } catch {|error|
          log error $"Failed to downloaded cover from (ansi yellow)($cover_url)(ansi reset): ($error)";
          # Attempt to extract the existing cover from the PDF
          let cover = (
            {
              parent: $temporary_directory
              stem: "cover"
            } | path join
          );
          let result = (^ebook-meta --get-cover $cover $renamed_pdf | complete)
          if $result.exit_code == 0 {
            $cover | rename_image_with_extension
          } else {
            null
          }
        }
      );
      if ($cover | is-not-empty) {
        $cover | optimize_image;
      }
      $formats
      | update pdf $renamed_pdf
      | insert comic_info $comic_info
      | upsert_if_value cover $cover
      | (
        let input = $in;
        log debug "Updating PDF in table";
        log debug $"Input:\n($input)\n";
        # todo untested
        if $archive_pdf {
          log debug "Creating JPEG-XL CBZ from PDF";
          $input
          | update cbz (
            $formats.pdf
            | convert_to_lossless_jxl
            | (
              let cbz = $in;
              {
                archive: $cbz
                comic_info: (open $formats.comic_info)
              }
            ) | inject_comic_info
          )
        } else {
          log debug "Dropping cbz from formats since the input format is a PDF";
          $input | reject cbz
        }
      )
    } else {
      $formats
    }
  )
  log debug "Finished renaming files";

  let updated_optimized_file_hashes = (
    $optimized_file_hashes | update sha256 (
      $optimized_file_hashes.sha256 | append (
        if "epub" in $formats {
          # At this point, the images in the EPUB should be optimized.
          # Just optimize the compression.
          # Since we already cached the hash of this file, if nothing else has changed, we'll accidentally skip this part.
          # So, ignore any existing hash for the epub and optimize it anyway.
          # todo I could use a separate cache for that for just images optimized and use the normal cache here.
          # todo I might need to fix this to work with larger files
          # todo Expire the cache?
          # let hash = open --raw $formats.epub | hash sha256
          # if $hash not-in $optimized_file_hashes.sha256 {
            log debug "Optimizing the EPUB ZIP compression"
            open --raw ($formats.epub | optimize_zip_ect) | hash sha256
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
          if $image_format == null {
            if not $keep_tmp {
              rm --force --recursive $temporary_directory
            }
            return {
              file: $original_file
              error: "Failed to determine the image file format"
            }
          }

          # todo Detect if another lossless format, i.e. webp, is being used and if so, convert those to jxl as well.
          if $image_format in ["png"] and $jxl {
            $formats.cbz | convert_to_lossless_jxl | optimize_zip_ect
          # todo Someday, will it be possible to further optimize JXL?
          } else if $image_format != "jxl" {
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
          }
        }
      ) | uniq | sort
    )
  )
  if $updated_optimized_file_hashes != $optimized_file_hashes {
    $updated_optimized_file_hashes | save --force $optimized_files_cache_file
  }
  let optimized_file_hashes = $updated_optimized_file_hashes

  # Not sure if "webp" would really be any better than jpeg here or not...
  # I'm assuming it might at least be a little bit smaller given cbconvert doesn't appear to use mozjpeg.
  # Use PNG for lossless codecs and webp for lossy.
  # CBconvert appears to always use lossy webp encoding.
  let formats = (
    if $ereader == null {
      $formats
    } else {
      $formats
      | insert ereader_cbz (
        $formats
        | get $input_format
        | convert_for_ereader $ereader $temporary_directory
      )
    }
  )

  # todo Functions archive_epub, upload_cbz, and perhaps copy_cbz_to_ereader

  let authors_subdirectory = $authors | str join ", " | use_unicode_in_title | sanitize_file_name
  # todo How to handle multiple series?
  let series_subdirectory = (
    # Don't use a series subdirectory if the series is only one issue long.
    # This may change if more issues are published in the future, fyi.
    if "series" in $comic_metadata and ($comic_metadata.series | is-not-empty) and "issue_count" in $comic_metadata and ($comic_metadata.issue_count | is-not-empty) and $comic_metadata.issue_count > 1 {
      $comic_metadata.series | use_unicode_in_title | sanitize_file_name
    }
  )
  let target_directory = (
    [$destination $authors_subdirectory]
    | append $series_subdirectory
    | path join
  )
  log debug $"Target directory: ($target_directory)"
  let target_destination = (
    let components = ($formats | get $output_format | path parse);
    {
      parent: $target_directory
      stem: ($components.stem | use_unicode_in_title | sanitize_file_name)
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
      log info $"Uploading (ansi yellow)($formats.comic_info)(ansi reset) to (ansi yellow)($comic_info_target_destination)(ansi reset)"
      if $use_rsync {
        $formats.comic_info | rsync $comic_info_target_destination "--mkpath"
      } else {
        $formats.comic_info | scp $comic_info_target_destination --mkdir
      }
      if ($cover_target_destination | is-not-empty) {
        log info $"Uploading (ansi yellow)($formats.cover)(ansi reset) to (ansi yellow)($cover_target_destination)(ansi reset)"
        if $use_rsync {
          $formats.cover | rsync $cover_target_destination "--mkpath"
        } else {
          $formats.cover | scp $cover_target_destination --mkdir
        }
      }
    }
  } else {
    mkdir $destination
    mv --force ($formats | get $output_format) $destination
    if $output_format == "pdf" {
      mv --force $formats.comic_info $destination
      if "cover" in $formats and ($formats.cover | is-not-empty) {
        mv --force $formats.cover $destination
      }
    }
  }

  # Keep the EPUB for archival purposes.
  # I have Calibre reduce the size of images in a so-called "lossless" manner.
  # If anything about that isn't actually lossless, that's not good...
  # Guess I'm willing to take that risk right now.
  let archival_target_directory = (
    [$archival_path $authors_subdirectory]
    | append $series_subdirectory
    | append (
      if $input_format == "pdf" and $archive_pdf {
        $formats.pdf | path parse | get stem
      } else {
        null
      }
    )
    | path join
  )
  let epub_archival_destination = (
    if "epub" in $formats {
      let components = ($formats.epub | path parse);
      {
        parent: $archival_target_directory
        stem: $components.stem
        extension: $components.extension
      } | path join
    }
  )
  let pdf_archival_destination = (
    if "pdf" in $formats and $archive_pdf {
      let components = ($formats.pdf | path parse);
      {
        parent: $archival_target_directory
        stem: $components.stem
        extension: $components.extension
      }
      | path join
    }
  )
  let comic_info_archival_destination = (
    if "pdf" in $formats and $archive_pdf {
      let components = ($formats.comic_info | path parse);
      {
        parent: $archival_target_directory
        stem: $components.stem
        extension: $components.extension
      } | path join
    }
  )
  let cover_archival_destination = (
    if "pdf" in $formats and $archive_pdf and "cover" in $formats and ($formats.cover | is-not-empty) {
      let components = ($formats.cover | path parse);
      {
        parent: $archival_target_directory
        stem: $components.stem
        extension: $components.extension
      } | path join
    }
  )
  if not $skip_upload {
    if "epub" in $formats {
      log info $"Uploading (ansi yellow)($formats.epub)(ansi reset) to (ansi yellow)($epub_archival_destination)(ansi reset)"
      if $use_rsync {
        $formats.epub | rsync $epub_archival_destination "--mkpath"
      } else {
        $formats.epub | scp $epub_archival_destination --mkdir
      }
    } else if "pdf" in $formats and $archive_pdf  {
      log info $"Uploading (ansi yellow)($formats.pdf)(ansi reset) to (ansi yellow)($pdf_archival_destination)(ansi reset)"
      if $use_rsync {
        $formats.pdf | rsync $pdf_archival_destination "--mkpath"
      } else {
        $formats.pdf | scp $pdf_archival_destination --mkdir
      }
      log info $"Uploading (ansi yellow)($formats.comic_info)(ansi reset) to (ansi yellow)($comic_info_archival_destination)(ansi reset)"
      if $use_rsync {
        $formats.comic_info | rsync $comic_info_archival_destination "--mkpath"
      } else {
        $formats.comic_info | scp $comic_info_archival_destination --mkdir
      }
      if ($cover_archival_destination | is-not-empty) {
        log info $"Uploading (ansi yellow)($formats.cover)(ansi reset) to (ansi yellow)($cover_archival_destination)(ansi reset)"
        if $use_rsync {
          $formats.cover | rsync $cover_archival_destination "--mkpath"
        } else {
          $formats.cover | scp $cover_archival_destination --mkdir
        }
      }
    }
  }

  if ereader_cbz in $formats {
    if $no_copy_to_ereader {
      let safe_basename = (($formats.ereader_cbz | path basename) | str replace --all ":" "_")
      let target = ([$ereader_target_directory $safe_basename] | path join)
      log info $"Copying (ansi yellow)($formats.ereader_cbz)(ansi reset) to (ansi yellow)($target)(ansi reset)"
      cp $formats.ereader_cbz $target
    }
    if $upload_ereader_cbz {
      log info $"Uploading (ansi yellow)($formats.ereader_cbz)(ansi reset) to (ansi yellow)($target_directory)/($formats.ereader_cbz | path basename)(ansi reset)"
      if $use_rsync {
        $formats.ereader_cbz | rsync $target_directory "--mkpath"
      } else {
        $formats.ereader_cbz | scp $target_directory --mkdir
      }
    }
    if $no_copy_to_ereader and not $upload_ereader_cbz {
      mv --force $formats.ereader_cbz $destination
    }
  }

  if not $keep {
    log debug "Deleting the original file"
    let uploaded_paths = (
      [$target_destination]
      | append $comic_info_target_destination
      | append $cover_target_destination
      | append $epub_archival_destination
      | append $pdf_archival_destination
      | append $cover_archival_destination
      | append $comic_info_archival_destination
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
      if $destination != null {
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
