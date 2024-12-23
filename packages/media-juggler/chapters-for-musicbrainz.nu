#!/usr/bin/env nu

use std log

use media-juggler-lib *

# Print out the chapters for an audiobook in the format used when adding the track list to MusicBrainz.
#
# Takes the path to an M4B file or an Audible ASIN
#
# Unfortunately, MusicBrainz doesn't support down to the millisecond level in their editor yet.
# https://tickets.metabrainz.org/browse/MBS-7130
# For right now, I just round to the nearest second.
# However, I could take into account the cumulative remainder seconds and adjust the durations better this way.
#
#
def main [
    input: string
]: {
    let chapters = (
        if ($input | path parse | get extension) == "m4b" {
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
        } else {
            http get $"https://api.audnex.us/books/($input)/chapters"
            | get chapters
            | enumerate
            | each {|c|
                {
                    index: $c.index
                    title: $c.item.title
                    duration: ($c.item.startOffsetMs | into duration --unit ms)
                }
            }
        }
    )
    let chapters = (
        let durations = $chapters | get duration | round_to_second_using_cumulative_offset;
        $chapters | merge ($durations | wrap duration)
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
            $"($c.index) ($c.title) \(($hours):($minutes):($seconds)\)"
            # $"($c.duration | format duration ms)"
        }
        | print --raw
    )
}
