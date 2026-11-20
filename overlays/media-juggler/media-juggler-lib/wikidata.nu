# Functions for querying Wikidata

use std log

use constants.nu *
use identifiers.nu *
use utils.nu *

# Search for editions on Wikidata by ISBN-13.
#
# Requires the environment variable MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN to set to a Wikidata access token.
# The environment variable WIKIDATA_USERNAME must also be set to your Wikidata username.
export def wikidata_search_editions_by_isbn [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> list<string>] {
  let isbn = $in | hyphenate_isbn
  if ($isbn | is-empty) {
    log error $"Error hyphenating ISBN (ansi yellow)($isbn)(ansi reset)"
    return null
  }

  for var in [WIKIDATA_USERNAME MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      return null
    }
  }

  let sparql_query = $"SELECT DISTINCT ?edition WHERE {
    ?edition wdt:P31/wdt:P279* wd:Q3331189.
    ?edition wdt:P212 '($isbn)'.
  }"

  # log debug $"sparql_query: ($sparql_query)"

  # https://query.wikidata.org/sparql?format=json&query=
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_sparql_api_url)($sparql_query | url encode)"
    )
  }

  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting Wikidata edition by ISBN-13 ($isbn) from (ansi yellow)($wikidata_sparql_api_url)($sparql_query | url encode)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) searching for Wikidata editions with ISBN-13 ($isbn) with SPARQL query ($sparql_query) at (ansi yellow)($wikidata_sparql_api_url)($sparql_query | url encode)(ansi reset): ($response.body)"
    return null
  }
  let bindings = $response.body | from json | get results.bindings
  if ($bindings | is-empty) {
    return null
  }
  (
    $bindings
    | get edition
    | where type == "uri"
    | get value
    | str replace "http://www.wikidata.org/entity/" ""
  )
}

# Obtain the metadata for a Wikidata edition ID
export def fetch_wikidata_edition_and_works_metadata [
  cache: closure
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> record] {
  let wikidata_edition_id = $in

  if ($wikidata_edition_id | is-empty) {
    error make {
      msg: "missing wikidata edition id"
      labels: [
        {text: "wikidata_edition_id" span: (metadata $wikidata_edition_id).span}
      ]
      help: "pipe in a Wikidata edition ID"
    }
  }

  for var in [WIKIDATA_USERNAME MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      error make {
        msg: "missing required Wikidata environment variable"
        labels: [
          {text: "env" span: (metadata $env).span}
        ]
        help: $"set the environment variable (ansi yellow)($var)(ansi reset)"
      }
    }
  }

  let update_function = {|type id|
    let request = {
      (
        http get --full --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_api_url)/entities/items/($id)"
      )
    }

    let response = (
      try {
        retry_http $request $retries $retry_delay
      } catch {|error|
        log error $"Error getting Wikidata edition ($id) from (ansi yellow)($wikidata_api_url)(ansi reset): ($error.debug)"
        return null
      }
    )
    if ($response.status != 200) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Wikidata item ($id) from (ansi yellow)($wikidata_api_url)/entities/items/($id)(ansi reset): ($response.body)"
      return null
    }
    $response.body
  }

  let edition = (do $cache "wikidata-item" $wikidata_edition_id $update_function null)
  let wikidata_work_ids = (
    if ($edition | get --optional statements.P629 | is-not-empty) {
      $edition.statements.P629 | where rank != "deprecated" | get --optional value.content
    }
  )
  let works = (
    $wikidata_work_ids | each {|wikidata_work_id|
      let update_function = {|type id|
        let request = {
          (
            http get --full --headers {
              "User-Agent": $user_agent
              "Accept": "application/json"
              "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
              "X-Authenticated-User": $env.WIKIDATA_USERNAME
            }
            $"($wikidata_api_url)/entities/items/($id)"
          )
        }

        let response = (
          try {
            retry_http $request $retries $retry_delay
          } catch {|error|
            log error $"Error getting Wikidata work at (ansi yellow)($wikidata_api_url)(ansi reset): ($error.debug)"
            return null
          }
        )
        if ($response.status != 200) {
          log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Wikidata item ($id) from (ansi yellow)($wikidata_api_url)/entities/items/($id)(ansi reset): ($response.body)"
          return null
        }
        # Avoid rate-limiting
        sleep 0.1sec
        $response.body
      }
      (do $cache "wikidata-item" $wikidata_work_id $update_function null)
    }
  )
  {
    edition: $edition
    works: $works
  }
}

# Parse the data from the Wikidata API for a Wikidata edition and its associated works
#
# Processing is limited to what information can be gleaned that doesn't require additional lookups.
# Call process_wikidata_edition_and_works_metadata on the result to retrieve additional information that requires further lookups.
export def parse_wikidata_edition_and_works_metadata [
  form_of_creative_work_map: table<name: string, wikidata_id: string> = $form_of_creative_work_wikidata
  genre_list: table<name: string, aliases: list<string>, wikidata_ids: list<string>> = $genre_allowlist # The table of mappings from Wikidata ID to genre
  genres_to_age_rating_map: table<genres: list<string>, comic_info_age_rating: string, metron_info_age_rating: string> = $genre_to_age_rating_comic_info_map
  intended_public_map: table<name: string, wikidata_id: string> = $intended_public_wikidata
  intended_publics_to_age_rating_map: table<intended_publics: list<string>, comic_info_age_rating: string, metron_info_age_rating: string> = $intended_public_to_age_rating_comic_info_map
  language_codes_map: table = $iso_language_codes_map
]: [record -> record] {
  let edition_and_works = $in
  let edition = $edition_and_works.edition
  let works = $edition_and_works | get --optional works

  let sort_by_rank = {|a b|
    let ranks = [preferred normal deprecated] | enumerate
    ($ranks | where item == $a.rank | first) < ($ranks | where item == $b.rank | first)
  }

  # Edition-related properties

  # P407
  let language = (
    let wikidata_languages = $edition | get --optional statements.P407;
    if ($wikidata_languages | is-empty) {
      error make {
        msg: "missing language for Wikidata edition"
        labels: [
          {text: "edition" span: (metadata $edition).span}
        ]
        help: $"add the language to the Wikidata edition (ansi yellow)(('https://www.wikidata.org/wiki/' + $edition.id) | ansi link --text $edition.id)(ansi reset) with property (ansi yellow)P407(ansi reset)"
      }
    };
    let wikidata_languages = $wikidata_languages | where rank != "deprecated";
    if ($wikidata_languages | is-empty) {
      error make {
        msg: "missing non-deprecated language for Wikidata edition"
        labels: [
          {text: "edition" span: (metadata $edition).span}
        ]
        help: $"add a language to the Wikidata edition (ansi yellow)(('https://www.wikidata.org/wiki/' + $edition.id) | ansi link --text $edition.id)(ansi reset) with property (ansi yellow)P407(ansi reset) which isn't deprecated"
      }
    };
    let wikidata_languages = (
      $wikidata_languages
      | sort-by --custom $sort_by_rank
      | get --optional value.content
    );
    if ($wikidata_languages | is-empty) {
      null
    } else {
      if ($wikidata_languages | length) > 1 {
        log warning $"Multiple languages found for Wikidata edition (ansi yellow)($edition.id)(ansi reset): ($wikidata_languages). Using only the first."
      }
      let wikidata_language = $wikidata_languages | first
      let languages = $language_codes_map | where wikidata_id == $wikidata_language
      if ($languages | is-empty) {
        error make {
          msg: "missing language mapping for Wikidata item ID"
          labels: [
            {text: "wikidata_language" span: (metadata wikidata_language).span}
          ]
          help: $"add a mapping for the Wikidata language ID (ansi yellow)(('https://www.wikidata.org/wiki/' + $wikidata_language) | ansi link --text $wikidata_language)(ansi reset) to the language_codes_map table"
        }
      } else {
        $languages.language | first
      }
    }
  )

  # P577: publication date
  let publication_date = (
    let wikidata_publication_dates = $edition | get --optional statements.P577;
    if ($wikidata_publication_dates | is-empty) {
      error make {
        msg: "missing publication date for Wikidata edition"
        labels: [
          {text: "edition" span: (metadata $edition).span}
        ]
        help: $"add the publication date to the Wikidata edition (ansi yellow)(('https://www.wikidata.org/wiki/' + $edition.id) | ansi link --text $edition.id)(ansi reset) with property (ansi yellow)P407(ansi reset)"
      }
    };
    let wikidata_publication_dates = $wikidata_publication_dates | where rank != "deprecated";
    if ($wikidata_publication_dates | is-empty) {
      error make {
        msg: "missing non-deprecated publication date for Wikidata edition"
        labels: [
          {text: "edition" span: (metadata $edition).span}
        ]
        help: $"add a publication date to the Wikidata edition (ansi yellow)(('https://www.wikidata.org/wiki/' + $edition.id) | ansi link --text $edition.id)(ansi reset) with property (ansi yellow)P407(ansi reset) which isn't deprecated"
      }
    };
    let wikidata_publication_dates = (
      $wikidata_publication_dates
      | sort-by --custom $sort_by_rank
      | get --optional value.content
    );
    if ($wikidata_publication_dates | is-empty) {
      null
    } else {
      if ($wikidata_publication_dates | length) > 1 {
        log warning $"Multiple publication dates found for Wikidata edition (ansi yellow)($edition.id)(ansi reset): ($wikidata_publication_dates). Using only the first."
      }
      let wikidata_publication_date = $wikidata_publication_dates | first
      if ($wikidata_publication_date.calendarmodel != "http://www.wikidata.org/entity/Q1985727") {
        error make {
          msg: "unsupported calendar model for publication date"
          labels: [
            {text: "wikidata_publication_date.calendarmodel" span: (metadata wikidata_publication_date.calendarmodel).span}
          ]
          help: $"the publication date on the Wikidata edition (ansi yellow)($edition.id)(ansi reset) has a calendar model of (ansi yellow)($wikidata_publication_date.calendarmodel)(ansi reset) which is not supported. Only (ansi yellow)(http://www.wikidata.org/entity/Q1985727)(ansi reset) is supported."
        }
      }
      $wikidata_publication_date.time | str trim --left --char "+" | into datetime --timezone UTC
    }
  )

  let sort_by_rank_then_wikidata_id = {|a b|
    let ranks = [preferred normal deprecated] | enumerate
    if ($a.rank == $b.rank) {
      $a.wikidata_id < $b.wikidata_id
    } else {
      ($ranks | where item == $a.rank | first) < ($ranks | where item == $b.rank | first)
    }
  }

  # On Wikidata, typically the publisher is actually the imprint.
  # This can be further verified by checking that the publisher is an instance of an imprint or one of its subclasses.
  # The publishers require further processing.
  # Uses object_named_as for the name if present
  let publishers = (
    # P123: publisher
    # P1932: object named as
    let wikidata_publishers = $edition | get --optional statements.P123 | where {|item| $item | is-not-empty};
    if ($wikidata_publishers | is-empty) {
      error make {
        msg: "missing publisher for Wikidata edition"
        labels: [
          {text: "edition" span: (metadata $edition).span}
        ]
        help: $"add the publisher to the Wikidata edition (ansi yellow)(('https://www.wikidata.org/wiki/' + $edition.id) | ansi link --text $edition.id)(ansi reset) with property (ansi yellow)P123(ansi reset)"
      }
    };
    let wikidata_publishers = $wikidata_publishers | where rank != "deprecated";
    if ($wikidata_publishers | is-empty) {
      error make {
        msg: "missing non-deprecated publisher for Wikidata edition"
        labels: [
          {text: "edition" span: (metadata $edition).span}
        ]
        help: $"add a publisher to the Wikidata edition (ansi yellow)(('https://www.wikidata.org/wiki/' + $edition.id) | ansi link --text $edition.id)(ansi reset) with property (ansi yellow)P123(ansi reset) which isn't deprecated"
      }
    };
    let wikidata_publishers = $wikidata_publishers | sort-by --custom $sort_by_rank_then_wikidata_id;
    let wikidata_publishers = $wikidata_publishers | each {|wikidata_publisher|
      let object_named_as = $wikidata_publisher | get qualifiers | where property.id == "P1932" | get --optional value.content
      {
        wikidata_id: $wikidata_publisher.value.content
        object_named_as: $object_named_as
      }
    };
    if ($wikidata_publishers | is-empty) {
      []
    } else {
      $wikidata_publishers
    }
  )

  let omnibus = (
    # P31: instance of
    "Q13137339" in $edition.statements.P31.value
  )

  # Work-related properties

  let genres = (
    let wikidata_genres = $works.statements | get --optional P136 | where {|item| $item | is-not-empty};
    let wikidata_genres = (
      if ($wikidata_genres | is-empty) {
        []
      } else {
        let wikidata_genres = $wikidata_genres | flatten | where rank != "deprecated"
        if ($wikidata_genres | is-empty) {
          error make {
            msg: "missing non-deprecated genres for Wikidata works"
            labels: [
              {text: "works" span: (metadata $works).span}
            ]
            help: $"add non-deprecated genres, property (ansi yellow)P136(ansi reset), to the Wikidata works"
          }
        } else {
          # log debug $"Wikidata genres: ($wikidata_genres | to nuon)"
          $wikidata_genres | get --optional value.content | uniq
        }
      }
    );
    $wikidata_genres | each {|wikidata_genre|
      let $matching_genres = $genre_list | where {|g| $wikidata_genre in $g.wikidata_ids}
      if ($matching_genres | is-empty) {
        error make {
          msg: "missing wikidata id for genre"
          labels: [
            {text: "wikidata_genre" span: (metadata $wikidata_genre).span}
          ]
          help: $"add the wikidata id (ansi yellow)(('https://www.wikidata.org/wiki/' + $wikidata_genre) | ansi link --text $wikidata_genre)(ansi reset) to the genre table"
        }
      } else if ($matching_genres | length) > 1 {
        error make {
          msg: "duplicate wikidata id for genre"
          labels: [
            {text: "wikidata_genre" span: (metadata $wikidata_genre).span}
          ]
          help: $"remove the duplicate wikidata id (ansi yellow)(('https://www.wikidata.org/wiki/' + $wikidata_genre) | ansi link --text $wikidata_genre)(ansi reset) from the genre table"
        }
      } else {
        $matching_genres.name | first
      }
    } | sort
  )

  let forms_of_creative_work = (
    # P7937: form of creative work
    let wikidata_forms = $works.statements | get --optional P7937 | where {|item| $item | is-not-empty};
    let wikidata_forms = (
      if ($wikidata_forms | is-empty) {
        []
      } else {
        let wikidata_forms = $wikidata_forms | flatten | where rank != "deprecated"
        if ($wikidata_forms | is-empty) {
          error make {
            msg: "missing non-deprecated forms for Wikidata works"
            labels: [
              {text: "works" span: (metadata $works).span}
            ]
            help: $"add non-deprecated forms, property (ansi yellow)P7937(ansi reset), to the Wikidata works"
          }
        } else {
          $wikidata_forms | get --optional value.content | uniq
        }
      }
    );
    # log debug $"Wikidata forms of creative work: ($wikidata_forms | to nuon)";
    $wikidata_forms | each {|wikidata_form|
      let $matching_forms = $form_of_creative_work_map | where wikidata_id == $wikidata_form
      if ($matching_forms | is-empty) {
        error make {
          msg: "missing wikidata id for form of creative work"
          labels: [
            {text: "wikidata_form" span: (metadata $wikidata_form).span}
          ]
          help: $"add the wikidata id (ansi yellow)(('https://www.wikidata.org/wiki/' + $wikidata_form) | ansi link --text $wikidata_form)(ansi reset) to the form of creative works table"
        }
      } else if ($matching_forms | length) > 1 {
        error make {
          msg: "duplicate wikidata id for form of creative work"
          labels: [
            {text: "wikidata_form" span: (metadata $wikidata_form).span}
          ]
          help: $"remove the duplicate wikidata id (ansi yellow)(('https://www.wikidata.org/wiki/' + $wikidata_form) | ansi link --text $wikidata_form)(ansi reset) from the form of creative works table"
        }
      } else {
        $matching_forms.name | first
      }
    } | sort
  )

  let intended_publics = (
    # P2360: intended public
    let wikidata_intended_publics = $works.statements | get --optional P2360 | where {|item| $item | is-not-empty};
    let wikidata_intended_publics = (
      if ($wikidata_intended_publics | is-empty) {
        []
      } else {
        let wikidata_intended_publics = $wikidata_intended_publics | flatten | where rank != "deprecated"
        if ($wikidata_intended_publics | is-empty) {
          error make {
            msg: "missing non-deprecated intended public for Wikidata works"
            labels: [
              {text: "works" span: (metadata $works).span}
            ]
            help: $"add non-deprecated intended public, property (ansi yellow)P2360(ansi reset), to the Wikidata works"
          }
        } else {
          $wikidata_intended_publics | get --optional value.content | uniq
        }
      }
    );
    $wikidata_intended_publics | each {|wikidata_intended_public|
      let $matching_intended_publics = $intended_public_map | where wikidata_id == $wikidata_intended_public
      if ($matching_intended_publics | is-empty) {
        # todo This should probably be loosened to just ignore unknown intended publics.
        error make {
          msg: "missing wikidata id mapping for intended public"
          labels: [
            {text: "wikidata_intended_public" span: (metadata $wikidata_intended_public).span}
          ]
          help: $"add the wikidata id (ansi yellow)(('https://www.wikidata.org/wiki/' + $wikidata_intended_public) | ansi link --text $wikidata_intended_public)(ansi reset) to the intended publics table"
        }
      } else if ($matching_intended_publics | length) > 1 {
        error make {
          msg: "duplicate wikidata id mapping for intended public"
          labels: [
            {text: "wikidata_intended_public" span: (metadata $wikidata_intended_public).span}
          ]
          help: $"remove the duplicate wikidata id (ansi yellow)(('https://www.wikidata.org/wiki/' + $wikidata_intended_public) | ansi link --text $wikidata_intended_public)(ansi reset) from the intended publics table"
        }
      } else {
        $matching_intended_publics.name | first
      }
    } | sort
  )

  let manga = (
    if ($forms_of_creative_work | any {|form| $form in ["manga" "manga volume" "manga chapter"]}) {
      "YesAndRightToLeft"
    } else if  ($forms_of_creative_work | any {|form| $form in ["manhua" "manhua volume" "manhwa" "manhwa volume"]}) {
      # Not technically true, but this implies that the volume should be treated in the same manner as it is for manga in the ComicInfo.xml.
      "Yes"
    } else {
      "No"
    }
  )

  # Requires subsequent processing to get the label language.
  let main_subjects = (
    # P921: main subject
    let wikidata_main_subjects = $works.statements | get --optional P921 | where {|item| $item | is-not-empty};
    if ($wikidata_main_subjects | is-empty) {
      []
    } else {
      # log debug $"Wikidata main subjects: ($wikidata_main_subjects | to nuon)"
      let wikidata_main_subjects = $wikidata_main_subjects | flatten | where rank != "deprecated"
      if ($wikidata_main_subjects | is-empty) {
        error make {
          msg: "missing non-deprecated main subject for Wikidata works"
          labels: [
            {text: "works" span: (metadata $works).span}
          ]
          help: $"add non-deprecated main subject, property (ansi yellow)P921(ansi reset), to the Wikidata works"
        }
      } else {
        $wikidata_main_subjects | sort-by --custom $sort_by_rank | get --optional value.content | sort | uniq
      }
    }
  )

  let tags = (
    []
    | append (
      if $omnibus {
        "omnibus"
      }
    )
    | append (
      if ($forms_of_creative_work | is-not-empty) {
        # Don't include manga/manhwa volume/chapter tags for brevity.
        if "manga volume" in $forms_of_creative_work or "manga chapter" in $forms_of_creative_work {
          "manga"
        } else if "manhua volume" in $forms_of_creative_work or "manhua chapter" in $forms_of_creative_work {
          "manhua"
        } else if "manhwa volume" in $forms_of_creative_work or "manhwa chapter" in $forms_of_creative_work {
          "manhwa"
        } else {
          $forms_of_creative_work
        }
      }
    )
    | append (
      if ($intended_publics | is-not-empty) {
        # Only use certain intended publics as tags, at least for now.
        $intended_publics | where {|intended_public| $intended_public in [shōnen seinen shōjo josei]}
      }
    )
    | sort
    | uniq
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

  # tags:
  # omnibus edition -> format?

  (
    {}
    | upsert_if_value comic_info_age_rating $comic_info_age_rating
    | upsert_if_value forms_of_creative_work $forms_of_creative_work
    | upsert_if_value genres $genres
    | upsert_if_value intended_publics $intended_publics
    | upsert_if_value language $language
    | upsert_if_value main_subjects $main_subjects
    | upsert_if_value manga $manga
    | upsert_if_value publication_date $publication_date
    | upsert_if_value publishers $publishers
    | upsert_if_value tags $tags
  )
}

# Process the metadata for a Wikidata edition and its associated works for items requiring additional lookups to the Wikidata API
#
# Should be called on the result of parse_wikidata_edition_and_works_metadata.
# The fields that are processed further are:
#   main_subjects: Labels are looked up and added to tags
#   publishers: Labels are looked up for publishers and they are divided between publishers and imprints
export def process_wikidata_edition_and_works_metadata [
  wikidata_language_code: string # The language code to use when looking up labels
  cache: closure
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [record -> record] {
  let metadata = $in

  if ($wikidata_language_code | str length) != 2 {
    error make {
      msg: "invalid Wikidata language code"
      labels: [
        {text: "wikidata_language_code" span: (metadata $wikidata_language_code).span}
      ]
      help: "the wikidata_language_code argument must be a 2-letter language code"
    }
  }

  if ($metadata | is-empty) {
    return $metadata
    # error make {
    #   msg: "empty edition and works data"
    #   labels: [
    #     {text: "edition_and_works" span: (metadata $edition_and_works).span}
    #   ]
    #   help: $"pipe in the edition and works data"
    # }
  }

  for var in [WIKIDATA_USERNAME MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      error make {
        msg: "missing required Wikidata environment variable"
        labels: [
          {text: "env" span: (metadata $env).span}
        ]
        help: $"set the environment variable (ansi yellow)($var)(ansi reset)"
      }
    }
  }

  let label_update_function = {|type id|
    let request = {
      (
        http get --full --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_api_url)/entities/items/($id)/labels/($wikidata_language_code)"
      )
    }

    let response = (
      try {
        retry_http $request $retries $retry_delay
      } catch {|error|
        log error $"Error getting the (ansi yellow)($wikidata_language_code)(ansi reset) label of Wikidata item (ansi yellow)($id)(ansi reset) from (ansi yellow)($wikidata_api_url)/entities/items/($id)/labels/($wikidata_language_code)(ansi reset): ($error.debug)"
        return null
      }
    )
    if ($response.status != 200) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) getting the (ansi yellow)($wikidata_language_code)(ansi reset) label of Wikidata item ($id) from (ansi yellow)($wikidata_api_url)/entities/items/($id)/labels/($wikidata_language_code)(ansi reset): ($response.body)"
      return null
    }
    # Avoid rate-limiting
    sleep 0.1sec
    { label: $response.body }
  }

  # main_subject
  let main_subjects = (
    let wikidata_main_subjects = $metadata | get --optional main_subjects | each {|wikidata_main_subject|
      let label = (do $cache "wikidata-label" $wikidata_main_subject $label_update_function $wikidata_language_code) | get --optional label
      if ($label | is-empty) {
        log warning $"Missing (ansi yellow)($wikidata_language_code)(ansi reset) label for main subject Wikidata item (ansi yellow)($wikidata_main_subject)(ansi reset). Ignoring main subject."
        null
      } else {
        $label
      }
    };
    if ($wikidata_main_subjects | is-empty) {
      []
    } else {
      $wikidata_main_subjects | where {|label| $label | is-not-empty} | sort | uniq
    }
  )

  let item_update_function = {|type id|
    let request = {
      (
        http get --full --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_api_url)/entities/items/($id)"
      )
    }

    let response = (
      try {
        retry_http $request $retries $retry_delay
      } catch {|error|
        log error $"Error getting Wikidata item (ansi yellow)($id)(ansi reset) from (ansi yellow)($wikidata_api_url)/entities/items/($id)(ansi reset): ($error.debug)"
        return null
      }
    )
    if ($response.status != 200) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Wikidata item ($id) from (ansi yellow)($wikidata_api_url)/entities/items/($id)(ansi reset): ($response.body)"
      return null
    }
    # Avoid rate-limiting
    sleep 0.1sec
    $response.body
  }

  let imprint_wikidata_ids = [
    Q2608849 # imprint
    Q115693088 # manga imprint
    Q115693146 # comic book imprint
    Q139545998 # light novel imprint
  ]

  let publishers = (
    let wikidata_publishers = $metadata | get --optional publishers | each {|wikidata_publisher|
      let item = (do $cache "wikidata-item" $wikidata_publisher.wikidata_id $item_update_function null)
      let name = (
        # For consistency, ignore object named as for now
        # if ($wikidata_publisher | get --optional object_named_as | is-empty) {
          if ($item | get --optional labels | get --optional $wikidata_language_code | is-empty) {
            log error $"Missing (ansi yellow)($wikidata_language_code)(ansi reset) label for publisher Wikidata item (ansi yellow)($wikidata_publisher.wikidata_id)(ansi reset)."
            null
          } else {
            $item.labels | get $wikidata_language_code
          }
        # } else {
        #   $wikidata_publisher.object_named_as
        # }
      )
      # Is the item an imprint of some kind?
      # todo Get the actual publisher name when the item is an imprint.
      # This will probably be complicated.
      # P31: instance of
      let is_imprint = $item | get --optional statements.P31.value.content | any {|item| $item in $imprint_wikidata_ids}
      # log debug $"is_imprint: ($is_imprint)"
      {
        name: $name
        is_imprint: $is_imprint
      }
    };
    if ($wikidata_publishers | is-empty) {
      []
    } else {
      $wikidata_publishers | where {|item| $item.name | is-not-empty} | uniq
    }
  )

  let tags = (
    if ($metadata | get --optional tags | is-empty) {
      []
    } else {
      $metadata.tags
    } | append $main_subjects | sort
  )

  (
    $metadata
    | upsert tags $tags
    | upsert_if_value imprints ($publishers | where is_imprint | get --optional name)
    | upsert_if_value main_subjects $main_subjects
    | upsert_if_value publishers ($publishers | where not is_imprint | get --optional name)
  )
}

# Search for an edition on Wikidata by BLAKE3 or SHA3-512 checksum.
#
# Requires the environment variable MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN to set to a Wikidata access token.
# The environment variable WIKIDATA_USERNAME must also be set to your Wikidata username.
#
# This will only work for unmodified release assets, of course.
export def wikidata_search_editions_by_checksum [
  type: string # The type of checksum, either "blake3" or "sha3-512"
  file_size: filesize # The size of the file
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> list<string>] {
  let checksum = $in
  if ($checksum | is-empty) {
    log error "No checksum provided!"
    return null
  }
  if $type not-in [blake3 sha3-512] {
    log error $"The type must be either (ansi yellow)blake3(ansi reset) or (ansi yellow)sha3-512(ansi reset)"
    return null
  }

  for var in [WIKIDATA_USERNAME MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      return null
    }
  }

  let checksum_type = (
    if $type == "blake3" {
      "Q81575705"
    } else if $type == "sha3-512" {
      "Q110651449"
    }
  )

  # let data_size_bytes = $file_size | format filesize B
  # let data_size_mebibytes = $file_size | format filesize MiB

  # todo Use data size.
  # Data size isn't normalizable on Wikidata.
  # So, I need to do something special to normalize the data.
  #
  # ?statement pq:P3575 ?nodeDataSize.
  # ?statement pqv:P3575 ?valueNodeDataSize.
  # ?valueNodeDataSize wikibase:quantityAmount "+160.16015625"^^xsd:decimal.
  # ?valueNodeDataSize wikibase:quantityUnit wd:Q79758.

  let sparql_query = $"SELECT DISTINCT ?edition WHERE {
    ?edition wdt:P31/wdt:P279* wd:Q3331189.
    ?edition p:P4092 ?statement.
    ?statement ps:P4092 '($checksum)'.
    ?statement pq:P459 wd:($checksum_type).
  }"

  # log debug $"sparql_query: ($sparql_query)"

  # https://query.wikidata.org/sparql?format=json&query=
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_sparql_api_url)($sparql_query | url encode)"
    )
  }

  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting Wikidata edition by the ($type | str upcase) checksum ($checksum) from (ansi yellow)($wikidata_sparql_api_url)($sparql_query | url encode)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) searching for Wikidata editions with the ($type | str upcase) checksum ($checksum) with SPARQL query ($sparql_query) at (ansi yellow)($wikidata_sparql_api_url)($sparql_query | url encode)(ansi reset): ($response.body)"
    return null
  }
  let bindings = $response.body | from json | get results.bindings
  if ($bindings | is-empty) {
    return null
  }
  (
    $bindings
    | get edition
    | where type == "uri"
    | get value
    | str replace "http://www.wikidata.org/entity/" ""
  )
}

# Search for editions on Wikidata by Amazon ASIN.
#
# Requires the environment variable MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN to set to a Wikidata access token.
# The environment variable WIKIDATA_USERNAME must also be set to your Wikidata username.
export def wikidata_search_editions_by_asin [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> list<string>] {
  let asin = $in
  for var in [WIKIDATA_USERNAME MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      return null
    }
  }

  let sparql_query = $"SELECT DISTINCT ?edition WHERE {
    ?edition wdt:P31/wdt:P279* wd:Q3331189.
    ?edition wdt:P5749 '($asin)'.
  }"

  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_sparql_api_url)($sparql_query | url encode)"
    )
  }

  # log debug $"sparql_query: ($sparql_query)"

  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting Wikidata edition by Amazon ASIN ($asin) from (ansi yellow)($wikidata_sparql_api_url)($sparql_query | url encode)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) searching for Wikidata editions with Amazon ASIN ($asin) with SPARQL query ($sparql_query) at (ansi yellow)($wikidata_sparql_api_url)($sparql_query | url encode)(ansi reset): ($response.body)"
    return null
  }
  let bindings = $response.body | from json | get results.bindings
  if ($bindings | is-empty) {
    return null
  }
  (
    $bindings
    | get edition
    | where type == "uri"
    | get value
    | str replace "http://www.wikidata.org/entity/" ""
  )
}

# Search for editions on Wikidata by Comic Vine ID.
#
# Requires the environment variable MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN to set to a Wikidata access token.
# The environment variable WIKIDATA_USERNAME must also be set to your Wikidata username.
export def wikidata_search_editions_by_comic_vine_id [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> list<string>] {
  let comic_vine_id = $in
  let comic_vine_id = (
    if ($comic_vine_id | str starts-with "4000-") {
      $comic_vine_id
    } else {
      "4000-" + $comic_vine_id
    }
  )
  for var in [WIKIDATA_USERNAME MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      return null
    }
  }

  let sparql_query = $"SELECT DISTINCT ?edition WHERE {
    ?edition wdt:P31/wdt:P279* wd:Q3331189.
    ?edition wdt:P5905 '($comic_vine_id)'.
  }"

  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_sparql_api_url)($sparql_query | url encode)"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting Wikidata edition by Comic Vine ID ($comic_vine_id) from (ansi yellow)($wikidata_sparql_api_url)($sparql_query | url encode)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) searching for Wikidata editions with Comic Vine ID ($comic_vine_id) with SPARQL query ($sparql_query) at (ansi yellow)($wikidata_sparql_api_url)($sparql_query | url encode)(ansi reset): ($response.body)"
    return null
  }
  let bindings = $response.body | from json | get results.bindings
  if ($bindings | is-empty) {
    return null
  }
  (
    $bindings
    | get edition
    | where type == "uri"
    | get value
    | str replace "http://www.wikidata.org/entity/" ""
  )
}

# Get identifiers for an edition on Wikidata
export def wikidata_get_edition_identifiers [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> list<string>] {
  let wikidata_edition_id = $in
  for var in [WIKIDATA_USERNAME MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      return null
    }
  }
  let wikidata_identifier_properties = [
    [id name];
    [P5905 "Comic Vine ID"]
    [P12351 "BookBrainz edition ID"]
    [P212 "ISBN-13"]
    [P648 "Open Library ID"]
  ]

  let request = {
    (
      http get --full --headers {
        "User-Agent": $user_agent
        "Accept": "application/json"
        "Authorization": $"Bearer ($env.MEDIA_JUGGLER_WIKIDATA_ACCESS_TOKEN)"
        "X-Authenticated-User": $env.WIKIDATA_USERNAME
      }
      $"($wikidata_api_url)/entities/items/($wikidata_edition_id)/statements"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting Wikidata item ($wikidata_edition_id) from (ansi yellow)($wikidata_api_url)/entities/items/($wikidata_edition_id)/statements(ansi reset): ($error.debug)"
      exit 1
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Wikidata item ($wikidata_edition_id) from (ansi yellow)($wikidata_api_url)/entities/items/($wikidata_edition_id)/statements(ansi reset): ($response.body)"
    exit 1
  }
  let statements = $response.body
  # log debug $"statements:\n($statements | to json)\n"
  let result = $wikidata_identifier_properties | reduce --fold {} {|property, acc|
    let values = $statements | get --optional $property.id | get --optional value.content
    if ($values | is-empty) {
      $acc
    } else {
      let values = (
        if ($property.name == "ISBN-13") {
          $values | str replace --all "-" ""
        } else if ($property.name == "Comic Vine ID") {
          $values | str replace "4000-" ""
        } else {
          $values
        }
      )
      $acc | insert $property.name $values
    }
  }

  # log debug $"wikidata identifiers:\n($result | to json)\n"
  $result
}
