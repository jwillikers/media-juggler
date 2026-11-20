# Functions for querying the Hardcover API

use std log

use constants.nu *
use metadata.nu *
use utils.nu *

# Remove the light novel, manga, manhua, and manhwa disambiguation from the title and standardize the title
#
# This removes the (Light Novel), (Manga), (Manhua), and (Manhwa) disambiguation comments since these are kept in separate libraries on Kavita.
# This basically ends up following the MusicBrainz style guidelines.
#
# todo Add test cases for this function.
export def standardize_hardcover_title []: string -> string {
  let title = $in
  # We don't want to replace the "-" before the volume part with an emdash or endash.
  let components = $title | split row --number 2 " (Light Novel), "
  let components = (
    if ($components | length) == 1 {
      $title | split row --number 2 " (Manga), "
    } else {
      $components
    }
  )
  let components = (
    if ($components | length) == 1 {
      $title | split row --number 2 " (Manhua), "
    } else {
      $components
    }
  )
  let components = (
    if ($components | length) == 1 {
      $title | split row --number 2 " (Manhwa), "
    } else {
      $components
    }
  )
  if ($components | length) > 1 {
    # If the title of the series ends with punctuation, don't add a comma.
    if ($components | first | split chars | last) in ["!", "?", ".", ","] {
      $components | str join " "
    } else {
      $components | str join ", "
    }
  } else {
    $title
  }
}

# Search for an edition on Hardcover by id such as ASIN, ISBN, or hardcover edition id.
#
# Requires the environment variable MEDIA_JUGGLER_HARDCOVER_API_TOKEN be set to a Hardcover API key.
export def hardcover_search_editions_by_exact_field [
  type: string # The identifier or field type, which is can be one of asin, isbn_10, isbn_13, id (which is the Hardcover edition ID)
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> table] {
  let id = $in | str replace --all "-" ""
  if ($env | get --optional MEDIA_JUGGLER_HARDCOVER_API_TOKEN | is-empty) {
    log error "The environment variable MEDIA_JUGGLER_HARDCOVER_API_TOKEN must be set to a Hardcover API key to search by ISBN."
    return null
  }
  let token = (
    if ($env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN | str starts-with "Bearer ") {
      $env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN
    } else {
      "Bearer " + $env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN
    }
  )
  # Reading format (1=Physical, 2=Audio, 3=Both, 4=Ebook)
  let graphql_query = {
    "query": $"query {
      editions\(where: { ($type): { _eq: \"($id)\" } } ) {
        id
        title
        reading_format_id
        book { slug }
      }
    }"
  }

  # {
  #   "query": '
  #     query {
  #       editions(where: { isbn_13: { _eq: "9781975301200" } } ) {
  #         id
  #         canonical_id
  #         title
  #         isbn_13
  #         language {
  #           code2
  #           code3
  #           id
  #           language
  #         }
  #         release_date
  #         image {
  #           id
  #           height
  #           width
  #           ratio
  #           url
  #         }
  #         edition_format
  #         reading_format {
  #           id
  #           format
  #         }
  #         pages
  #         audio_seconds
  #         book_mappings {
  #           id
  #           external_id
  #           platform_id
  #         }
  #         publisher { name }
  #         book {
  #           slug
  #           contributions { author { name } }
  #           taggings {
  #             id
  #             tag {
  #               id
  #               tag
  #               tag_category {
  #                 id
  #               }
  #               tag_category_id
  #               slug
  #             }
  #           }
  #           book_series {
  #             id
  #             featured
  #             details
  #             position
  #             series_id
  #           }
  #         }
  #       }
  #     }
  #   '
  # }

  # log debug $"Running: (ansi yellow)http post --content-type \"application/json\" --full --headers {\"User-Agent\": ($user_agent), Authorization: \"<token>\"} \"https://api.hardcover.app/v1/graphql\"(ansi reset)"
  let request = {
    (
      http post
        --content-type "application/json"
        --full
        --headers {
          "User-Agent": $user_agent
          Authorization: $token
        }
        "https://api.hardcover.app/v1/graphql" $graphql_query
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting Hardcover edition by ($type) ($id) from (ansi yellow)($hardcover_api_url)(ansi reset): ($error.debug)"
      log error $"GraphQL query:\n(ansi yellow)($graphql_query | to json)(ansi reset)\n"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) searching for Hardcover editions with ($type) ($id) with GraphQL query ($graphql_query) at (ansi yellow)($hardcover_api_url)(ansi reset): ($response.body)"
    return null
  }
  $response.body | get --optional data.editions
}

# Get cover art URL for an edition on Hardcover
export def hardcover_cover_art_url [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> string] {
  let edition_id = $in | str replace --all "-" ""
  if ($env | get --optional MEDIA_JUGGLER_HARDCOVER_API_TOKEN | is-empty) {
    log error "The environment variable MEDIA_JUGGLER_HARDCOVER_API_TOKEN must be set to a Hardcover API key to search by ISBN."
    return null
  }
  let token = (
    if ($env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN | str starts-with "Bearer ") {
      $env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN
    } else {
      "Bearer " + $env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN
    }
  )
  let graphql_query = {
    "query": $"
      query {
        editions\(where: { id: { _eq: \"($edition_id)\" } } \) {
          image {
            url
          }
        }
      }
    "
  }
  let request = {
    (
      http post
        --content-type "application/json"
        --full
        --headers {
          "User-Agent": $user_agent
          Authorization: $token
        }
        "https://api.hardcover.app/v1/graphql" $graphql_query
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting Hardcover cover art for edition (ansi purple)($edition_id)(ansi reset) from (ansi yellow)($hardcover_api_url)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Hardcover cover art URL for the edition (ansi purple)($edition_id)(ansi reset) with GraphQL query ($graphql_query) at (ansi yellow)($hardcover_api_url)(ansi reset): ($response.body)"
    return null
  }
  if ($response.body | get --optional data.editions | is-not-empty) {
    let editions = $response.body.data.editions
    if ($editions | length) > 1 {
      log error $"More than one Hardcover edition found for edition (ansi purple)($edition_id)(ansi reset): ($editions)"
      return null
    } else {
      $editions | first | get image.url
    }
  } else {
    null
  }
}

# Get metadata for an edition on Hardcover by Hardcover edition id or another identifier.
#
# Requires the environment variable MEDIA_JUGGLER_HARDCOVER_API_TOKEN be set to a Hardcover API key.
export def get_hardcover_edition [
  id_type: string # The identifier or field type, which is can be one of asin, isbn_10, isbn_13, id (which is the Hardcover edition ID)
  cache: closure
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> record] {
  let id = $in | str replace --all "-" ""
  if ($env | get --optional MEDIA_JUGGLER_HARDCOVER_API_TOKEN | is-empty) {
    log error "The environment variable MEDIA_JUGGLER_HARDCOVER_API_TOKEN must be set to a Hardcover API key to search by ISBN."
    return null
  }
  let token = (
    if ($env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN | str starts-with "Bearer ") {
      $env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN
    } else {
      "Bearer " + $env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN
    }
  )
  # Reading format (1=Physical, 2=Audio, 3=Both, 4=Ebook)
  let graphql_query = {
    "query": $"query {
      editions\(where: { ($id_type): { _eq: \"($id)\" } } ) {
        id
        canonical_id
        title
        isbn_13
        language {
          code2
          code3
          id
          language
        }
        release_date
        contributions {
          author {
            name
            canonical_id
            id
          }
          contribution
        }
        image {
          id
          height
          width
          ratio
          url
        }
        edition_format
        reading_format {
          id
          format
        }
        pages
        audio_seconds
        book_mappings {
          id
          external_id
          platform_id
        }
        publisher { name }
        book {
          book_characters {
            character {
              name
              canonical_id
              id
            }
          }
          description
          literary_type_id
          book_category_id
          slug
          cached_tags
          release_year
          featured_book_series {
            id
            featured
            details
            position
            series_id
            series {
              id
              canonical_id
              name
              author {
                id
                name
              }
              books_count
              book_series {
                book {
                  release_year
                }
              }
            }
          }
        }
      }
    }"
  }

          # taggings {
          #   id
          #   tag {
          #     id
          #     tag
          #     tag_category {
          #       id
          #     }
          #     tag_category_id
          #     slug
          #   }
          # }

  let update_function = {|type id|
    let request = {
      (
        http post
          --content-type "application/json"
          --full
          --headers {
            "User-Agent": $user_agent
            Authorization: $token
          }
          "https://api.hardcover.app/v1/graphql" $graphql_query
      )
    }

    let response = (
      try {
        retry_http $request $retries $retry_delay
      } catch {|error|
        log error $"Error getting Hardcover edition by ($id_type) ($id) from (ansi yellow)($hardcover_api_url)(ansi reset): ($error.debug)"
        log error $"GraphQL query:\n(ansi yellow)($graphql_query | to json)(ansi reset)\n"
        return null
      }
    )
    if ($response.status != 200) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) searching for Hardcover editions with ($id_type) ($id) with GraphQL query ($graphql_query) at (ansi yellow)($hardcover_api_url)(ansi reset): ($response.body)"
      return null
    }
    let editions = $response.body | get --optional data.editions
    if ($editions | is-empty) {

    } else if ($editions | length) > 1 {
      log error $"Multiple Hardcover editions found for ($id_type) ID ($id): ($editions)"
    } else {
      $editions | first
    }
  }
  do $cache "hardcover-edition" $"($id_type)-($id)" $update_function null
}

# Parse the data from the Hardcover API for a Harcover edition
export def parse_hardcover_edition [
  the_genre_allowlist: table = $genre_allowlist
  the_tag_allowlist: table = $tag_allowlist
  genres_to_age_rating_map: table<genres: list<string>, comic_info_age_rating: string, metron_info_age_rating: string> = $genre_to_age_rating_comic_info_map
  intended_public_map: table<name: string, wikidata_id: string> = $intended_public_wikidata
  intended_publics_to_age_rating_map: table<intended_publics: list<string>, comic_info_age_rating: string, metron_info_age_rating: string> = $intended_public_to_age_rating_comic_info_map
]: [record -> record] {
  let hardcover_edition = $in
  # log debug $"hardcover_edition: ($hardcover_edition)"
  if ($hardcover_edition | is-empty) {
    return null
  }

  let series_begin_year = (
    let years = $hardcover_edition | get --optional book.featured_book_series.series.book_series.book.release_year;
    if ($years | is-empty) {
      # Assume the book is not in a series and fallback to using the release year of the book.
      $hardcover_edition | get --optional book.release_year
    } else {
      $years | where {|it| $it | is-not-empty} | into int | sort | first
    }
  )

  let language = (
    let language_code = $hardcover_edition | get --optional language.code3;
    if ($language_code | is-not-empty) {
      if ($language_code | str length) == 2 {
        $language_code | from_language_code # iso_639_1
      } else if ($language_code | str length) == 3 {
        $language_code | from_language_code # iso_639_3
      } else {
        # todo Support type parameter in from_language_code
        # $language_code | from_language_code ietf_bcp_47
      }
    }
  )

  let ids = $hardcover_edition | get --optional book_mappings.external_id
  let platform_id_mappings = [
    # platform_id
    # 3 -> Open Library
    # 1 -> Goodreads
    # 20 -> Google Books
    [platform id];
    # [goodreads_edition_id 1]
    [open_library_edition_id 3]
  ]
  let ids = (
    [
      [type id];
      [hardcover_book_slug $hardcover_edition.book.slug]
      [hardcover_edition_id ($hardcover_edition.id | into string)]
    ] | append (
      $hardcover_edition | get --optional book_mappings | reduce --fold [] {|book_mapping acc|
        let platform_id_mapping =  $platform_id_mappings | where id == $book_mapping.platform_id
        if ($platform_id_mapping | is-empty) {
          $acc
        } else if ($platform_id_mapping | length) > 1 {
          log error $"Multiple platform id mappings for id ($book_mapping.platform_id). Ignoring."
          $acc
        } else {
          let platform_id_mapping =  $platform_id_mapping | first
          $acc | append [
            [type id];
            [$platform_id_mapping.platform ($book_mapping.external_id | str replace "/books/" "")]
          ]
        }
      }
    )
    # | where {|it| $it.id | is-not-empty }
  );

  # Rewrite credits to match ComicTagger's format.
  #  [[person, role, primary, language]; ["Some Person", Editor, false, ""]]
  let credits = (
    $hardcover_edition.contributions | reduce --fold [] {|contribution acc|
      let role = (
        if ($contribution | get --optional contribution | is-empty) or ($contribution | get --optional contribution) == "Author" {
          "Writer"
        } else if $contribution.contribution == "Illustrator" {
          "Artist"
        # } else if $contribution.contribution == "Cover Artist" {
        #   "Cover Artist"
        } else {
          $contribution.contribution
        }
      )
      $acc | append [
        [person id role primary language];
        [$contribution.author.name ($contribution.author.id | into string) $role false ""]
      ] | append (
        # todo Always just keep "Cover Artist" as one role instead of multiple Cover and Artist roles.
        if $role == "Cover Artist" {
          [
            [person id role primary language];
            [$contribution.author.name ($contribution.author.id | into string) "Cover" false ""]
            [$contribution.author.name ($contribution.author.id | into string) "Artist" false ""]
          ]
        }
      ) | uniq
      # ] | append (
      #   if $contribution.contribution == "Cover Artist" {
      #     [
      #       [person id role primary language];
      #       [$contribution.author.name $contribution.author.id "Cover" false ""]
      #     ]
      #   }
      # )
    }
    # todo Should "Cover Artist" be separate Cover and Artist roles?
  )

  let hardcover_book_category_map = {
    0: "unknown"
    1: "book"
    2: "novella"
    3: "short story"
    4: "graphic novel"
    5: "fan fiction"
    6: "research paper"
    7: "poetry"
    8: "collection"
    9: "web novel"
    10: "light novel"
  }
  let book_category = (
    if ($hardcover_edition | get --optional book.book_category_id | is-empty) {
    } else {
      $hardcover_book_category_map | get ($hardcover_edition.book.book_category_id | into string)
    }
  )

  let hardcover_literary_type_map = {
    0: "unknown"
    1: "fiction"
    2: "nonfiction"
  }
  let literary_type = (
    if ($hardcover_edition | get --optional book.literary_type_id | is-empty) {
    } else {
      $hardcover_literary_type_map | get ($hardcover_edition.book.literary_type_id | into string)
    }
  )

  let characters = (
    if ($hardcover_edition | get --optional book.book_characters.character | is-empty) {
    } else {
      $hardcover_edition.book.book_characters.character | select --optional name id | each {|character|
        {
          id: ($character.id | into string)
          name: $character.name
        }
      }
    }
  )

  let genres = (
    let cached_tags = $hardcover_edition | get --optional book.cached_tags;
    if ($cached_tags | is-empty) {
      []
    } else {
      let genres = $cached_tags | get --optional Genre
      if ($genres | is-empty) {
        []
      } else {
        $genres.tag | sanitize_genres_or_tags $the_genre_allowlist
      }
    }
  )
  let tags = (
    let cached_tags = $hardcover_edition | get --optional book.cached_tags;
    if ($cached_tags | is-empty) {
      []
    } else {
      let tags = $cached_tags | get --optional Tag
      if ($tags | is-empty) {
        []
      } else {
        # Tags have such a broad range that sanitizing them might prove difficult.
        # I need a way to ensure I don't lose any tags on accident.
        # It's probably best to remove unknown tags that are likely to cause a bunch of clutter.
        $tags.tag | sanitize_genres_or_tags $the_tag_allowlist
        # $tags.tag | str downcase
      }
    }
  )
  # todo Maybe I should try to get the intended public from the taggings instead of cached_tags?
  let intended_publics = (
    if ($tags | is-empty) {
      []
    } else {
      $tags | reduce --fold [] {|tag acc|
        if ($tag | str downcase) in ($intended_public_map.name | append $intended_public_map.aliases) {
          $acc | append $intended_public_map.name
        } else {
          $acc
        }
      }
    }
  )
  let comic_info_age_rating = (
    let genre_age_rating = $genres_to_age_rating_map | where {|genre_to_age_rating|
      $genre_to_age_rating.genres | any {|genre| $genre in $genres}
    };
    let intended_public_age_rating = $intended_publics_to_age_rating_map | where {|intended_public_to_age_rating|
      $intended_public_to_age_rating.intended_publics | any {|intended_public| $intended_public in $intended_publics}
    };
    let age_ratings = $genre_age_rating | append $intended_public_age_rating;
    let age_ratings = $age_ratings | each {|age_rating|
      let age_range_begin = $age_rating_map | where {|comic_info_age_rating|
        $comic_info_age_rating.comic_info == $age_rating.comic_info_age_rating
      } | get --optional age_range_begin | first
      $age_rating | insert age_range_begin $age_range_begin
    };
    if ($age_ratings | is-not-empty) {
      $age_ratings | sort-by --reverse age_range_begin | first | get comic_info_age_rating
    }
  )

  let unfiltered_genres = (
    let cached_tags = $hardcover_edition | get --optional book.cached_tags;
    if ($cached_tags | is-not-empty) {
      let genres = $cached_tags | get --optional Genre
      if ($genres | is-not-empty) {
        $genres.tag | str downcase
      } else {
        []
      }
    } else {
      []
    }
  )

  # Surmise whether it is manga or not based on the Manga genre or tag and the disambiguation comment in the title or series name.
  # This is left as null for non-comics.
  let manga = (
    if $book_category == "graphic novel" {
      (
        "manga" in $unfiltered_genres
        or "manga" in $tags
        or " (Manga), " in $hardcover_edition.title
        or (
          $hardcover_edition
          | get --optional book.featured_book_series.series.name
          | (
            let input = $in;
            ($input | is-not-empty) and ($input | str ends-with " (Manga)")
          )
        )
      )
    } else {
      null
    }
  )
  # Attempt to deduce the form of creative work as manga volume or manhwa volume when the book category is "graphic novel"
  let form_of_creative_work = (
    if $book_category == "graphic novel" {
      if $manga {
        "manga volume"
      } else if (
          "manhua" in $unfiltered_genres
          or "manhua" in $tags
          or " (Manhua), " in $hardcover_edition.title
          or (
            $hardcover_edition
            | get --optional book.featured_book_series.series.name
            | (
              let input = $in;
              ($input | is-not-empty) and ($input | str ends-with " (Manhua)")
            )
          )
        ) {
        "manhua volume"
      } else if (
          "manhwa" in $unfiltered_genres
          or "manhwa" in $tags
          or " (Manhwa), " in $hardcover_edition.title
          or (
            $hardcover_edition
            | get --optional book.featured_book_series.series.name
            | (
              let input = $in;
              ($input | is-not-empty) and ($input | str ends-with " (Manhwa)")
            )
          )
        ) {
        "manhwa volume"
      } else {
        "graphic novel"
      }
    } else {
      $book_category
    }
  )

  (
    {
      issue: ($hardcover_edition | get --optional book.featured_book_series.position)
      series: (
        $hardcover_edition
        | get --optional book.featured_book_series.series.name
        | (
          let input = $in;
          if ($input | is-not-empty) {
            (
              $input
              | str replace " (Light Novel)" ""
              | str replace " (Manga)" ""
              | str replace " (Manhua)" ""
              | str replace " (Manhwa)" ""
              | use_unicode_in_title
            )
          }
        )
      )
      title: (
        if ($hardcover_edition | get --optional title | is-not-empty) {
          # todo Drop , after punctuation
          $hardcover_edition.title | standardize_hardcover_title | use_unicode_in_title
        }
      )
      description: $hardcover_edition.book.description
      volume: $series_begin_year
      issue_count: ($hardcover_edition | get --optional book.featured_book_series.series.books_count)
      ids: $ids
      isbn: ($hardcover_edition | get --optional isbn_13)
      characters: $characters
      language: $language
      # Use the forms_of_creative_work field for compatibility with Wikidata.
      forms_of_creative_work: [$form_of_creative_work]
      literary_type: $literary_type
      genres: $genres
      tags: $tags
      publication_date: ($hardcover_edition | get --optional release_date)
      publishers: [($hardcover_edition | get --optional publisher.name)]
      credits: $credits
      # todo Make sure this is a string?
      series_id: ($hardcover_edition | get --optional book.featured_book_series.series_id)
      _cover_image: [0, "", ($hardcover_edition | get --optional image.url) ($hardcover_edition | get --optional image.width) ($hardcover_edition | get --optional image.height)]
    }
    | upsert_if_value primary_series_author ($hardcover_edition | get --optional book.featured_book_series.series.author.name)
    | upsert_if_value comic_info_age_rating $comic_info_age_rating
    | upsert_if_value manga $manga
  )
}

# Get metadata for an edition on Hardcover by Hardcover edition id or another identifier.
#
# Requires the environment variable MEDIA_JUGGLER_HARDCOVER_API_TOKEN be set to a Hardcover API key.
export def fetch_and_parse_hardcover_edition [
  type: string # The identifier or field type, which is can be one of asin, isbn_10, isbn_13, id (which is the Hardcover edition ID)
  cache: closure
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> record] {
  let id = $in | str replace --all "-" ""
  if ($env | get --optional MEDIA_JUGGLER_HARDCOVER_API_TOKEN | is-empty) {
    log error "The environment variable MEDIA_JUGGLER_HARDCOVER_API_TOKEN must be set to a Hardcover API key to search by ISBN."
    return null
  }
  let token = (
    if ($env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN | str starts-with "Bearer ") {
      $env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN
    } else {
      "Bearer " + $env.MEDIA_JUGGLER_HARDCOVER_API_TOKEN
    }
  )

  let edition_response = $id | get_hardcover_edition $type $cache --retries $retries --retry-delay $retry_delay
  if ($edition_response | is-empty) {
    return null
  }
  $edition_response | parse_hardcover_edition
}
