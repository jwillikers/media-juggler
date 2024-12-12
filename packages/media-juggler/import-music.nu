#!/usr/bin/env nu

# todo Consider using bragibooks instead: https://github.com/djdembeck/bragibooks
# todo Use tone and a JS script to query Audible?
# tone can rename files as needed

use std log
use media-juggler-lib *

# Import Audiobooks with Beets.
#
# The final file is named according to Beets defaults.
#
export def beet_import [
    beets_directory: directory # Directory to which the books are imported
    # config: path # Path to the Beets config to use
    --library: path # Path to the Beets library to use
    # --search-id
    # --set
    --working-directory: directory
]: path -> path {
    let item = $in
    (
        ^beet
        # --config $config
        --directory $beets_directory
        --library $library
        import
        $item
    )
    # let args = (
    #     []
    #     | append (if $library == null { "--volume=audible-beets-library:/config/library:Z" } else { $"--volume=($library | path dirname):/config/library:Z" })
    # )
    let imported_music = (
        let music_files = glob ([$beets_directory "**" "*.{aac,flac,m4a,mp3,opus}"] | path join);
        if ($music_files | is-empty) {
            log error $"No music files found in (ansi yellow)($beets_directory)(ansi reset)!"
            exit 1
        } else {
            # todo throw an error if multiple directories
            $music_files | first | path dirname
        }
    )
    # let artist_directory = ls --full-paths $beets_directory | get name | first
    log debug $"The imported music is (ansi yellow)($imported_music)(ansi reset)"
    $imported_music
}

# Import music to my collection.
#
# Music can be provided in directories, zip archives, or as individual audio files.
#
# This script performs several steps to process the audiobook file.
#
# 1. Decrypt the audiobook if it is from Audible.
# 2. Tag the audiobook.
# 3. Upload the audiobook
#
# The final file is named according to Jellyfin's recommendation, but includes a directory for the series if applicable.
# The path for a book in a series will look like "<authors>/<series>/<series-position> - <title>.m4b".
# The path for a standalone book will look like "<authors>/<title>.m4b".
#
def main [
    ...files: string # The paths to M4A and M4B files to tag and upload. Prefix paths with "minio:" to download them from the MinIO instance
    --beets-config: path # The Beets config file to use
    --beets-directory: directory
    --beets-library: path # The Beets library to use
    --delete # Delete the original file
    --minio-alias: string = "jwillikers" # The alias of the MinIO server used by the MinIO client application
    --minio-path: string = "media/Music" # The upload bucket and directory on the MinIO server. The file will be uploaded under a subdirectory named after the author.
    --output-directory: directory # Directory to place files when not being uploaded
    --skip-upload # Don't upload files to the server
] {
    if ($files | is-empty) {
        log error "No files provided"
        exit 1
    }

    # if $asin != null and ($files | length) > 1 {
    #     log error "Setting the ASIN for multiple files is not allowed as it can result in overwriting the final file"
    #     exit 1
    # }

    let output_directory = (
        if $output_directory == null {
            "." | path expand
        } else {
            $output_directory
        }
    )
    mkdir $output_directory

    for original_item in $files {

    log info $"Importing the file (ansi purple)($original_item)(ansi reset)"

    let temporary_directory = (mktemp --directory "import-music.XXXXXXXXXX")
    log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

    let beets_directory = (
        if $beets_directory == null {
            # [$env.HOME "Music"] | path join
            [$temporary_directory "Music"] | path join
        } else {
            $beets_directory
        }
    )
    mkdir $beets_directory

    # let audible_activation_bytes = (
    #     if $audible_activation_bytes != null {
    #         $audible_activation_bytes
    #     } else if "AUDIBLE_ACTIVATION_BYTES" in $env {
    #         $env.AUDIBLE_ACTIVATION_BYTES
    #     } else {
    #         null
    #     }
    # )

    # try {

    let original_music_files = (
        if ($original_item | str starts-with "minio:") {
            let item = ($original_item | str replace "minio:" "")
            ^mc find $item
        } else {
            ls $original_item | get name
        }
    )

    let item = (
        if ($original_item | str starts-with "minio:") {
            let item = ($original_item | str replace "minio:" "")
            ^mc cp --recursive $item $"($temporary_directory)/($item | path basename)"
            [$temporary_directory ($item | path basename)] | path join
        } else {
            cp --recursive $original_item $temporary_directory
            [$temporary_directory ($original_item | path basename)] | path join
        }
    )

    # let input_format = (
    #     if ($item | path type) == "dir" {
    #         "dir"
    #     } else {
    #         let ext = $file | path parse | get extension;
    #         if $ext == null {
    #             log error $"Unable to determine input file type of (ansi yellow)($file)(ansi reset). It is not a directory and has no file extension."
    #             exit 1
    #         } else {
    #             $ext
    #         }
    #     }
    # )

    let beets_library = (
        if $beets_library == null {
            # let library_directory = [$env.HOME ".local" "share" "beets-audible"] | path join
            let library_directory = $temporary_directory
            mkdir $library_directory
            [$library_directory "library.db"] | path join
        } else {
            $beets_library
        }
    )

    let music = (
        # if $input_format == "aax" {
        #     if $audible_activation_bytes == null {
        #         log error "Audible activation bytes must be provided to decrypt Audible audiobooks"
        #         exit 1
        #     }
        #     $file | decrypt_audible $activation_bytes --working-directory $temporary_directory
        # } else if $input_format in ["m4a", "m4b"] {
        #     $file
        # } else if $input_format == "dir" {
        #     $file | mp3_directory_to_m4b $temporary_directory
        # } else if $input_format == "zip" {
        #     $file
        #     | unzip $temporary_directory
        #     | mp3_directory_to_m4b $temporary_directory
        # } else {
        #     log error $"Unsupported input file type (ansi red_bold)($input_format)(ansi reset)"
        #     exit 1
        # }
        $item | beet_import $beets_directory --library $beets_library
        # | (
        #     if $asin == null {
        #         tag_audiobook --tone-tag-args $tone_tag_args $temporary_directory
        #     } else {
        #         tag_audiobook --asin $asin --tone-tag-args $tone_tag_args $temporary_directory
        #     }
        # )
    )

    # Authors are considered to be creators with the role of "Writer" in the ComicVine metadata
    # let authors = ($comic_metadata | get credits | where role == "Writer" | get person)
    # log debug $"Authors determined to be (ansi purple)'($authors)'(ansi reset)"

    # let current_metadata = ^tone dump --format json $audiobook | from json | get meta

    # let authors_subdirectory = $audiobook | path dirname | path relative-to $temporary_directory
    # let subdirectory =
    let music_files = ls $music | get name
    let minio_target_directory = (
        [
            $minio_alias
            $minio_path
            (
                $music_files
                | first
                | path dirname
                | path relative-to $beets_directory
            )
        ] | path join | sanitize_minio_filename
    )
    let music_file_destinations = $music_files | path parse | update parent $minio_target_directory | path join
    if $skip_upload {
        $music_files | each {|| mv $in $output_directory }
    } else {
        log info $"Uploading (ansi yellow)($music)(ansi reset) to (ansi yellow)($minio_target_directory)(ansi reset)"
        $music_files | zip $music_file_destinations | each {|| ^mc mv $in.0 $in.1 }
    }

    if $delete {
        log debug "Deleting the original files"
        if ($original_item | str starts-with "minio:") {
            (
                $original_music_files
                | zip $music_file_destinations
                | each {||
                    let original = $in.0
                    let upload = $in.1
                    if $original == $upload {
                        log info $"Not deleting the original file (ansi yellow)($original)(ansi reset) since it was overwritten by the updated file"
                    } else {
                        log info $"Deleting the original file on MinIO (ansi yellow)($original)(ansi reset)"
                        ^mc rm $original
                    }
                }
            )
        } else {
            log info $"Deleting the original files (ansi yellow)($original_music_files)(ansi reset)"
            (
                $original_music_files
                | each {|original|
                    log info $"Deleting the original file (ansi yellow)($original)(ansi reset)"
                    ^mc rm $original
                }
            )
            # todo Remove empty directories?
        }
    }
    log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
    rm --force --recursive $temporary_directory

    # } catch {
    #     log error $"Import of (ansi red)($original_item)(ansi reset) failed!"
    #     continue
    # }

    }
}
