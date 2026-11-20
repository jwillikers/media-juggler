# Functions for querying BookBrainz

use std log

use constants.nu *
use utils.nu *

# Search for editions on BookBrainz by ISBN.
export def bookbrainz_search_editions_by_isbn [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> table] {
  let isbn = $in | str replace --all "-" ""
  # todo Not sure how ISBNs are set in BB might effect the search.
  # Might have to search with and without hyphens.
  # There is also a search endpoint at https://api.bookbrainz.org/1/search?q=
  # It doesn't include as much information, though.
  let bookbrainz_api_query_url = "https://bookbrainz.org/search/search?q="
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
        }
        $"($bookbrainz_api_query_url)($isbn | url encode)&type=edition&size=20&from=0"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting BookBrainz editions by ISBN-13 ($isbn) from (ansi yellow)($bookbrainz_api_query_url)($isbn | url encode)&type=edition&size=20&from=0(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) searching for BookBrainz editions with ISBN-13 ($isbn) with query (ansi yellow)($bookbrainz_api_query_url)($isbn | url encode)&type=edition&size=20&from=0(ansi reset): ($response.body)"
    return null
  }
  $response.body.results
}

# Fetch the identifiers for a BookBrainz edition
export def bookbrainz_get_edition_identifiers [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> table] {
  let bookbrainz_edition_id = $in
  let bookbrainz_api_edition_identifiers_url = $"https://api.bookbrainz.org/1/edition/($bookbrainz_edition_id)/identifiers"
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
        }
        $"($bookbrainz_api_edition_identifiers_url)"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting identifiers for BookBrainz edition ($bookbrainz_edition_id) from (ansi yellow)($bookbrainz_api_edition_identifiers_url)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting identifiers for BookBrainz edition ($bookbrainz_edition_id) from (ansi yellow)($bookbrainz_api_edition_identifiers_url)(ansi reset): ($response.body)"
    return null
  }
  $response.body.identifiers
}
