#!/usr/bin/env nu

use std log
use media-juggler-lib *

# Import Audiobooks with Beets.
#
# The final file is named according to Beets defaults.
#
export def beet_import [
  beets_directory: directory # Directory to which the books are imported
  config: path # Path to the Beets config to use
  --library: path # Path to the Beets library to use
  --search-id: string
  --working-directory: directory
]: path -> list<path> {
  let item = $in
  let args = (
    []
    | append (if $search_id == null { null } else { ["--search-id" $search_id] })
  )
  (
    ^beet
    --config $config
    --directory $beets_directory
    --library $library
    import
    ...$args
    $item
  )
  # Submit fingerprints
  (
    ^beet
    --config $config
    --directory $beets_directory
    --library $library
    submit
  )
  let imported_music = (
    let music_files = glob ([$beets_directory "**" "*.{aac,flac,lrc,m4a,mp3,opus}"] | path join);
    if ($music_files | is-empty) {
      log error $"No music files found in (ansi yellow)($beets_directory)(ansi reset)!"
      exit 1
    } else {
      $music_files
    }
  )
  log debug $"The imported music is (ansi yellow)($imported_music)(ansi reset)"
  $imported_music
}

# Generate a Beets config file
#
# Creating the config allows interpolating environment variables for various API tokens.
# Takes an input configuration which is merged with the default configuration.
#
export def generate_beets_config []: record -> record {
  let secrets = $in
  {
    artist_credit: true
    embedart: {
      remove_art_file: true
    }
    fetchart: {
      high_resolution: true
      sources: [
        filesystem
        coverart
        itunes
        amazon
        albumart
        google
        fanarttv
        # lastfm
      ]
    }
    keyfinder : {
      bin: "keyfinder-cli"
    }
    lyrics: {
      bing_lang_to: "en-US"
      synced: true
    }
    plugins: [
      "chroma"
      "deezer"
      "discogs"
      "embedart"
      "export"
      "fetchart"
      "keyfinder"
      "lyrics"
      "mbsubmit"
      "scrub"
      "spotify"
    ]
  } | merge $secrets
}

# Obtain secret tokens for the Beets config from the environment
export def beet_secrets_from_env []: nothing -> record {
  [
    [env key subkey];
    [BEETS_ACOUSTID_APIKEY acoustid apikey]
    [BEETS_DISCOGS_TOKEN discogs user_token]
    [BEETS_FANARTTV_KEY fetchart fanarttv_key]
    [BEETS_GOOGLE_KEY fetchart google_key]
    [BEETS_LASTFM_KEY fetchart lastfm_key]
    # todo Doesn't work?
    # [BEETS_BING_CLIENT_SECRET lyrics bing_client_secret]
    [BEETS_GOOGLE_KEY lyrics google_API_key]
  ] | reduce --fold {} {|mapping, acc|
    if $mapping.env in $env and not ($env | get $mapping.env | is-empty) {
      if $mapping.key in $acc {
        $acc
        | update $mapping.key (
          $acc
          | get $mapping.key
          | merge { $mapping.subkey: ($env | get $mapping.env) }
        )
      } else {
        $acc | insert $mapping.key { $mapping.subkey: ($env | get $mapping.env) }
      }
    } else {
      $acc
    }
  }
}

# Import music to my collection.
#
# Music can be provided as directories, zip archives, or as individual audio files.
#
# This script is mostly a convenience wrapper around Beets.
#
# 1. Import and tag the music with Beets
# 2. Upload the music
#
# The directory structure for the imported music follows Beets configuration.
# The default configuration for paths is used unless --beets-config is used to pass in alternate config file.
#
def main [
  ...items: string # The paths to audio files and directories containing audio files to import. Prefix paths with "ssh:" to download them over SSH from a server
  --beets-config: path # The Beets config file to use
  --beets-directory: directory # The directory in which to import music with Beets. Defaults to a Music subdirectory in a temporary directory. This option can be be useful for keeping imported music between imports.
  --beets-library: path # The Beets library database file to use
  --delete # Delete the original file
  --ssh-server: string = "meerkat" # The address of the SSH server
  --ssh-path: string = "/var/media/music" # The target directory on the server
  --output-directory: directory # Directory to place files when not being uploaded
  --search-id: string # An id to limit the search for metadata. One example is the MusicBrainz release id.
  --skip-upload # Don't upload files to the server
] {
  if ($items | is-empty) {
    log error "No files provided"
    exit 1
  }

  if $search_id != null and ($items | length) > 1 {
    log error "Setting the search_id for multiple items is not allowed as it can result in overwriting the imported music on subsequent items"
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

  let beets_config_data = (
    if $beets_config == null {
      beet_secrets_from_env | generate_beets_config
    }
  )

  for original_item in $items {

  log info $"Importing the file (ansi purple)($original_item)(ansi reset)"

  let temporary_directory = (mktemp --directory "import-music.XXXXXXXXXX")
  log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

  let beets_config = (
    if $beets_config == null {
      let config = [$temporary_directory config.yaml] | path join
      $beets_config_data | to yaml | save --force $config
      $config
    } else {
      $beets_config
    }
  )

  let beets_directory = (
    if $beets_directory == null {
      [$temporary_directory "Music"] | path join
    } else {
      $beets_directory
    }
  )
  mkdir $beets_directory

  # try {

  let item_type = (
    if ($original_item | str starts-with "ssh:") {
      $original_item | str replace "ssh:" "" | ssh path type $ssh_server
    } else {
      $original_item | path type
    }
  )

  let original_music_files = (
    if ($original_item | str starts-with "ssh:") {
      let item = $original_item | str replace "ssh:" ""
      let item = (
        if $item_type == "dir" {
          $"($item)/**/*"
        } else {
          $item
        }
      )
      $item | ssh ls $ssh_server | where type == file | get name
    } else {
      let item = (
        if $item_type == "dir" {
          $"($original_item)/**/*"
        } else {
          $original_item
        }
      )
      ls $item | where type == file | get name
      # glob --no-dir ([($original_item "**" "*"] | path join)
    }
  )

  if ($original_music_files | is-empty) {
    log error $"No music files found for (ansi yellow)($original_item)(ansi reset)"
  }

  let import_directory = [$temporary_directory import] | path join
  mkdir $import_directory

  let item = (
    if ($original_item | str starts-with "ssh:") {
      let item = ($original_item | str replace "ssh:" "")
      if $item_type == "dir" {
        scp --recursive $item $"($import_directory)/($item | path basename)"
      } else {
        scp $item $"($import_directory)/($item | path basename)"
      }
      [$import_directory ($item | path basename)] | path join
    } else {
      if $item_type == "dir" {
        cp --recursive $original_item $import_directory
      } else {
        cp $original_item $import_directory
      }
      [$import_directory ($original_item | path basename)] | path join
    }
  )

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

  let music_files = (
    if $search_id == null {
      $item | beet_import --library $beets_library $beets_directory $beets_config
    } else {
      $item | beet_import --library $beets_library --search-id $search_id $beets_directory $beets_config
    }
  )

  let music_file_destinations = (
    $music_files
    | each {|f|
      [
        $ssh_server
        $ssh_path
        ($f | path relative-to $beets_directory)
      ] | path join
    }
  )
  if $skip_upload {
    (
      $music_files
      | each {|f|
        let target = [$output_directory ($f | path relative-to $beets_directory)] | path join
        mkdir ($target | path dirname)
        mv $f $target
      }
    )
  } else {
    (
      $music_files
      | zip $music_file_destinations
      | each {||
        log info $"Uploading (ansi yellow)($in.0)(ansi reset) to (ansi yellow)($in.1)(ansi reset)"
        $in.0 | ssh mv $ssh_server $in.1
      }
    )
  }

  if $delete {
    log debug "Deleting the original files"
    if ($original_item | str starts-with "ssh:") {
      (
        $original_music_files
        | each {|original|
          if $original in $music_file_destinations {
            log debug $"(ansi red_bold)Not(ansi reset) deleting the original file (ansi yellow)($original)(ansi reset) since it was overwritten by the updated file"
          } else {
            log info $"Deleting the original file on the server (ansi yellow)($original)(ansi reset)"
            ssh rm $original
          }
        }
      )
    } else {
      log info $"Deleting the original files (ansi yellow)($original_music_files)(ansi reset)"
      (
        $original_music_files
        | each {|original|
          log info $"Deleting the original file (ansi yellow)($original)(ansi reset)"
          rm $original
        }
      )
      # todo Remove empty directories?
    }
  }
  log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
  rm --force --recursive $temporary_directory

  # } catch {|err|
  #     log error $"Import of (ansi red)($original_item)(ansi reset) failed!\n($err.msg)\n"
  #     continue
  # }

  }
}
