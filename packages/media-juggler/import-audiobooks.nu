#!/usr/bin/env nu

# todo Consider using bragibooks instead: https://github.com/djdembeck/bragibooks
# tone can rename files as needed

use std log
use media-juggler-lib *

# Embed the cover art to an M4B file
export def embed_cover []: record<cover: path, m4b: path> -> path {
  let audiobook = $in
  if $audiobook.cover == null {
    ^tone tag --auto-import=covers $audiobook.m4b
  } else {
    ^tone tag --meta-cover-file $audiobook.cover $audiobook.m4b
  }
  $audiobook
}

export const supported_file_extensions = ["aax" "flac" "m4a" "m4b" "mp3" "mp4" "oga" "ogg" "opus" "wav" "zip"]

# Import an audiobook to my collection.
#
# Audiobooks must be organized with the all of the book's audio files in a single directory.
# It will be assumed that all files in the directory belong to the same audiobook.
#
# This script performs several steps to process the audiobook file.
#
# 1. Decrypt the audiobook if it is from Audible.
# 2. Tag the audiobook.
# 3. Upload the audiobook to a server over SSH
#
# The path for a book in a series will look like "<primary authors>/<series>/<title>/<title>.m4b".
# The path for a standalone book will look like "<primary authors>/<title>/<title>.m4b".
#
# Lossless FLACs will be stored in an OGG container using the ".oga" file extension.
# Lossy AAC or MP3 files transcoded to OPUS will be stored in an OGG container using the ".opus" file extension.
def main [
  ...items: string # The paths to the audio files in a book or a directory containing the audio files belonging to a single book to tag and upload. Prefix paths with "ssh:" to download them from the server via SSH.
  # --asin: string
  # --isbn: string
  # --ignore-embedded-acoustid-fingerprints
  --transcode-lossy-to-opus
  --acoustid-client-key: string # The application API key for the AcoustID server
  --acoustid-user-key: string # Submit AcoustID fingerprints to the AcoustID server using the given user API key
  --musicbrainz-release-id: string
  --audible-activation-bytes: string # The Audible activation bytes used to decrypt the AAX file
  --delete # Delete the original file
  --destination: directory = "meerkat:/var/media/audiobooks" # The directory under which to copy files.
  --skip-combine # Don't combine multiple audio files for a book into a single M4B file
  --tone-tag-args: list<string> = [] # Additional arguments to pass to the tone tag command
] {
  if ($items | is-empty) {
    log error "No files provided"
    exit 1
  }

  let audible_activation_bytes = (
    if $audible_activation_bytes != null {
      $audible_activation_bytes
    } else if "AUDIBLE_ACTIVATION_BYTES" in $env {
      $env.AUDIBLE_ACTIVATION_BYTES
    } else {
      null
    }
  )

  let acoustid_client_key = (
    if $acoustid_client_key != null {
      $acoustid_client_key
    } else if "MEDIA_JUGGLER_ACOUSTID_CLIENT_KEY" in $env {
      $env.MEDIA_JUGGLER_ACOUSTID_CLIENT_KEY
    } else {
      null
    }
  )

  let acoustid_user_key = (
    if $acoustid_user_key != null {
      $acoustid_user_key
    } else if "MEDIA_JUGGLER_ACOUSTID_USER_KEY" in $env {
      $env.MEDIA_JUGGLER_ACOUSTID_USER_KEY
    } else {
      null
    }
  )

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

  # Group files together into individual audiobooks based on directory
  let audiobooks = (
    $items
    | par-each {|item|
      let item_type = (
        if ($item | is_ssh_path) {
          $item | ssh_path_type
        } else {
          $item | path type
        }
      )
      let files = (
        if ($item | is_ssh_path) {
          log info $"is_ssh_path: true for ($item)"
          let item = (
            if $item_type == "dir" {
              $"($item)/**/*"
            } else {
              $item
            }
          )
          let server = $item | split_ssh_path | get server
          $item | ssh ls | where type == "file" | get name | each {|file| $"($server):($file)"}
        } else {
          let item = (
            if $item_type == "dir" {
              $"($item)/**/*"
            } else {
              $item
            }
          )
          ls ($item | path expand) | where type == file | get name
        }
      )
      if ($files | is-empty) {
        log error $"Missing audio files for (ansi yellow)($item)(ansi reset)"
        exit 1
      }
      $files
    }
    | flatten
    | uniq
    | path parse
    # Group files together by directory
    | group-by --to-table parent
    | rename directory files
    | par-each {|audiobook|
      $audiobook | update files ($audiobook.files | path join)
    }
  )

  # Check for errors
  let audiobooks = $audiobooks | par-each {|audiobook|
    let audio_files = $audiobook.files | path parse | where extension in $supported_file_extensions
    if ($audiobook.files | is-empty) {
      log error $"No supported audio files in ($audiobook.directory). Skipping."
      null
    } else {
      # All audio files for the audiobook must be the same type.
      let zips = $audio_files | where extension == zip
      let audio_files = $audio_files | where extension != zip | append (
        $zips
        | each {|zip|
          if ($zip | is_ssh_path) {
            let temporary_directory = (mktemp --directory $"import-audiobooks.($audiobook.directory | path basename).XXXXXXXXXX")
            let downloaded_zip = $zip | scp $temporary_directory
            let files = $downloaded_zip | list_files_in_archive_with_extensions (
              # Zip archives inside of zip archives are not supported.
              $supported_file_extensions | filter {|extension| $extension != "zip"}
            )
            rm --force --recursive $temporary_directory
            $files
          } else {
            $zip | list_files_in_archive_with_extensions (
            # Zip archives inside of zip archives are not supported.
              $supported_file_extensions | filter {|extension| $extension != "zip"}
            )
          }
        }
        | path parse
        | flatten
        | uniq
      )
      let audio_file_extension = $audio_files.extension | first
      if (
        $audio_files
        | all {|file|
          $file.extension == $audio_file_extension
        }
      ) {
        $audiobook | insert type $audio_file_extension
      } else {
        log error $"Not all audio files for the audiobook are of the same type: ($audio_files). Skipping."
        null
      }
    }
  }
  if ($audiobooks | is-empty) {
    log error "No audiobooks to import!"
    exit 1
  }

  if $musicbrainz_release_id != null and ($audiobooks | length) > 1 {
    log error "Setting the MusicBrainz ID for multiple books is not allowed to prevent mistakes"
    exit 1
  }

  # Copy files column to original_files
  let audiobooks = $audiobooks | rename directory original_files | insert files {|audiobook| $audiobook.original_files}

  # Set target output type
  let audiobooks = $audiobooks | insert output_type {|audiobook|
    # todo I should probably improve this to properly account for the input/output codec/container
    # Lossless or already in OGG container
    # I guess we can keep using the FLAC container. Which one to use?
    if $audiobook.type in ["flac" "oga" "wav"] {
      "oga"
    } else if $audiobook.type in ["opus"] {
      "opus"
    # Other lossy
    } else {
      if $transcode_lossy_to_opus {
        "opus"
      } else {
        "m4b"
      }
    }
  }

  # todo WAV's should be encoded to FLAC
  # -acodec flac audio.oga

  for audiobook in $audiobooks {

  log info $"Importing (ansi purple)($audiobook)(ansi reset)"

  let temporary_directory = (mktemp --directory $"import-audiobooks.($audiobook.directory | path basename).XXXXXXXXXX")
  log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

  # try {

  # First, copy files via SSH if necessary
  let audiobook = $audiobook | update files (
    if ($audiobook.files | first | is_ssh_path) {
      $audiobook.files | each {|file|
        $file | scp ([$temporary_directory "downloads" ($file | path basename)] | path join)
      }
    } else {
      $audiobook.files
    }
  )

  # Next, unzip any zip archives
  let audiobook = $audiobook | update files (
    $audiobook.files
    | each {|file|
      if ($file | path parse | get extension) == "zip" {
        $file | unzip ([$temporary_directory "extracted"] | path join)
      } else {
        [$file]
      }
    }
    | flatten
  )

  # Next, decrypt any Audible AAX files and remove video stream from any M4B files
  let audiobook = (
    if $audiobook.type == "aax" {
      if $audible_activation_bytes == null {
        log error "Audible activation bytes must be provided to decrypt Audible audiobooks"
        exit 1
      }
      let files = $audiobook.files | each {|file|
        log debug $"Decrypting Audible AAX file (ansi yellow)($file)(ansi reset) with ffmpeg"
        $file | decrypt_audible_aax $audible_activation_bytes --working-directory $temporary_directory
      }
      $audiobook | update files $files | update type m4b
    } else if $audiobook.type == "m4b" {
      $audiobook | update files (
        $audiobook.files | each {|file|
          log info $"file: ($file)"
          # todo Only remove this when it actually exists
          $file | remove_video_stream
        }
      )
    } else {
      $audiobook
    }
  )

  # Combine multiple files into a single M4B file
  # An individual file not in the M4B format will be wrapped into an MP4 container and renamed with the M4B file extension
  let audiobook = (
    if ($audiobook.files | length) == 1 and $audiobook.type == "m4b" {
      $audiobook
    } else {
      log debug "Merging audio files into a single M4B file with m4b-tool"
      $audiobook | update files (
        $audiobook.files | merge_into_m4b $temporary_directory
      ) | rename --column {files: "file"}
    }
  )

  # todo Convert the single M4B file into an OPUS / OGA file?

  let metadata = (
    $audiobook.files
    | (
      tag_audiobook $temporary_directory
      --acoustid-client-key $acoustid_client_key
      --acoustid-user-key $acoustid_user_key
      --musicbrainz-release-id $musicbrainz_release_id
    )
  )
  if ($metadata | is-empty) {
    return {audiobook: $audiobook.directory error: $"Failed to retrieve metadata for the audiobook (ansi yellow)($audiobook.directory)(ansi clear)"}
  }
  if ($metadata.book | get --ignore-errors contributors | is-empty) {
    return {audiobook: $audiobook.directory error: $"Missing contributors for the audiobook (ansi yellow)($audiobook.directory)(ansi clear)"}
  }

  let audiobook = $audiobook | insert file {|a| $a.files | first}

  # Rename M4B file using the title of the audiobook
  let audiobook = $audiobook | update file (
    # This is okay for single file outputs only.
    let new_file = (
      $audiobook.file
      | path parse
      | update stem ($metadata.book.title | sanitize_file_name)
      | update parent $temporary_directory
      | path join
    );
    mkdir ($new_file | path dirname);
    cp --force $audiobook.file $new_file;
    $new_file
  )

  let audiobook = $audiobook | update files [$audiobook.file]

  let primary_authors = $metadata.book.contributors | where role == "primary author"
  if ($primary_authors | is-empty) {
    return {audiobook: $audiobook.directory error: $"Failed to find primary authors for the audiobook (ansi yellow)($audiobook.directory)(ansi clear). Contributors are ($metadata.book.contributors)"}
  }

  let relative_destination = (
    [
      ($audiobook.file | path parse | get stem)
      ($audiobook.file | path basename)
    ]
    | prepend (
      if ($metadata.book | get --ignore-errors series | is-not-empty) {
        # First series is the primary series
        $metadata.book.series.name | first | sanitize_file_name
      }
    )
    | prepend ($primary_authors.name | str join ", " | sanitize_file_name)
    | path join
  )

  let target_destination = [$destination $relative_destination] | path join

  if ($target_destination | is_ssh_path) {
    log info $"Uploading (ansi yellow)($audiobook.file)(ansi reset) to (ansi yellow)($target_destination)(ansi reset)"
    $audiobook.file | scp $target_destination
  } else {
    mkdir ($target_destination | path dirname)
    mv $audiobook.file $target_destination
  }

  if $delete {
    log debug "Deleting the original files"
    (
      $audiobook.original_files
      | filter {|file|
        $file != $target_destination
      }
      | each {|file|
        if ($file | is_ssh_path) {
          $file | ssh rm
        } else {
          rm $file
        }
      }
    )
  }
  log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
  rm --force --recursive $temporary_directory

  # } catch {
  #     log error $"Import of (ansi red)($original_file)(ansi reset) failed!"
  #     continue
  # }

  }
}
