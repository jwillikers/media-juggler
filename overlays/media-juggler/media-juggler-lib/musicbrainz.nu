# Functions for querying the MusicBrainz API and the Cover Art Archive

# Functions prefixed with "fetch_" are used to query the MusicBrainz API.
# Functions prefixed with "parse_" are used to parse responses from the MusicBrainz API without making any external calls.
# This allows using unit tests for the functions prefixed with "parse_".

use std log

use chapters.nu *
use constants.nu *
use identifiers.nu *
use metadata.nu *
use utils.nu *

# Get the release group to which a release belongs
export def fetch_musicbrainz_release_group_for_release []: string -> table {
  let release_id = $in
  let url = "https://musicbrainz.org/ws/2/release-group/"
  let query = $"reid:($release_id)" | url encode
  (musicbrainz_get $"($url)/?query=($query)").body
}

# Fetch the front cover image of a release from the Cover Art Archive
export def fetch_release_front_cover [
  download_directory: directory
  size: string = original # original, 1200, 500, or 250
  --retries: int = 3
  --retry-delay: duration = 3sec
]: string -> path {
  let release_id = $in
  let url = "https://coverartarchive.org/release"
  let request = {http get --full --headers [User-Agent $user_agent] $"($url)/($release_id)"}
  let response = retry_http $request $retries $retry_delay
  let front_covers = $response | get body | get images | where front == true | select id image thumbnails
  if ($front_covers | is-empty) {
    return null
  }
  let cover = $front_covers | first

  # thumbnail sizes are 1200, 500, and 250
  let download_url = (
    if $size == "original" {
      $cover | get image
    } else {
      $cover | get thumbnails | get $size
    }
  )
  let filename = $download_url | url parse | get path | path basename
  let destination = $download_directory | path join $filename
  # If the path exists, skip the download.
  if ($destination | path exists) {
    return $destination
  }
  let download_request = {http get --headers [User-Agent $user_agent] $download_url}
  let destination = retry_download $download_request $destination $retries $retry_delay
  if ($destination | is-empty) {
    log error $"Error downloading cover image from ($download_url) to ($destination)"
    return null
  }
  $destination
}

# Fetch a release group from MusicBrainz by ID
export def fetch_musicbrainz_release_group [
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  let release_group_id = $in
  let url = "https://musicbrainz.org/ws/2/release-group"
  let request = {musicbrainz_get $"($url)/($release_group_id)/?inc=series-rels"}
  retry_http $request $retries $retry_delay
}

# Get a Release with all of the gory details
export def fetch_musicbrainz_release [
  includes: list<string> = [
    aliases
    artist-credits
    labels
    recordings
    release-groups
    media
    genres
    tags
    release-group-rels
    work-rels
    series-rels
    genre-rels
    artist-rels
    label-rels
    recording-level-rels
    release-group-level-rels
    work-level-rels
    url-rels # for Audible ASIN
  ]
  --retries: int = 3
  --retry-delay: duration = 5sec
]: [
  string -> record
  string -> nothing
] {
  let release_id = $in
  let url = "https://musicbrainz.org/ws/2/release"
  let request = {musicbrainz_get $"($url)/($release_id)/?inc=($includes | str join '+')"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error fetching MusicBrainz Release: ($url): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code (ansi red)($response.status)(ansi reset) when fetching MusicBrainz Release: ($url)"
    return null
  }
  $response.body
}

# Get a MusicBrainz Work by id
export def fetch_musicbrainz_work [
  includes: list<string> = [series-rels genres tags url-rels]
  --retries: int = 3
  --retry-delay: duration = 5sec
]: [
  string -> record
  string -> nothing
] {
  let work_id = $in
  let url = "https://musicbrainz.org/ws/2/work"
  let request = {musicbrainz_get $"($url)/($work_id)/?inc=($includes | str join '+')"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error fetching MusicBrainz Work: ($url): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code (ansi red)($response.status)(ansi reset) when fetching MusicBrainz Work: ($url)"
    return null
  }
  $response.body
}

# Parse a MusicBrainz Work
export def parse_musicbrainz_work []: record -> record<id: string, title: string, language: string, genres: table<name: string, count: int>, tags: table<name: string, count: int>> {
  let input = $in
  if ($input | is-empty) {
    return null
  }
  let genres_and_tags = $input | select --optional genres tags | parse_genres_and_tags
  {
    id: $input.id
    title: $input.title
    language: $input.language
    genres: $genres_and_tags.genres
    tags: $genres_and_tags.tags
  }
}

# Fetch and parse a MusicBrainz Work by ID
export def fetch_and_parse_musicbrainz_work [
  cache: closure # Closure that returns parsed work information given a type and a work id
  --retries: int = 3
  --retry-delay: duration = 3sec
]: string -> record {
  let musicbrainz_work_id = $in
  let update_function = {|type id|
    let work = (
      $id | fetch_musicbrainz_work --retries $retries --retry-delay $retry_delay
    )

    if ($work | is-not-empty) {
      $work | parse_musicbrainz_work
    }
  }
  do $cache "work" $musicbrainz_work_id $update_function null
}

# Get a Series
export def fetch_musicbrainz_series [
  includes: list<string> = [series-rels genres tags]
  --retries: int = 3
  --retry-delay: duration = 5sec
]: [
  string -> record
  string -> nothing
] {
  let series_id = $in
  let url = "https://musicbrainz.org/ws/2/series"
  let request = {musicbrainz_get $"($url)/($series_id)/?inc=($includes | str join '+')"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error fetching MusicBrainz Series: ($url): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code (ansi red)($response.status)(ansi reset) when fetching MusicBrainz Series: ($url)"
    return null
  }
  $response.body
}

# Parse a MusicBrainz series
export def parse_musicbrainz_series []: record -> record<id: string, name: string, subseries: table<id: string, name: string>, parent_series: table<id: string, name: string>, genres: table<name: string, count: int>, tags: table<name: string, count: int>> {
  let input = $in
  if ($input | is-empty) {
    return null
  }
  let genres_and_tags = $input | select --optional genres tags | parse_genres_and_tags
  let series = {
    id: $input.id
    name: $input.name
    parent_series: []
    subseries: []
    genres: $genres_and_tags.genres
    tags: $genres_and_tags.tags
  }
  let relations = $input | get --optional relations
  if ($relations | is-empty) {
    return $series
  }
  let series_relations = $relations | where target-type == "series"
  if ($series_relations | is-empty) {
    return $series
  }
  let parent_series_relations = $series_relations | where direction == "backward"
  let parent_series = (
    if ($parent_series_relations | is-empty) {
      []
    } else {
      $parent_series_relations.series | select id name
    }
  )
  let subseries_relations = $series_relations | where direction == "forward"
  let subseries = (
    if ($subseries_relations | is-empty) {
      []
    } else {
      $subseries_relations.series | select id name
    }
  )
  $series | upsert parent_series $parent_series | upsert subseries $subseries
}

# Fetch and parse a MusicBrainz Series by ID.
export def fetch_and_parse_musicbrainz_series [
  cache: closure # Closure that returns parsed series information given a type and a series id
  --retries: int = 3
  --retry-delay: duration = 3sec
]: string -> record {
  let musicbrainz_series_id = $in
  let update_cache = {|type id|
    let series = (
      $id | fetch_musicbrainz_series --retries $retries --retry-delay $retry_delay
    )
    if ($series | is-not-empty) {
      $series | parse_musicbrainz_series
    }
  }
  do $cache "series" $musicbrainz_series_id $update_cache null
}

# Build a tree of subseries going up through the parent series
export def build_series_tree_up [
  depth: int
  # cache: directory # Cache directory where HTTP responses are stored in files named according to mbid, i.e. mbid.json.
  cache: closure # Cache directory where HTTP responses are stored in files named according to mbid, i.e. mbid.json.
  --required-series: list<string>
  --retries: int = 3
  --retry-delay: duration = 3sec
]: record -> record {
  let series = $in

  # log info $"Series: ($series)"
  # log info $"Depth: ($depth)"

  # Base case: No parent series
  if ($series | get --optional parent_series | is-empty) {
    return $series
  }

  # Alternate base case, this is the last required series.
  if ($required_series != null and ($required_series | length) == 1) and ($required_series | first) == $series.id {
    return $series
  }

  # Hit max depth
  if ($depth <= 0) {
    log error $"Reached max depth at series: ($series). Unwinding!"
    # I could return null here to signal the error.
    return $series
  }

  $series | upsert parent_series (
    # log info $"$series.parent_series: ($series.parent_series | to nuon)";
    # $series.parent_series | each {|parent_series|
      # log info $"$parent_series: ($parent_series | to nuon)";
      # log info $"$parent_series.id: ($parent_series.id)";
    # };
    $series.parent_series | each {|parent_series|
      # log info $"parent_series: ($parent_series)"
      if $required_series == null {
        # log info $"parent_series.id: ($parent_series.id)"
        $parent_series.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay | build_series_tree_up ($depth - 1) $cache
      } else {
        $parent_series.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay | build_series_tree_up ($depth - 1) $cache --required-series ($required_series | where {|id| $id != $series.id})
      }
    }
  )
}

# Build a tree of subseries under a series
export def build_series_tree [
  depth: int
  # cache: directory # Cache directory where HTTP responses are stored in files named according to mbid, i.e. mbid.json.
  cache: closure
  --required-series: list<string>
  --retries: int = 3
  --retry-delay: duration = 3sec
]: record -> record {
  let series = $in

  # Base case: No subseries (leaf node)
  if ($series | get --optional subseries | is-empty) {
    return $series
  }

  # Alternate base case, this is the last required series.
  if ($required_series != null and ($required_series | length) == 1) and ($required_series | first) == $series.id {
    return $series
  }

  # Hit max depth
  if ($depth <= 0) {
    log error $"Reached max depth at series: ($series). Unwinding!"
    # I could return null here to signal the error.
    return $series
  }

  $series | upsert subseries (
    $series.subseries | each {|subseries|
      if $required_series == null {
        $subseries.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay | build_series_tree ($depth - 1) $cache
      } else {
        $subseries.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay | build_series_tree ($depth - 1) $cache --required-series ($required_series | where {|id| $id != $series.id})
      }
    }
  )
}

# # Nest one subseries in another
# export def nest_subseries [
#   series_to_nest: table
# ]: record -> record {
#   let series = $in
#   # Base case: No subseries (leaf node)
#   # if ($series | all {|s| $s | get --optional subseries | is-empty}) {
#   if ($series | get --optional subseries | is-empty) {
#     let s = $series_to_nest | where id == $series.id
#     if ($s | is-empty) {
#       return {}
#       # return $series
#     }
#     return ($s | first)
#   }

#   $series | upsert nested_subseries (
#     $series.subseries | each {|s|
#       $s | nest_subseries $series_to_nest
#     }
#   )
# }

export def series_is_in_series [
  id: string
]: record -> bool {
  let series = $in
  # Base case: No subseries (leaf node)
  # if ($series | all {|s| $s | get --optional subseries | is-empty}) {
  if ($series | get --optional nested_subseries | is-empty) {
    return ($series.id == $id)
  }

  $series.nested_subseries | any {|s|
    $s | series_is_in_series $id
  }
}

# Organize series into a hierarchy based on subseries relationships
#
# Parent series are at the top of the hierarchy.
# Subseries are nested under their parent series.
# Series are sorted by name when multiple are at the same tier.
export def create_series_tree [
  # cache: directory # todo Use a cache closure to allow unit testing
  cache: closure
  max_depth: int = 10
  --retries: int = 3
  --retry-delay: duration = 3sec
]: table -> table {
  let all_series = $in

  # let all_series_and_subseries = $all_series | append (
  #   # Recursively traverse the series relationships, calling fetch_musicbrainz_series as necessary to fill in missing series
  #   # Need to call out to MusicBrainz for all series data
  # ) | uniq-by id

  # let all_series = $all_series_and_subseries | each {|s|
  #   $s | nest_subseries $all_series_and_subseries
  # }
  # let top_level_series = $all_series | where {|s|
  #   not ($s | series_is_in_series $s.id)
  # }

  # $top_level_series

  let ancestors_and_series = $all_series | each {|series|
    {
      ancestors: (
        $series
        | build_series_tree_up $max_depth $cache --required-series ($all_series | get id) --retries $retries --retry-delay $retry_delay
        | get_top_parents
        | sort-by name
      )
      series: $series
    }
  # Group by shared ancestor(s)
  } | group-by ancestors --to-table | each {|ancestors_and_series_group|
    {
      # Could try merging here maybe...
      ancestors: ($ancestors_and_series_group.items | first | get ancestors)
      series: ($ancestors_and_series_group.items | get series)
    }
  } | each {|ancestors_and_series|
    let full_series_tree = $ancestors_and_series.ancestors | build_series_tree $max_depth $cache --required-series ($ancestors_and_series.series | get id) --retries $retries --retry-delay $retry_delay
    # Finally, calculate the degrees of separation between the common ancestor
    let series = $ancestors_and_series.series | each {|s|
      let depth = $ancestors_and_series.ancestors | distance_to_top $s
      $s | upsert depth $depth
    }
    {
      ancestor: $full_series_tree
      series: ($series | sort-by depth)
    }
  } | sort-by --custom {|pair|
    # When there are multiple top-level series, the primary series is assumed to be the one with the shortest depth between it and it's common ancestor.
    # Each group will be sorted by the min depth of its series, followed by series without any depth, and any ties will be sorted based on the name of the ancestral series
  }
  # todo Take into account series which have an index vs. those that don't.
}

# The minimum interval between successive requests to the MusicBrainz API.
#
# MusicBrainz allows an average of one request per second per IP address and responds with 503 errors when this is exceeded.
# See https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting
# To stay within the limit, requests to the MusicBrainz API must be made sequentially, i.e. with each instead of par-each.
export const musicbrainz_request_interval = 1sec

# Make a GET request to the MusicBrainz API, respecting the rate limit.
#
# Waits for the rate limit interval before each request, so successive sequential calls are spaced out appropriately.
# Returns the full response, as with http get --full.
export def musicbrainz_get [
  url: string # The full URL of the request
]: nothing -> record {
  sleep $musicbrainz_request_interval
  http get --full --headers [User-Agent $user_agent Accept "application/json"] $url
}

# Parse the works from MusicBrainz recording relationships
export def parse_works_from_musicbrainz_relations []: table -> table {
  let relations = $in
  if ($relations | describe) == "list<nothing>" or ($relations | is-empty) or "target-type" not-in ($relations | columns) or "type" not-in ($relations | columns) {
    return null
  }
  let work_relations = $relations | where target-type == "work" | where type == "performance"
  if ($work_relations | is-empty) {
    return null
  }
  (
    $work_relations
    | get work
    | uniq
  )
}

# Parse artists from MusicBrainz recording and release relationships
export def parse_contributor_by_type_from_musicbrainz_relations [
  entity: string # The type of entity, i.e. artist or label
  type: string # vocal, engineer, director, producer, recording, etc.
  attribute: string = "" # attribute to filter on, i.e "spoken vocals"
]: list -> table<id: string, name: string> {
  let relations = $in
  if ($relations | is-empty) or "target-type" not-in ($relations | columns) or "type" not-in ($relations | columns) {
    return null
  }
  let relations = (
    $relations
    | where target-type == $entity
    | where type == $type
    | where {|relation|
      if ($attribute | is-not-empty) {
        $attribute in $relation.attributes
      } else {
        true
      }
    }
  )
  if ($relations | is-empty) {
    return null
  }
  (
    $relations
    # attribute-credits is used for specific characters, which isn't useful for tagging yet
    | select $entity target-credit # attribute-credits
    | uniq
    | par-each {|relation|
      let name = (
        if "target-credit" in $relation and ($relation.target-credit | is-not-empty) {
          $relation.target-credit
        } else {
          $relation | get $entity | get name
        }
      )
      {
        id: ($relation | get $entity | get id)
        name: $name
      }
    }
  )
}

# Parse contributors from MusicBrainz release, recording, and work relationships
#
# A table of relationships is the input.
export def parse_contributors []: table -> table<id: string, name: string, entity: string, role: string> {
  let relations = $in
  if ($relations | is-empty) or "target-type" not-in ($relations | columns) or "type" not-in ($relations | columns) {
    return null
  }
  let inputs = [
    [entity type attribute role];
    [artist vocal "spoken vocals" narrator]
    [artist writer "" writer]
    [artist illustration "" illustrator]
    [artist "audio director" "" director]
    [artist instrument "" performer]
    [artist adapter "" adapter]
    [artist translator "" translator]
    [artist composer "" composer]
    [artist editor "" editor]
    [artist engineer "" engineer]
    [artist sound "" engineer]
    [artist recording "" engineer]
    [artist producer "" producer]
    [artist mixer "" mixer]
    [artist remixer "" remixer]
    [artist arranger "" arranger]
    [artist lyricist "" lyricist]
    [label distributed "" distributor]
    [label published "" publisher]
  ]

  let contributors = (
    $inputs | par-each {|input|
      let contributors = $relations | parse_contributor_by_type_from_musicbrainz_relations $input.entity $input.type $input.attribute
      if ($contributors | is-not-empty) {
        $contributors | insert entity $input.entity | insert role $input.role
      }
    } | flatten
  )
  if ($contributors | is-not-empty) {
    $contributors | sort-by entity role name id
  } else {
    $contributors
  }
}

# Parse series from MusicBrainz relationships
#
# Multiple series are sorted according to index, in descending order, followed by name length, and finally name.
# The goal of this is to order parent series before subseries.
# This is due to the limited series information available when querying a release from MusicBrainz.
# Actually subseries information must be obtained through separate API calls to MusicBrainz.
export def parse_series_from_musicbrainz_relations []: [
  table -> nothing
  table -> table<id: string, name: string, index: string>
] {
  let relations = $in
  if ($relations | is-empty) or "target-type" not-in ($relations | columns) or "type" not-in ($relations | columns) {
    return []
  }
  let series = (
    $relations
    | where target-type == "series"
    | where type == "part of"
  )
  if ($series | is-empty) {
    return []
  }
  (
    $series | par-each {|s|
      let name = (
        if "target-credit" in $s and ($s.target-credit | is-not-empty) {
          $s.target-credit
        } else {
          $s.series.name
        }
      )
      {
        name: $name
        id: $s.series.id
        index: ($s.attribute-values | get --optional number)
      }
    }
    | uniq
    # Try to order the series with the top-level parent series followed by the subseries.
    # Most entities that appear in both a parent series and a subseries will have indices in both.
    # When a series has multiple subseries, the parent series will have the larger indices after the first subseries.
    # Additionally, it can be cleverly deduced that most subseries will have names that are longer than their parent series.
    # This owes to the pension of including the name of the parent series as part of the name of the subseries.
    # The actual subseries relationships can and should be figured out later by making separate API calls to MusicBrainz to get the series relationships.
    | sort-by --custom {|a, b|
      if ($a.index == $b.index) {
        let a_length = ($a.name | str length)
        let b_length = ($b.name | str length)
        if $a_length == $b_length {
          # If they have the same name, that's really bizarre...
          if ($a.name | str downcase) == ($b.name | str downcase) {
            # Someone should probably fix this.
            log warning $"Multiple series have the same name: ($a) and ($b). If this is a duplicate or erroneous, please correct it. Thanks!"
            # Sort by ID I guess...
            $a.id < $b.id
          } else {
            # Sort by the name itself.
            ($a.name | str downcase) < ($b.name | str downcase)
          }
        } else {
          # Sort by shortest to longest name.
          $a_length < $b_length
        }
      } else {
        # Sort by index in reverse.
        $a.index >= $b.index
      }
    }
  )
}

# Parse series from MusicBrainz release, release group, and works
#
# The series are returned in the order of relevance:
# 1. release
# 2. release group
# 3. work
#
# Multiple series of the same type a further sorted according to index, in descending order.
# The goal of this is to order subseries after parent series.
# Of course, this won't help where indices are missing or indices match.
# Unfortunately, separate lookups for each series are necessary to determine if a series is a subseries.
export def parse_series_from_musicbrainz_release []: [
  record -> table<name: string, id: string, index: string, scope: string>
] {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  let release_series = (
    $metadata
    | get --optional relations
    | (
      let input = $in;
      if ($input | is-not-empty) {
        $input | parse_series_from_musicbrainz_relations | default "release" scope
      }
    )
  )
  let release_group_series = (
    $metadata
    | get --optional release-group.relations
    | (
      let input = $in;
      if ($input | is-not-empty) {
        $input | parse_series_from_musicbrainz_relations | default "release group" scope
      }
    )
  )
  # There could also be recording series, but I haven't come across that yet
  let work_series = (
    $metadata
    | get --optional media
    | get --optional tracks
    | flatten
    | get --optional recording
    | get --optional relations
    | flatten
    | parse_works_from_musicbrainz_relations
    | (
      let input = $in;
      if ($input | is-not-empty) {
        (
          $input
          | get --optional relations
          | flatten
          | parse_series_from_musicbrainz_relations
          | default "work" scope
        )
      }
    )
  )
  $release_series | append $release_group_series | append $work_series # | sort-by scope
}

# Parse genres from a MusicBrainz release, release group, and recordings
#
# The genres should also be parsed from associated series and works, but these require separate API calls.
#
# MusicBrainz doesn't really provide genres for audiobooks yet, so most genres are directly imported from tags.
export def parse_genres_and_tags_from_musicbrainz_release []: record -> record<genres: table<name: string, count: int, scope: string>, tags: table<name: string, count: int, scope: string>> {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  let release = (
    $metadata
    | get --optional tags
    | (
      let input = $in;
      if ($input | is-not-empty) {
        {tags: $input, genres: []}
      } else {
        {tags: [], genres: []}
      }
    )
    | parse_genres_and_tags | default "release" scope
  )
  let release_group = (
    $metadata
    | get --optional release-group
    | get --optional tags
    | (
      let input = $in;
      if ($input | is-not-empty) {
        {tags: $input, genres: []}
      } else {
        {tags: [], genres: []}
      }
    )
    | parse_genres_and_tags | default "release group" scope
  )
  let recording = (
    $metadata
    | get --optional media
    | get --optional tracks
    | flatten
    | get --optional recording
    | get --optional tags
    | flatten
    | (
      let input = $in;
      if ($input | is-not-empty) {
        {tags: $input, genres: []}
      } else {
        {tags: [], genres: []}
      }
    )
    | parse_genres_and_tags | default "recording" scope
  )
  let genres = (
    $release
    | get --optional genres
    | default "release" scope
    | append (
      $release_group
      | get --optional genres
      | default "release group" scope
    )
    | append (
      $recording
      | get --optional genres
      | default "recording" scope
    )
    | where {|row| ($row | is-not-empty) and "name" in $row and "count" in $row}
    | select --optional name count scope
  )
  let tags = (
    $release
    | get --optional tags
    | default "release" scope
    | append (
      $release_group
      | get --optional tags
      | default "release group" scope
    )
    | append (
      $recording
      | get --optional tags
      | default "recording" scope
    )
    | where {|row| ($row | is-not-empty) and "name" in $row and "count" in $row}
    | select --optional name count scope
  )
  {
    genres: $genres
    tags: $tags
  }
}

# Parse the artist names and ids from the MusicBrainz artist credits
export def parse_musicbrainz_artist_credit []: list -> table {
  $in | enumerate | select index item.artist.id item.name | rename index id name
}

# Parse an Audible ASIN from the URL relationships in a MusicBrainz Release
export def parse_audible_asin_from_musicbrainz_release []: record -> list<string> {
  let metadata = $in
  if relations not-in $metadata {
    return null
  }
  let purchase_urls = (
    $metadata
    | get relations
    | where target-type == url
    | where {|r|
      $r.type | str starts-with purchase
    }
  )
  if ($purchase_urls | is-empty) {
    return null
  }
  $purchase_urls | get url | get resource | par-each {|url|
    $url | parse_audible_asin_from_url
  }
}

# Convert the artist-credit from MusicBrainz into a single string.
export def artist_credit_to_string []: table<joinphrase: string, name: string, artist: record> -> string {
  let artist_credit = $in
  $artist_credit | reduce --fold '' {|it, acc|
    $acc + $it.name + $it.joinphrase
  }
}

# Parse the data of a MusicBrainz release
export def parse_musicbrainz_release []: [
  record -> record
] {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }

  let release_artist_credits = (
    if "artist-credit" in $metadata and ($metadata.artist-credit | is-not-empty) {
      $metadata.artist-credit | parse_musicbrainz_artist_credit
    }
  )
  let release_contributors = (
    if "relations" in $metadata and ($metadata.relations | is-not-empty) {
      $metadata.relations | parse_contributors
    }
  )

  # Track metadata
  let tracks = (
    $metadata
    | get media
    | par-each {|media|
      $media.tracks | par-each {|track|
        let length = (
          if "length" in $track {
            $track.length | into duration --unit ms
          }
        );

        # todo function to join artists with credits
        let track_artist_credits = (
          if "artist-credit" in $track.recording and ($track.recording.artist-credit | is-not-empty) {
            $track.recording.artist-credit | parse_musicbrainz_artist_credit
          }
        )
        let works = (
          if "recording" in $track and "relations" in $track.recording and ($track.recording.relations | is-not-empty) {
            $track.recording.relations | parse_works_from_musicbrainz_relations
          }
        )
        let work_relations = (
          if ($works | is-not-empty) and "relations" in ($works | columns) {
            $works | get relations | flatten
          }
        )
        let track_contributors = (
          if ($track.recording | is-not-empty) and "relations" in ($track.recording | columns) {
            # todo Ignore special [unknown] MusicBrainz artist?
            let parsed_contributors = $track.recording.relations | append $work_relations | parse_contributors
            # If artist roles exist at the release level and not at the track level, use them for the track.
            let parsed_contributors = (
              $parsed_contributors | append (
                $release_contributors
                | where role not-in $release_only_contributor_roles
                | get role
                | uniq
                | par-each {|role|
                  if ($parsed_contributors | where role == $role | is-empty) {
                    $release_contributors | where role == $role
                  }
                } | flatten
              )
            )
            (
              # Prefer the name in the track artist credit here, followed by the name in the release artist credit.
              $parsed_contributors
              | (
                let input = $in;
                if ($input | is-not-empty) and ($track_artist_credits | is-not-empty) {
                  $input | join --left $track_artist_credits id
                } else {
                  $input
                }
              )
              | join --left $release_artist_credits id
              | rename id name entity role track_artist_credit_index track_artist_credit release_artist_credit_index release_artist_credit
              | sort-by track_artist_credit_index release_artist_credit_index name
              | each {|contributor|
                let name = (
                  if ($contributor.track_artist_credit | is-not-empty) {
                    $contributor.track_artist_credit
                  } else if ($contributor.release_artist_credit | is-not-empty) {
                    $contributor.release_artist_credit
                  } else {
                    $contributor.name
                  }
                )
                {
                  id: $contributor.id
                  name: $name
                  entity: $contributor.entity
                  role: $contributor.role
                }
              }
            ) | uniq
          }
        )
        let musicbrainz_works = (
          if ($works | is-not-empty) {
            (
              $works
              | each {|work|
                if ($work | get --optional relations | is-empty) {
                  $work | default null bookbrainz_work_id open_library_work_id wikidata_work_id
                } else {
                  let url_relations = $work.relations | where target-type == "url";
                  let bookbrainz_work_id = (
                    if ($url_relations | is-not-empty) {
                      let bookbrainz_url_relations = $url_relations | where type == "BookBrainz"
                      if ($bookbrainz_url_relations | is-not-empty) {
                        let bookbrainz_urls = $bookbrainz_url_relations | get --optional url
                        if ($bookbrainz_urls | is-not-empty) {
                          let bookbrainz_work_urls = $bookbrainz_urls | where {|url|
                            (
                              ($url.resource | str starts-with "https://bookbrainz.org/work/")
                              or ($url.resource | str starts-with "http://bookbrainz.org/work/")
                            )
                          }
                          if ($bookbrainz_work_urls | is-not-empty) {
                            if ($bookbrainz_work_urls | length) > 1 {
                              log warning $"Multiple BookBrainz Works are linked for the MusicBrainz Work ($work.id)"
                            }
                            $bookbrainz_work_urls.resource | first | str replace "https://bookbrainz.org/work/" "" | str replace "http://bookbrainz.org/work/" ""
                          }
                        }
                      }
                    }
                  )
                  let open_library_work_id = (
                    if ($url_relations | is-not-empty) {
                      let open_library_url_relations = $url_relations | where type == "other databases"
                      if ($open_library_url_relations | is-not-empty) {
                        let open_library_urls = $open_library_url_relations | get --optional url
                        if ($open_library_urls | is-not-empty) {
                          let open_library_work_urls = $open_library_urls | where {|url|
                            (
                              ($url.resource | str starts-with "https://openlibrary.org/works/")
                              or ($url.resource | str starts-with "http://openlibrary.org/works/")
                            )
                          }
                          if ($open_library_work_urls | is-not-empty) {
                            if ($open_library_work_urls | length) > 1 {
                              log warning $"Multiple Open Library Works are linked for the MusicBrainz Work ($work.id)"
                            }
                            $open_library_work_urls.resource | first | str replace "https://openlibrary.org/works/" "" | str replace "http://openlibrary.org/works/" ""
                          }
                        }
                      }
                    }
                  )
                  let wikidata_work_id = (
                    if ($url_relations | is-not-empty) {
                      let wikidata_url_relations = $url_relations | where type == "wikidata"
                      if ($wikidata_url_relations | is-not-empty) {
                        let wikidata_urls = $wikidata_url_relations | get --optional url
                        if ($wikidata_urls | is-not-empty) {
                          let wikidata_work_urls = $wikidata_urls | where {|url|
                            (
                              ($url.resource | str starts-with "https://www.wikidata.org/wiki/Q")
                              or ($url.resource | str starts-with "http://www.wikidata.org/wiki/Q")
                            )
                          }
                          if ($wikidata_work_urls | is-not-empty) {
                            if ($wikidata_work_urls | length) > 1 {
                              log warning $"Multiple Wikidata Works are linked for the MusicBrainz Work ($work.id)"
                            }
                            $wikidata_work_urls.resource | first | str replace "https://www.wikidata.org/wiki/" "" | str replace "http://www.wikidata.org/wiki/" ""
                          }
                        }
                      }
                    }
                  )
                  (
                    $work
                    | upsert bookbrainz_work_id $bookbrainz_work_id
                    | upsert open_library_work_id $open_library_work_id
                    | upsert wikidata_work_id $wikidata_work_id
                  )
                }
              }
              | select id title bookbrainz_work_id open_library_work_id wikidata_work_id
              | uniq
            )
          }
        )
        let genres_and_tags = (
          if "recording" in $track and "tags" in $track.recording and ($track.recording.tags | is-not-empty) {
            let tags = (
              $track
              | get --optional recording
              | get --optional tags
              | select name count
            )
            let genres_and_tags = (
              {
                genres: []
                tags: $tags
              }
              | parse_genres_and_tags
            )
            {
              genres: ($genres_and_tags.genres | default recording scope | where {|row| "name" in $row and "count" in $row})
              tags: ($genres_and_tags.tags | default recording scope | where {|row| "name" in $row and "count" in $row})
            }
          } else {
            {
              genres: []
              tags: []
            }
          }
        )
        let title = (
          if "title" in $track and ($track.title | is-not-empty) {
            $track.title
          } else {
            $metadata.title
          }
        )
        # The sort name can only be found in aliases.
        let title_sort = (
          if "recording" in $track and ($track.recording | is-not-empty) and "aliases" in $track.recording and ($track.recording | is-not-empty) {
            let matching_aliases = (
              $track.recording.aliases
              | where name == $title
              | where {|alias| $alias.name != $alias.sort-name}
            )
            if ($matching_aliases | is-not-empty) {
              if ($matching_aliases | length) > 1 {
                log warning $"Multiple aliases match the title exactly for the recording: ($matching_aliases). Using the first one. Please correct this issue on MusicBrainz."
              }
              $matching_aliases.sort-name | first
            }
          }
        )
        let musicbrainz_artist_ids = (
          let ids = $track | get --optional artist-credit.artist.id;
          if ($ids | is-not-empty) {
            $ids | uniq
          }
        )
        let disc_subtitle = (
          if "title" in $media and ($media.title | is-not-empty) {
            $media.title
          }
        )
        let artist_credit_string = (
          if "artist-credit" in $track.recording and ($track.recording.artist-credit | is-not-empty) {
            $track.recording.artist-credit | artist_credit_to_string
          }
        )
        (
          {
            index: $track.position
          }
          | upsert_if_present disc_number $media position
          | upsert_if_value disc_subtitle $disc_subtitle
          | upsert_if_present media $media format
          | upsert_if_present musicbrainz_track_id $track id
          | upsert_if_present title $track
          | upsert_if_value title_sort $title_sort
          | upsert_if_present musicbrainz_recording_id $track.recording id
          | upsert_if_value genres $genres_and_tags.genres
          | upsert_if_value tags $genres_and_tags.tags
          | upsert_if_value musicbrainz_works $musicbrainz_works
          | upsert_if_value contributors $track_contributors
          | upsert_if_value duration $length
          | upsert_if_value artist_credit $artist_credit_string
          # AcoustID metadata may be supplemented in the provided track metadata
          | upsert_if_present acoustid_fingerprint $track
          | upsert_if_present acoustid_track_id $track
        )
      }
    } | flatten | sort-by index
  )

  # log debug $"tracks: ($tracks)"
  let primary_authors = (
    if "contributors" in ($tracks | columns) and ($tracks.contributors | is-not-empty) {
      let writers = $tracks.contributors | flatten | where entity == "artist" | where role == "writer"
      if ($writers | is-not-empty) {
        $writers
        | join $release_artist_credits id
        | rename id name entity role release_artist_credit_index release_artist_credit
        | sort-by release_artist_credit_index name
        # Be sure to use the name in the release artist credit and not the track artist credit
        | each {|writer|
          let name = (
            if ($writer.release_artist_credit | is-not-empty) {
              $writer.release_artist_credit
            } else {
              $writer.name
            }
          )
          {
            id: $writer.id
            name: $name
          }
        }
      # There are no writers associated with any works in the release credits.
      # Try using any artists not attributed with a specific role as the primary authors.
      } else {
        let unassociated = (
          $tracks
          | get contributors
          | where entity == "artist"
          | join --right $release_artist_credits id
          | where role == null
        )
        if ($unassociated | is-empty) {
          # Give up and just use everyone in the artist credit
          $release_artist_credits
        } else {
          $unassociated
        }
      }
    }
  )
  let primary_authors = (
    if ($primary_authors | is-not-empty) {
      $primary_authors | uniq
    }
  )
  let contributors = (
    $primary_authors
    | each {|primary_author|
      if ($primary_author | is-not-empty) {
        {
          id: $primary_author.id
          name: $primary_author.name
          entity: "artist"
          role: "primary author"
        }
      }
    }
    | append $release_contributors
  ) | uniq
  let contributors = (
    if ($contributors | is-not-empty) {
      $contributors | sort-by entity role name id
    } else {
      $contributors
    }
  )
  let publication_date = (
    if "date" in $metadata {
      $metadata | get date | into datetime
    }
  )
  let publishers = (
    # todo Also check for publishers in the release relationships.
    if "label-info" in $metadata and "label" in ($metadata.label-info | columns) {
      $metadata.label-info.label | select id name
    }
  )

  let series = $metadata | parse_series_from_musicbrainz_release
  # log debug $"series: ($series | to json)"

  let audible_asin = (
    let audible_asins = $metadata | parse_audible_asin_from_musicbrainz_release;
    # We just kind of ignore all besides the first when there are multiple
    if ($audible_asins | is-not-empty) {
      if ($audible_asins | length) > 1 {
        log warning $"Multiple Audible ASINs found: ($audible_asins). Using the first one."
      }
      $audible_asins | first
    }
  )

  let genres_and_tags = $metadata | parse_genres_and_tags_from_musicbrainz_release

  # Chapters can come from multi-track releases, otherwise, they need to found in another release
  let chapters = (
    if ($tracks | length) > 1 {
      $metadata | parse_chapters_from_musicbrainz_release
    }
  )

  let front_cover_available = (
    "cover-art-archive" in $metadata and $metadata.cover-art-archive.front
  )

  let musicbrainz_artist_ids = (
    let ids = $metadata | get --optional artist-credit.artist.id;
    if ($ids | is-not-empty) {
      $ids | uniq
    }
  )
  let musicbrainz_release_types = (
    []
    | append (
      $metadata
      | get --optional release-group.primary-type
    )
    | append (
      $metadata
      | get --optional release-group.secondary-types
    )
    | str downcase
  )
  let total_discs = (
    if "media" in $metadata and ($metadata.media | is-not-empty) {
      $metadata.media | length
    }
  )
  let total_tracks = $tracks | length

  let musicbrainz_release_country = (
    if "country" in $metadata and ($metadata.country | is-not-empty) {
      $metadata.country | str upcase
    }
  )
  let musicbrainz_release_status = (
    if "status" in $metadata and ($metadata.status | is-not-empty) {
      $metadata.status | str downcase
    }
  )

  # The sort name can only be found in aliases.
  let title_sort = (
    if "aliases" in $metadata and ($metadata.aliases | is-not-empty) {
      let matching_aliases = (
        $metadata.aliases
        | where name == $metadata.title
        | where {|alias| $alias.name != $alias.sort-name}
      )
      if ($matching_aliases | is-not-empty) {
        if ($matching_aliases | length) > 1 {
          log warning $"Multiple aliases match the title exactly: ($matching_aliases). Using the first one. Please correct this issue on MusicBrainz."
        }
        $matching_aliases.sort-name | first
      }
    }
  )

  let artist_credit_string = (
    if "artist-credit" in $metadata and ($metadata.artist-credit | is-not-empty) {
      $metadata.artist-credit | artist_credit_to_string
    }
  )

  # Book metadata
  let book = (
    {}
    | upsert_if_present musicbrainz_release_id $metadata id
    | upsert_if_value musicbrainz_release_group_id (
      if "release-group" in $metadata and "id" in $metadata.release-group {
        $metadata.release-group.id
      }
    )
    | upsert_if_value musicbrainz_release_types $musicbrainz_release_types
    | upsert_if_value artist_credit $artist_credit_string
    | upsert_if_present title $metadata
    | upsert_if_value title_sort $title_sort
    | upsert_if_value contributors $contributors
    | upsert_if_present isbn $metadata barcode
    | upsert_if_value musicbrainz_release_country $musicbrainz_release_country
    | upsert_if_value musicbrainz_release_status $musicbrainz_release_status
    | upsert_if_present amazon_asin $metadata asin
    | upsert_if_value audible_asin $audible_asin
    | upsert_if_present hardcover_edition_id $metadata
    | upsert_if_present hardcover_book_slug $metadata
    | upsert_if_present open_library_edition_id $metadata
    | upsert_if_present open_library_work_id $metadata
    | upsert_if_present wikidata_edition_id $metadata
    | upsert_if_present wikidata_work_id $metadata
    | upsert_if_value genres $genres_and_tags.genres
    | upsert_if_value tags $genres_and_tags.tags
    | upsert_if_value publication_date $publication_date
    | upsert_if_value series $series
    | upsert_if_value chapters $chapters
    | upsert_if_value front_cover_available $front_cover_available
    | upsert_if_value publishers $publishers
    | upsert_if_value total_discs $total_discs
    | upsert_if_value total_tracks $total_tracks
    | upsert_if_present packaging $metadata
    | (
      let input = $in;
      if "text-representation" in $metadata {
        $input
        | upsert_if_present script $metadata.text-representation
        | upsert_if_present language $metadata.text-representation
      } else {
        $input
      }
    )
  )

  {
    book: $book
    tracks: $tracks
  }
}

# Fetch the given release id from MusicBrainz and parse it into a normalized data structure
export def fetch_and_parse_musicbrainz_release [
  cache: closure
  includes: list<string> = [
    aliases
    artist-credits
    labels
    recordings
    release-groups
    media
    genres
    tags
    release-group-rels
    work-rels
    series-rels
    genre-rels
    artist-rels
    label-rels
    recording-level-rels
    release-group-level-rels
    work-level-rels
    url-rels # for Audible ASIN
  ]
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  let musicbrainz_release_id = $in
  let update_cache = {|type id|
    let release = (
      $id | fetch_musicbrainz_release --retries $retries --retry-delay $retry_delay $includes
    )
    if ($release | is-not-empty) {
      $release | parse_musicbrainz_release
    }
  }
  let includes_checksum = $includes | sort | uniq | str join | hash sha256
  do $cache "release" $musicbrainz_release_id $update_cache $includes_checksum
}

# Append the the value for the given key in the given metadata to a MusicBrainz search query for the given search term
#
# Uses the 'AND' conjunction when appending to a non-empty query.
# Special lucene characters are properly escaped in the value.
export def append_to_musicbrainz_query [
  metadata: record
  key: string
  musicbrainz_search_term: string
  --transform: closure
]: string -> string {
  let query = $in
  if ($metadata | is-empty) {
    return $query
  }
  let prefix = (
    if ($query | is-empty) {
      ""
    } else {
      " AND "
    }
  )
  let transform = (
    if $transform == null {
      {|v| $v}
    } else {
      $transform
    }
  )
  if ($metadata | get --optional $key | is-not-empty) {
    let value = do $transform ($metadata | get $key) | escape_special_lucene_characters
    if ($value | is-not-empty) {
      $query + $"($prefix)($musicbrainz_search_term):\"($value)\""
    } else {
      $query
    }
  } else {
    $query
  }
}

# Escape special Lucene characters in a string with a backslash
export def escape_special_lucene_characters []: any -> string {
  let input = $in
  if ($input | describe) != "string" {
    return $input
  }
  const special_lucene_characters = ['\' '+' '-' '&&' '||' '!' '(' ')' '{' '}' '[' ']' '^' '"' '~' '*' '?' ':' '/']
  $special_lucene_characters | reduce --fold $input {|character, acc|
    $acc | str replace --all $character ('\' + $character)
  }
}

# Using metadata from the audio tracks, search for a MusicBrainz Release
export def search_for_musicbrainz_release [
  use_tags: bool = false
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: record -> table {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }

  if ($metadata.book | get --optional musicbrainz_release_id | is-not-empty) {
    return [[musicbrainz_release_id]; [$metadata.book.musicbrainz_release_id]]
  }

  let url = "https://musicbrainz.org/ws/2/release/"

  let artists = (
    if ($metadata.book | get --optional contributors | is-not-empty) {
      let release_artists = $metadata.book.contributors | where entity == artist
      let track_artists = (
        if ($metadata.tracks | get --optional contributors | is-not-empty) {
          let track_artists = $metadata.tracks.contributors | uniq | where entity == artist
          if ($track_artists | is-not-empty) {
            $track_artists | where type in [narrator, writer]
          }
        }
      );
      $release_artists | append $track_artists
    }
  );

  # The release must be an Audiobook, Audio drama, or Spokenword
  let query = "primarytype:Other AND (secondarytype:Audiobook OR secondarytype:\"Audio drama\" OR secondarytype:Spokenword)"

  let query = (
    if ($artists | is-not-empty) {
      $query + (
        $artists | get --optional id | reduce {|it, acc|
          $acc + $" AND arid:\"($it | escape_special_lucene_characters)\""
        }
      )
    } else {
      $query
    }
  )
  let query = (
    if ($artists | is-not-empty) {
      $query + (
        $artists | get --optional name | reduce {|it, acc|
          $acc + $" AND artistname:\"($it | escape_special_lucene_characters)\""
        }
      )
    } else {
      $query
    }
  )
  let query = (
    # Audiobooks should have either an ASIN or a barcode, likely an ISBN, set, but not both simultaneously.
    # Prefer the ISBN if both are set.
    # todo Maybe both should be included?
    if ($metadata.book | get --optional isbn | is-not-empty) {
      $query + $" AND barcode:\"($metadata.book.isbn | escape_special_lucene_characters)\""
    } else if ($metadata.book | get --optional amazon_asin | is-not-empty) {
      $query + $" AND asin:\"($metadata.book.amazon_asin | escape_special_lucene_characters)\""
    } else {
      $query
    }
  )

  let tags = (
    let genres = (
      if ($metadata.book | get --optional genres | is-not-empty) {
        $metadata.book.genres
      }
    );
    let tags = (
      if ($metadata.book | get --optional tags | is-not-empty) {
        $metadata.book.tags
      }
    );
    $genres | append $tags
  )
  let query = (
    if $use_tags and ($tags | is-not-empty) {
      $query + $tags | reduce {|it, acc|
        $acc + $" AND tag:\"($it | escape_special_lucene_characters)\""
      }
    } else {
      $query
    }
  )

  let query = (
    if ($metadata.book | get --optional title | is-not-empty) {
      let title = $metadata.book.title | escape_special_lucene_characters
      $query + $" AND \(release:\"($title)\" OR alias:\"($title)\"\)"
    } else {
      $query
    }
  )

  let query = (
    $query
    | append_to_musicbrainz_query $metadata.book musicbrainz_release_country country
    # todo Store year specially compared to full date?
    | append_to_musicbrainz_query $metadata.book publication_date date --transform {|d|
      let date = $d | format date '%Y-%m-%d'
      if ($date | str ends-with "-01-01") {
        $date | str replace "-01-01" ""
      } else {
        $date
      }
    }
    | append_to_musicbrainz_query $metadata.book media format
    | append_to_musicbrainz_query $metadata.book publishers laid --transform {|l| $l | get --optional id}
    | append_to_musicbrainz_query $metadata.book publishers label --transform {|l| $l | get --optional name}
    | append_to_musicbrainz_query $metadata.book language lang
    | append_to_musicbrainz_query $metadata.book mediums total_discs
    | append_to_musicbrainz_query $metadata.book packaging packaging
    | append_to_musicbrainz_query $metadata.book script script
    | append_to_musicbrainz_query $metadata.book musicbrainz_release_status status
    | append_to_musicbrainz_query $metadata.book total_tracks tracks
    | append_to_musicbrainz_query $metadata.book musicbrainz_release_group_id rgid
  )
  # todo discids, discidsmedium, and tracksmedium?

  log debug $"query: ($query)"

  let query = $query | url encode

  log debug $"request: ($url)?query=($query)"

  let request = {musicbrainz_get $"($url)?query=($query)"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error searching for a release: ($url)?&query=($query)\t($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code ($response.status) when searching for a release: ($url)?query=($query)"
    return null
  }

  let releases = $response | get body | get releases
  if ($releases | is-empty) {
    return null
  }
  $releases | sort-by --reverse score
}
