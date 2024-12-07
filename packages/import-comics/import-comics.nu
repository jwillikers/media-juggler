#!/usr/bin/env nu

# ~/Projects/media-juggler/packages/import-comics/import-comics.nu --output-directory ~/Downloads ~/Downloads/ComicTagger-x86_64.AppImage ...(^mc find --name '*.cbz' "jwillikers/media/Books/Books/Ryoko Kui" | lines | par-each {|l| "minio:" + $l})

use std log

# $env.NU_LOG_LEVEL = "DEBUG"

# Publishers excluded from ComicTagger matches.
let excluded_publishers = [
    "Azbooka"
    "Carlsen Verlag"
    "Crunchyroll SA"
    "Crunchyroll SAS"
    "Daewon C.I."
    "Dargaud"
    "Darkwood"
    "Delcourt"
    "Editorial Ivrea"
    "Edizioni BD"
    "Egmont Ehapa Verlag "
    "Europe Comics"
    "Éditions Glénat "
    "Image"
    "Jademan"
    "Japonica Polonica Fantastica"
    "Ki-oon"
    "Kodansha"
    "Kurokawa"
    "M&C"
    "NBM"
    "Norma Editorial"
    "Planeta DeAgostini"
    "Scary Go Round"
    "Schibsted"
    "Shueisha"
    "Shogakukan"
    "Siam Inter"
    "Soleil"
    "Square Enix"
    "Tong Li Publishing Co."
    "Tokyopop GmbH"
]

let ereader_profiles = [
    [model height width volume];
    ["Kobo Elipsa 2E" 1872 1404 "KOBOeReader"]
]

# Convert an Adobe Digital Editions ACSM file to an EPUB
export def acsm_to_epub [
    working_directory: directory # The scratch-space directory to use
]: [path -> path] {
    let acsm_file = $in
    log info "Closing running instance of Calibre"
    ^calibre --shutdown-running-calibre

    log info $"Importing the ACSM file (ansi yellow)($acsm_file)(ansi reset) into Calibre. This may take a bit..."
    let book_id = (
        ^calibredb add --automerge overwrite -- $acsm_file
            # todo Keep output and print in case of error?
            # err> /dev/null
        | lines --skip-empty
        | last
        | parse --regex '.* book ids: (?P<book_id>\w+)'
        | get book_id
        | first
    )
    log info $"Successfully imported into Calibre as id (ansi purple_bold)($book_id)(ansi reset)"

    log debug $"Exporting the EPUB from Calibre to (ansi yellow)($working_directory)/($book_id).epub(ansi reset)"
    (
        ^calibredb export
            --dont-asciiize
            --dont-save-cover
            --dont-save-extra-files
            --dont-write-opf
            --progress
            --template '{id}'
            --single-dir
            --to-dir $working_directory
            -- $book_id
            # err> /dev/null
    )

    log debug $"Removing EPUB format for book '($book_id)' in Calibre"
    ^calibredb remove_format $book_id EPUB
    let available_formats = (
        ^calibredb list
            --fields "formats"
            --for-machine
            --search $"id:($book_id)"
    )
    if ($available_formats | is-empty) {
        log debug $"Removing book '($book_id)' in Calibre"
        ^calibredb remove $book_id
    }

    ({ parent: $working_directory, stem: $book_id, extension: "epub" } | path join)
}

# Losslessly optimize images
export def optimize_images []: [list<path> -> record] {
    let paths = $in
    # Ignore config paths to ensure that lossy compression is not enabled.
    log debug $"Running command: (ansi yellow)image_optim --config-paths \"\" --recursive ($paths | str join ' ')(ansi reset)"
    let result = ^image_optim --config-paths "" --recursive --threads ((^nproc | into int) / 2) ...$paths | complete
    if ($result.exit_code != 0) {
        log error $"Exit code ($result.exit_code) from command: (ansi yellow)image_optim --config-paths \"\" --recursive ($paths)(ansi reset)\n($result.stderr)\n"
        return null
    }
    log debug $"image_optim stdout:\n($result.stdout)\n"
    (
        $result.stdout
        | lines --skip-empty
        | last
        | (
            let line = $in;
            log debug $"image_optim line: ($line)";
            if "------" in $line {
                { difference: 0.0, bytes: (0.0 | into filesize) }
            } else {
                $line
                | parse --regex 'Total:\W+(?P<difference>.+)%\W+(?P<bytes>.+)'
                | first
                | (
                    let i = $in;
                    {
                        difference: ($i.difference | into float),
                        bytes: ($i.bytes | into filesize),
                    }
                )
            }
        )
    )
}

# Losslessly optimize the images in a ZIP archive such as an EPUB or CBZ
export def optimize_images_in_zip []: [path -> path] {
    let archive = ($in | path expand)
    log debug $"Optimizing images in (ansi yellow)($archive)(ansi reset)"
    let temporary_directory = (mktemp --directory)
    let extraction_path = ($temporary_directory | path join "extracted")
    log debug $"Extracting zip archive to (ansi yellow)($extraction_path)(ansi reset)"
    ^unzip -q $archive -d $extraction_path
    let reduction = [$extraction_path] | optimize_images
    log debug "Image optimization complete"
    if $reduction.difference > 0 {
        let filename = $archive | path basename
        log info $"The archive (ansi yellow)($filename)(ansi reset) was reduced by (ansi purple_bold)($reduction.bytes)(ansi reset), a (ansi purple_bold)($reduction.difference)%(ansi reset) reduction in size"
    }
    log debug $"Compressing directory (ansi yellow)($extraction_path)(ansi reset) as (ansi yellow)($archive)(ansi reset)"
    cd $extraction_path
    ^zip --quiet --recurse-paths $archive .
    cd -
    rm --force --recursive $temporary_directory
    $archive
}

# Optimize and clean up an EPUB with Calibre
export def polish_epub []: [path -> path] {
    let epub = $in;
    (
        ^ebook-polish
            --compress-images
            --download-external-resources
            --remove-unused-css
            --upgrade-book
            $epub
            $epub
            # err> /dev/null
    )
    $epub
}

# Convert an EPUB to a CBZ
export def epub_to_cbz [
    --working-directory: directory # Directory to work in
]: [path -> path] {
    let epub = $in
    let cbz = ({ parent: $working_directory, stem: ($epub | path parse | get stem), extension: "cbz" } | path join)

    log debug $"Extracting contents of the EPUB (ansi yellow)($epub)(ansi reset) to (ansi yellow)($working_directory)/epub(ansi reset)"
    unzip -q $epub -d ($working_directory | path join "epub")

    let image_files = (glob $"($working_directory)/epub/**/*.{avif,bmp,jpeg,jpg,jxl,png,tiff,webp}")
    let image_file_extension = ($image_files | first | path parse | get extension)
    let image_subdirectory = ($image_files | first | path parse | get parent)
    let image_format = (
        if $image_file_extension == "jpg" {
            "jpeg"
        } else {
            $image_file_extension
        }
    )

    # todo Verify the cover is indeed the first page in the archive.
    # Especially for the bonking sorting order used by ComicTagger.
    if ($"($image_subdirectory)/page_cover.($image_file_extension)" | path exists) {
        log debug $"Renaming ($image_subdirectory)/page_cover.($image_file_extension) to ($image_subdirectory)/cover.($image_file_extension) to avoid the cover not being detected as the first page"
        mv $"($image_subdirectory)/page_cover.($image_file_extension)" $"($image_subdirectory)/cover.($image_file_extension)"
    }
    log debug $"Compressing the contents of the directory (ansi yellow)($image_subdirectory)(ansi reset) into the CBZ file (ansi yellow)($cbz)(ansi reset)"
    ^zip -jqr $cbz $image_subdirectory
    rm --force --recursive $"($working_directory)/epub"
    $cbz
}

# Incorporate metadata for ComicTagger in the filename.
export def rename_cbz_from_epub_metadata [
    epub: path
    --issue: string
    --issue_year: string
    --series: string
    --series_year: string
    --title: string
]: [path -> path] {
    let cbz = $in
    let opf_file = ($epub | path parse | update extension "opf" | path join)
    ^ebook-meta --to-opf $opf_file $epub
    let epub_title = (
        $opf_file
        | open
        | from xml
        | get content
        | where tag == 'metadata'
        | first
        | get content
        | where tag == 'title'
        | first
        | get content
        | first
        | get content
    )
    log debug $"EPUB title: ($epub_title)"

    let parsed_title = (
        if ($epub_title | str contains "Volume") {
            (
                $epub_title
                | parse --regex '(?P<series>.+) Volume (?P<issue>[0-9]+)'
                | first
            )
        } else if ($epub_title =~ ".*[ _]+vol[0-9]+") {
            (
                $epub_title
                | parse --regex '(?P<series>.+)[ _]+vol(?P<issue>[0-9]+)'
                | first
            )
        } else if $epub_title =~ ".+ [0-9]+" {
            $epub_title
            | parse --regex '(?P<series>.+) (?P<issue>[0-9]+)'
            | first
        } else {
            { series: $epub_title, issue: 1 }
        }
    )
    log debug $"Retrieved the title (ansi purple)'($parsed_title)'(ansi reset) from Calibre"
    let series = (
        if $series == null {
            if $parsed_title == null {
                null
            } else {
                log debug $"Parsed the series as (ansi purple)'($parsed_title.series)'(ansi reset) from the title"
                $parsed_title.series
            }
        } else {
            $series
        }
    )
    let issue = (
        if $issue == null {
            if $parsed_title == null {
                null
            } else {
                log debug $"Parsed the issue as (ansi purple)'($parsed_title.issue)'(ansi reset) from the title"
                $parsed_title.issue
            }
        } else {
            $issue
        }
    )

    if $series == null and $issue == null {
        log error $"Unable to determine the series and issue from the EPUB title '($epub_title)'. Pass the Comic Vine issue id with the (ansi green)--comic-vine-issue-id(ansi reset) flag."
        $cbz
    } else {
        let directory = ($cbz | path parse | get parent)
        let comic_file = $"($series) \(($series_year)\) #($issue) \(($issue_year)\).cbz"
        log debug $"Renaming the CBZ file to (ansi yellow)($directory)/($comic_file)(ansi reset) for ComicTagger"
        mv $cbz $"($directory)/($comic_file)"
        $"($directory)/($comic_file)"
    }
}

# Get the image extension used in a comic book archive
export def get_image_extension []: [path -> string] {
    let cbz = $in
    let file_extensions = (
        ^unzip -l $cbz
        | lines
        | drop nth 0 1
        | drop 2
        | str trim
        | parse "{length}  {date} {time}   {name}"
        | get name
        | path parse
        | where extension != "xml"
        | get extension
        | filter {|extension| not ($extension | is-empty) }
        | uniq
    )
    let file_extensions = (
        if (($file_extensions | length) == 2 and "jpg" in $file_extensions and "jpeg" in $file_extensions) {
            ["jpeg"]
        } else {
            $file_extensions
        }
    )
    if ($file_extensions | is-empty) {
        log error "No file extensions found"
        null
    } else if (($file_extensions | length) > 1 or ($file_extensions | length) == 0) {
        log error $"Multiple file extensions found: ($file_extensions)"
        null
    } else {
        $file_extensions | first
    }
}

# Tag CBZ file with ComicTagger using Comic Vine
export def tag_cbz [
    comictagger: path
    --comic-vine-issue-id: string # The Comic Vine issue id. Useful when nothing else works.
    # --excluded-publishers: list<string> # A list of publishers to exclude
    --interactive # Ask for input from the user
]: [path -> record] {
    let cbz = $in
    let result = (
        if $comic_vine_issue_id != null {
            (
                ^$comictagger
                --cv-use-series-start-as-volume
                --filename-parser "original"
                --id $comic_vine_issue_id
                --json
                --no-cr
                --no-gui
                --online
                --parse-filename
                --publisher-filter ...$excluded_publishers
                --save
                --tags-read "CR,CIX"
                --tags-write "CIX"
                --use-publisher-filter
                $cbz
            )
            | from json
        } else if $interactive {
            (
                ^$comictagger
                --cv-use-series-start-as-volume
                --filename-parser "original"
                --interactive
                --no-cr
                --no-gui
                --online
                --parse-filename
                --publisher-filter ...$excluded_publishers
                --save
                --tags-write "CIX"
                --use-publisher-filter
                $cbz
            )
            (
                ^$comictagger
                --json
                --print
                --no-gui
                --tags-read "CIX"
                $cbz
            ) | from json
        } else {
            (
                ^$comictagger
                --cv-use-series-start-as-volume
                --filename-parser "original"
                --json
                --no-cr
                --no-gui
                --online
                --parse-filename
                --publisher-filter ...$excluded_publishers
                --save
                --tags-write "CIX"
                --use-publisher-filter
                $cbz
            )
            | from json
        }
    )
    { cbz: $cbz, result: $result }
}

# Rename the comic according to the ComicInfo metadata
export def comictagger_rename_cbz [
    --comictagger: path # ComicTagger executable
]: [path -> path] {
    let cbz = $in
    (
        ^$comictagger
        --no-cr
        --no-gui
        --rename
        --tags-read "CIX"
        --template '{series} ({volume}) #{issue} ({year})'
        $cbz
        | lines --skip-empty
        | last
        | (
            let output = $in;
            log debug $"ComicTagger rename output: ($output)";
            if $output == "Filename is already good!" {
                $cbz
            } else {
                let new_name = (
                    $output
                    | parse --regex 'renamed \'(?P<original>.+\.cbz)\' -> \'(?P<renamed>.+\.cbz)\''
                    | get renamed
                    | first
                    | (
                        let filename = $in;
                        ($cbz | path parse | get parent) | path join $filename
                    )
                )
                log debug $"Renamed (ansi yellow)($cbz)(ansi reset) to (ansi yellow)($new_name)(ansi reset)"
                $new_name
            }
        )
    )
}

# Fetch metadata for the EPUB and embed it
#
# The metadata for Authors and Title from the ComicVine Calibre plugin are corrected here.
# The title includes the issue number twice in the name, which is kind of ugly, so that is fixed.
# All creators are tagged as authors which is incorrect.
# To accommodate this, authors must be passed directly.
#
export def tag_epub [
    comic_vine_issue_id: string # The unique ComicVine id for the issue
    authors: list<string> # A list of authors to use
    title: string # The title to use
    --working-directory: directory
]: [path -> path] {
    let epub = $in
    let opf_file = ({ parent: $working_directory, stem: $comic_vine_issue_id, extension: "opf" } | path join)
    let opf = (
        ^fetch-ebook-metadata
            --allowed-plugin "Comicvine"
            --identifier $"comicvine:($comic_vine_issue_id)"
            --opf
        | from xml
    )
    log debug $"The opf metadata for ComicVine issue id (ansi purple_bold)($comic_vine_issue_id)(ansi reset) is:\n($opf)\n"
    # todo edit XML directly?
    (
        $opf
        | to xml
        | save --force $opf_file
    )
    (
        ^ebook-meta
            $epub
            --authors ($authors | str join "&")
            --from-opf $"($working_directory)/($comic_vine_issue_id).opf"
            --title $title
    )
    rm $opf_file
    $epub
}

# Update ComicInfo metadata with ComicTagger
export def comictagger_update_metadata [
    metadata: string # Key and values to update in the metadata in a YAML-like syntax
    --comictagger: path # ComicTagger executable
]: [path -> path] {
    let cbz = $in
    (
        ^$comictagger
            --metadata $metadata
            --no-cr
            --no-gui
            --quiet
            --save
            --tags-read "CIX"
            --tags-write "CIX"
            $cbz
    )
    $cbz
}

# Convert images in a CBZ to lossless JXL.
# JXL should be a great archival format going forward and is a significant reduction in size over JPEG, even using lossless compression.
# AVIF is an alternative format which could be used for archival purposes.
# I decided to go with JXL, but haven't looked into both formats exhaustively.
#
# CBconvert uses lossless encoding when the quality is set to 100.
# The intent is for this to be archival quality.
# The EPUB is saved to ensure that the original source material remains intact, just in case I messed something up in the conversion process.
#
# Unfortunately, the JXL format isn't supported by KOReader yet.
#
# Okay, so, updating CBConvert to 1.1.0 results in proper JXL lossless compression I'm pretty sure.
# However, it results in significantly larger files than the source JPEGs.
# I'll probably only want to use JXL when the source files are PNGs.
export def convert_to_lossless_jxl []: [path -> path] {
    let cbz = $in
    let components = ($cbz | path parse)
    let original_size = (ls $cbz | first | get size)
    log debug $"Running command: cbconvert --filter 7 --format jxl --outdir ($components.parent) ($cbz)"
    (
        ^cbconvert convert
            --filter 7 # Since we aren't resizing the images, the resampling filter shouldn't actually be used here.
            --format "jxl"
            --outdir $components.parent
            --quality 100 # lossless
            $cbz
    )
    let current_size = (ls $cbz | first | get size)
    let average = (($original_size + $current_size) / 2)
    let percent_difference = ((($original_size - $current_size) / $average) * 100)
    let size_table = [[original current "% difference"]; [$original_size $current_size $percent_difference]]
    log info $"Converted images in (ansi yellow)($cbz)(ansi reset) to JPEG-XL: ($size_table)"
    if $current_size > $original_size {
        log warning "CBZ file converted to JPEG-XL increased in size!"
    }
    $cbz
}

# Convert a copy for my primary e-reader:
# Kobo Elipsa 2E: 1404x1872 (Gamma 1.8).
# todo I'm not sure this is even really necessary
# Using the correct resolution does seem to result in much faster page loads.
# Although, maybe that's due to using webp?
# I should verify.
export def convert_for_ereader [
    suffix: string # Suffix to add to the CBZ filename
    --format: string # The image format to convert to
    --height: string # The height of the converted images
    --quality: string # The quality setting to use for the encoder
    --width: string # The width of the converted images
]: [path -> path] {
    let cbz = $in
    let components = ($cbz | path parse)
    # todo Use some sort of wrapper to print out command-line of command being run?
    # todo This doesn't work right with jpegs.
    # I recommend KCC for now
    log error "Need to convert for ereader using KCC right now"
    exit 1
    log debug $"Running command: cbconvert --filter 7 --format ($format) --height ($height) --outdir ($components.parent) --quality ($quality) --suffix ($suffix) --width ($width) ($cbz)"
    (
        ^cbconvert convert
            --filter 7 # Use the highest quality resampling filter.
            --format $format
            --height $height
            --outdir $components.parent
            --quality $quality
            --suffix $suffix
            --width $width
            $cbz
    )
    $components | update stem ($components.stem + $suffix) | path join
}

export def sanitize_minio_filename []: [string -> string] {
    $in | str replace --all "!" ""
}

# Import my comic or manga file to my collection.
#
# This script performs several steps to process the comic or manga file.
#
# 1. Decrypt the ACSM file.
# 2. Convert from EPUB to the CBZ format.
# 4. Fetch and add metadata in the ComicInfo.xml format.
# 5. Upload the file to object storage.
#
# Information that is not provided will be gleaned from the title of the EPUB file if possible.
#
# The final file is named according to Jellyfin's recommendation.
# The name will look like "<series> (<series-year>) #<issue> (<issue-year>).cbz".
#
#
def main [
    comictagger: path = "./ComicTagger-x86_64.AppImage" # Temporarily required until the Nix package is available
    ...files: path # The paths to ACSM, EPUB, and CBZ files to convert, tag, and upload. Prefix paths with "minio:" to download them from the MinIO instance
    --comic-vine-issue-id: string # The ComicVine issue id. Useful when nothing else works
    --delete # Delete the original file
    --ereader: string # Create a copy of the comic book optimized for this specific e-reader, i.e. "Kobo Elipsa 2E"
    --ereader-subdirectory: string = "Books/Manga" # The subdirectory on the e-reader in-which to copy
    --interactive # Ask for input from the user
    --keep-acsm # Keep the ACSM file after conversion. These stop working for me before long, so no point keeping them around.
    # --issue: string # The issue number
    # --issue-year: string # The publication year of the issue
    --manga: string = "Yes" # Whether the file is manga "Yes", right-to-left manga "Yes (Right to Left)", or not manga "No"
    --minio-alias: string = "jwillikers" # The alias of the MinIO server used by the MinIO client application
    --minio-path: string = "media/Books/Books" # The upload bucket and directory on the MinIO server. The file will be uploaded under a subdirectory named after the author.
    --minio-archival-path: string = "media-archive/Books/Books" # The upload bucket and directory on the MinIO server where EPUBs will be archived. The file will be uploaded under a subdirectory named after the author.
    --no-copy-to-ereader # Don't copy the E-Reader specific format to a mounted e-reader
    --output-directory: directory # Directory to place files when not being uploaded
    # --series: string # The name of the series
    # --series-year: string # The initial publication year of the series, also referred to as the volume
    --skip-upload # Don't upload files to the server
    --title: string # The title of the comic or manga issue
    --upload-ereader-cbz # Upload the E-Reader specific format to the server
] {
    let output_directory = (
        if $output_directory == null {
            "." | path expand
        } else {
            $output_directory
        }
    )
    mkdir $output_directory

    if ($files | is-empty) {
        log error "No files provided"
        exit 1
    }

    for original_file in $files {

    log info $"Importing the file (ansi purple)($original_file)(ansi reset)"

    let temporary_directory = (mktemp --directory)
    log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

    # todo if given --comic-vine-issue-id and multiple files, report an error.

    try {

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

    let input_format = ($file | path parse | get extension)

    let formats = (
        if $input_format == "acsm" {
            let epub = ($file | acsm_to_epub $temporary_directory | optimize_images_in_zip | polish_epub)
            let cbz = (
                $epub
                | epub_to_cbz --working-directory $temporary_directory
                | (
                    let cbz = $in;
                    if $comic_vine_issue_id == null {
                        $cbz | rename_cbz_from_epub_metadata $epub
                    } else {
                        $cbz
                    }
                )
            )
            { cbz: $cbz, epub: $epub }
        } else if $input_format == "epub" {
            let cbz = (
                $file
                | optimize_images_in_zip
                | polish_epub
                | epub_to_cbz --working-directory $temporary_directory
                | (
                    let cbz = $in;
                    if $comic_vine_issue_id == null {
                        $cbz | rename_cbz_from_epub_metadata $epub
                    } else {
                        $cbz
                    }
                )
            )
            { cbz: $cbz, epub: $file }
        } else if $input_format in ["cbz" "zip"] {
            { cbz: ($file) }
        } else {
            log error $"Unsupported input file type (ansi red_bold)($input_format)(ansi reset)"
            exit 1
        }
    )

    log debug $"Fetching and writing metadata to '($formats.cbz)' with ComicTagger"
    let tag_result = (
        $formats.cbz | tag_cbz
        $comictagger
        --comic-vine-issue-id $comic_vine_issue_id
        # --excluded-publishers $excluded_publishers
        # --interactive $interactive
    )

    log debug $"The ComicTagger result is:\n(ansi green)($tag_result.result)(ansi reset)\n"

    log debug "Renaming the CBZ according to the updated metadata"
    let formats = $formats | (
        let format = $in;
        $format | update cbz ($format.cbz | comictagger_rename_cbz --comictagger $comictagger)
    )

    let comic_metadata = ($tag_result.result | get md)

    # Authors are considered to be creators with the role of "Writer" in the ComicVine metadata
    let authors = (
      let credits = $comic_metadata | get credits;
      let writers = $credits | where role == "Writer" | get person;
      if ($writers | is-empty) {
        $credits | where role == "Artist" | get person
      } else {
        $writers
      }
    )
    log debug $"Authors determined to be (ansi purple)'($authors)'(ansi reset)"

    # We keep the name of the series in the title to keep things organized.
    # Displaying only "Vol. 4" as the title can be confusing.
    let title = (
        if $title == null {
            $comic_metadata
            | (
                let metadata = $in;
                # todo Handle issue_title?
                if $metadata.title == null {
                    # If the volume is most likely just a single issue, just use the series as the nameV
                    if $metadata.issue_count == 1 and (((date now) - ($metadata.volume | into string | into datetime)) | format duration yr) > 2yr {
                        $metadata.series
                    } else {
                        $"($metadata.series), Vol. ($metadata.issue)"
                    }
                } else {
                    log debug "The title will be updated to include the name of the series"
                    $"($metadata.series), ($metadata.title)"
                }
            )
        } else {
            $title
        }
    )

    # Update the metadata in the EPUB and rename it to match the filename of the CBZ
    let formats = (
        if "epub" in $formats {
            # Update the metadata in the EPUB file.
            $formats.epub | (
                tag_epub
                (if $comic_vine_issue_id == null { $comic_metadata.issue_id } else { $comic_vine_issue_id })
                $authors
                $title
                --working-directory $temporary_directory
            )
            let stem = ($formats.cbz | path parse | get stem)
            let renamed_epub = ({ parent: ($formats.epub | path parse | get parent), stem: $stem, extension: "epub" } | path join)
            mv $formats.epub $renamed_epub
            $formats | (
                let format = $in;
                $format | update epub $renamed_epub
            )
        } else {
            $formats
        }
    )

    let previous_title = ($comic_metadata | get title)
    log info $"Rewriting the title from (ansi yellow)'($previous_title)'(ansi reset) to (ansi yellow)'($title)'(ansi reset)"
    # todo Read from YAML file to ensure proper string escaping of single / double quotes?
    let sanitized_title = $title | str replace --all '"' '\"'
    $formats.cbz | comictagger_update_metadata $"manga: \"($manga)\", title: \"($sanitized_title)\"" --comictagger $comictagger

    let image_format = ($formats.cbz | get_image_extension)
    if $image_format == null {
        log error "Failed to determine the image file format"
        exit 1
    }

    # todo Detect if another lossless format, i.e. webp, is being used and if so, convert those to jxl as well.
    #
    if $image_format in ["png"] {
        $formats.cbz | convert_to_lossless_jxl
    } else {
        $formats.cbz | optimize_images_in_zip
    }

    # Not sure if "webp" would really be any better than jpeg here or not...
    # I'm assuming it might at least be a little bit smaller given cbconvert doesn't appear to use mozjpeg.
    # Use PNG for lossless codecs and webp for lossy.
    # CBconvert appears to always use lossy webp encoding.
    let formats = (
        if $ereader == null {
            $formats
        } else {
            $formats
            | insert ereader_cbz (
                $formats.cbz
                | convert_for_ereader ("_" + ($ereader | str replace --all " " "_" | str downcase))
                --format (if $image_format in [ "avif", "jxl", "png", ] { "png" } else { "jpeg" })
                --height ($ereader_profiles | where model == $ereader | first | get height)
                --quality 100
                --width ($ereader_profiles | where model == $ereader | first | get width)
                | optimize_images_in_zip
            )
        }
    )

    # todo Functions archive_epub, upload_cbz, and perhaps copy_cbz_to_ereader

    let authors_subdirectory = ($authors | str join ", ")
    let minio_target_directory =  [$minio_alias $minio_path $authors_subdirectory] | path join | sanitize_minio_filename
    let minio_target_destination = (
        let components = ($formats.cbz | path parse);
        { parent: $minio_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
    )
    if $skip_upload {
        mv $formats.cbz $output_directory
    } else {
        log info $"Uploading (ansi yellow)($formats.cbz)(ansi reset) to (ansi yellow)($minio_target_destination)(ansi reset)"
        ^mc mv $formats.cbz $minio_target_destination
    }

    # Keep the EPUB for archival purposes.
    # I have Calibre reduce the size of images in a so-called "lossless" manner.
    # If anything about that isn't actually lossless, that's not good...
    # Guess I'm willing to take that risk right now.
    let minio_archival_target_directory =  [$minio_alias $minio_archival_path $authors_subdirectory] | path join | sanitize_minio_filename
    if "epub" in $formats {
        let minio_archival_destination = (
            let components = ($formats.epub | path parse);
            { parent: $minio_archival_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
        )
        if $skip_upload {
            mv $formats.epub $output_directory
        } else {
            log info $"Uploading (ansi yellow)($formats.epub)(ansi reset) to (ansi yellow)($minio_archival_destination)(ansi reset)"
            ^mc mv $formats.epub $minio_archival_destination
        }
    }

    if ereader_cbz in $formats {
        if not $no_copy_to_ereader {
            let username = (^id --name --user)
            let mounted_volume_name = ($ereader_profiles | where model == $ereader | first | get volume)
            # todo Automatically mount the device.
            mkdir (["/run/media" $username $mounted_volume_name $ereader_subdirectory] | path join)
            let safe_basename = (($formats.ereader_cbz | path basename) | str replace --all ":" "_")
            let target = (["/run/media" $username $mounted_volume_name $ereader_subdirectory $safe_basename] | path join)
            log info $"Copying (ansi yellow)($formats.ereader_cbz)(ansi reset) to (ansi yellow)($target)(ansi reset)"
            cp $formats.ereader_cbz $target
        }
        if $upload_ereader_cbz {
            log info $"Uploading (ansi yellow)($formats.ereader_cbz)(ansi reset) to (ansi yellow)($minio_target_directory)/($formats.ereader_cbz | path basename)(ansi reset)"
            ^mc mv $formats.ereader_cbz $minio_target_directory
        }
        if not $no_copy_to_ereader and not $upload_ereader_cbz {
            mv $formats.ereader_cbz $output_directory
        }
    }

    if $delete {
        log debug "Deleting the original file"
        if ($original_file | str starts-with "minio:") {
            let actual_path = ($original_file | str replace "minio:" "")
            log debug $"Actual path: ($actual_path)"
            let uploaded_paths = (
                [$minio_target_destination]
                | append (if "epub" in $formats {
                        ([$minio_archival_target_directory ($formats.epub | path basename)] | path join | sanitize_minio_filename)
                    } else {
                        null
                    })
            )
            log debug $"Uploaded paths: ($uploaded_paths)"
            if ($actual_path | sanitize_minio_filename) in $uploaded_paths {
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

    } catch {
        log error $"Import of (ansi red)($original_file)(ansi reset) failed!"
        continue
    }

    }
}
