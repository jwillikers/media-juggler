#!/usr/bin/env nu

# Print out the chapters for an audiobook in the format used when adding the track list to MusicBrainz.
#
# Unfortunately, MusicBrainz doesn't support down to the millisecond level in their editor yet.
# https://tickets.metabrainz.org/browse/MBS-7130
# For right now, I just round to the nearest second.
# However, I could take into account the cumulative remainder seconds and adjust the durations better this way.
#
#
def main [
    m4b: path
]: {
    (
        ^tone dump --format json $m4b
        | from json
        | get meta
        | reject embeddedPictures
        | get chapters
        | enumerate
        | each {|c|
            let d = $c.item.length | into duration --unit ms
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
            $"($c.index) ($c.item.title) \(($hours):($minutes):($seconds)\)"
        }
        | print --raw
    )
}
