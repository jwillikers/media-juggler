#!/usr/bin/env nu

# Print out the chapters for an audiobook in the format used when adding the track list to MusicBrainz.
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
            let hours = $d // 1hr | into string | fill --width 2 --alignment right --character '0'
            let minutes = ($d mod 1hr) // 1min | into string | fill --width 2 --alignment right --character '0'
            let seconds = ($d mod 1min) // 1sec | into string | fill --width 2 --alignment right --character '0'
            $"($c.index) ($c.item.title) \(($hours):($minutes):($seconds)\)"
        }
        | print --raw
    )
}
