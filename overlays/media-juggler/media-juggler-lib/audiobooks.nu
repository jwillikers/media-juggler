# Functions for tagging audiobooks

use std log

use acoustid.nu *
use audio.nu *
use chapters.nu *
use hardcover.nu *
use musicbrainz.nu *
use tone.nu *
use utils.nu *
use wikidata.nu *

# Determine whether the length of tracks in one set are within a given threshold compared to tracks in another set
export def equivalent_track_durations [
  right: table<index: int, duration: duration>
  threshold: duration = 3sec # The allowed drift between the duration of tracks
]: table<index: int, duration: duration> -> bool {
  let left = $in
  let joined = ($left | rename index left_duration) | join ($right | rename index right_duration) index
  (
    # Same number of tracks
    ($left | length) == ($right | length)
    # Same indices
    and ($joined | length) == ($right | length)
    # Difference is within threshold
    and (
      $joined | all {|track|
        (($track.left_duration - $track.right_duration) | math abs) <= $threshold
      }
    )
  )
}

# Determine if two sets of contributors have at least one distributor in common
#
# If both sets are empty, true is returned.
export def has_distributor_in_common [
  right: table<id: string, name: string, entity: string, role: string>
]: [
  table<id: string, name: string, entity: string, role: string> -> bool
  nothing -> bool
] {
  let left = $in
  # log debug $"has_distributor_in_common: right: ($right | to json)"
  # log debug $"has_distributor_in_common: left: ($left | to json)"
  if ($right | is-empty) and ($left | is-empty) {
    return true
  }
  let right_distributors = (
    if ($right | is-empty) {
      []
    } else {
      $right | where role == "distributor"
    }
  )
  let left_distributors = (
    if ($left | is-empty) {
      []
    } else {
      $left | where role == "distributor"
    }
  )
  # log debug $"has_distributor_in_common: right_distributors: ($right_distributors | to json)"
  # log debug $"has_distributor_in_common: left_distributors: ($left_distributors | to json)"
  if ($left_distributors | is-empty) and ($right_distributors | is-empty) {
    return true
  }
  if ($left_distributors | is-empty) or ($right_distributors | is-empty) {
    return false
  }
  let joined_on_id = (
    $left_distributors
    | rename id left_name left_entity
    | join ($right_distributors | rename id right_name right_entity) id
    | where {|distributor|
      $distributor.left_entity == $distributor.right_entity
    }
  )
  if ($joined_on_id | is-not-empty) {
    return true
  }
  let joined_on_name = (
    $left_distributors
    | rename left_id name left_entity
    | join ($right_distributors | rename right_id name right_entity) name
  )
  if ($joined_on_name | is-empty) {
    return false
  }
  $joined_on_name | any {|distributor|
    (
      $distributor.left_entity == $distributor.right_entity
      and (
        ($distributor.left_id | is-empty)
        or ($distributor.right_id | is-empty)
      )
    )
  }
}

# Given a list of MusicBrainz Release audiobook metadata records and metadata of an audiobook, attempt to narrow down the matching releases
#
# The chapters release must be within the duration threshold and must be from the same distributor if one is set.
export def filter_musicbrainz_releases [
  metadata: record<book: record, tracks: table> # Audiobook metadata
  duration_threshold: duration = 3sec # The allowed drift between the duration of tracks
]: table<book: record, tracks: table> -> list<string> {
  let candidates = $in
  # log info $"candidates: ($candidates | to nuon)"
  # log info $"metadata: ($metadata | reject tracks.embedded_pictures | to nuon)"

  if ($metadata | is-empty) or "book" not-in ($metadata) or "tracks" not-in ($metadata) or ($metadata.tracks | is-empty) {
    return null
  }

  if "musicbrainz_release_id" in $metadata.book and ($metadata.book.musicbrainz_release_id | is-not-empty) {
    return [$metadata.book.musicbrainz_release_id]
  }

  # Filter based on the Audible ASIN, track durations, and distributor

  let candidates = (
    if ($metadata.book | get --optional audible_asin | is-empty) {
      $candidates
    } else {
      $candidates | where {|candidate|
        ($candidate.book | get --optional audible_asin) == $metadata.book.audible_asin
      }
    }
  )
  if ($candidates | is-empty) {
    return null
  }
  if ($candidates | length) == 1 {
    return $candidates.book.musicbrainz_release_id
  }

  let candidates = (
    # If for some reason tracks are missing from the audiobook, this won't filter anything based on track lengths
    if ($metadata.tracks | length) == $metadata.book.total_tracks {
      $candidates | where {|candidate|
        $candidate.tracks | select index duration | equivalent_track_durations ($metadata.tracks | select index duration) $duration_threshold
      }
    } else {
      $candidates
    }
  )
  if ($candidates | is-empty) {
    return null
  }
  if ($candidates | length) == 1 {
    return $candidates.book.musicbrainz_release_id
  }

  let candidates = (
    $candidates | where {|candidate|
      $candidate.book | get --optional contributors | has_distributor_in_common ($metadata.book | get --optional contributors)
    }
  )
  if ($candidates | is-empty) {
    return null
  }
  $candidates.book.musicbrainz_release_id
}

# Tag the files of an audiobook
#
# This function will attempt to identify audiobooks using available information in the following order.
# 1. Embedded MusicBrainz Release and Recording IDs
# 2. Embedded AcoustID fingerprints
# 3. Calculated AcoustID fingerprints
# 4. Via MusicBrainz search using the existing metadata
#
# If results for none of these methods is conclusive, it's recommended to provide the MusicBrainz Release ID.
# AcoustID fingerprints will be submitted automatically when they are not already embedded in the file along with the corresponding MusicBrainz Recording IDs.
# AcoustID fingerprints are also not submitted when they are successfully retrieved from the server.
#
# When an audiobook consists of multiple files, the caller must order the files correctly when the track number tag is missing and MusicBrainz Recording IDs can't be determined via AcoustID or embedded tags.
# I might add logic here in the future to allow ordering recordings based on the natural order of the titles, but track number is usually embedded.
export def tag_audiobook [
  working_directory: directory
  cover_art_directory: directory
  cache: closure # Function to call to check for or update cached values. Looks like {|type, id, update_function| ...}
  submit_all_acoustid_fingerprints = false # AcoustID fingerprints are only submitted for files where one or both of the AcoustID fingerprints and MusicBrainz Recording IDs are updated from the values present in the embedded metadata. Set this to true to submit all AcoustIDs regardless of this.
  combine_chapter_parts = false # Combine chapters split into multiple parts into individual chapters
  ignore_embedded_acoustid_fingerprints = false # Recalculate AcoustID fingerprints for all files
  ignore_embedded_musicbrainz_ids = false # Ignore existing MusicBrainz IDs embedded in the files
  fail_fast = true # Immediately return null when a fingerprint has no matches that meet the threshold score
  --search-score-threshold: int = 100 # An int value between zero and one hundred, the minimum score required to be considered a match when searching MusicBrainz
  --max-track-duration-difference: duration = 3sec # The maximum allowable difference between track durations
  --acoustid-score-threshold: float = 1.0 # A float value between zero and one, the minimum score required to be considered a match when searching AcoustID fingerprints
  --acoustid-client-key: string # The application API key for the AcoustID server
  --acoustid-user-key: string # The user API key for the AcoustID server. Required to look up fingerprints starting January 1, 2027. AcoustID fingerprints are only submitted when this is provided.
  --musicbrainz-release-id: string = "" # The MusicBrainz Release ID associated with the release
  --api-requests-per-second: int = 3 # The number of API requests to make per second. AcoustID only permits up to three requests per second.
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: list<path> -> record<book: record, tracks: table> {
  let audiobook_files = $in
  if ($audiobook_files | is-empty) {
    log error "No audiobook files provided!"
    return null
  }

  let metadata = $audiobook_files | parse_audiobook_metadata_from_files

  # Create a copy of the original embedded metadata to see if AcoustID Fingerprints should be submitted at then end
  let original_metadata = $metadata

  # log info $"$metadata: ($metadata)"

  if "tracks" not-in $metadata or ($metadata.tracks | is-empty) {
    # This shouldn't ever happen
    log error "No track metadata!"
    return null
  }

  let metadata = (
    if ($musicbrainz_release_id | is-not-empty) {
      # todo Wipe existing recording ids here to ensure they don't effect tagging
      # Or otherwise ensure they won't be an issue when tagging
      $metadata | upsert book.musicbrainz_release_id $musicbrainz_release_id
    } else {
      $metadata
    }
  )

  # If missing MusicBrainz Release and/or Recording IDs, try using AcoustID
  let acoustid_metadata = (
    if (
      ($musicbrainz_release_id | is-empty)
      and (
        ($metadata.book | get --optional musicbrainz_release_id | is-empty)
        or (
          $metadata.tracks
          | any {|track|
            "musicbrainz_recording_id" not-in $track or ($track.musicbrainz_recording_id | is-empty)
          }
        )
      )
    ) {
      (
        $metadata
        | (
          get_musicbrainz_ids_by_acoustid
          $acoustid_client_key
          $ignore_embedded_acoustid_fingerprints
          $fail_fast
          --user-key $acoustid_user_key
          --threshold $acoustid_score_threshold
          --api-requests-per-second $api_requests_per_second
          --retries $retries
          --retry-delay $retry_delay
        )
      )
    }
  )
  let metadata = (
    if ($acoustid_metadata | is-empty) {
      $metadata
    } else {
      $acoustid_metadata
    }
  )

  let metadata = (
    if (
      ($musicbrainz_release_id | is-empty)
      and ($metadata.book | get --optional musicbrainz_release_id | is-empty)
    ) {
      log info $"Unable to determine MusicBrainz Recording and Release IDs using AcoustID fingerprints"
      let release_candidates = $metadata | search_for_musicbrainz_release --retries $retries --retry-delay $retry_delay
      if ($release_candidates | is-empty) {
        log error $"Unable to find any matching MusicBrainz releases. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
        $metadata
      } else {
        let release_candidates = $release_candidates | where score >= $search_score_threshold
        if ($release_candidates | is-empty) {
          log error $"Unable to find any matching MusicBrainz releases with a perfect score. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
          $metadata
        } else if ($release_candidates | length) > 20 {
          log error $"Found over 20 matching MusicBrainz releases. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
          $metadata
        } else if ($release_candidates | length) == 1 {
          let release_candidate = $release_candidates.id | first
          log info $"Found matching MusicBrainz Release (ansi yellow)($release_candidate)(ansi reset)"
          $metadata | upsert book.musicbrainz_release_id $release_candidate
        } else {
          log debug $"Found multiple MusicBrainz releases with a perfect score. Attempting to narrow down further based on the distributor and track lengths"
          let $release_candidates = $release_candidates | get id | each {|candidate|
            let received_metadata = $candidate | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay $cache [label-rels recordings url-rels]
            if ($received_metadata | is-empty) {
              log error $"Error fetching metadata for MusicBrainz Release (ansi yellow)($candidate)(ansi reset)"
              null
            } else {
              $received_metadata
            }
          }
          if ($release_candidates | any {|r| $r == null}) {
            return null
          }
          let release_candidates = $release_candidates | filter_musicbrainz_releases $metadata $max_track_duration_difference
          if ($release_candidates | is-empty) {
            log error $"Unable to find any matching MusicBrainz releases after filtering. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
            $metadata
          } else if ($release_candidates | length) == 1 {
            let release_candidate = $release_candidates | first
            log info $"Found matching MusicBrainz Release (ansi yellow)($release_candidate)(ansi reset) after filtering"
            $metadata | upsert book.musicbrainz_release_id $release_candidate
          } else {
            # todo Interactively allow selecting an available release
            log error $"Multiple matching MusicBrainz releases remaining after filtering. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
            $metadata
          }
        }
      }
    } else {
      log info $"Successfully determined the MusicBrainz Recording and Release IDs using AcoustID fingerprints"
      $metadata
    }
  )

  # todo Validate MBIDs when parsing them.

  if ($metadata | is-empty) or "book" not-in $metadata or "musicbrainz_release_id" not-in $metadata.book or ($metadata.book.musicbrainz_release_id | is-empty) {
    log error "Unable to determine the MusicBrainz Release ID. Aborting. Please supply the MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
    return null
  }

  # Tag the files
  let metadata = (
    $metadata
    | (
      tag_audiobook_tracks_by_musicbrainz_release_id
      $working_directory
      $cover_art_directory
      $cache
      $combine_chapter_parts
      --retries $retries
      --retry-delay $retry_delay
    )
  )
  if ($metadata | is-empty) {
    log error "Failed to tag audio tracks!"
    return null
  }

  # Submit AcoustID fingerprints
  if ($acoustid_user_key | is-not-empty) {
    # Calculate the AcoustID fingerprint if necessary
    let tracks = (
      $metadata.tracks | each {|track|
        if ($track | get --optional "acoustid_fingerprint" | is-empty) {
          $track | get_acoustid_fingerprint_track $ignore_embedded_acoustid_fingerprints
        } else {
          $track
        }
      }
    )
    # Filter out tracks where the MusicBrainz Recording IDs were successfully retrieved by using their AcoustID fingerprints.
    # That means that the AcoustID fingerprints already exist on the server and don't need to be submitted.
    let tracks = (
      if $submit_all_acoustid_fingerprints {
        $tracks
      } else {
        if ($acoustid_metadata | is-empty) {
          $tracks
        } else {
          # Don't filter out tracks where the retrieved MusicBrainz Recording ID differs from the one the track ended up with at the end
          (
            $tracks
            | join ($acoustid_metadata.tracks | rename --column {musicbrainz_recording_id: "retrieved_musicbrainz_recording_id"}) file
            | where {|track|
              $track.musicbrainz_recording_id != $track.retrieved_musicbrainz_recording_id
            }
          )
        }
      }
    )
    # Filter out tracks which already had the embedded AcoustID fingerprint and corresponding MusicBrainz Recording ID.
    let tracks = (
      if $submit_all_acoustid_fingerprints {
        $tracks
      } else {
        if (
          "acoustid_fingerprint" in ($original_metadata.tracks | columns)
          and "musicbrainz_recording_id" in ($original_metadata.tracks | columns)
        ) {
          # We have both acoustid_fingerprint and musicbrainz_recording_id columns, but one or the other could be missing for individual tracks
          (
            $original_metadata.tracks
            | rename --column {
              acoustid_fingerprint: "original_acoustid_fingerprint"
              musicbrainz_recording_id: "original_musicbrainz_recording_id"
            }
            | join $tracks file
            # Filter out tracks with consistent fingerprints and recording ids
            | where {|track|
              # Double check if original values are missing or empty for each individual track
              if ($track | get --optional original_acoustid_fingerprint | is-empty) or ($track | get --optional original_musicbrainz_recording_id | is-empty) {
                true
              } else {
                not (
                  $track.original_acoustid_fingerprint == $track.acoustid_fingerprint
                  and $track.original_musicbrainz_recording_id == $track.musicbrainz_recording_id
                )
              }
            }
          )
        } else {
          $tracks
        }
      }
    )
    # log info $"tracks: ($tracks)"
    if ($tracks | is-empty) {
      log info "No AcoustID fingerprints will be submitted since tracks already had corresponding AcoustID fingerprints and MusicBrainz Recording IDs on the AcoustID server or embedded in their metadata."
    } else {
      # log info $"$tracks: ($tracks | reject embedded_pictures)"
      let acoustid_submissions = (
        $tracks
        # Missing AcoustID fingerprints are possible for tracks with very short durations.
        # Filter those out.
        | where {|track| ($track | get --optional acoustid_fingerprint | is-not-empty) }
        | where {|track| ($track | get --optional duration | is-not-empty) and $track.duration != 0ms }
        | select index musicbrainz_recording_id duration acoustid_fingerprint title artist_credit disc_number file
        | rename index musicbrainz_recording_id duration fingerprint title track_artist_credit disc_number file
        | default $metadata.book.title release_title
        | default $metadata.book.artist_credit release_artist_credit
        # | default $metadata.book.publication_date release_date
        # | each {|track|
        #   if "disc_number" not-in $track or $track.disc_number == null {
        #     $track | upsert disc_number null
        #   } else {
        #     $track | upsert disc_number $track.disc_number
        #   }
        # }
        | each {|track|
          let bit_rate = (
            # todo Uncomment this if needed
            # try {
              # log debug $"tag_audiobook: Parsing audio bit rate for file: ($track.file)";
              $track.file | ffprobe | parse_ffprobe_audio_bit_rate
            # } catch {|error|
            #   null
            # }
          )
          # log info $"track: ($track | to json)"
          # log info $"track columns: ($track | columns)"
          # log info $"bit_rate: ($bit_rate)"
          if ($bit_rate | is-empty) {
            log info "tag_audiobook: Failed to parse audio bit rate from file --brief output"
            $track | upsert bit_rate 0
          } else {
            $track | upsert bit_rate $bit_rate
          }
        }
        # The release date is converted to a string somehow by the default command above.
        # Convert it back to a datetime here to fix it.
        | upsert release_date ($metadata.book.publication_date | into datetime)
        | each {|track|
          # log info $"track: ($track | to json)"
          # log info $"track columns: ($track | columns)"
          let file_format = $track.file | ffprobe | parse_ffprobe_file_format
          if $file_format == null {
            log error "tag_audiobook: Failed to parse file format from ffprobe output"
            $track
          } else {
            $track | upsert file_format $file_format
          }
        }
        | reject file
        | submit_acoustid_fingerprints $acoustid_client_key $acoustid_user_key --retries $retries --retry-delay $retry_delay
      )
      log debug $"AcoustID submissions: ($acoustid_submissions | to nuon)"
      if $acoustid_submissions == null {
        log error $"tag_audiobook: Failed to submit AcoustID fingerprints!"
      } else if ($acoustid_submissions | is-empty) {
        log info "tag_audiobook: No AcoustID fingerprints were eligible for submission"
      } else {
        log info $"Submitted AcoustID fingerprints: ($acoustid_submissions | to nuon)"
      }
    }
  }

  $metadata
}

# Filter and sort audiobooks based on the chapters tag, returning only the audiobooks which have the highest chapters count
export def audiobooks_with_the_highest_voted_chapters_tag []: table<id: string, tags: table<name: string, count: int>> -> list<string> {
  let candidates = $in
  if ($candidates | is-empty) {
    return null
  }
  let candidates_with_chapters_tag = $candidates | where {|candidate|
    "chapters" in $candidate.tags.name
  }
  if ($candidates_with_chapters_tag | is-empty) {
    return null
  }
  if ($candidates_with_chapters_tag | length) == 1 {
    return ($candidates_with_chapters_tag | get id)
  }
  let sorted_candidates = (
    $candidates_with_chapters_tag
    | sort-by --custom {|a, b|
      (
        ($a.tags | where name == "chapters" | get count | first)
        >=
        ($b.tags | where name == "chapters" | get count | first)
      )
    }
  )
  let highest_count = ($sorted_candidates | first | get tags | where name == "chapters" | get count | first)
  $sorted_candidates | where {|candidate|
    ($candidate.tags | where name == "chapters" | get count | first) >= $highest_count
  } | get --optional id | sort
}

# Given a number of audiobooks and a target audiobook, narrow down the audiobooks that can be used as chapters for the target audiobook
export def filter_musicbrainz_chapters_releases [
  release: record<book: record, tracks: table>
  duration_threshold: duration = 3sec # The allowed drift between the duration of the release and a candidate chapters release
]: table<book: record, tracks: table> -> table<book: record, tracks: table> {
  let candidates = $in
  # log info $"candidates: ($candidates | to nuon)"
  # log info $"release: ($release | reject tracks.embedded_pictures | to nuon)"

  let candidates = (
    if ($release.book | get --optional audible_asin | is-empty) {
      $candidates
    } else {
      $candidates | where {|candidate|
        ($candidate.book | get --optional audible_asin) == $release.book.audible_asin
      }
    }
  )
  if ($candidates | is-empty) {
    return null
  }

  let candidates = $candidates | where {|candidate|
    if ($release.tracks | length) >= ($candidate.tracks | length) {
      log debug $"Disqualified MusicBrainz Release chapters candidate (ansi green)($candidate.book.musicbrainz_release_id)(ansi reset) because it has (ansi purple)($candidate.tracks | length)(ansi reset) which is less than (ansi purple)($release.tracks | length)(ansi reset)"
      return false
    }
    if ((($release.tracks | get duration | math sum) - ($candidate.tracks | get duration | math sum)) | math abs) > $duration_threshold {
      log debug $"Disqualified MusicBrainz Release chapters candidate (ansi green)($candidate.book.musicbrainz_release_id)(ansi reset) because it's total duration (ansi purple)($candidate.tracks | get duration | math sum)(ansi reset) is above the threshold (ansi purple)($duration_threshold)(ansi reset) compared against the duration of the release (ansi purple)($release.tracks | get duration | math sum)(ansi reset)"
      return false
    }
    if not ($candidate.book | get --optional contributors | has_distributor_in_common ($release.book | get --optional contributors)) {
      log debug $"Disqualified MusicBrainz Release chapters candidate (ansi green)($candidate.book.musicbrainz_release_id)(ansi reset) because it does not share the same distributors"
      return false
    }
    true
  }
  if ($candidates | is-empty) {
    return null
  }
  if ($candidates | length) == 1 {
    return $candidates
  }
  # Use the chapters tag to decide between multiple remaining candidates
  if "tags" in ($candidates.book | columns) {
    let highest_voted_chapters = (
      $candidates.book | each {|book|
        let release_tags = (
          $book.tags
          | where scope == "release"
          | reject --optional scope
        )
        {
          id: $book.musicbrainz_release_id
          tags: $release_tags
        }
      } | audiobooks_with_the_highest_voted_chapters_tag
    )
    $candidates | where book.musicbrainz_release_id in $highest_voted_chapters
  } else {
    return $candidates
  }
}

# Given a release, attempt to find a release in the same release group that has more tracks.
#
# The chapters release must be within the duration threshold and must be from the same distributor if one is set.
#
# Input is the parsed metadata of the MusicBrainz release.
# The output is the chapters in a table formatted for a tone JSON file
export def look_up_chapters_from_similar_musicbrainz_release [
  cache: closure # Function to call to check for or update cached values. Looks like {|type, id, update_function| ...}
  duration_threshold: duration = 3sec # The allowed drift between the duration of the release and a candidate chapters release
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: record -> table<index: int, start: duration, length: duration, title: string> {
# ]: table -> table<index: int, start: duration, length: duration, title: string> {
  let release = $in
  if "musicbrainz_release_group_id" not-in $release.book or ($release.book.musicbrainz_release_group_id | is-empty) {
    return null
  }

  let num_tracks = ($release.tracks | length)

  let allowed_statuses = ["official", "pseudo-release"]

  # "https://musicbrainz.org/ws/2/release/?fmt=json&query="
  let url = "https://musicbrainz.org/ws/2/release/"
  let query = $"rgid:($release.book.musicbrainz_release_group_id) AND NOT tracks:1 AND \(status:official OR status:pseudo-release\) AND NOT reid:($release.book.musicbrainz_release_id)"

  let query = (
    $query
    | append_to_musicbrainz_query $release.book musicbrainz_release_country country
    # todo Store year specially compared to full date?
    | append_to_musicbrainz_query $release.book publication_date date --transform {|d|
      let date = $d | format date '%Y-%m-%d'
      if ($date | str ends-with "-01-01") {
        $date | str replace "-01-01" ""
      } else {
        $date
      }
    }
    | append_to_musicbrainz_query $release.book amazon_asin asin
    | append_to_musicbrainz_query $release.book isbn barcode
    | append_to_musicbrainz_query $release.book language lang
    | append_to_musicbrainz_query $release.book script script
  )

  # log info $"query: ($query)"
  let query = $query | url encode
  let request = {musicbrainz_get $"($url)?query=($query)"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error searching for similar releases: ($url)?query=($query)\t($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code ($response.status) when searching for similar releases: ($url)?query=($query)"
    return null
  }

  let candidates = $response | get body | get releases | where score == 100 | get --optional id
  if ($candidates | is-empty) {
    return null
  }
  # Don't parallelize for the sake of the MusicBrainz API
  let candidates = $candidates | each {|candidate|
    let received_metadata = $candidate | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay $cache [recordings label-rels tags url-rels]
    if ($received_metadata | is-empty) {
      log error $"Error fetching metadata for MusicBrainz Release (ansi yellow)($candidate)(ansi reset)"
      return null
    }
    $received_metadata
  }

  # log info $"$release ($release)"
  # log info $"candidates: ($candidates)"
  let candidates = $candidates | filter_musicbrainz_chapters_releases $release $duration_threshold
  if ($candidates | is-empty) {
    log warning $"No MusicBrainz Release candidates for chapters found. Please add or vote up the chapters tag on the desired release."
    return null
  }
  if ($candidates | length) > 1 {
    log warning $"More than one MusicBrainz Release candidate for chapters found: ($candidates | get book.id). Please add or vote up the chapters tag on the desired release."
    return null
  }
  let candidate = $candidates | first
  log info $"Using the MusicBrainz Release (ansi yellow)($candidate.book.musicbrainz_release_id)(ansi reset) for chapters"
  $candidate | get book.chapters
}

# Tag the given audio files using the given MusicBrainz release id
#
# The individual audio files should be provided in a table as input.
# The file key should be used for the path of each file on disk.
#
# The table can also include the MusicBrainz Recording ID using the musicbrainz_recording_id key.
# This ensures that each track is associated with the correct recording.
# It's particularly useful for associating files with recordings using AcoustID fingerprints.
# Without the MusicBrainz Recording ID, tracks must be provided in the correct order as they appear on the release.
# The tracks will be checked against their expected durations in this case to ensure correctness.
#
# In addition to the musicbrainz_recording_id key, the acoustid_fingerprint, audio_duration, and acoustid_track_id tags can also be included.
# The acoustid_fingerprint and acoustid_track_id will be embedded in the files with the other metadata.
# The audio_duration value is used to avoid recalculating the duration of the audio.
# export def tag_audiobook_files_by_musicbrainz_release_id [
#   release_id: string
#   working_directory: directory
#   duration_threshold: duration = 2sec # The acceptable difference in track length of the file vs. the length of the track in MusicBrainz
#   chapters_duration_threshold: duration = 3sec # The acceptable difference in the duration of the release vs. the duration of a MusicBrainz Release for chapters
#   --retries: int = 3
#   --retry-delay: duration = 5sec
# ]: table -> list<path> {
#   let audiobook_files = $in
#   # let current_metadata = (
#   #   $audiobook_files | parse_audiobook_metadata_from_files
#   # )
#   let metadata = (
#     $release_id | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay
#   )
#   if ($metadata | is-empty) {
#     log error $"Failed to fetch MusicBrainz Release (ansi yellow)($release_id)(ansi reset)"
#     return null
#   }
#   # log info $"audiobook_files: ($audiobook_files)"
#   # log info $"audiobook_files.metadata.track: ($audiobook_files.metadata.track)"
#   let tracks = (
#     if (
#       "musicbrainz_recording_id" in ($audiobook_files | columns)
#       and ($audiobook_files.musicbrainz_recording_id | is-not-empty)
#     ) {
#       $metadata.tracks | join $audiobook_files musicbrainz_recording_id
#     } else {
#       let enumerated_audiobook_files = (
#         $audiobook_files | enumerate | each {|f|
#           {
#             index: ($f.index + 1)
#             file: $f.item.file
#           }
#         }
#       )
#       $metadata.tracks | join $enumerated_audiobook_files index
#     }
#   )
#   # log info $"tracks: ($tracks)"
#   for track in $tracks {
#     let duration = (
#       if "audio_duration" in $track and ($track.audio_duration | is-not-empty) {
#         $track.audio_duration
#       } else {
#         $track.file | tone_dump | get audio.duration | into int | into duration --unit ms
#       }
#     )
#     if ($track.duration - $duration | math abs) > $duration_threshold {
#       log error $"The (ansi green)($track)(ansi reset) is ($duration) long, but the MusicBrainz track is ($track.duration) long, which is outside the acceptable duration threshold of ($duration_threshold)"
#       return null
#     }
#   }

#   let chapters = (
#     if ($metadata | get --optional chapters | is-empty) {
#       $metadata | look_up_chapters_from_similar_musicbrainz_release $chapters_duration_threshold --retries $retries --retry-delay $retry_delay
#     } else {
#       $metadata.chapters
#     }
#   )
#   # log info $"Chapters: ($chapters)"

#   let front_cover = (
#     if "front_cover_available" in $metadata.book and $metadata.book.front_cover_available {
#       $metadata.book.musicbrainz_release_id | fetch_release_front_cover $working_directory
#     }
#   )

#   # let chapters_file = mktemp --suffix ".txt" --tmpdir
#   # if ($chapters | is-not-empty) {
#   #   $chapters | chapters_into_chapters_txt_format | save --force $chapters_file
#   # }

#   let files = (
#     $metadata
#     | update tracks $tracks
#     | reject --optional book.embedded_pictures
#     | (
#       let input = $in;
#       if ($chapters | is-not-empty) {
#         $input | upsert book.chapters $chapters
#       } else {
#         $input
#       }
#     )
#     | (
#       tone_tag_tracks $working_directory
#       "--taggers" 'remove,*'
#       # Remove all sort fields
#       "--meta-remove-property" "sortalbum"
#       "--meta-remove-property" "sorttitle"
#       "--meta-remove-property" "sortalbumartist"
#       "--meta-remove-property" "sortartist"
#       "--meta-remove-property" "sortcomposer"
#       "--meta-remove-property" "EmbeddedPictures"
#       "--meta-remove-property" "comment"
#       "--meta-cover-file" $front_cover
#       # "--meta-chapters-file" $chapters_file
#     )
#   )

#   # Clean up
#   if ($front_cover | is-not-empty) {
#     rm $front_cover
#   }
#   # if ($chapters_file | is-not-empty) {
#   #   rm $chapters_file
#   # }

#   $files
# }

# Tag the given audiobook tracks using the MusicBrainz Release ID and certain other metadata
#
# The individual audio files should be provided in a table as input.
# The file key should be used for the path of each file on disk.
#
# The table can also include the MusicBrainz Recording ID using the musicbrainz_recording_id key.
# This ensures that each track is associated with the correct recording.
# It's particularly useful for associating files with recordings using AcoustID fingerprints.
# Without the MusicBrainz Recording ID, tracks must be provided in the correct order as they appear on the release.
# The tracks will be checked against their expected durations in this case to ensure correctness.
#
# In addition to the musicbrainz_recording_id key, the acoustid_fingerprint, audio_duration, and acoustid_track_id tags can also be included.
# The acoustid_fingerprint and acoustid_track_id will be embedded in the files with the other metadata.
# The audio_duration value is used to avoid recalculating the duration of the audio.
export def tag_audiobook_tracks_by_musicbrainz_release_id [
  working_directory: directory
  cover_art_directory: directory
  cache: closure
  combine_chapter_parts = false # Combine chapters split into multiple parts into individual chapters
  # todo Expose duration threshold as a command-line option for situations where it needs to be increased.
  duration_threshold: duration = 2sec # The acceptable difference in track length of the file vs. the length of the track in MusicBrainz
  chapters_duration_threshold: duration = 3sec # The acceptable difference in the duration of the release vs. the duration of a MusicBrainz Release for chapters
  --retries: int = 3
  --retry-delay: duration = 5sec
]: record<book: record, tracks: table> -> record<book: record, tracks: table> {
  let existing_metadata = $in
  if "book" not-in $existing_metadata or "musicbrainz_release_id" not-in $existing_metadata.book or ($existing_metadata.book.musicbrainz_release_id | is-empty) {
    log error "Missing MusicBrainz Release ID"
    return null
  }
  if "tracks" not-in $existing_metadata or ($existing_metadata.tracks | is-empty) {
    log error "Missing tracks to tag"
    return null
  }
  # Keep / rename only the necessary columns
  let existing_metadata = (
    $existing_metadata | upsert tracks (
      # Rename duration column to audio_duration
      $existing_metadata.tracks | insert audio_duration {|track| $track.duration}
    )
  )
  let musicbrainz_metadata = (
    $existing_metadata.book.musicbrainz_release_id | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay $cache
  )
  if ($musicbrainz_metadata | is-empty) {
    log error $"Failed to fetch MusicBrainz Release (ansi yellow)($existing_metadata.book.musicbrainz_release_id)(ansi reset)"
    return null
  }

  # Look up the Hardcover IDs for the book based on ISBN or Audible ASIN.
  let hardcover_edition = (
    if (($musicbrainz_metadata.book | get --optional isbn | is-not-empty) or ($musicbrainz_metadata.book | get --optional audible_asin | is-not-empty)) and (($musicbrainz_metadata.book | get --optional hardcover_edition_id | is-empty) or ($musicbrainz_metadata.book | get --optional hardcover_book_slug | is-empty)) {
      let id = (
        if ($musicbrainz_metadata.book | get --optional isbn | is-not-empty) {
          { type: "isbn_13", value: $musicbrainz_metadata.book.isbn }
        } else if ($musicbrainz_metadata.book | get --optional audible_asin | is-not-empty) {
          { type: "asin", value: $musicbrainz_metadata.book.audible_asin }
        }
      )
      let editions = $id.value | hardcover_search_editions_by_exact_field --retries $retries --retry-delay $retry_delay $id.type
      if ($editions | is-empty) {
        # No editions found.
        log warning $"No Hardcover editions found for ($id.type) (ansi purple)($id.value)(ansi reset)"
        null
      } else {
        # Reading format (1=Physical, 2=Audio, 3=Both, 4=Ebook)
        let audiobook_editions = $editions | where reading_format_id == 2
        if ($audiobook_editions | is-empty) {
          log warning $"No Hardcover audiobooks editions found for ($id.type) (ansi purple)($id.value)(ansi reset), matching non-audiobook editions: ($editions)"
          null
        } else if ($editions | length) == 1 {
          $audiobook_editions | first
        } else {
          log warning $"Multiple Hardcover audiobooks editions found for the ($id.type) (ansi purple)($id.value)(ansi reset): ($audiobook_editions)"
          null
        }
      }
    } else {
      # No ISBN or Audible ASIN, or the Hardcover edition id and book slug metadata is already available.
    }
  )
  let musicbrainz_metadata = (
    if ($hardcover_edition | is-empty) {
      $musicbrainz_metadata
    } else {
      (
        $musicbrainz_metadata
        | upsert book.hardcover_edition_id ($hardcover_edition.id | into string)
        | upsert book.hardcover_book_slug $hardcover_edition.book.slug
      )
    }
  )

  # Query Wikidata by ISBN or Amazon ASIN if there is no Wikidata edition ID.
  # I could also just query by MusicBrainz release ID...
  let wikidata_edition_id = (
    if ($musicbrainz_metadata.book | get --optional wikidata_edition_id | is-empty) and (($musicbrainz_metadata.book | get --optional isbn | is-not-empty) or ($musicbrainz_metadata.book | get --optional amazon_asin | is-not-empty)) {
      let id = (
        if ($musicbrainz_metadata.book | get --optional isbn | is-not-empty) {
          { type: "ISBN", value: $musicbrainz_metadata.book.isbn }
        } else if ($musicbrainz_metadata.book | get --optional amazon_asin | is-not-empty) {
          { type: "Amazon ASIN", value: $musicbrainz_metadata.book.amazon_asin }
        }
      )
      let editions = (
        if ($musicbrainz_metadata.book | get --optional isbn | is-not-empty) {
          $musicbrainz_metadata.book.isbn | wikidata_search_editions_by_isbn --retries $retries --retry-delay $retry_delay
        } else if ($musicbrainz_metadata.book | get --optional amazon_asin | is-not-empty) {
          $musicbrainz_metadata.book.amazon_asin | wikidata_search_editions_by_asin --retries $retries --retry-delay $retry_delay
        }
      )
      if ($editions | is-empty) {
        # No editions found.
        log warning $"No Wikidata editions found for ($id.type) (ansi purple)($id.value)(ansi reset)"
        null
      } else if ($editions | length) == 1 {
        $editions | first
      } else {
        log warning $"Multiple Wikidata editions found for the ($id.type) (ansi purple)($id.value)(ansi reset): ($editions)"
        null
      }
    } else {
      null
    }
  )
  let musicbrainz_metadata = (
    if ($wikidata_edition_id | is-empty) {
      $musicbrainz_metadata
    } else {
      $musicbrainz_metadata | upsert book.wikidata_edition_id $wikidata_edition_id
    }
  )

  # Pull Open Library identifiers from Wikidata.
  let wikidata_edition_identifiers = (
    if ($wikidata_edition_id | is-not-empty) and (($musicbrainz_metadata.book | get --optional open_library_edition_id | is-empty)) {
      $wikidata_edition_id | wikidata_get_edition_identifiers --retries $retries --retry-delay $retry_delay
    } else {
      null
    }
  )
  let open_library_edition_id = (
    if ($musicbrainz_metadata.book | get --optional open_library_edition_id | is-empty) and ($wikidata_edition_identifiers | is-not-empty) {
      let open_library_edition_ids = $wikidata_edition_identifiers | get --optional "Open Library ID"
      if ($open_library_edition_ids | is-empty) {
        log warning $"No Open Library edition IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset)"
        null
      } else if ($open_library_edition_ids | length) == 1 {
        $open_library_edition_ids | first
      } else {
        log warning $"Multiple Open Library edition IDs found for the Wikidata edition (ansi purple)($wikidata_edition_id)(ansi reset): ($open_library_edition_ids)"
        null
      }
    } else {
      null
    }
  )
  let musicbrainz_metadata = (
    if ($open_library_edition_id | is-empty) {
      $musicbrainz_metadata
    } else {
      $musicbrainz_metadata | upsert book.open_library_edition_id $open_library_edition_id
    }
  )
  # log debug $"musicbrainz_metadata: ($musicbrainz_metadata)"

  # log info $"audiobook_files: ($audiobook_files)"
  # log info $"musicbrainz_metadata: ($musicbrainz_metadata)"
  let tracks = (
    if (
      "musicbrainz_recording_id" in ($existing_metadata.tracks | columns)
      and ($existing_metadata.tracks.musicbrainz_recording_id | is-not-empty)
    ) {
      # todo Verify that no individual recording ids are missing?
      $musicbrainz_metadata.tracks | join --right $existing_metadata.tracks musicbrainz_recording_id
      # log info $"x: ($x | reject embedded_pictures | to nuon)"
    } else {
      let enumerated_tracks = (
        $existing_metadata.tracks | enumerate | each {|t|
          $t.item | upsert index ($t.index + 1)
        }
      )
      $musicbrainz_metadata.tracks | join $enumerated_tracks index
    }
  )

  # log info $"tracks: ($tracks)"
  for track in $tracks {
    let duration = (
      if "audio_duration" in $track and ($track.audio_duration | is-not-empty) {
        $track.audio_duration
      } else {
        log error $"The track (ansi green)($track)(ansi reset) is missing the field audio_duration!"
        return null
      }
    )
    if ($track.duration | is-empty) {
      log error $"The track (ansi green)($track)(ansi reset) has an empty duration field!"
      return null
    }
    if ($track.duration - $duration | math abs) > $duration_threshold {
      log error $"The (ansi green)($track)(ansi reset) is ($duration) long, but the MusicBrainz track is ($track.duration) long, which is outside the acceptable duration threshold of ($duration_threshold)"
      return null
    }
  }
  # log info $"musicbrainz_metadata: ($musicbrainz_metadata)"
  # log info $"tracks: ($tracks)"
  let musicbrainz_metadata = $musicbrainz_metadata | upsert tracks $tracks

  # This should only be necessary to check at the point where renaming occurs
  # Verify that there is only one release-group, work, or other kind of series for a book.
  # if "series" in $metadata.book and $metadata.book.series != null {
  #   if "scope" in ($metadata.book.series | columns) {
  #     let release_group_series = $metadata.book.series | where scope == "release group"
  #     if ($release_group_series | is-empty) {
  #       # Fall back to the work series if there is no release group series
  #       let work_series = $metadata.book.series | where scope == "work"
  #       if ($work_series | is-empty) {
  #         # Use whatever series exist are at this point
  #         if ($metadata.book.series | length) > 1 {
  #           log warning "More than one non release group / non work series exists when no release group series exist. Not yet able to determine series and subseries ordering."
  #         } else if ($metadata.book.series | length) == 1 {
  #           log warning "Will fall back to non release group / non work series because no release group or work series exist"
  #         }
  #       } else if ($work_series | length) != 1 {
  #         log warning "More than one work series exists when no release group series exist. Not yet able to determine series and subseries ordering."
  #       } else {
  #         log warning "Will fall back to work series because no release group series exists"
  #       }
  #     } else if ($release_group_series | length) != 1 {
  #       log warning $"More than one release group series exists. Not yet able to determine series and subseries ordering."
  #     }
  #   } else {
  #     log warning $"No scope available for series: ($metadata.book.series)"
  #   }
  # }

  # Fetch additional MusicBrainz Series info, such as genres, tags, and series relationships
  # todo Attach series to tracks?
  # todo Determine series order based on parent and subseries relationships
  let musicbrainz_metadata = (
    if ($musicbrainz_metadata | get --optional book.series | is-empty) {
      $musicbrainz_metadata
    } else {
      $musicbrainz_metadata | update book.series (
        $musicbrainz_metadata.book.series | each {|series|
          log debug $"series: ($series | to json)"
          let scope = $series.scope
          let index = $series.index
          (
            $series.id
            | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay
            | insert scope $scope
            | insert index $index
          )
        }
      )
    }
  )

  # Incorporate the series genres and tags into the book genres and tags.
  # Prefer those belonging to a series.
  let musicbrainz_metadata = (
    if ($musicbrainz_metadata | get --optional book.series | is-empty) {
      $musicbrainz_metadata
    } else {
      (
        $musicbrainz_metadata
        | upsert book.genres (
          $musicbrainz_metadata.book.series | reduce --fold [] {|series, acc|
            let genres = (
              if ($series | get --optional genres | is-empty) {
                []
              } else {
                $series.genres | default ($series.scope + " series") scope
              }
            )
            $genres | append $acc
          } | uniq-by name scope | append ($musicbrainz_metadata.book | get --optional genres)
        )
        | upsert book.tags (
          $musicbrainz_metadata.book.series | reduce --fold [] {|series, acc|
            let tags = (
              if ($series | get --optional tags | is-empty) {
                []
              } else {
                $series.tags | default ($series.scope + " series") scope
              }
            )
            $tags | append $acc
          } | uniq-by name scope | append ($musicbrainz_metadata.book | get --optional tags)
        )
      )
    }
  )

  # Fetch the genres and tags from the MusicBrainz Works
  # todo Apply series tags and genres of work series to relevant tracks?
  let musicbrainz_metadata = (
    $musicbrainz_metadata | update tracks (
      $musicbrainz_metadata.tracks | each {|track|
        if ($track | get --optional musicbrainz_works | is-empty) {
          $track
        } else {
          let musicbrainz_works = $track.musicbrainz_works | each {|musicbrainz_work|
            $musicbrainz_work | merge ($musicbrainz_work.id | fetch_and_parse_musicbrainz_work $cache --retries $retries --retry-delay $retry_delay)
          }
          let genres = $musicbrainz_works.genres | flatten | uniq-by name | default work scope
          let tags = $musicbrainz_works.tags | flatten | uniq-by name | default work scope
          (
            $track
            | update musicbrainz_works $musicbrainz_works
            | upsert genres (
              if ($track | get --optional genres | is-empty) {
                $genres
              } else {
                if ($genres | is-empty) {
                  $track | get --optional genres
                } else {
                  # Prefer the genres from the works
                  $genres | append $track.genres | uniq-by name scope
                }
              }
            )
            | upsert tags (
              if ($track | get --optional tags | is-empty) {
                $tags
              } else {
                if ($tags | is-empty) {
                  $track | get --optional tags
                } else {
                  # Prefer the tags from the works
                  $tags | append $track.tags | uniq-by name scope
                }
              }
            )
          )
        }
      }
    )
  )

  let chapters = (
    if "chapters" not-in $musicbrainz_metadata.book or ($musicbrainz_metadata.book.chapters | is-empty) {
      let chapters = $musicbrainz_metadata | look_up_chapters_from_similar_musicbrainz_release $cache $chapters_duration_threshold --retries $retries --retry-delay $retry_delay
      if ($chapters | is-not-empty) {
        $chapters
      } else {
        if "chapters" in $existing_metadata.book and ($existing_metadata.book.chapters | is-not-empty) {
          # todo Should probably add flag to select whether to lookup or reuse existing chapters
          $existing_metadata.book.chapters
        }
      }
    }
  )
  let chapters = (
    if ($chapters | is-empty) or not $combine_chapter_parts {
      $chapters
    } else {
      $chapters | combine_chapter_parts
    }
  )

  let front_cover = (
    if "front_cover_available" in $musicbrainz_metadata.book and $musicbrainz_metadata.book.front_cover_available {
      let cover_file = (
        $musicbrainz_metadata.book.musicbrainz_release_id
        | fetch_release_front_cover $cover_art_directory
      )
      if ($cover_file | is-empty) {
        log error $"Failed to fetch front cover for MusicBrainz Release (ansi yellow)($musicbrainz_metadata.book.musicbrainz_release_id)(ansi reset). Aborting."
        exit 1
      } else {
        $cover_file
      }
    }
  )

  let tone_args = (
    [
      "--taggers" 'remove,*'
      # Remove all sort fields
      "--meta-remove-property" "sortalbum"
      "--meta-remove-property" "sorttitle"
      "--meta-remove-property" "sortalbumartist"
      "--meta-remove-property" "sortartist"
      "--meta-remove-property" "sortcomposer"
      "--meta-remove-property" "comment"
    ]
    | append (
      if ($front_cover | is-not-empty) {
        # Drop any embedded pictures, only using the downloaded cover file
        ["--meta-remove-property" "EmbeddedPictures" "--meta-cover-file" $front_cover]
      }
    )
  )

  let files = (
    $musicbrainz_metadata
    | (
      let input = $in;
      if ($chapters | is-empty) {
        $input
      } else {
        $input | upsert book.chapters $chapters
      }
    )
    | (
      let input = $in;
      if ($front_cover | is-empty) {
        $input
      } else {
      # Drop any embedded pictures, only using the downloaded cover file
        $input | reject --optional book.embedded_pictures
      }
    )
    | tone_tag_tracks $working_directory ...$tone_args
  )
  if ($files | is-empty) {
    return null
  }

  $musicbrainz_metadata
}
