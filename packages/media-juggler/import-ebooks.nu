#!/usr/bin/env nu

use std log
use media-juggler-lib *

# Import my EBooks to my collection.
#
# Input files can be in the ACSM, EPUB, and PDF formats.
#
# This script performs several steps to process the ebook file.
#
# 1. Decrypt the ACSM file if applicable.
# 2. Fetch and add metadata to the EPUB and PDF formats.
# 3. Upload the file to object storage.
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
    ...files: string # The paths to ACSM, EPUB, and PDF files to convert, tag, and upload. Prefix paths with "minio:" to download them from the MinIO instance
    --delete # Delete the original file
    --isbn: string # ISBN of the book
    # --identifiers: string # asin:XXXX
    --ereader: string # Create a copy of the comic book optimized for this specific e-reader, i.e. "Kobo Elipsa 2E"
    --ereader-subdirectory: string = "Books/Books" # The subdirectory on the e-reader in-which to copy
    --keep-acsm # Keep the ACSM file after conversion. These stop working for me before long, so no point keeping them around.
    --minio-alias: string = "jwillikers" # The alias of the MinIO server used by the MinIO client application
    --minio-path: string = "media/Books/Books" # The upload bucket and directory on the MinIO server. The file will be uploaded under a subdirectory named after the author.
    --no-copy-to-ereader # Don't copy the E-Reader specific format to a mounted e-reader
    --output-directory: directory # Directory to place files when not being uploaded
    --skip-upload # Don't upload files to the server
    --title: string # The title of the comic or manga issue
] {
    if ($files | is-empty) {
        log error "No files provided"
        exit 1
    }

    if $isbn != null and ($files | length) > 1 {
        log error "Setting the ISBN for multiple files is not allowed as it can result in overwriting the final file"
        exit 1
    }

    let output_directory = (
        if $output_directory == null {
            "." | path expand
        } else {
            $output_directory
        }
    )
    mkdir $output_directory

    let username = (^id --name --user)
    let ereader_disk_label = (
      if $ereader == null {
        null
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

    for original_file in $files {

    log info $"Importing the file (ansi purple)($original_file)(ansi reset)"

    let temporary_directory = (mktemp --directory "import-ebooks.XXXXXXXXXX")
    log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

    # try {

    # todo Add support for input files from Calibre using the Calibre ID number
    let file = (
        if ($original_file | str starts-with "minio:") {
            let file = ($original_file | str replace "minio:" "")
            ^mc cp $file $"($temporary_directory)/($file | path basename)"
            let opf = $file | path dirname | path join "metadata.opf"
            if (^mc stat $opf | complete).exit_code == 0 {
                ^mc cp $opf $"($temporary_directory)/($opf | path basename)"
            }
            let covers = (
                ^mc find ($file | path dirname) --name 'cover.*'
                | lines --skip-empty
                | filter {|f|
                    let components = $f | path parse
                    $components.stem == "cover" and $components.extension in $image_extensions
                }
            )
            if not ($covers | is-empty) {
                if ($covers | length) > 1 {
                    log error $"Found multiple files looking for the cover image file:\n($covers)\n"
                    exit 1
                }
                ^mc cp ($covers | first) $temporary_directory
            }
            [$temporary_directory ($file | path basename)] | path join
        } else {
            cp $original_file $temporary_directory
            let opf = $original_file | path dirname | path join "metadata.opf"
            if ($opf | path exists) {
                cp $opf $"($temporary_directory)/($opf | path basename)"
            }
            let covers = (
                ls ($original_file | path expand | path dirname)
                | get name
                | filter {|f|
                    let components = $f | path parse
                    $components.stem == "cover" and $components.extension in $image_extensions
                }
            );
            if not ($covers | is-empty) {
                if ($covers | length) > 1 {
                    log error $"Found multiple files looking for the cover image file:\n($covers)\n"
                    exit 1
                }
                cp ...$covers $temporary_directory
            }
            [$temporary_directory ($original_file | path basename)] | path join
        }
    )

    let input_format = ($file | path parse | get extension)
    let output_format = (
        if $input_format == "pdf" {
            "pdf"
        } else {
            "epub"
        }
    )

    let formats = (
        if $input_format == "acsm" {
            let epub = ($file | acsm_to_epub $temporary_directory | optimize_images_in_zip | polish_epub)
            { book: $epub }
        } else if $input_format == "epub" {
            { book: ($file | optimize_images_in_zip | polish_epub) }
        } else if $input_format == "pdf" {
            { book: $file }
        } else {
            log error $"Unsupported input file type (ansi red_bold)($input_format)(ansi reset)"
            exit 1
        }
    )

    let book = (
        $formats.book
        | (
            if $isbn == null {
                fetch_book_metadata $temporary_directory
            } else {
                fetch_book_metadata --isbn $isbn $temporary_directory
            }
        )
        | export_book_to_directory $temporary_directory
        | embed_book_metadata $temporary_directory
    )

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
      | par-each {|creator| $creator | get content | first | get content }
      | str trim --char ','
      | str trim
      | filter {|author| not ($author | is-empty)}
      | sort
    )
    log debug $"Authors: ($authors)"

    let authors_subdirectory = ($authors | str join ", ")
    let target_subdirectory = (
        [$authors_subdirectory]
        | append (
            if $output_format == "pdf" {
                $book.book | path parse | get stem
            } else {
                null
            }
        )
        | path join
    )
    let minio_target_directory = (
        [$minio_alias $minio_path $target_subdirectory]
        | path join
        | sanitize_minio_filename
    )
    log debug $"MinIO target directory: ($minio_target_directory)"
    let minio_target_destination = (
        let components = $book.book | path parse;
        { parent: $minio_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
    )
    log debug $"MinIO target destination: ($minio_target_destination)"
    if $skip_upload {
        mkdir $target_subdirectory
        if $output_format == "pdf" {
          mv $book.book $book.cover $book.opf $target_subdirectory
        } else {
          mv $book.book $target_subdirectory
        }
    } else {
        log info $"Uploading (ansi yellow)($book.book)(ansi reset) to (ansi yellow)($minio_target_destination)(ansi reset)"
        ^mc mv $book.book $minio_target_destination
        if $output_format == "pdf" {
          let opf_target_destination = [$minio_target_directory ($book.opf | path basename)] | path join
          log info $"Uploading (ansi yellow)($book.opf)(ansi reset) to (ansi yellow)($opf_target_destination)(ansi reset)"
          ^mc mv $book.opf $opf_target_destination
          let cover_target_destination = [$minio_target_directory ($book.cover | path basename)] | path join
          log info $"Uploading (ansi yellow)($book.cover)(ansi reset) to (ansi yellow)($cover_target_destination)(ansi reset)"
          ^mc mv $book.cover $cover_target_destination
        }
    }

    if $delete {
        log debug "Deleting the original file"
        if ($original_file | str starts-with "minio:") {
            let actual_path = ($original_file | str replace "minio:" "")
            log debug $"Actual path: ($actual_path)"
            let uploaded_path = $minio_target_destination
            log debug $"Uploaded path: ($uploaded_path)"
            if ($actual_path | sanitize_minio_filename) == $uploaded_path {
                log info $"Not deleting the original file (ansi yellow)($original_file)(ansi reset) since it was overwritten by the updated file"
            } else {
                log info $"Deleting the original file on MinIO (ansi yellow)($actual_path)(ansi reset)"
                ^mc rm $actual_path
                let opf = $actual_path | path dirname | path join "metadata.opf"
                if (^mc stat $opf | complete).exit_code == 0 {
                    log info $"Deleting the metadata file on MinIO (ansi yellow)($opf)(ansi reset)"
                    ^mc rm $opf
                }
                let covers = (
                    ^mc find ($actual_path | path dirname) --name 'cover.*'
                    | lines --skip-empty
                    | filter {|f|
                        let components = ($f | path parse);
                        $components.stem == "cover" and $components.extension in $image_extensions
                    }
                )
                if not ($covers | is-empty) {
                    if ($covers | length) > 1 {
                        log warning $"Not deleting cover file. Found multiple files looking for the cover image file:\n($covers)\n"
                    } else {
                        let cover = $covers | first
                        log info $"Deleting the cover image file on MinIO (ansi yellow)($cover)(ansi reset)"
                        ^mc rm $cover
                    }
                }
            }
        } else {
            log info $"Deleting the original file (ansi yellow)($original_file)(ansi reset)"
            rm $original_file
        }
    }
    log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
    rm --force --recursive $temporary_directory

    # } catch {
    #     log error $"Import of (ansi red)($original_file)(ansi reset) failed!"
    #     continue
    # }

    }

    if $ereader != null and not $no_copy_to_ereader {
      if (^findmnt --target $ereader_target_directory | complete | get exit_code) == 0 {
        ^udisksctl unmount --block-device ("/dev/disk/by-label/" | path join $ereader_disk_label) --no-user-interaction
      }
    }
}
