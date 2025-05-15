#!/usr/bin/env nu

# todo Consider using bragibooks instead: https://github.com/djdembeck/bragibooks
# tone can rename files as needed

use std log
use media-juggler-lib *

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
  --keep # Keep the original file
  --delay-between-imports: duration = 1min # When importing multiple books, pause for this amount between imports. This reduces load on various endpoints by spreading out workload over time. For metadata refreshes, this should probably be increased to as large a delay as you can tolerate.
  --destination: directory = "meerkat:/var/media/audiobooks" # The directory under which to copy files.
  --merge # Combine multiple audio files for a book into a single file
  --submit-all-acoustid-fingerprints # AcoustID fingerprints are only submitted for files where one or both of the AcoustID fingerprints and MusicBrainz Recording IDs are updated from the values present in the embedded metadata. Set this to true to submit all AcoustIDs regardless of this.
  --preferred-mp3-container: string = "m4b" # The preferred container for mp3 files. Can be either mp3 or m4b.
  --preferred-container: string = "ogg" # The preferred container for the output audio. Use either m4b or ogg.
  --tone-tag-args: list<string> = [] # Additional arguments to pass to the tone tag command
  --transcode-bitrate: string = "" # The bitrate to use when transcoding audio. For opus, it defaults to 24k for mono and 32k for stereo recordings. For further details, see here: https://wiki.xiph.org/Opus_Recommended_Settings
  --use-rsync # Use rsync instead of scp to transfer files
] {
  if ($items | is-empty) {
    log error "No files provided"
    exit 1
  }

  let cache_directory = [($nu.cache-dir | path dirname) "media-juggler" "import-audiobooks"] | path join
  let config_file = [($nu.default-config-dir | path dirname) "media-juggler" "import-audiobooks-config.json"] | path join
  let config: record = (
    try {
      open $config_file
    } catch {
      {}
    }
  )

  let cache_function = {|type, id, update_function|
    let cached_file = [$cache_directory $type $"($id).json"] | path join
    try {
      open $cached_file
    } catch {
      let result = do $update_function $type $id
      mkdir ($cached_file | path dirname)
      $result | save --force $cached_file
      $result
    }
  }

  let audible_activation_bytes = (
    if $audible_activation_bytes != null {
      $audible_activation_bytes
    } else if "AUDIBLE_ACTIVATION_BYTES" in $env {
      $env.AUDIBLE_ACTIVATION_BYTES
    } else if ($config | get --ignore-errors audible_activation_bytes | is-not-empty) {
      $config.audible_activation_bytes
    } else {
      null
    }
  )

  let acoustid_client_key = (
    if $acoustid_client_key != null {
      $acoustid_client_key
    } else if "MEDIA_JUGGLER_ACOUSTID_CLIENT_KEY" in $env {
      $env.MEDIA_JUGGLER_ACOUSTID_CLIENT_KEY
    } else if ($config | get --ignore-errors acoustid_client_key | is-not-empty) {
      $config.acoustid_client_key
    } else {
      null
    }
  )

  let acoustid_user_key = (
    if $acoustid_user_key != null {
      $acoustid_user_key
    } else if "MEDIA_JUGGLER_ACOUSTID_USER_KEY" in $env {
      $env.MEDIA_JUGGLER_ACOUSTID_USER_KEY
    } else if ($config | get --ignore-errors acoustid_user_key | is-not-empty) {
      $config.acoustid_user_key
    } else {
      null
    }
  )

  let keep = (
    if $keep != null {
      $keep
    } else if ($config | get --ignore-errors keep | is-not-empty) {
      $config.keep
    }
  )
  let merge = (
    if $merge != null {
      $merge
    } else if ($config | get --ignore-errors merge | is-not-empty) {
      $config.merge
    }
  )
  let use_rsync = (
    if $use_rsync != null {
      $use_rsync
    } else if ($config | get --ignore-errors use_rsync | is-not-empty) {
      $config.use_rsync
    }
  )

  let destination = (
    if ($destination | is-not-empty) {
      $destination
    } else if ($config | get --ignore-errors destination | is-not-empty) {
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
          let server = $item | split_ssh_path | get server
          if $item_type == "dir" {
            $"($item | escape_special_glob_characters)/**/*" | ssh glob "--no-dir" "--no-symlink" | each {|file| $"($server):($file)"}
          } else {
            $item | ssh ls --expand-path | get name | each {|file| $"($server):($file)"}
          }
        } else {
          if $item_type == "dir" {
            glob --no-dir --no-symlink (($item | path expand | escape_special_glob_characters) + "/**/*")
          } else {
            [($item | path expand)]
          }
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

  for audiobook in ($audiobooks | enumerate) {
    let index = $audiobook.index
    let audiobook = $audiobook.item

  log info $"Importing audiobook files in directory (ansi purple)($audiobook.directory)(ansi reset)"

  let temporary_directory = (mktemp --directory $"import-audiobooks.($audiobook.directory | path basename).XXXXXXXXXX")
  log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

  # try {

  # First, copy files via SSH if necessary
  let audiobook = $audiobook | update files (
    $audiobook.files | each {|file|
      if ($file | is_ssh_path) {
        mkdir ([$temporary_directory "downloads"] | path join)
        if $use_rsync {
          $file | rsync ([$temporary_directory "downloads" ($file | path basename)] | path join) "--mkpath"
        } else {
          $file | scp ([$temporary_directory "downloads" ($file | path basename)] | path join)
        }
      } else if $keep {
        # Copy to temp directory to avoid modifying the original file
        if ($file | path parse | get extension) == "zip" {
          $file
        } else {
          let new_file = [$temporary_directory "downloads" ($file | path basename)] | path join
          mkdir ($new_file | path dirname)
          cp $file $new_file
          $new_file
        }
      } else {
        $file
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


  # Locate any supplementary documents, i.e. accompanying PDFs
  let audiobook = (
    let companion_documents = (glob $"($audiobook.directory | escape_special_glob_characters)/*.{($audiobook_companion_document_file_extensions | str join ',')}");
    if ($companion_documents | is-not-empty) {
      $audiobook | insert companion_documents $companion_documents
    } else {
      $audiobook | insert companion_documents []
    }
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
      if ($audiobook.files | first | path parse | get extension) == "m4b" {
        # Check for weird embedded video stream that needs removed
        let files = $audiobook.files | each {|file|
          if ($file | ffprobe | has_bad_video_stream) {
            $file | remove_video_stream
          } else {
            $file
          }
        }
        $audiobook | update files $files
      } else {
        $audiobook
      }
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
    } else if $merge {
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
    } else {
      # If --no-merge is passed, don't worry about conversion either
      $audiobook
    }
  )

  let metadata = (
    $audiobook.files
    | (
      tag_audiobook
      $temporary_directory
      $cache_function
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
  # This issue should be caught before here, but check just to be safe.
  if ($metadata.tracks | length) != ($audiobook.files | length) {
    return {audiobook: $audiobook.directory error: $"Number of tracks doesn't match the number of files for (ansi yellow)($audiobook.directory)(ansi clear)"}
  }

  let primary_authors = $metadata.book.contributors | where role == "primary author"
  if ($primary_authors | is-empty) {
    return {audiobook: $audiobook.directory error: $"Failed to find primary authors for the audiobook (ansi yellow)($audiobook.directory)(ansi clear). Contributors are ($metadata.book.contributors)"}
  }

  let relative_destination_directory = (
    [
      ($metadata.book.title | sanitize_file_name)
    ]
    | prepend (
      if ($metadata.book | get --ignore-errors series | is-not-empty) {
        # First series will eventually be the primary series.
        # todo Nest under subseries of the primary series.
        let primary_series = (
          if "scope" in ($metadata.book.series | columns) {
            let release_group_series = $metadata.book.series | where scope == "release group"
            if ($release_group_series | is-empty) {
              # Fall back to the work series if there is no release group series
              let work_series = $metadata.book.series | where scope == "work"
              if ($work_series | is-empty) {
                # Use whatever series exist are at this point
                if ($metadata.book.series | length) > 1 {
                  log warning "More than one non release group / non work series exists when no release group series exist. Not yet able to determine series and subseries ordering. Ignoring series altogether and placing book directory directly under the authors' subdirectory."
                } else if ($metadata.book.series | length) == 1 {
                  log warning "Falling back to non release group / non work series because no release group or work series exist"
                  $metadata.book.series | first
                }
              } else if ($work_series | length) == 1 {
                log warning "Falling back to work series because no release group series exists"
                $work_series | first
              } else {
                log warning "More than one work series exists when no release group series exist. Not yet able to determine series and subseries ordering. Ignoring series altogether and placing book directory directly under the authors' subdirectory."
              }
            } else if ($release_group_series | length) == 1 {
              $release_group_series | first
            } else {
              log warning $"More than one release group series exists. Not yet able to determine series and subseries ordering. Ignoring series altogether and placing book directory directly under the authors' subdirectory."
            }
          } else {
            if ($metadata.book.series | length) == 1 {
              $metadata.book.series | first
            } else {
              log info "Multiple series with no scope exist. Ignoring series altogether and placing book directory directly under the authors' subdirectory."
            }
          }
        )
        if ($primary_series | is-not-empty) {
          log info $"Primary series is ($primary_series)"
          $primary_series.name | sanitize_file_name
        }
      }
    )
    | prepend ($primary_authors.name | str join ", " | sanitize_file_name)
    | path join
  )

  let target_destination_directory = [$destination $relative_destination_directory] | path join

  # Determine how many leading zeros are required for the track number.
  let number_of_digits = (($metadata.tracks | length) - 1) | into string | str length;
  let audiobook = $audiobook | update files (
    $metadata.tracks
    | each {|track|
      # For multiple files, prefix the name with the index
      let stem = (
        if ($metadata.tracks | length) == 1 {
          $track.title | sanitize_file_name
        } else {
          ($track.index | fill --alignment r --character '0' --width $number_of_digits) + " " + $track.title
        }
      )
      let destination = $track.file | path parse | update stem $stem | update parent $target_destination_directory | path join
      {
        file: $track.file
        destination: $destination
      }
    }
  )

  # todo Get supplementary document metadata from BookBrainz
  let audiobook = $audiobook | update companion_documents (
    $audiobook.companion_documents
    | each {|document|
      let stem = (
        # For a single file, rename the file to match the book.
        if ($audiobook.companion_documents | length) == 1 {
          $metadata.book.title | sanitize_file_name
        # For multiple files, leave the names as is.
        } else {
          $document | path parse | get stem
        }
      )
      let destination = $document | path parse | update stem $stem | update parent $target_destination_directory | path join
      {
        file: $document
        destination: $destination
      }
    }
  )

  # todo
  # If the audiobook files are already present under the correct author / series subdirectory, but reside under extra directories, go ahead and leave that directory structure intact.
  # This is to accommodate external subseries management since this script doesn't yet support nesting series / subseries directories.
  # Note that if anything is renamed in the path hierarchy, such subdirectories will be dropped.
  # if top_part matches top_part, and audiobook_directory matches bottom_part, use existing path.

  if ($target_destination_directory | is_ssh_path) {
    $audiobook.files | append $audiobook.companion_documents | each {|file|
      log info $"Uploading (ansi yellow)($file.file)(ansi reset) to (ansi yellow)($file.destination)(ansi reset)"
      if $use_rsync {
        $file.file | rsync $file.destination "--chmod=Dg+s,ug+rwx,Fug+rw,ug-x" "--mkpath"
      } else {
        $file.file | scp --mkdir $file.destination
      }
    }
  } else {
    mkdir $target_destination_directory
    $audiobook.files | append $audiobook.companion_documents | each {|file|
      mv $file.file $file.destination
    }
  }

  if not $keep {
    log debug "Deleting the original files"
    (
      $audiobook.original_files
      | filter {|file|
        $file not-in ($audiobook.files | get destination)
      }
      | each {|file|
        if ($file | is_ssh_path) {
          $file | ssh rm
        } else {
          rm $file
        }
      }
    )
    (
      $audiobook.companion_documents
      | filter {|file|
        $file.file != $file.destination
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
    if $index < ($audiobooks | length) - 1 {
      sleep $delay_between_imports
    }
  }
}
