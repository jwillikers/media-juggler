# A collection of helpful utility functions

use std log

export const ereader_profiles = [
    [model height width volume];
    ["Kobo Elipsa 2E" 1872 1404 "KOBOeReader"]
]

# Extract the ComicInfo.xml file from an archive
export def extract_comic_info [
    working_directory: directory # The scratch-space directory to use
]: path -> path {
    let archive = $in;
    ^unzip $archive "ComicInfo.xml" -d $working_directory
    [$working_directory "ComicInfo.xml"] | path join
}

# Inject a ComicInfo.xml file into an archive
# Takes a record containing the archive and ComicInfo.xml file
export def inject_comic_info []: [
    record<archive: path, comic_info: path> -> path
] {
    let input = $in
    let has_comic_info = (
        ^unzip -l $input.archive
        | lines
        | drop nth 0 1
        | drop 2
        | str trim
        | parse "{length}  {date} {time}   {name}"
        | get name
        | path basename
        | any {|name| $name == "ComicInfo.xml"}
    )
    if $has_comic_info {
        ^zip --delete $input.archive "ComicInfo.xml"
    }
    ^zip --junk-paths $input.archive $input.comic_info
    $input.archive
}

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

# Convert an PDF to a CBZ
export def pdf_to_cbz [
    --working-directory: directory # Directory to work in
]: path -> path {
    let pdf = $in
    let cbz = ({ parent: $working_directory, stem: ($pdf | path parse | get stem), extension: "cbz" } | path join)

    # https://lonm.vivaldi.net/2022/11/16/converting-comics-from-pdf-into-cbz-format/
    # pdfimages -png -j -p $pdf $images_directory
    # mutool convert -F cbz ../../attackontitan_beforethefall_vol9.pdf
    # Convert to jxl

    log debug $"Extracting contents of the PDF (ansi yellow)($pdf)(ansi reset) to (ansi yellow)($working_directory)/epub(ansi reset)"
    unzip -q $pdf -d ($working_directory | path join "pdf")

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
]: path -> path {
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
export def get_image_extension []: path -> string {
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
]: path -> path {
    let epub = $in
    let opf_file = ({ parent: $working_directory, stem: $comic_vine_issue_id, extension: "opf" } | path join)
    let opf = (
        ^fetch-ebook-metadata
            --allowed-plugin "Comicvine"
            --identifier $"comicvine:($comic_vine_issue_id)"
            --opf
        | from xml
    )
    log debug $"The opf metadata for Comic Vine issue id (ansi purple_bold)($comic_vine_issue_id)(ansi reset) is:\n($opf)\n"
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
export def convert_to_lossless_jxl []: path -> path {
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
export def cbconvert [
    suffix: string = "" # Suffix to add to the CBZ filename
    --format: string # The image format to convert to
    --height: string # The height of the converted images
    --quality: string # The quality setting to use for the encoder
    --width: string # The width of the converted images
]: path -> path {
    let file = $in
    let components = ($file | path parse)
    # todo Use some sort of wrapper to print out command-line of command being run?
    # todo This doesn't work right with jpegs.
    if $height == null and $width == null {
        log debug $"Running command: cbconvert --filter 7 --format ($format) --height ($height) --outdir ($components.parent) --quality ($quality) --suffix ($suffix) --width ($width) ($file)"
        (
            ^cbconvert convert
                --filter 7 # Use the highest quality resampling filter.
                --format $format
                --outdir $components.parent
                --quality $quality
                --suffix $suffix
                $file
        )
    } else {
        log debug $"Running command: cbconvert --filter 7 --format ($format) --height ($height) --outdir ($components.parent) --quality ($quality) --suffix ($suffix) --width ($width) ($file)"
        (
            ^cbconvert convert
                --filter 7 # Use the highest quality resampling filter.
                --fit
                --format $format
                --height $height
                --outdir $components.parent
                --quality $quality
                --suffix $suffix
                --width $width
                $file
        )
    }
    $components | update stem ($components.stem + $suffix) | path join
}

# Convert a copy for my primary e-reader:
# Kobo Elipsa 2E: 1404x1872 (Gamma 1.8).
# todo I'm not sure this is even really necessary
# Using the correct resolution does seem to result in much faster page loads.
# Although, maybe that's due to using webp?
# I should verify.
export def convert_for_ereader [
    ereader: string
]: path -> path {
    let file = $in
    let suffix = ("_" + ($ereader | str replace --all " " "_" | str downcase))
    let components = ($file | path parse)
    let input_format = $components.extension

    let image_format = (
        if $input_format in ["cbz" "epub" "zip"] {
            let image_extension = ($file | get_image_extension);
            if ($image_extension == null) {
                log error "Failed to determine the image file format"
                exit 1
            }
            $image_extension
        } else {
            null
        }
    )

    # todo Use KCC for PDFs too?

    # Use KCC because it won't look right when converting jpegs with cbconvert 1.1.0.
    if $image_format in ["jpeg" "jpg"] {
        (
            let components = ($file | path parse);
            let temp = (
                {
                    parent: ($env.HOME + "/Downloads"),
                    stem: $components.stem,
                    extension: $components.extension
                }
                | path join
            );
            cp $file $temp;
            let components = ($temp | path parse);
            let kcc_output = (
                {
                    parent: $components.parent,
                    stem: ($components.stem + "_kcc0"),
                    extension: $components.extension
                }
                | path join
            );
            let output = (
                {
                    parent: $components.parent,
                    stem: ($components.stem + "_kobo_elipsa_2e"),
                    extension: $components.extension
                }
                | path join
            );
            (^flatpak run --command=kcc-c2e io.github.ciromattia.kcc --profile KoE --manga-style --forcecolor --format CBZ --output $temp --targetsize 10000 --upscale $temp);
            mv $kcc_output $output;
            rm $temp;
            $output
        )
    } else {
        (
            $file
            | cbconvert $suffix
                # Alternatively, PNG could also be used for PDFs i.e. when image_format is null.
                --format (if $image_format in [ "avif", "jxl", "png", ] { "png" } else { "jpeg" })
                --height ($ereader_profiles | where model == $ereader | first | get height)
                --quality 100
                --width ($ereader_profiles | where model == $ereader | first | get width)
        )
    }
    $components | update stem ($components.stem + $suffix) | path join
}

export def sanitize_minio_filename []: string -> string {
    $in | str replace --all "!" ""
}
