# Functions for parsing, converting, and naming audiobook chapters

# Parse chapters from tone.
#
# The format is similar to tone's format.
# Unlike the format tone uses, the start and length fields are durations.
# For output via tone, these need to be converted back to milliseconds as integers.
export def parse_chapters_from_tone []: table<start: int, length: int, title: string> -> table<index: int, start: duration, length: duration, title: string> {
  $in | enumerate | each {|chapter|
    {
      index: $chapter.index
      start: ($chapter.item.start | into duration --unit ms)
      length: ($chapter.item.length | into duration --unit ms)
      title: $chapter.item.title
    }
  }
}

# Convert chapters to the format used by tone.
#
# This format is similar to the internal format used for chapters.
# The only difference is that the start and length fields are milliseconds represented by integers.
export def chapters_into_tone_format []: table<index: int, start: duration, length: duration, title: string> -> table<index: int, start: int, length: int, title: string> {
  $in | each {|chapter|
    (
      $chapter
      | update start (($chapter.start / 1ms) | math round)
      | update length (($chapter.length / 1ms) | math round)
      # To make Tone's output nicer
      | insert subtitle ""
    )
  }
}

# Convert chapters to the chapters.txt format used by tone.
export def chapters_into_chapters_txt_format []: table<index: int, start: duration, length: duration, title: string> -> table<string> {
  $in | each {|chapter|
    let offset = $chapter.start | format_chapter_duration
    $"($offset) ($chapter.title)"
  }
}

# Parse chapters from a MusicBrainz Release into a format similar to the one used by tone.
#
# Unlike the format tone uses, the start and length fields are durations.
# For tone, these need to be converted to milliseconds as integers.
export def parse_chapters_from_musicbrainz_release []: record -> table<index: int, start: duration, length: duration, title: string> {
  let metadata = $in
  let chapters = (
    $metadata
    | get media.tracks
    | flatten
    | enumerate
    | each {|track|
      {
        index: $track.index
        title: $track.item.title
        duration: ($track.item.length | into duration --unit ms)
      }
    }
  )
  let start_offsets = $chapters | get duration | lengths_to_start_offsets
  $chapters | each {|c|
    let start = $start_offsets | get $c.index
    {
      index: $c.index
      start: $start
      length: $c.duration
      title: $c.title
    }
  }
}

# Get a list of start offsets from a list of durations
export def lengths_to_start_offsets []: [
  list<duration> -> list<duration>
] {
  $in
  | reduce --fold {total: 0ms offsets: []} {|length, acc|
    {
      total: ($acc.total + $length)
      offsets: ($acc.offsets | append $acc.total)
    }
  }
  | get offsets
}

# Format the duration of a chapter in format used for audiobook chapters
export def format_chapter_duration []: duration -> string {
    # HH:MM:SS.fff
    let time = $in
    let hours = (
        ($time // 1hr)
        | fill --alignment right --character "0" --width 2
    )
    let minutes = (
        ($time mod 1hr // 1min)
        | fill --alignment right --character "0" --width 2
    )
    let seconds = (
        ($time mod 1min // 1sec)
        | fill --alignment right --character "0" --width 2
    )
    let fractional_seconds = (
        ($time mod 1sec / 1sec * 1000 // 1)
        | fill --alignment right --character "0" --width 3
    )
    $"($hours):($minutes):($seconds).($fractional_seconds)"
}

export def round_to_second_using_cumulative_offset []: list<duration> -> list<duration> {
    let i = $in
    $i | reduce --fold {durations: [], cumulative_offset: 0.0} {|it, acc|
    # $i | reduce {|it, acc|
        let seconds = $it / 1sec
        let floor = $seconds // 1
        let ceil = ($seconds // 1) + 1
        let floor_offset = $floor - $seconds
        let ceil_offset = $ceil - $seconds
        let duration_and_offset = (
            if (($acc.cumulative_offset + $floor_offset) | math abs) <= (($acc.cumulative_offset + $ceil_offset) | math abs) {
                # round down
                {
                    cumulative_offset: ($acc.cumulative_offset + $floor_offset)
                    duration: ($floor | into int | into duration --unit sec)
                }
            } else {
                # round up
                {
                    cumulative_offset: ($acc.cumulative_offset + $ceil_offset)
                    duration: ($ceil | into int | into duration --unit sec)
                }
            }
        )

        {
            durations: ($acc.durations | append $duration_and_offset.duration)
            cumulative_offset: $duration_and_offset.cumulative_offset
        }
    } | get durations
}

# Parse chapters out of MusicBrainz recordings data in the chapters.txt format.
# $release | get media
export def chapters_from_musicbrainz_release_media []: table -> string {
  let tracks = $in | get tracks | flatten
  let start_offsets = (
    $tracks
    | get length
    | each {|length| $length | into duration --unit ms }
    | lengths_to_start_offsets
  )
  $tracks
  | enumerate
  | each {|t|
    $"($start_offsets | get $t.index | format_chapter_duration) ($t.item.title)"
  }
  | str join "\n"
}

# Determine if the chapters are named according to standard defaults.
#
# Default naming schemes:
#
# Libro.fm: Title - Track <x>
# Audible: Chapter <x>
#
export def has_default_chapters []: table<index: int, title: string, duration: duration> -> bool {
    let chapters = $in
    if ($chapters | is-empty) {
        return false
    }
    (
        (
            $chapters | all {|c|
                $c.title =~ '^Chapter [0-9]+$'
            }
        ) or (
            $chapters | all {|c|
                $c.title =~ ' - Track [0-9]+$'
            }
        )
    )
}

# Rename chapters.
#
# Note that the indices most be 1-based and not 0-based.
#
export def rename_chapters [
    --chapter-word: string = "Chapter" # The string to use for the name of each chapter. This is usually "Chapter".
    --offset: int # The difference between the track indices and the chapter numbers, i.e. the chapter number is the track index minus this value
    --prefix: string # A prefix to add before the name of each chapter
    --suffix: string # A suffix to add after the name of each chapter
]: table<index: int, title: string, duration: duration> -> table<index: int, title: string, duration: duration> {
    let chapters = $in
    if ($chapters | length) <= 1 {
        return $chapters
    }
    let chapters = $chapters | sort-by index
    # todo Handle indexing automatically when it isn't 1-based.
    if ($chapters | first | get index) != 1 {
      error make {msg: "rename_chapters requires 1-based indices"}
    }
    let offset = (
        if $offset == null {
            let c = $chapters | first;
            if $c.duration < 1min {
                1
            } else {
                0
            }
        } else {
            $offset
        }
    )
    $chapters | each {|c|
        if $c.index == 1 {
            if $c.duration < 1min {
                $c | update title "Opening Credits"
            } else {
                if $c.index - $offset == 0 {
                    $c | update title "Opening Credits / Prologue"
                } else {
                    $c | update title $"Opening Credits / ($prefix)($chapter_word) ($c.index - $offset)($suffix)"
                }
            }
        } else if $c.index == ($chapters | length) {
            if $c.duration < 3min {
                $c | update title "End Credits"
            } else {
                $c | update title $"($prefix)($chapter_word) ($c.index - $offset)($suffix) / End Credits"
            }
        } else {
            if $c.index - $offset == 0 {
                if $c.duration < 1min {
                    $c | update title "Epigraph"
                } else {
                    $c | update title "Prologue"
                }
            } else {
                $c | update title $"($prefix)($chapter_word) ($c.index - $offset)($suffix)"
            }
        }
    }
}

# Remove a matching pair of quotes surrounding a string.
export def unquote []: string -> string {
  $in | str trim | str replace --regex '^"(.*)"$|^“(.*)”$|^\x27(.*)\x27$' '$1$2$3'
}

# Parse the Part, Chapter, and Title portions of a chapter.
#
# Handles titles following the MusicBrainz Audiobook style guideline, with or without quotes around the titles.
#
# Part One: "The Part Title", Chapter 1: "The Chapter Title", Part 1
# Part One, Chapter 1: The Chapter Title
# Chapter 1: The Chapter Title, Part 1
# Epigraph / Chapter 1: The Chapter Title
#
# Tracks combined with " / " are split into their labels and titles, which are each joined with " / ".
# Quote a part title that contains a comma so that it isn't mistaken for the end of the part.
export def parse_chapter_title []: string -> record<part: any, part_title: string, chapter: string, chapter_title: string, chapter_part: any> {
  let input = $in | str trim

  # A trailing ", Part <n>" indicates that this is one part of a chapter split across multiple tracks.
  let chapter_part_regex = ',\s+(Part \d+)(?=\s+/\s|$)'
  let chapter_part = $input | parse --regex $chapter_part_regex | get capture0?.0?
  let rest = $input | str replace --regex $chapter_part_regex ''

  # A leading "Part <x>", optionally with a title, followed by a comma and the chapter.
  let part = $rest | parse --regex '^(?<part>Part \w+)(?::\s*(?<part_title>"[^"]*"|“[^”]*”|[^,]*))?,\s+(?<rest>.+)$' | get 0?
  let rest = if $part == null { $rest } else { $part.rest }

  # Split combined tracks on " / " outside of double quotes.
  let segments = (
    $rest
    | split row --regex '\s+/\s+(?=(?:[^"]*"[^"]*")*[^"]*$)'
    | each {|segment|
      let parsed = $segment | parse --regex '^(?<label>[^:]+?)(?::\s*(?<title>.*))?$' | first
      {
        label: ($parsed.label | str trim)
        title: ($parsed.title | default "" | unquote)
      }
    }
  )

  {
    part: $part.part?
    part_title: ($part.part_title? | default "" | unquote)
    chapter: ($segments.label | str join " / ")
    chapter_title: ($segments.title | where {|t| $t | is-not-empty } | str join " / ")
    chapter_part: $chapter_part
  }
}

# Combine chapters split into multiple parts into complete chapters
#
# Only works for chapters titled according to the MusicBrainz Audiobook style guidelines.
export def combine_chapter_parts []: table<index: int, title: string, duration: duration> -> table<index: int, title: string, duration: duration> {
  let chapters = $in
  let index_offset = $chapters.index | first
  (
    # Parse each title into the title and part portions
    $chapters
    | each {|chapter|
      $chapter | update title (
        $chapter.title
        | parse --regex '(?P<title>.*?)(?P<part>, Part [0-9]+)?$'
        | first
      )
    }
    | reduce {|it acc|
      if ($acc | is-empty) {
        $acc | append $it
      } else {
        let last = (
          if ($acc | describe | str starts-with record) {
            $acc
          } else {
            $acc | last
          }
        )
        if $last.title.title == $it.title.title {
          let updated = $last | update duration ($last.duration + $it.duration)
          if $acc == $last {
            $updated
          } else {
            $acc | drop | append $updated
          }
        } else {
          $acc | append $it
        }
      }
    }
    | enumerate
    | each {|chapter|
      {
        index: ($chapter.index + $index_offset)
        title: $chapter.item.title.title
        duration: $chapter.item.duration
      }
    }
  )
}
