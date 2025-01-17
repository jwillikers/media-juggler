#!/usr/bin/env nu

use std log

use media-juggler-lib *

# Print out the chapters for an audiobook in the format used when adding the track list to MusicBrainz.
#
# Takes the path to an M4B file, an Audible ASIN, or a MusicBrainz Release ID.
#
# Unfortunately, MusicBrainz doesn't support down to the millisecond level in their editor yet.
# https://tickets.metabrainz.org/browse/MBS-7130
#
# So, I use some logic to round the track length based on the cumulative drift from previous rounding.
# This way, the drift due to rounding won't accumulate and make the chapter offsets incorrect.
#
def main [
    input: string
    format: string = "musicbrainz" # Can also be "chapters.txt" or "debug"
    # --chapter-offset: int = 0 # The number to use as the first chapter number
    --round # Force rounding for chapters.txt
]: {
    let input_type = (
        if ($input | path parse | get extension) == "m4b" {
          "m4b"
        } else if $input =~ '[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}' {
          "MusicBrainz" # Release ID
        } else if $input =~ '[a-zA-Z0-9]{10}' {
          "ASIN"
        } else {
          null
        }
    )
    if $input_type == null {
      log error $"Unsupported input (ansi purple)($input)(ansi reset)"
      exit 1
    }

    let chapters = (
        if $input_type == "m4b" {
            ^tone dump --format json $input
            | from json
            | get meta
            | get chapters
            | enumerate
            | each {|c|
                {
                    index: $c.index
                    title: $c.item.title
                    duration: ($c.item.length | into duration --unit ms)
                }
            }
        } else if $input_type == "ASIN" {
            http get $"https://api.audnex.us/books/($input)/chapters"
            | get chapters
            | enumerate
            | each {|c|
                {
                    index: $c.index
                    title: $c.item.title
                    duration: ($c.item.lengthMs | into duration --unit ms)
                }
            }
        } else if $input_type == "MusicBrainz" {
            (
              $input
              | get_musicbrainz_release
              | get media
              | get tracks
              | flatten
              | enumerate
              | each {|recording|
                {
                    index: $recording.index
                    title: $recording.item.title
                    duration: ($recording.item.length | into duration --unit ms)
                }
              }
            )
        }
    )
    let chapters = (
        if $format == "musicbrainz" or $round {
            let durations = $chapters | get duration | round_to_second_using_cumulative_offset
            $chapters | merge ($durations | wrap duration)
        } else {
            $chapters
        }
    )
    let start_offsets = (
        $chapters | get duration | lengths_to_start_offsets
    )

    (
        $chapters
        | each {|c|
            let d = $c.duration
            let seconds = (
                ($d mod 1min) / 1sec
                | math round
            )
            let minutes = (
                ($d mod 1hr) // 1min
                | (
                    let i = $in;
                    if $seconds == 60 { $i + 1 } else { $i }
                )
            )
            let hours = (
                $d // 1hr
                | (
                    let i = $in;
                    if $minutes == 60 { $i + 1 } else { $i }
                )
                | into string
                | fill --width 2 --alignment right --character '0'
            )
            let seconds = (
                (if $seconds == 60 { 0 } else $seconds)
                | into string
                | fill --width 2 --alignment right --character '0'
            )
            let minutes = (
                (if $minutes == 60 { 0 } else $minutes)
                | into string
                | fill --width 2 --alignment right --character '0'
            )
            if $format == "musicbrainz" {
                $"($c.index + 1) ($c.title) \(($hours):($minutes):($seconds)\)"
            } else if $format == "chapters.txt" {
                let offset = $start_offsets | get $c.index | format_chapter_duration
                $"($offset) ($c.title)"
            } else if $format == "debug" {
                {
                    index: $c.index
                    start_offset: ($start_offsets | get $c.index | format_chapter_duration)
                    length: $"($hours):($minutes):($seconds)"
                    title: $c.title
                }
            }
        }
        | (
            let i = $in;
            if $format == "debug" {
                $i | print
            } else {
                $i | print --raw
            }
        )
    )
}
