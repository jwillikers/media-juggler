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
# The path for a book in a subseries will look like "<primary authors>/<series>/<subseries>/<title>/<title>.m4b".
# The path for a standalone book will look like "<primary authors>/<title>/<title>.m4b".
#
# This script will attempt to merge multiple files of an audiobook into a single file.
# Additionally, it will try to use a container with proper chapters support if possible.
# Lossless FLACs will be merged into one FLAC-encoded OGG file using the ".oga" file extension.
# The OGG container has support for multiple chapters.
# Lossy AAC or MP3 files will be transcoded to OPUS and stored in an OGG container using the ".opus" file extension.
# I still need to implement all of this.
def main [
  ...items: string # The paths to the audio files in a book or a directory containing the audio files belonging to a single book to tag and upload. Prefix paths with "ssh:" to download them from the server via SSH.
  # --asin: string
  # --isbn: string
  # --ignore-embedded-acoustid-fingerprints
  --acoustid-client-key: string # The application API key for the AcoustID server
  --acoustid-user-key: string # Submit AcoustID fingerprints to the AcoustID server using the given user API key
  --lossy-to-lossy # Allow transcoding lossy formats to other lossy formats. This is irreversible and has the potential to introduce artifacts and degrade quality. It's recommended to keep the original lossy files for archival purposes when doing this.
  --musicbrainz-release-id: string
  --audible-activation-bytes: string # The Audible activation bytes used to decrypt the AAX file
  --delete # Delete the original file
  --destination: directory = "meerkat:/var/media/audiobooks" # The directory under which to copy files.
  --skip-combine # Don't combine multiple audio files for a book into a single M4B file
  --submit-all-acoustid-fingerprints # AcoustID fingerprints are only submitted for files where one or both of the AcoustID fingerprints and MusicBrainz Recording IDs are updated from the values present in the embedded metadata. Set this to true to submit all AcoustIDs regardless of this.
  --preferred-mp3-container: string = "m4b" # The preferred container for mp3 files. Can be either mp3 or m4b.
  --preferred-container: string = "ogg" # The preferred container for the output audio. Use either m4b or ogg.
  --tone-tag-args: list<string> = [] # Additional arguments to pass to the tone tag command
  --transcode-bitrate: string = "" # The bitrate to use when transcoding audio. For opus, it defaults to 24k for mono and 32k for stereo recordings. For further details, see here: https://wiki.xiph.org/Opus_Recommended_Settings
  --delay-between-imports: duration = 1min # When importing multiple books, pause for this amount between imports. This reduces load on various endpoints by spreading out workload over time. For metadata refreshes, this should probably be increased to as large a delay as you can tolerate.
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
          # log info $"is_ssh_path: true for ($item)"
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

  # Verify that audiobooks contain files with supported file extensions
  let audiobooks = $audiobooks | par-each {|audiobook|
    let audio_files = $audiobook.files | path parse | where extension in $supported_file_extensions
    if ($audiobook.files | is-empty) {
      log error $"No supported audio files in ($audiobook.directory). Skipping."
      null
    } else {
      $audiobook
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

  for audiobook in $audiobooks {

  log info $"Importing (ansi purple)($audiobook)(ansi reset)"

  let temporary_directory = (mktemp --directory $"import-audiobooks.($audiobook.directory | path basename).XXXXXXXXXX")
  log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

  # try {

  # First, copy files via SSH if necessary
  let audiobook = $audiobook | update files (
    if ($audiobook.files | first | is_ssh_path) {
      $audiobook.files | each {|file|
        mkdir ([$temporary_directory "downloads"] | path join)
        $file | scp ([$temporary_directory "downloads" ($file | path basename)] | path join)
      }
    } else {
      # Copy to temp directory to avoid modifying the original file
      $audiobook.files | each {|file|
        if ($file | path parse | get extension) == "zip" {
          $file
        } else {
          let new_file = [$temporary_directory "downloads" ($file | path basename)] | path join
          mkdir ($new_file | path dirname)
          cp $file $new_file
          $new_file
        }
      }
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

  # Next, decrypt any Audible AAX files
  let audiobook = (
    if ($audiobook.files | first | path parse | get extension) == "aax" {
      if $audible_activation_bytes == null {
        log error "Audible activation bytes must be provided to decrypt Audible audiobooks"
        exit 1
      }
      let files = $audiobook.files | each {|file|
        log debug $"Decrypting Audible AAX file (ansi yellow)($file)(ansi reset) with ffmpeg"
        $file | decrypt_audible_aax $audible_activation_bytes --working-directory $temporary_directory
      }
      $audiobook | update files $files
    } else {
      $audiobook
    }
  )

  # Check that the audio codecs and containers are consistent among all audiobook files
  let audiobook = (
    let audio_files = $audiobook.files | path parse | where extension in $supported_file_extensions | path join;
    let audio_codec_and_container = $audio_files | first | ffprobe | parse_container_and_audio_codec_from_ffprobe_output;
    if (
      $audio_files
      | skip 1
      | all {|file|
        ($file | ffprobe | parse_container_and_audio_codec_from_ffprobe_output) == $audio_codec_and_container
      }
    ) {
      (
        $audiobook
        | insert audio_codec $audio_codec_and_container.audio_codec
        | insert container $audio_codec_and_container.container
        | insert audio_channel_layout $audio_codec_and_container.audio_channel_layout
      )
    } else {
      return {audiobook: $audiobook.directory, error: $"Not all audio files for the audiobook are of the same container and audio codec: ($audio_files). Skipping."}
    }
  )

  # Set target output type
  let audiobook = (
    let target = (
      # Lossless
      if $audiobook.audio_codec in ["flac"] or ($audiobook.audio_codec | str starts-with "pcm") {
        if $preferred_container == "ogg" {
          {audio_codec: "flac", container: "ogg", file_extension: "oga"}
        } else {
          {audio_codec: "flac", container: "mov,mp4,m4a,3gp,3g2,mj2", file_extension: "m4b"}
        }
      # Lossy
      } else {
        # Use opus
        if $lossy_to_lossy or $audiobook.audio_codec == "opus" {
          if $preferred_container == "ogg" {
            {audio_codec: "opus", container: "ogg", file_extension: "opus"}
          } else {
            {audio_codec: "opus", container: "mov,mp4,m4a,3gp,3g2,mj2", file_extension: "m4b"}
          }
        # Keep the original audio codec
        } else {
          if $audiobook.audio_codec == "mp3" and $preferred_mp3_container == "mp3" {
            {audio_codec: $audiobook.audio_codec, container: "mp3", file_extension: "mp3"}
          } else {
            {audio_codec: $audiobook.audio_codec, container: "mov,mp4,m4a,3gp,3g2,mj2", file_extension: "m4b"}
          }
        }
      }
    );
    $audiobook | insert target $target
  )
  log debug $"Target: ($audiobook.target)"

  # Convert and merge audio files
  let audiobook = (
    if ($audiobook.files | length) == 1 {
      if (
        $audiobook.container == $audiobook.target.container
        and $audiobook.audio_codec == $audiobook.target.audio_codec
      ) {
        # No conversion necessary
        $audiobook
      } else {
        let audiobook_file = $audiobook.files | first
        log debug $"Converting ($audiobook_file) file to a ($audiobook.target.audio_codec) encoded ($audiobook.target.container) container"
        let output_file = $audiobook_file | path parse | update parent $temporary_directory | update extension $audiobook.target.file_extension | path join
        let ffmpeg_audio_encoder = (
          if $audiobook.target.audio_codec == "opus" {
            "libopus"
          } else if $audiobook.target.audio_codec == "aac" {
            "libfdk_aac"
          } else if $audiobook.target.audio_codec == "mp3" {
            "libmp3lame"
          } else if $audiobook.target.audio_codec == "wav" {
            "wavpack"
          } else {
            $audiobook.target.audio_codec
          }
        )
        let ffmpeg_args = (
          []
          | append (
            if $audiobook.audio_codec == $audiobook.target.audio_codec {
              ["-c" "copy"]
            } else {
              ["-c:a" $ffmpeg_audio_encoder]
            }
          )
          | append (
            if $audiobook.target.audio_codec == "opus" and $audiobook.audio_codec != $audiobook.target.audio_codec {
              if ($transcode_bitrate | is-empty) {
                if $audiobook.audio_channel_layout == "mono" {
                  ["-b:a" "24k"]
                } else if $audiobook.audio_channel_layout == "stereo" {
                  ["-b:a" "32k"]
                } else {
                  # Not sure, so just use variable, which is the default
                }
              } else {
                if $transcode_bitrate != "variable" {
                  ["-b:a" $transcode_bitrate]
                }
              }
            }
          )
        )
        ^ffmpeg -i $audiobook_file ...$ffmpeg_args $output_file
        $audiobook | update files [$output_file]
      }
    } else {
      log debug $"Merging ($audiobook.container) files into a single ($audiobook.target.file_extension) file with m4b-tool"
      let m4b_tool_audio_format = (
        if $audiobook.target.container == "mov,mp4,m4a,3gp,3g2,mj2" {
          "m4b"
        } else {
          $audiobook.target.container
        }
      )
      let ffmpeg_audio_encoder = (
        if $audiobook.audio_codec == $audiobook.target.audio_codec {
          "copy"
        } else if $audiobook.target.audio_codec == "opus" {
          "libopus"
        } else if $audiobook.target.audio_codec == "aac" {
          "libfdk_aac"
        } else if $audiobook.target.audio_codec == "mp3" {
          "libmp3lame"
        } else if $audiobook.target.audio_codec == "wav" {
          "wavpack"
        } else {
          $audiobook.target.audio_codec
        }
      )
      let m4b_tool_args = (
        [
          "--audio-codec" $ffmpeg_audio_encoder
        ]
        | append (
          if $audiobook.target.audio_codec == "opus" and $audiobook.audio_codec != $audiobook.target.audio_codec {
            if ($transcode_bitrate | is-empty) {
              if $audiobook.audio_channel_layout == "mono" {
                ["--audio-bitrate" "24k"]
              } else if $audiobook.audio_channel_layout == "stereo" {
                ["--audio-bitrate" "32k"]
              } else {
                # Not sure, so just use variable, which is the default
              }
            } else {
              if $transcode_bitrate != "variable" {
                ["--audio-bitrate" $transcode_bitrate]
              }
            }
          }
        )
      )
      $audiobook | update files (
        $audiobook.files | (
          merge_into_m4b $temporary_directory
          --audio-format $m4b_tool_audio_format
          --audio-extension $audiobook.target.file_extension
          ...$m4b_tool_args
        )
      )
    }
  )

  let metadata = (
    $audiobook.files
    | (
      tag_audiobook $temporary_directory
      $submit_all_acoustid_fingerprints
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

  # todo Handle multiple output files, naming tracks appropriately with the index prefix as necessary
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
    # log info $"ls: (ls $audiobook.file)";
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
    sleep $delay_between_imports
  }
}
