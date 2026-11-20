# Functions for normalizing metadata such as languages, genres, and tags

use std log

use constants.nu *

# Filter and rename genres or tags according to the allow list
export def sanitize_genres_or_tags [
  allowlist: table<name: string, aliases: list<string>> # The allow list
]: [list<string> -> list<string>] {
  let tags = $in
  if ($allowlist | is-empty) {
    error make {
      msg: "empty allowlist"
      labels: [
          {text: "in" span: (metadata $in).span}
      ]
      help: "pass a non-empty allowlist for the allowlist argument"
    }
  }
  if ($tags | is-empty) {
    return []
  }

  $tags | reduce --fold [] {|tag acc|
    let lowercase_tag = $tag | str downcase
    let matching_tags = $allowlist | where {|allowed_tag|
      (($allowed_tag.name | str downcase) == $lowercase_tag) or ($allowed_tag.aliases | any {|alias| $lowercase_tag == ($alias | str downcase)})
    }
    if ($matching_tags | is-empty) {
      log debug $"Ignoring tag/genre: (ansi purple)($tag)(ansi reset)"
      $acc
    } else if ($matching_tags | length) == 1 {
      $acc | append ($matching_tags.name | first)
    } else {
      error make {
        msg: "multiple matches in the allowlist"
        labels: [
          {text: "matching_tags" span: (metadata $matching_tags).span}
        ]
        help: $"found multiple matches for (ansi yellow)($tag)(ansi reset) in the allowlist ($allowlist): (ansi yellow)($matching_tags)(ansi reset)"
      }
    }
  } | sort
}

# Convert a language to it's corresponding IETF BCP 47 or ISO 639-3 language code
#
# https://en.wikipedia.org/wiki/IETF_language_tag
# https://en.wikipedia.org/wiki/List_of_ISO_639-3_codes
export def into_language_code [
  type: string # 'ietf_bcp_47', 'iso_639_1', or 'iso_639_3'
  language_codes_map: table = $iso_language_codes_map
]: [string -> string] {
  let language = $in
  if $type not-in ($language_codes_map | reject --optional language default_language | columns) {
    error make {
      msg: "invalid language code type"
      labels: [
          {text: "type" span: (metadata $type).span}
      ]
      help: $"the language code type must be one of (ansi yellow)($language_codes_map | reject --optional language language_default | str join ' ')(ansi reset)"
    }
  }
  let language_codes = $language_codes_map | where language == $language
  if ($language_codes | is-empty) {
    error make {
      msg: "unsupported language"
      labels: [
          {text: "language_codes_map" span: (metadata $language_codes_map).span}
      ]
      help: $"add the language (ansi yellow)($language)(ansi reset) to the language_codes_map table"
    }
  }
  let language_codes = (
    if ($language_codes | length) > 1 {
      let default_codes = $language_codes | where default_language == true
      if ($default_codes | length) > 1 {
        error make {
          msg: "duplicate language in language_codes_map table default_language set to true"
          labels: [
              {text: "language_codes_map" span: (metadata $language_codes_map).span}
          ]
          help: $"remove the duplicate of the (ansi yellow)($language)(ansi reset) language from the table or set default_language to false for all but one of the entries which has the same language codes"
        }
      } else {
        $default_codes
      }
    } else {
      $language_codes
    }
  )
  $language_codes | get $type | first
}

# Convert an IETF BCP 47 or ISO 639-3 language code into its corresponding language
#
# https://en.wikipedia.org/wiki/IETF_language_tag
# https://en.wikipedia.org/wiki/List_of_ISO_639-3_codes
export def from_language_code [
  # todo: I should be using type here
  # type: string # 'iso_639_1' 2-letter code, 'iso_639_3' 3-letter code, or 'ietf_bcp_47' to try everything else
  language_codes_map: table = $iso_language_codes_map
]: [string -> string] {
  let language_code = $in
  let language_code_length = $language_code | str length
  let type = (
    if $language_code_length == 2 {
      "iso_639_1"
    } else if $language_code_length == 3 {
      "iso_639_3"
    } else {
      "ietf_bcp_47"
      # error make {
      #   msg: "unsupported language code type for the number of characters"
      #   labels: [
      #       {text: "language_code" span: (metadata $language_code).span}
      #   ]
      #   help: $"language codes must be 2-letters for (ansi yellow)iso_639_1(ansi reset) or 3-letters for (ansi yellow)iso_639_3(ansi reset)"
      # }
    }
  )
  let languages = $language_codes_map | where {|it| ($it | get $type) == $language_code}
  if ($languages | is-empty) {
    error make {
      msg: "invalid language code"
      labels: [
          {text: "language_code" span: (metadata $language_code).span}
      ]
      help: $"the language code (ansi yellow)($language_code)(ansi reset) of type (ansi yellow)($type)(ansi reset) does not exist in the language_codes_map table"
    }
  }
  let languages = (
    if ($languages | length) > 1 {
      let default_languages = $languages | where default_language == true
      if ($default_languages | length) > 1 {
        error make {
          msg: "duplicate language code in language_codes_map table where default_language is set to true"
          labels: [
              {text: "language_codes_map" span: (metadata $language_codes_map).span}
          ]
          help: $"remove the duplicate of the (ansi yellow)($language_code)(ansi reset) language from the table or set default_language to false for all but one of the entries which have the same language codes"
        }
      } else {
        $default_languages
      }
    } else {
      $languages
    }
  )
  $languages.language | first
}

# Parse genres and tags from MusicBrainz metadata
#
# Since MusicBrainz doesn't yet support genres / themes for books, genres are generally determined from the tags.
# Tags become the genres, with a few special tags filtered out, which remain in the tags table.
# Genres and tags are then sorted by count from highest to lowest and then by name
#
# Any genres in the input table will be in the output genres table.
export def parse_genres_and_tags []: record<genres: table<name: string, count: int>, tags: table<name: string, count: int>> -> record<genres: table<name: string, count: int>, tags: table<name: string, count: int>> { # record<genres: table<name: string, count: int>, tags: table<name: string, count: int>> -> record<genres: table<name: string, count: int>, tags: table<name: string, count: int>> {
  let input = $in
  if ($input | is-empty) {
    return null
  }

  # sort by the count, highest to lowest, and then name alphabetically
  let sort = {|a, b|
    if (
      ($a | is-empty)
      or ($b | is-empty)
      or "name" not-in ($a | columns)
      or "name" not-in ($b | columns)
      or "count" not-in ($a | columns)
      or "count" not-in ($b | columns)
    ) {
      return true
    }
    if $a.count == $b.count {
      $a.name < $b.name
    } else {
      $a.count > $b.count
    }
  }

  if ($input | get --optional tags | is-empty) or "tags" not-in ($input | columns) {
    if "genres" in ($input | columns) and ($input | get --optional genres | is-not-empty) {
      return {
        genres: (
          $input
          | get --optional genres
          | reduce --fold [] {|tag acc|
            let lowercase_tag = $tag.name | str downcase
            let matching_tags = $genre_allowlist | where {|allowed_tag|
              ($allowed_tag.name | str downcase) == $lowercase_tag or ($allowed_tag.aliases | any {|alias| $lowercase_tag == ($alias | str downcase)})
            }
            if ($matching_tags | is-empty) {
              log debug $"Ignoring genre: (ansi purple)($tag.name)(ansi reset)"
              $acc
            } else if ($matching_tags | length) == 1 {
              $acc | append {name: ($matching_tags.name | first), count: $tag.count}
            } else {
              error make {
                msg: "multiple matches in the allowlist"
                labels: [
                  {text: "matching_tags" span: (metadata $matching_tags).span}
                ]
                help: $"found multiple matches for (ansi yellow)($tag.name)(ansi reset) in the allowlist ($genre_allowlist): (ansi yellow)($matching_tags)(ansi reset)"
              }
            }
          }
          | sort-by --custom $sort
          | uniq-by name
        )
        tags: []
      }
    }
    return {
      genres: []
      tags: []
    }
  }

  let genres = $input | get --optional genres | append (
    $input.tags
    # | select name count
    | reduce --fold [] {|tag acc|
      let lowercase_tag = $tag.name | str downcase
      let matching_tags = $genre_allowlist | where {|allowed_tag|
        (($allowed_tag.name | str downcase) == $lowercase_tag) or ($allowed_tag.aliases | any {|alias| $lowercase_tag == ($alias | str downcase)})
      }
      if ($matching_tags | is-empty) {
        log debug $"Ignoring genre: (ansi purple)($tag.name)(ansi reset)"
        $acc
      } else if ($matching_tags | length) == 1 {
        $acc | append {name: ($matching_tags.name | first), count: $tag.count}
      } else {
        error make {
          msg: "multiple matches in the allowlist"
          labels: [
            {text: "matching_tags" span: (metadata $matching_tags).span}
          ]
          help: $"found multiple matches for (ansi yellow)($tag.name)(ansi reset) in the allowlist ($genre_allowlist): (ansi yellow)($matching_tags)(ansi reset)"
        }
      }
    }
  ) | sort-by --custom $sort | uniq-by name

  let tags = (
    $input.tags
    # | select name count
    | reduce --fold [] {|tag acc|
      let lowercase_tag = $tag.name | str downcase
      let matching_tags = $tag_allowlist | where {|allowed_tag|
        (($allowed_tag.name | str downcase) == $lowercase_tag) or ($allowed_tag.aliases | any {|alias| $lowercase_tag == ($alias | str downcase)})
      }
      if ($matching_tags | is-empty) {
        log debug $"Ignoring tag: (ansi purple)($tag.name)(ansi reset)"
        $acc
      } else if ($matching_tags | length) == 1 {
        $acc | append {name: ($matching_tags.name | first), count: $tag.count}
      } else {
        error make {
          msg: "multiple matches in the allowlist"
          labels: [
            {text: "matching_tags" span: (metadata $matching_tags).span}
          ]
          help: $"found multiple matches for (ansi yellow)($tag.name)(ansi reset) in the allowlist ($tag_allowlist): (ansi yellow)($matching_tags)(ansi reset)"
        }
      }
    }
    # sort by the count, highest to lowest, and then name alphabetically
    | sort-by --custom $sort
    | uniq-by name
  )

  {
    genres: $genres
    tags: $tags
  }
}
