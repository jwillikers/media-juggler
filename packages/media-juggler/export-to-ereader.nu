#!/usr/bin/env nu

use std log
use media-juggler-lib *

# Convert a comic for an e-reader
def main [
    ereader: string # Create a copy of the comic book optimized for this specific e-reader, i.e. "Kobo Elipsa 2E"
    ...files: path # The paths to EPUB, PDF, and CBZ files to convert for the ereader. Prefix paths with "minio:" to download them from the MinIO instance
    # todo rename to target-subdirectory
    --ereader-subdirectory: string # The subdirectory on the e-reader in-which to copy, i.e. "Books/Manga" or "Books/Books"
    --no-copy-to-ereader # Don't copy the E-Reader specific format to a mounted e-reader
    --optimize-images # Don't attempt to optimize the size of the image files with image_optim
    --output-directory: directory # Directory to place files when not being uploaded
    --type: string # The type of books such as "manga", "comic", "book", or "light novel"
] {
    if ($files | is-empty) {
        log error "No files provided"
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

    let ereader_disk_label = ($ereader_profiles | where model == $ereader | first | get disk_label)
    let username = (^id --name --user)
    let ereader_mountpoint = (["/run/media" $username $ereader_disk_label] | path join)
    if not $no_copy_to_ereader {
      if (^findmnt --target $ereader_mountpoint | complete | get exit_code) != 0 {
        ^udisksctl mount --block-device ("/dev/disk/by-label/" | path join $ereader_disk_label) --no-user-interaction
        # todo Parse the mountpoint from the output of this command
      }
    }

    for original_file in $files {

    log info $"Exporting the file (ansi purple)($original_file)(ansi reset)"

    let temporary_directory = (mktemp --directory --tmpdir-path ~/.cache "export-to-ereader.XXXXXXXXXX")
    log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

    try {

    let file = (
        if ($original_file | str starts-with "minio:") {
            let file = ($original_file | str replace "minio:" "")
            ^mc cp $file $"($temporary_directory)/($file | path basename)"
            [$temporary_directory ($file | path basename)] | path join
        } else {
            cp $original_file $temporary_directory
            [$temporary_directory ($original_file | path basename)] | path join
        }
    )

    # todo Support EPUB and PDF files.
    let input_format = ($file | path parse | get extension)

    let type = (
        if $type == null {
            if $input_format == "cbz" {
                "manga"
            } else {
                if ($file | path parse | get stem | str contains --ignore-case "light novel") {
                    "light novel"
                } else {
                    "book"
                }
            }
        } else {
            $type
        }
    )

    let ereader_subdirectory = (
        if $ereader_subdirectory == null {
            if $type == "manga" {
                "Books/Manga"
            } else if $type == "comic" {
                "Books/Comics"
            } else if $type == "light novel" {
                "Books/Light Novels"
            } else if $type == "book" {
                "Books/Books"
            } else {
                log warning $"Unknown type '($type)'. Files will be placed in the Books/Books directory"
                "Books/Books"
            }
        } else {
            $ereader_subdirectory
        }
    )

    let output_format = (
      if $type in [comic manga] {
        "cbz"
      } else {
        # todo Convert PDF to EPUB?
        $input_format
      }
    )

    let file = (
        if $type in [comic manga] {
            if $input_format == "epub" {
                $file | epub_to_cbz --working-directory $temporary_directory
            } else if $input_format in ["cbz" "pdf" "zip"] {
                $file | convert_for_ereader $ereader $temporary_directory
            } else {
                log error $"Unsupported input file type (ansi red_bold)($input_format)(ansi reset) for type ($type)"
                exit 1
            }
        } else {
            if $input_format == "epub" {
                $file
            } else {
                log error $"Unsupported input file type (ansi red_bold)($input_format)(ansi reset) for type ($type)"
                exit 1
            }
        }
    )

    if $optimize_images and ($file | path parse | get extension) in ["cbz" "zip"]  {
      $file | optimize_zip
      # todo Add support for reducing image size of epubs with ebook-polish.
    }

    if $no_copy_to_ereader {
        mv $file $output_directory
    } else {
        let ereader_target_directory = ([$ereader_mountpoint $ereader_subdirectory] | path join)
        mkdir $ereader_target_directory
        # todo Make this a function with tests.
        let safe_basename = (($file | path basename) | str replace --all ":" "_")
        let target = ([$ereader_target_directory $safe_basename] | path join)
        log info $"Copying (ansi yellow)($file)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        cp $file $target
    }

    rm --force --recursive $temporary_directory

    } catch {
        log error $"Export of (ansi red)($original_file)(ansi reset) failed!"
        continue
    }

    }

    if not $no_copy_to_ereader {
      if (^findmnt --target $ereader_mountpoint | complete | get exit_code) == 0 {
        ^udisksctl unmount --block-device ("/dev/disk/by-label/" | path join $ereader_disk_label) --no-user-interaction
      }
    }
}
