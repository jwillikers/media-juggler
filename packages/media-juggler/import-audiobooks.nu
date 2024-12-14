#!/usr/bin/env nu

# todo Consider using bragibooks instead: https://github.com/djdembeck/bragibooks
# todo Use tone and a JS script to query Audible?
# tone can rename files as needed

use std log
use media-juggler-lib *

# Unzip a directory
export def unzip [
    working_directory: directory
]: path -> path {
    let archive = $in
    let target_directory = [$working_directory ($archive | path parse | get stem)] | path join
    ^unzip -q $archive -d $target_directory
    $target_directory
}

# Convert a directory of MP3 files to an M4B file
export def mp3_directory_to_m4b [
    working_directory: directory
]: path -> path {
    let directory = $in
    let m4b = { parent: $working_directory, stem: ($directory | path basename), extension: "m4b" } | path join
    ^m4b-tool merge --jobs ((^nproc | into int) / 2) --output-file $m4b $directory
    $m4b
}

export def format_chapter_duration []: duration -> string {
    # HH:MM:SS.fff
    let time = $in
    let hours = ($time // 1hr) | fill --alignment right --character "0" --width 2
    let minutes = ($time mod 1hr // 1min) | fill --alignment right --character "0" --width 2
    let seconds = ($time mod 1min // 1sec) | fill --alignment right --character "0" --width 2
    let fractional_seconds = ($time mod 1sec / 1sec * 1000 // 1) | fill --alignment right --character "0" --width 3
    $"($hours):($minutes):($seconds).($fractional_seconds)"
}

# const audible_workarounds = [
#     [match apply];
#     [
#         {
#             key: series.name
#             value: "Rascal Does Not Dream Series"
#         }
#         {
#             authors: ["Hajime Kamoshida"]
#             translators: ["Andrew Cunningham"]
#             illustrators: ["Keji Mizoguchi"]
#         }
#     ],
# ]

# export def apply_workarounds []: record -> record {
#     let tone_json = $in
#     let tone_json = (
#         $audible_workarounds
#         | reduce --fold $tone_json {|it, acc|
#             $acc
#             | where $it.match.key == $it.match.value
#             | update
#         }
#     )
#     $tone_json
# }

# todo Support getting values from MusicBrainz first and then falling back to Audible.
# Audible's data is not the most accurate...
#
# Can search based on details or use the id directly
# http get --headers [Accept "application/json"]  $"https://musicbrainz.org/ws/2/release/?query=('secondarytype:audiobook AND packaging:"None" AND artistname:\"Brandon Sanderson\" AND release:\"The Way of Kings\"' | url encode)" | get releases | sort-by --reverse score | first

export def tag_audiobook [
    output_directory: directory
    --asin: string
    --tone-tag-args: list<string> = []
]: path -> path {
    let m4b = $in

    let current_metadata = ^tone dump --format json $m4b | from json | get meta
    let asin = (
        if $asin == null {
            if "additionalFields" in $current_metadata and "asin" in $current_metadata.additionalFields {
                $current_metadata.additionalFields.asin
            } else if "title" in $current_metadata {
                # todo Use additional fields to make this query more reliable.
                http get $"https://api.audible.com/1.0/catalog/products?region=us&response_groups=series&title=($current_metadata.title | url encode)"  | get products | first | get asin
            } else {
                log error "Unable to determine the ASIN for the book!"
                exit 1
            }
        } else {
            $asin
        }
    )

    log info $"ASIN is (ansi purple)($asin)(ansi reset)"
    let r = (
        let result = http get $"https://api.audnex.us/books/($asin)";
        # Fix bad data
        if "seriesPrimary" in $result {
            if ($result.seriesPrimary.name | str contains --ignore-case "Eighty-Six") {
                $result
                # Just to be safe
                | update seriesPrimary.name "86--EIGHTY-SIX"
                | update authors [[name]; ["Asato Asato"] ["Roman Lempert - translator"] ["Shirabii - illustrator"]]
            } else {
                $result
            }
            if $result.seriesPrimary.name =~ "Rascal Does Not Dream" {
                $result
                # Series seems to now be Rascal Does Not Dream (light novel)
                # todo Remove "(light novel)" and "Series" from the end of series names?
                | update seriesPrimary.name "Rascal Does Not Dream"
                | update authors [[name]; ["Hajime Kamoshida"] ["Andrew Cunningham - translator"] ["Keji Mizoguchi - illustrator"]]
                | (
                    let input = $in;
                    if ($result.genres | is-empty) {
                        $input | update genres [[name type]; ["Science Fiction & Fantasy" genre]]
                    } else {
                        $input
                    }
                )
            } else {
                $result
            }
            if $result.seriesPrimary.name =~ "Spice and Wolf" {
                $result
                | update authors [[name]; ["Isuna Hasekura"] ["Paul Starr - translator"]]
            } else {
                $result
            }
        } else {
            $result
        }
    )
    let r = (
        if $r.title == "Arcanum Unbounded: The Cosmere Collection" {
            $r
            # Tries to put this under the Mistborn series, which isn't quite right
            | reject seriesPrimary
        } else {
            $r
        }
    )

    # todo Check for inconsistencies between the previous data and the current metadata, such as different authors.

    let authors = (
        $r.authors
        | get name
        | filter {|a|
            (
            not ($a | str ends-with "- afterword")
            and not ($a | str ends-with "- contributor")
            and not ($a | str ends-with "- editor")
            and not ($a | str ends-with "- illustrator")
            and not ($a | str ends-with "- translator")
            )
        }
    )
    let contributors = (
        $r.authors
        | get name
        | filter {|a| $a | str ends-with "- contributor" }
        | str replace "- contributor" ""
        | str trim
    )
    let editors = (
        $r.authors
        | get name
        | filter {|a| $a | str ends-with "- editor" }
        | str replace "- editor" ""
        | str trim
    )
    let illustrators = (
        $r.authors
        | get name
        | filter {|a| $a | str ends-with "- illustrator" }
        | str replace "- illustrator" ""
        | str trim
    )
    let translators = (
        $r.authors
        | get name
        | filter {|a| $a | str ends-with "- translator" }
        | str replace "- translator" ""
        | str trim
    )
    # let primary_authors = (
    #     let authors_with_asin = (
    #         $r.authors
    #         | default null asin
    #         | where asin != null
    #         | get name
    #         | filter {|a| not ($a | str ends-with " - translator") }
    #     );
    #     if ($authors_with_asin | is-empty) {
    #         $authors
    #     } else {
    #         $authors_with_asin
    #     }
    # )
    let series = (
        if "seriesPrimary" in $r {
            { name: $r.seriesPrimary.name } | (
                let input = $in;
                if "position" in $r.seriesPrimary {
                    $input | insert position $r.seriesPrimary.position
                } else {
                    $input
                }
            )
        } else {
            null
        }
    )
    # Normalize the title under weird circumstances where it doesn't match the title.
    let title = (
        if $series == null {
            $r.title
        } else {
            if ($r.title | str contains --ignore-case ', vol. ') {
                # 86 - Eighty-Six, Vol. 1 -> 86--EIGHTY-SIX, Vol. 1
                [$series.name ($r.title | str substring ($r.title | str downcase | str index-of ', vol. ')..)] | str join
            } else {
                $r.title
            }
        }
    )
    let title = (
        # Remove inconsistent use of " (light novel)" in titles
        if ($title | str contains --ignore-case " (light novel)") {
            $title | str replace --regex ' \([lL]ight [nN]ovel\)' ""
        } else {
            $title
        }
    )
    log debug $"The title is (ansi yellow)($title)(ansi reset)"
    # Audiobookshelf and Picard use a semicolon followed by a space to separate multiple values, I think.
    # Technically, I think ID3v2.4 is supposed to use a null byte, but not sure whether that's just what is shown or what is actually used.
    let tone_data = (
        {
            meta: {
                album: $title
                albumArtist: ($authors | str join ";")
                artist: ($authors | str join ";")
                composer: ($r.narrators | get name | str join ";")
                description: $r.description
                # todo Is language used at all?
                # language: $r.language
                narrator: ($r.narrators | get name | str join ";")
                publisher: $r.publisherName
                publishingDate: $r.releaseDate
                title: $title
                additionalFields: {
                    asin: $r.asin
                }
            }
        }
        | (
            let input = $in;
            if "genres" in $r {
                $input
                | insert meta.genre ($r.genres | where type == "genre" | get name | str join ";")
                | insert meta.additionalFields.tags ($r.genres | where type == "tag" | get name | str join ";")
            } else {
                $input
            }
        )
        | (
            let input = $in;
            if "isbn" in $r {
                $input | insert meta.additionalFields.isbn $r.isbn
            } else {
                $input
            }
        )
        | (
            let input = $in;
            if "copyright" in $r {
                $input | insert meta.copyright $r.copyright
            } else {
                $input
            }
        )
        # | (
        #     let input = $in;
        #     if ($authors | is-empty) or ($authors == $primary_authors) {
        #         $input
        #     } else {
        #         (
        #             $input
        #             | insert meta.additionalFields.authors ($authors | str join ";")
        #         )
        #     }
        # )
        | (
            let input = $in;
            if ($contributors | is-empty) {
                $input
            } else {
                (
                    $input
                    | insert meta.additionalFields.contributors ($contributors | str join ";")
                )
            }
        )
        | (
            let input = $in;
            if ($editors | is-empty) {
                $input
            } else {
                (
                    $input
                    | insert meta.additionalFields.editors ($editors | str join ";")
                )
            }
        )
        | (
            let input = $in;
            if ($illustrators | is-empty) {
                $input
            } else {
                (
                    $input
                    | insert meta.additionalFields.illustrators ($illustrators | str join ";")
                )
            }
        )
        | (
            let input = $in;
            if ($translators | is-empty) {
                $input
            } else {
                (
                    $input
                    | insert meta.additionalFields.translators ($translators | str join ";")
                )
            }
        )
        | (
            let input = $in;
            if $series == null {
                $input
            } else {
                (
                    $input
                    | insert meta.movementName $series.name
                )
            }
        )
    )
    let tone_json = $"($output_directory)/tone.json"
    $tone_data | save --force $tone_json
    let chapters = $"($output_directory)/chapters.txt"
    (
        http get $"https://api.audnex.us/books/($asin)/chapters"
        | get chapters
        | each {|chapter|
            let time = ($chapter.startOffsetMs | into duration --unit ms | format_chapter_duration);
            $"($time) ($chapter.title)"
        }
        | str join "\n"
        | save --force $chapters
    )
    log debug $"Chapters: ($chapters)"
    # let cover = $r.cover # "https://m.media-amazon.com/images/I/91rYWS09+AL.jpg"
    let cover = ({ parent: $output_directory, stem: "cover", extension: ($r.image | path parse | get extension )} | path join)
    # let ffmetadata = $"($output_directory)/ffmetadata.txt"
    # ^ffprobe -loglevel error -show_entries stream_tags:format_tags $m4b | save --force $ffmetadata
    http get --raw $r.image | save --force $cover
    [$cover] | optimize_images
    let args = (
        []
        | append (
            if $series != null and "position" in $series {
                $"--meta-part=($series.position)"
            } else {
                null
            }
        )
    )
    (
        ^tone tag
            # todo When tone is new enough:
            # --id $r.asin
            --meta-chapters-file $chapters
            --meta-cover-file $cover
            --meta-tone-json-file $tone_json
            --meta-remove-property "comment"
            ...$args
            ...$tone_tag_args
            $m4b
    )
    let renamed = (
        let components = $m4b | path parse;
        {
            parent: (
                [$output_directory]
                | append (
                    # Jellyfin can't handle having a bare audiobook file in the Audiobooks directory.
                    # So, place it in a directory named after the book if it won't be in a subdirectory for the author and/or series.
                    if ($authors | is-empty) and $series == null {
                        $title
                    } else {
                        $authors | str join ", "
                    }
                )
                | append (
                    if $series == null {
                        null
                    } else {
                        $series.name
                    }
                )
                | path join
            ),
            stem: $title,
            extension: $components.extension,
        }
        | path join
    )
    mkdir ($renamed | path dirname)
    mv $m4b $renamed
    $renamed
}

# Import Audiobooks with Beets.
#
# The final file is named according to Jellyfin's recommendation, Authors/Book.
#
export def beet_import [
    # beet_executable: path # Path to the Beets executable to use
    beets_directory: directory # Directory to which the books are imported
    config: path # Path to the Beets config to use
    --library: path # Path to the Beets library to use
    # --search-id
    # --set
    --working-directory: directory
]: path -> record<cover: path, m4b: path> {
    let m4b = $in
    # (
    #     ^beet
    #     --config $config
    #     --directory $beets_directory
    #     --library $library
    #     import
    #     $m4b
    # )
    let args = (
        []
        | append (if $library == null { "--volume=audible-beets-library:/config/library:Z" } else { $"--volume=($library | path dirname):/config/library:Z" })
    )
    log debug $"Running: podman run --detach --env PUID=0 --env PGID=0 --name beets-audible --rm --volume ($m4b):/input/($m4b | path basename):Z --volume ($beets_directory):/audiobooks:z --volume ($config):/config/config.yaml:Z --volume ($config | path dirname)/scripts:/custom-cont-init.d:Z ($args | str join ' ') lscr.io/linuxserver/beets:2.0.0"
    (
        ^podman run
            --detach
            --env "PUID=0"
            --env "PGID=0"
            --name "beets-audible"
            --rm
            # --volume $"($library | path dirname):/config/library:Z"
            --volume $"($m4b):/input/($m4b | path basename):Z"
            --volume $"($beets_directory):/audiobooks:z"
            --volume $"($config):/config/config.yaml:Z"
            --volume $"($config | path dirname)/scripts:/custom-cont-init.d:Z"
            ...$args
            "lscr.io/linuxserver/beets:2.0.0"
    )
    sleep 2min
    (
        ^podman exec
        --interactive
        --tty
        "beets-audible"
        beet import (["/input" ($m4b | path basename)] | path join)
    )
    ^podman stop beets-audible
    let author_directory = ls --full-paths $beets_directory | get name | first
    let imported_m4b = (
        let m4b_files = glob ([$author_directory "**" "*.m4b"] | path join);
        if ($m4b_files | is-empty) {
            log error $"No imported M4B file found in (ansi yellow)($author_directory)(ansi reset)!"
            exit 1
        } else if ($m4b_files | length) > 1 {
            log error $"Multiple imported M4B files found: (ansi yellow)($m4b_files)(ansi reset)!"
            exit 1
        } else {
            $m4b_files | first
        }
    )
    log debug $"The imported M4B file is (ansi yellow)($imported_m4b)(ansi reset)"
    let covers = (
        glob ([($imported_m4b | path dirname) "**" "cover.*"] | path join)
        | filter {|f|
            let components = $f | path parse
            $components.stem == "cover" and $components.extension in $image_extensions
        }
    );
    let cover = (
        if not ($covers | is-empty) {
            if ($covers | length) > 1 {
                log error $"Found multiple files looking for the cover image file:\n($covers)\n"
                exit 1
            } else {
                $covers | first
            }
        } else {
            null
        }
    )
    if $cover != null {
        log debug $"The cover file is (ansi yellow)($cover)(ansi reset)"
    } else {
        log warning $"No cover found!"
    }
    {
        cover: $cover,
        m4b: $imported_m4b,
    }
}

# Decrypt and convert an AAX file from Audible to an M4B file.
export def decrypt_audible [
    activation_bytes: string # Audible activation bytes
    --working-directory: directory
]: path -> path {
    let aax = $in
    let stem = $aax | path parse | get stem
    let m4b = ({ parent: $working_directory, stem: $stem, extension: "m4b" } | path join)
    ^ffmpeg -activation_bytes $activation_bytes -i $aax -c copy $m4b
    $m4b
}

# Embed the cover art to an M4B file
export def embed_cover []: record<cover: path, m4b: path> -> path {
    let audiobook = $in
    if $audiobook.cover == null {
        ^tone tag --auto-import=covers $audiobook.m4b
    } else {
        ^tone tag --meta-cover-file $audiobook.cover $audiobook.m4b
    }
    $audiobook
}

# Import an audiobook to my collection.
#
# Audiobooks can be provided in the AAX and M4B formats.
#
# This script performs several steps to process the audiobook file.
#
# 1. Decrypt the audiobook if it is from Audible.
# 2. Tag the audiobook.
# 3. Upload the audiobook
#
# The final file is named according to Jellyfin's recommendation, but includes a directory for the series if applicable.
# The path for a book in a series will look like "<authors>/<series>/<series-position> - <title>.m4b".
# The path for a standalone book will look like "<authors>/<title>.m4b".
#
def main [
    ...files: string # The paths to M4A and M4B files to tag and upload. Prefix paths with "minio:" to download them from the MinIO instance
    --asin: string
    --beets-config: path # The Beets config file to use
    --beets-directory: directory
    --beets-library: path # The Beets library to use
    --audible-activation-bytes: string # The Audible activation bytes used to decrypt the AAX file
    --delete # Delete the original file
    --minio-alias: string = "jwillikers" # The alias of the MinIO server used by the MinIO client application
    --minio-path: string = "media/Books/Audiobooks" # The upload bucket and directory on the MinIO server. The file will be uploaded under a subdirectory named after the author.
    --output-directory: directory # Directory to place files when not being uploaded
    --skip-upload # Don't upload files to the server
    --tone-tag-args: list<string> = [] # Additional arguments to pass to the tone tag command
] {
    if ($files | is-empty) {
        log error "No files provided"
        exit 1
    }

    if $asin != null and ($files | length) > 1 {
        log error "Setting the ASIN for multiple files is not allowed as it can result in overwriting the final file"
        exit 1
    }

    let output_directory = (
        if $output_directory == null {
            "." | path expand
        } else {
            $output_directory
        }
    )
    mkdir $output_directory

    for original_file in $files {

    log info $"Importing the file (ansi purple)($original_file)(ansi reset)"

    let temporary_directory = (mktemp --directory "import-audiobooks.XXXXXXXXXX")
    log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

    let beets_directory = (
        if $beets_directory == null {
            [$env.HOME "Books" "Audiobooks"] | path join
        } else {
            $beets_directory
        }
    )
    mkdir $beets_directory

    let audible_activation_bytes = (
        if $audible_activation_bytes != null {
            $audible_activation_bytes
        } else if "AUDIBLE_ACTIVATION_BYTES" in $env {
            $env.AUDIBLE_ACTIVATION_BYTES
        } else {
            null
        }
    )

    # try {

    let file = (
        if ($original_file | str starts-with "minio:") {
            let file = ($original_file | str replace "minio:" "")
            ^mc cp $file $"($temporary_directory)/($file | path basename)"
            [$temporary_directory ($file | path basename)] | path join
        } else {
            cp $original_file $temporary_directory
            [$temporary_directory ($original_file | path basename)] | path join
        }
    )

    let input_format = (
        if ($file | path type) == "dir" {
            "dir"
        } else {
            let ext = $file | path parse | get extension;
            if $ext == null {
                log error $"Unable to determine input file type of (ansi yellow)($file)(ansi reset). It is not a directory and has no file extension."
                exit 1
            } else {
                $ext
            }
        }
    )

    let beets_library = (
        if $beets_library == null {
            let library_directory = [$env.HOME ".local" "share" "beets-audible"] | path join
            mkdir $library_directory
            [$library_directory "library.db"] | path join
        } else {
            $beets_library
        }
    )

    let audiobook = (
        # Assume AAX files are from Audible and require decryption.
        if $input_format == "aax" {
            if $audible_activation_bytes == null {
                log error "Audible activation bytes must be provided to decrypt Audible audiobooks"
                exit 1
            }
            $file | decrypt_audible $audible_activation_bytes --working-directory $temporary_directory
        } else if $input_format in ["m4a", "m4b"] {
            $file
        } else if $input_format == "dir" {
            $file | mp3_directory_to_m4b $temporary_directory
        } else if $input_format == "zip" {
            $file
            | unzip $temporary_directory
            | mp3_directory_to_m4b $temporary_directory
        } else {
            log error $"Unsupported input file type (ansi red_bold)($input_format)(ansi reset)"
            exit 1
        }
        | (
            if $asin == null {
                tag_audiobook --tone-tag-args $tone_tag_args $temporary_directory
            } else {
                tag_audiobook --asin $asin --tone-tag-args $tone_tag_args $temporary_directory
            }
        )
    )

    # log debug $"Fetching and writing metadata to '($formats.cbz)' with ComicTagger"
    # log debug $"The ComicTagger result is:\n(ansi green)($tag_result.result)(ansi reset)\n"
    # log debug "Renaming the CBZ according to the updated metadata"

    # let formats = $formats | (
    #     let format = $in;
    #     $format | update cbz ($format.cbz | comictagger_rename_cbz --comictagger $comictagger)
    # )

    # let comic_metadata = ($tag_result.result | get md)

    # Authors are considered to be creators with the role of "Writer" in the ComicVine metadata
    # let authors = ($comic_metadata | get credits | where role == "Writer" | get person)
    # log debug $"Authors determined to be (ansi purple)'($authors)'(ansi reset)"

    # let current_metadata = ^tone dump --format json $audiobook | from json | get meta

    let authors_subdirectory = (
        $audiobook | path dirname | path relative-to $temporary_directory
    )
    let minio_target_directory =  [$minio_alias $minio_path $authors_subdirectory] | path join | sanitize_minio_filename
    let minio_target_destination = (
        let components = ($audiobook | path parse);
        { parent: $minio_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
    )
    if $skip_upload {
        mv $audiobook $output_directory
    } else {
        log info $"Uploading (ansi yellow)($audiobook)(ansi reset) to (ansi yellow)($minio_target_destination)(ansi reset)"
        ^mc mv $audiobook $minio_target_destination
    }

    if $delete {
        log debug "Deleting the original file"
        if ($original_file | str starts-with "minio:") {
            let actual_path = ($original_file | str replace "minio:" "")
            if ($actual_path | sanitize_minio_filename) == $minio_target_destination {
                log info $"Not deleting the original file (ansi yellow)($original_file)(ansi reset) since it was overwritten by the updated file"
            } else {
                log info $"Deleting the original file on MinIO (ansi yellow)($actual_path)(ansi reset)"
                ^mc rm $actual_path
            }
        } else {
            log info $"Deleting the original file (ansi yellow)($original_file)(ansi reset)"
            rm $original_file
        }
    }
    log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
    rm --force --recursive $temporary_directory

    # } catch {
    #     log error $"Import of (ansi red)($original_file)(ansi reset) failed!"
    #     continue
    # }

    }
}
