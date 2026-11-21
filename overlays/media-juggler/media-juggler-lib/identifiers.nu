# Functions for parsing, validating, and converting book identifiers such as ISBNs

use std log

# Parse ISBN from text
#
# todo Use a confidence rating for all ISBN results and use that to determine the most likely candidates?
# todo Add test cases for this function.
export def parse_isbn [
]: list<string> -> list<string> {
  let text = $in

  # todo Fix this so that ISBN's occurring after the first one on this line are still eligible?
  # Avoid the ISBN preview in Tor books like this:
  # A Tor Hardcover ISBN    978-0-3128-51408
  let text = (
    $text | where {
      |l| not ($l | str contains "A Tor Hardcover ISBN")
    }
  )

  # ISBN 978-1-250-16947-1 (ebook)
  # 978-1-250-16947-1 (ebook)
  # eISBN 978-1-6374-1067-7
  # eISBN
  # ISBN: 978-1-250-16947-1

  # ISBN-13: 978-1-7185-0186-7 (ebook)
  let obvious_isbn = (
    $text
    | parse --regex 'ISBN-13:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # ebook ISBN: xxx
  let obvious_isbn = (
    $text
    | parse --regex 'ebook ISBN:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # ISBN xxx (ebook)
  let obvious_isbn = (
    $text
    | parse --regex 'ISBN\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let obvious_isbn = (
    $text
    | parse --regex '(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # eISBN 978-1-6374-1067-7
  let obvious_isbn = (
    $text
    | parse --regex 'eISBN\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let obvious_isbn = (
    $text
    | parse --regex 'ISBN:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let isbn_numbers = (
    $text
    | parse --regex '(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($isbn_numbers | is-empty) {
    []
  } else {
    $isbn_numbers | get isbn | str replace --all "-" "" | uniq
  }
}

# Hyphenate an ISBN with the isbn_mask program from isbntools
export def hyphenate_isbn []: [string -> string] {
  let isbn = $in
  let result = do { ^isbn_mask $isbn } | complete
  if ($result.exit_code != 0) {
    log error $"Error hyphenating ISBN (ansi yellow)($isbn)(ansi reset): ($result.stderr)"
    return null
  }
  if ($result.stdout | is-empty) {
    log error $"No ISBN output from isbn_mask for ISBN (ansi yellow)($isbn)(ansi reset)"
    return null
  }
  $result.stdout | str trim
}

# Validate an ISBN with the isbn_validate program from isbntools
export def validate_isbn []: [string -> bool] {
  let isbn = $in
  # When stdin isn't a terminal, isbn_validate ignores its argument and validates the ISBNs read from stdin instead.
  # Always pass the ISBN through stdin so that it behaves the same everywhere, and doesn't wait on an open stdin.
  let result = $isbn | ^isbn_validate | complete
  if ($result.exit_code != 0) {
    log error $"Error validating ISBN (ansi yellow)($isbn)(ansi reset): ($result.stderr)"
    return null
  }
  $result.stdout | is-not-empty
}

export const book_identifiers = {
  bookbrainz_edition_id: {
    match_expression: '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    url: "https://bookbrainz.org/edition/{{ bookbrainz_edition_id }}"
    # url_match_expression: "^http[s]{0,1}://bookbrainz.org/edition/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
    url_parse_expression: '^http[s]{0,1}://bookbrainz.org/edition/(?<bookbrainz_edition_id>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/{0,1}$'
  }
  bookbrainz_work_id: {
    match_expression: '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    url: "https://bookbrainz.org/work/{{ bookbrainz_work_id }}"
    # url_match_expression: "^http[s]{0,1}://bookbrainz.org/work/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
    url_parse_expression: '^http[s]{0,1}://bookbrainz.org/work/(?<bookbrainz_work_id>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/{0,1}$'
  }
  comic_vine_issue_id: {
    match_expression: '^4000-[0-9]+$'
    url: "https://comicvine.gamespot.com/issue/{{ comic_vine_issue_id }}"
    url_parse_expression: '^http[s]{0,1}://comicvine.gamespot.com/[a-zA-Z0-9_-]+/(?<comic_vine_issue_id>4000-[0-9]+)/{0,1}$'
  }
  comic_vine_volume_id: {
    match_expression: '^4050-[0-9]+$'
    url: "https://comicvine.gamespot.com/issue/{{ comic_vine_volume_id }}"
    url_parse_expression: '^http[s]{0,1}://comicvine.gamespot.com/[a-zA-Z0-9_-]+/(?<comic_vine_volume_id>4050-[0-9]+)/{0,1}$'
  }
  hardcover_book_slug: {
    # More characters than this are probably allowed.
    match_expression: '^[a-zA-Z0-9_-]+$'
    url: "https://hardcover.app/books/{{ hardcover_book_slug }}"
    url_parse_expression: '^http[s]{0,1}://hardcover.app/books/(?<hardcover_book_slug>[a-zA-Z0-9_-]+)(?:(?:/editions/(?<hardcover_edition_id>[0-9]+)/{0,1})|(?:/.*)|(?:/{0,1}))$'
  }
  hardcover_edition_id: {
    match_expression: '^[0-9]+$'
    url: "https://hardcover.app/books/{{ hardcover_book_slug }}/editions/{{ hardcover_edition_id }}"
    edition_url: "https://hardcover.app/edition/id/{{ hardcover_edition_id }}"
    url_parse_expression: "^http[s]{0,1}://hardcover.app/(?:(?:books/(?<hardcover_book_slug>[a-zA-Z0-9_-]+)/editions)|(?:edition/id))/(?<hardcover_edition_id>[0-9]+)/{0,1}$"
  }
  metron_issue_id: {
    match_expression: '^[0-9]+$'
    url: "https://metron.cloud/issue/{{ metron_issue_id }}"
    url_parse_expression: '^http[s]{0,1}://metron.cloud/issue/(?<metron_issue_id>[0-9]+)/{0,1}$'
  }
  open_library_edition_id: {
    match_expression: '^OL[0-9]+M$'
    url: "https://openlibrary.org/books/{{ open_library_edition_id }}"
    url_parse_expression: '^http[s]{0,1}://openlibrary.org/books/(?<open_library_edition_id>OL[0-9]+M)(?:(?:/.+)|(?:/{0,1}))$'
  }
  open_library_work_id: {
    match_expression: '^OL[0-9]+W$'
    url: "https://openlibrary.org/works/{{ open_library_work_id }}"
    url_parse_expression: '^http[s]{0,1}://openlibrary.org/(?:books|works)/(?<open_library_work_id>OL[0-9]+W)(?:(?:/.+)|(?:/{0,1}))$'
  }
  wikidata_item_id: {
    match_expression: '^Q[0-9]+$'
    url: "https://www.wikidata.org/wiki/{{ wikidata_item_id }}"
    url_parse_expression: '^http[s]{0,1}://www.wikidata.org/wiki/(?<wikidata_item_id>Q[0-9]+)/{0,1}$'
  }
}

# Check if an identifier of the specified type is valid by checking it against a regular expression
export def is_identifier_valid [
  type: string # Identifier type. See columns in book_identifiers for available types.
]: [string -> bool] {
  let id = $in
  if ($type | is-empty) {
    error make {
      msg: "empty identifier type"
      labels: [
          {text: "type" span: (metadata $type).span}
      ]
      help: "pass a nonempty value for the type field"
    }
  }
  if $type not-in ($book_identifiers | columns) {
    error make {
      msg: "invalid identifier type"
      labels: [
          {text: "type" span: (metadata $type).span}
      ]
      help: $"the value for the type field must be one of ($book_identifiers | columns)"
    }
  }
  if ($id | is-empty) {
    return false
  }
  $id =~ ($book_identifiers | get $type | get match_expression)
}

export def identifier_into_url [
  type: string # Identifier type. See columns in book_identifiers for available types.
  --hardcover-book-slug: string # Required when the type is hardcover_edition_id
]: [string -> string] {
  let id = $in
  if ($id | is-empty) {
    error make {
      msg: "empty id"
      labels: [
          {text: "id" span: (metadata $id).span}
      ]
      help: "pipe the value of an id into identifier_into_url"
    }
  }
  if ($type | is-empty) {
    error make {
      msg: "empty identifier type"
      labels: [
          {text: "type" span: (metadata $type).span}
      ]
      help: "pass a nonempty value for the type field"
    }
  }
  if $type not-in ($book_identifiers | columns) {
    error make {
      msg: "invalid identifier type"
      labels: [
          {text: "type" span: (metadata $type).span}
      ]
      help: $"invalid value (ansi yellow)($type)(ansi reset) for the type field must be one of ($book_identifiers | columns)"
    }
  }
  if $type != "hardcover_edition_id" and ($hardcover_book_slug | is-not-empty) {
    error make {
      msg: "invalid use of --hardcover-book-slug"
      labels: [
        {text: "hardcover_book_slug" span: (metadata $hardcover_book_slug).span}
      ]
      help: "the flag --hardcover-book-slug is only valid when the type is hardcover_edition_id"
    }
  }
  if not ($id | is_identifier_valid $type) {
    error make {
      msg: "invalid identifier"
      labels: [
        {text: "in" span: (metadata $in).span}
      ]
      help: $"the (ansi red)($id)(ansi reset) of type (ansi yellow)($type)(ansi reset) is invalid"
    }
  }
  if $type == "hardcover_edition_id" and ($hardcover_book_slug | is-not-empty) and not ($hardcover_book_slug | is_identifier_valid "hardcover_book_slug") {
    error make {
      msg: "invalid hardcover_book_slug identifier"
      labels: [
        {text: "hardcover_book_slug" span: (metadata $hardcover_book_slug).span}
      ]
      help: $"the Hardcover book slug (ansi red)($hardcover_book_slug)(ansi reset) is invalid"
    }
  }
  let url = $book_identifiers | get $type | get url | str replace ("{{ " + $type + " }}") $id
  if $type == "hardcover_edition_id" {
    if ($hardcover_book_slug | is-empty) {
      $book_identifiers | get $type | get edition_url | str replace "{{ hardcover_edition_id }}" $id
    } else {
      $url | str replace "{{ hardcover_book_slug }}" $hardcover_book_slug
    }
  } else {
    $url
  }
}

# Parse a book identifier from its URL
#
# When the identifier is hardcover_edition_id, the hardcover_book_slug will also be included in the result.
export def identifier_from_url [
  type: string # Identifier type. See columns in book_identifiers for available types.
]: [string -> record] {
  let url = $in
  if ($url | is-empty) {
    error make {
      msg: "empty url"
      labels: [
        {text: "url" span: (metadata $url).span}
      ]
      help: "pipe a url string into identifier_from_url"
    }
  }
  if ($type | is-empty) {
    error make {
      msg: "empty identifier type"
      labels: [
        {text: "type" span: (metadata $type).span}
      ]
      help: "pass a nonempty value for the type field"
    }
  }
  if $type not-in ($book_identifiers | columns) {
    error make {
      msg: "invalid identifier type"
      labels: [
        {text: "type" span: (metadata $type).span}
      ]
      help: $"the value for the type field must be one of ($book_identifiers | columns)"
    }
  }
  let ids = $url | parse --regex ($book_identifiers | get $type | get url_parse_expression)
  if ($ids | is-empty) {
    return {}
  }
  # This should never happen.
  if ($ids | length) > 1 {
    error make {
      msg: $"more than one ID of type (ansi purple)($type)(ansi reset) parsed from URL (ansi yellow)($url)(ansi reset): ($ids)"
      labels: [
        {text: "ids" span: (metadata $ids).span}
      ]
      help: "parsing multiple ids of the same type from a URL should not be possible"
    }
  }
  let ids = $ids | first
  # Filter out empty IDs and double check that the identifier is valid.
  # The parse regex should only parse valid identifiers in the first place.
  # log debug $"ids: ($ids)"
  $ids | columns | reduce --fold {} {|type acc|
    # log debug $"type: ($type)"
    # log debug $"id: ($id)"
    if ($ids | get --optional $type | is-empty) {
      $acc
    } else {
      if not ($ids | get $type | is_identifier_valid $type) {
        error make {
          msg: $"the (ansi red)($ids | get $type)(ansi reset) of type (ansi yellow)($type)(ansi reset) is invalid"
          labels: [
            {text: "ids" span: (metadata $ids).span}
          ]
          help: $"there is a problem with the url_parse_expression (ansi yellow)($book_identifiers | get $type | get url_parse_expression)(ansi reset) parsing invalid IDs of type (ansi yellow)($type)(ansi reset)"
        }
      } else {
        $acc | insert $type ($ids | get $type)
      }
    }
  }
}

# Parse the ASIN out of an Audible URL
export def parse_audible_asin_from_url []: string -> string {
  let url = $in
  let parsed = $url | url parse
  if ($parsed.host | str starts-with "www.audible.") {
    $parsed | get path | path parse | get stem | str upcase
  }
}
