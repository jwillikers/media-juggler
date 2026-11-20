# Functions for calculating, looking up, and submitting AcoustID fingerprints

use std log

use constants.nu *
use tone.nu *
use utils.nu *

# Calculate the AcoustID of an audio file or files with the fpcalc utility
#
# fpcalc is part of the chromaprint package.
#
# Returns a record containing the duration and the fingerprint.
export def fpcalc []: list<path> -> table<file: path, fingerprint: string, duration: duration> {
  $in | par-each {|file|
    let file = $file | path expand
    let result = do {^fpcalc -json $file} | complete
    if $result.exit_code != 0 {
      if ("ERROR: Empty fingerprint" in $result.stderr) {
        log info $"Empty track '($file)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
        return {
          file: $file
          fingerprint: ""
          duration: 0ms
        }
      } else {
        log error $"Error running '^fpcalc -json ($file)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
        return null
      }
    }
    let track = $result.stdout | from json
    {
      file: $file
      fingerprint: $track.fingerprint
      duration: (($track.duration * 1000) | math round | into duration --unit ms)
    }
  }
}

# Find release and recording ids linked to an AcoustID fingerprint
#
# Requires an AcoustID application API key.
# Starting January 1, 2027, lookups also require an AcoustID user API key.
# See https://blog.acoustid.org/posts/2026-11-19-user-api-keys-required-for-lookups/
export def fetch_release_ids_by_acoustid_fingerprint [
  client_key: string # The application API key for the AcoustID server. Stored in the environment variable MEDIA_JUGGLER_ACOUSTID_CLIENT_KEY
  --user-key: string # The user API key for the AcoustID server. Stored in the environment variable MEDIA_JUGGLER_ACOUSTID_USER_KEY
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: record<file: path, duration: duration, fingerprint: string> -> record<file: path, http_response: table, result: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> {
  let input = $in

  # Currently, the server doesn't accept durations longer than 32767 seconds.
  # Issue: https://github.com/acoustid/acoustid-server/issues/43
  # PR: https://github.com/acoustid/acoustid-server/pull/179
  if ($input.duration > 32767sec) {
    log info "Duration longer than what is supported on the AcoustID Server"
    return null
  }

  let url = "https://api.acoustid.org/v2/lookup"

  let duration_seconds = ($input.duration / 1sec) | math round

  let payload = (
    $"format=json&meta=recordingids+releaseids&client=($client_key)&fingerprint=($input.fingerprint)&duration=($duration_seconds)"
    + (if ($user_key | is-not-empty) { $"&user=($user_key)" } else { "" })
  )
  let request = {||
    $payload
    | ^gzip --stdout
    | http post --content-type application/x-www-form-urlencoded --full --headers [Content-Encoding gzip] $url
  }

  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      # Don't log the payload since it contains the API keys
      log error $"Error looking up the AcoustID fingerprint for (ansi yellow)($input.file)(ansi reset) at ($url): ($error.msg)"
      return null
    }
  )

  if ($response.status != 200) {
    return {file: $input.file, "http_response": $response, result: null}
  }

  {
    file: $input.file
    http_response: $response
    result: ($response | get body)
  }
}

# Find the MusicBrainz releases linked to a set of AcoustID fingerprints
#
# Requires an AcoustID application API key.
# retries: int = 3 # The number of retries to attempt for a failed lookup request
export def fetch_release_ids_by_acoustid_fingerprints [
  client_key: string # The application API key for the AcoustID server
  --user-key: string # The user API key for the AcoustID server. Required for lookups starting January 1, 2027.
  threshold: float = 1.0 # A float value between zero and one, the minimum score required to be considered a match
  fail_fast = true # Immediately return null when a fingerprint has no matches that meet the threshold score
  api_requests_per_second: int = 3 # The number of API requests to make per second. AcoustID only permits up to three requests per second.
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: table<file: path, duration: duration, fingerprint: string> -> table<file: path, fingerprint: string, duration: duration, matches: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> {
  $in | chunks $api_requests_per_second | each {|chunk|
    let matches = (
      $chunk | par-each {|fingerprint|
        let result = $fingerprint | fetch_release_ids_by_acoustid_fingerprint $client_key --user-key $user_key --retries $retries --retry-delay $retry_delay
        # log info $"result: ($result)"
        if $result == null {
          log error $"Failed to lookup AcoustID fingerprint on the AcoustID server."
          return null
        }
        if $result.http_response.status != 200 {
          if $result.http_response.status in [401 403] {
            log error $"Failed to lookup AcoustID fingerprint on the AcoustID server. HTTP status code ($result.http_response.status). Check that the client and user API keys are correct."
            return null
          }
          log error $"Failed to lookup AcoustID fingerprint on the AcoustID server. HTTP status code ($result.http_response.status)."
          return null
        }
        let match = $result.result.results | where score >= $threshold
        if $fail_fast and ($match | is-empty) {
          return null
        }
        {
          file: $result.file
          fingerprint: $fingerprint.fingerprint
          duration: $fingerprint.duration
          matches: $match
        }
      }
    )
    sleep 1sec
    $matches
  } | flatten
}

# Attempt to find a release based on the AcoustID fingerprints of a set of tracks
#
# Takes as input a table of AcoustID fingerprints, track durations, and matches.
# This is the output of the fetch_release_ids_by_acoustid_fingerprints function.
#
# Returns the releases to which all tracks belong.
# export def determine_releases_from_acoustid_fingerprint_matches []: table<file: path, fingerprint: string, duration: duration, matches: table<id: string, recordings: table>> -> list<string> {
export def determine_releases_from_acoustid_fingerprint_matches []: table<file: path, fingerprint: string, duration: duration, matches: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> -> list<string> {
# table<file: path, fingerprint: string, duration: duration, matches: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> -> list<string>
  let tracks = $in
  if ($tracks | is-empty) {
    return null
  }
  let all_possible_release_ids = (
    $tracks | get matches | flatten | get recordings | flatten
  )
  let all_possible_release_ids = (
    if "releases" in ($all_possible_release_ids | columns) {
      $all_possible_release_ids | get releases | flatten | get id | uniq
    } else {
      return null
    }
  )
  $all_possible_release_ids | where {|release_id|
    $tracks | all {|track|
      $release_id in ($track | get matches | get recordings | flatten | get releases | flatten | get id)
    }
  }
}

# Submit AcoustID fingerprints to the AcoustID server
#
# Requires an AcoustID application API key and an AcoustID user API key.
export def submit_acoustid_fingerprints [
  client_key: string # The application API key for the AcoustID server
  user_key: string # The user's API key for the AcoustID server
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: table<index: int, musicbrainz_recording_id: string, duration: duration, fingerprint: string, title: string, track_artist_credit: string, disc_number: int, release_title: string, release_artist_credit: string, release_date: datetime, bit_rate: int, file_format: string> -> table<index: int, submission_id: string, submission_status: string> {
  let fingerprints = $in
  # log debug "submit_acoustid_fingerprints: Begin"
  # log debug $"fingerprints: ($fingerprints)"
  let endpoint = "https://api.acoustid.org/v2/submit"
  let submission_string = (
    $fingerprints | enumerate | reduce --fold "" {|it, acc|
      # Currently, the server doesn't accept durations longer than 32767 seconds.
      # Issue: https://github.com/acoustid/acoustid-server/issues/43
      # PR: https://github.com/acoustid/acoustid-server/pull/179
      if ($it.item.duration > 32767sec) {
        log error "Duration longer than what is supported on the AcoustID Server. Skipping submission"
        $acc
      } else {
        # The submission format is documented here: https://acoustid.org/webservice#submit

        # AcoustID seems to expect the bit rate in kbps from the example.
        let duration_seconds = ($it.item.duration / 1sec) | math round
        # log debug $"duration_seconds: ($duration_seconds)"
        let file_format = $it.item.file_format | str upcase
        # log debug $"file_format: ($file_format)"
        let year = $it.item.release_date | format date '%Y'
        # log debug $"year: ($year)"
        let track_submission = $"&trackno.($it.index)=($it.item.index)&fileformat.($it.index)=($file_format)&mbid.($it.index)=($it.item.musicbrainz_recording_id)&duration.($it.index)=($duration_seconds)&track.($it.index)=($it.item.title)&artist.($it.index)=($it.item.track_artist_credit)&album.($it.index)=($it.item.release_title)&albumartist.($it.index)=($it.item.release_artist_credit)&year.($it.index)=($year)&fingerprint.($it.index)=($it.item.fingerprint)"
        # log debug $"track_submission: ($track_submission)"
        let track_submission = (
          if "bit_rate" in $it.item and $it.item.bit_rate != null and $it.item.bit_rate > 0 {
            $track_submission + $"&bitrate.($it.index)=($it.item.bit_rate)"
          } else {
            $track_submission
          }
        )
        # log debug $"track_submission: ($track_submission)"
        let track_submission = (
          if "disc_number" in $it.item and $it.item.disc_number != null {
            $track_submission + $"&discno.($it.index)=($it.item.disc_number)"
          } else {
            $track_submission
          }
        )
        # log debug $"track_submission: ($track_submission)"
        # log debug $"acc + track_submission: ($acc + $track_submission)"
        $acc + $track_submission
      }
    }
  )
  if ($submission_string | is-empty) {
    return null
  }

  # todo include fileformat and bitrate?
  let submission_string = $"format=json&client=($client_key)&clientversion=($media_juggler_version)&user=($user_key)" + $submission_string
  log debug $"submit_acoustid_fingerprints: submission_string: ($submission_string)"

  let request = {||
    (
      $submission_string
      | ^gzip --stdout
      | http post --content-type application/x-www-form-urlencoded --full --headers [Content-Encoding gzip] $endpoint
    )
  }

  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error submitting AcoustID fingerprints to ($endpoint) with payload ($submission_string): ($error.debug)"
      return null
    }
  )

  if ($response.status != 200) {
    log error $"Error submitting AcoustID fingerprints to ($endpoint) with payload ($submission_string). HTTP error code: ($response.status). HTTP response: ($response)"
    return null
  }

  $response.body.submissions
}

# Get the embedded AcoustID fingerprint or calculate it for the audio files which do not have one.
export def get_acoustid_fingerprint [
  ignore_existing = false # Recalculate the AcoustID even when the tag exists
]: list<path> -> table<file: path, fingerprint: string, duration: duration> {
  let files = $in
  $files | par-each {|file|
    let metadata = $file | parse_audiobook_metadata_from_file
    let fingerprint = (
      if (
        not $ignore_existing
        and "acoustid_fingerprint" in $metadata.track
        and ($metadata.track.acoustid_fingerprint | is-not-empty)
        and "duration" in $metadata.track
        and ($metadata.track.duration | is-not-empty)
        and ($metadata.track.duration != 0ms)
      ) {
        {
          file: $file
          fingerprint: $metadata.track.acoustid_fingerprint
          duration: $metadata.track.duration
        }
      }
    )
    if ($fingerprint | is-empty) {
      [$file] | fpcalc | first
    } else {
      $fingerprint
    }
  }
}

# Get the embedded AcoustID fingerprint or calculate it for a track which does not have one.
export def get_acoustid_fingerprint_track [
  ignore_existing = false # Recalculate the AcoustID even when the tag exists
]: record -> record {
  let track = $in
  if (
    not $ignore_existing
    and ($track | get --optional acoustid_fingerprint | is-not-empty)
    and ($track | get --optional duration | is-not-empty)
    and ($track.duration != 0ms)
  ) {
    $track
  } else {
    let pair = [$track.file] | fpcalc | first
    (
      $track
      | upsert acoustid_fingerprint $pair.fingerprint
      | upsert duration $pair.duration
    )
  }
}

# Get the embedded AcoustID fingerprint or calculate it for the tracks which do not have one.
export def get_acoustid_fingerprint_tracks [
  ignore_existing = false # Recalculate the AcoustID even when the tag exists
]: table -> table {
  let tracks = $in
  $tracks | par-each {|track|
    $track | get_acoustid_fingerprint_track $ignore_existing
  }
}

# Determine the MusicBrainz Recording IDs and the MusicBrainz Release ID of the given files using their AcoustID fingerprints
export def get_musicbrainz_ids_by_acoustid [
  client_key: string # The application API key for the AcoustID server
  --user-key: string # The user API key for the AcoustID server. Required for lookups starting January 1, 2027.
  ignore_embedded_acoustid_fingerprints # Recalculate AcoustID fingerprints for all files
  fail_fast = true # Immediately return null when a fingerprint has no matches that meet the threshold score
  --threshold: float = 1.0 # A float value between zero and one, the minimum score required to be considered a match
  --api-requests-per-second: int = 3 # The number of API requests to make per second. AcoustID only permits up to three requests per second.
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: record<book: record, tracks: table> -> record<book: record, tracks: table> {
  let metadata = $in
  if ($metadata | is-empty) or "tracks" not-in $metadata or ($metadata.tracks | is-empty) {
    return null
  }

  let tracks = $metadata.tracks | get_acoustid_fingerprint_tracks $ignore_embedded_acoustid_fingerprints

  # log info $"acoustid_fingerprints: ($acoustid_fingerprints)"
  let acoustid_responses = (
    $tracks
    | select file duration acoustid_fingerprint
    | rename file duration fingerprint
    | fetch_release_ids_by_acoustid_fingerprints $client_key $threshold $fail_fast $api_requests_per_second --user-key $user_key --retries $retries --retry-delay $retry_delay
  )
  if ($acoustid_responses | is-empty) {
    log error "AcoustID responses missing"
    return null
  }
  # log info $"acoustid_responses: ($acoustid_responses | to nuon)"
  let release_ids = (
    if "releases" in ($acoustid_responses | get matches | first | get recordings | first | columns)  {
      $acoustid_responses | determine_releases_from_acoustid_fingerprint_matches
    } else {
      log warning "No releases available in the acoustid responses!"
      log debug $"acoustid_responses: (ansi yellow)($acoustid_responses)(ansi reset)"
      null
    }
  )
  if ($release_ids | is-empty) {
    log error "No common release ids found for the AcoustID fingerprints"
    return null
  } else if ($release_ids | length) > 1 {
    log error $"Multiple release ids found for the AcoustID fingerprints: ($release_ids)"
    return null
  }
  let release_id = $release_ids | first
  let track_recording_ids_for_release = (
    $acoustid_responses | flatten | each {|track|
      let recording_ids = (
        $track
        | get matches
        | get recordings
        | where {|recording|
          $release_id in ($recording.releases.id)
        }
        | get id
      );
      {
        file: $track.file
        acoustid_track_id: $track.matches.id
        musicbrainz_recording_ids: $recording_ids
      }
    }
  )
  let each_track_has_exactly_one_recording_for_the_release = $track_recording_ids_for_release | all {|track|
    ($track.musicbrainz_recording_ids | length) == 1
  }
  if (not $each_track_has_exactly_one_recording_for_the_release) {
    log error "Failed to link each AcoustID track to exactly one recording for the release"
    return null
  }
  let track_recording_ids_for_release = $track_recording_ids_for_release | each {|track|
    (
      $track
      | insert musicbrainz_recording_id ($track.musicbrainz_recording_ids | first)
      | reject musicbrainz_recording_ids
    )
  }

  # Add the AcoustID Track IDs and MusicBrainz Recording IDs for each track.
  let tracks = (
    $tracks
    | reject --optional acoustid_track_id musicbrainz_recording_id
    # | flatten
    | join --left $track_recording_ids_for_release file
  )

  {
    book: ($metadata.book | upsert musicbrainz_release_id $release_id)
    tracks: $tracks
  }
}
