# A collection of helpful utility functions

use std log

export const ereader_profiles = [
    [model height width disk_label];
    ["Kobo Elipsa 2E" 1872 1404 "KOBOeReader"]
]

export const image_extensions = [
  avif
  bmp
  gif
  jpeg
  jpg
  jxl
  png
  svg
  tiff
  webp
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
export def optimize_images []: list<path> -> record<bytes: filesize, difference: float> {
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
    ^chmod --recursive +rw $extraction_path
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
]: path -> path {
    let epub = $in
    let cbz = ({ parent: $working_directory, stem: ($epub | path parse | get stem), extension: "cbz" } | path join)

    log debug $"Extracting contents of the EPUB (ansi yellow)($epub)(ansi reset) to (ansi yellow)($working_directory)/epub(ansi reset)"
    ^unzip -q $epub -d ($working_directory | path join "epub")

    let image_files = (glob $"($working_directory)/epub/**/*.{($image_extensions | str join ',')}")
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
    ^unzip -q $pdf -d ($working_directory | path join "pdf")

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
        } else if ($epub_title =~ '.*,*[\W_]+[vV][oO][lL]\.*\W*[0-9]+') {
            (
                $epub_title
                | parse --regex '(?P<series>.+),*[\W_]+[vV][oO][lL]\.*\W*(?P<issue>[0-9]+)'
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

# Fetch metadata for the EPUB using Comic Vine and embed it
#
# The metadata for Authors and Title from the Comic Vine Calibre plugin are corrected here.
# The title includes the issue number twice in the name, which is kind of ugly, so that is fixed.
# All creators are tagged as authors which is incorrect.
# To accommodate this, authors must be passed directly.
#
export def tag_epub_comic_vine [
    comic_vine_issue_id: string # The unique Comic Vine id for the issue
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

# Fetch metadata for an ebook
export def fetch-ebook-metadata [
    ...args: string
    # Remove Comicvine because it can cause trouble, although it does have entries for some Light Novels apparently.
    --allowed-plugins: list<string> = ["Kobo Metadata" Google "Google Images" "Amazon.com" Edelweiss "Open Library" "Big Book Search"] # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
    # --allowed-plugins: list<string> = [Google "Amazon.com"] # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
    --authors: list<string> # A list of authors to use
    --cover: path # Path to which to download the cover
    --identifiers: list<string> # A list of identifiers
    --isbn: string # The ISBN of the book
    --title: string # The title to use
]: nothing -> record<opf: record, cover: path> {
  let allowed_plugins = (
    if $allowed_plugins == null {
      null
    } else {
      $allowed_plugins | par-each {|plugin| $"--allowed-plugin=($plugin)"}
    }
  )
  let authors = (
    if $authors == null {
      null
    } else {
      $authors | str join "&" | $"--authors=($in)"
    }
  )
  let identifiers = (
    if $identifiers == null {
      null
    } else {
      $identifiers | par-each {|identifier| $"--identifier=($identifier)"}
    }
  )
  let isbn = (
    if $isbn == null {
      null
      # log error "fetch-ebook-metadata currently requires that an ISBN be provided to avoid pulling in the wrong data."
      # exit 1
    } else {
      $"--isbn=($isbn)"
    }
  )
  let title = (
    if $title == null {
      null
    } else {
      $"--title=($title)"
    }
  )
  let cover_arg = (
    if $cover == null {
      null
    } else {
      $"--cover=($cover)"
    }
  )
  let args = (
    $args
    | append "--opf"
    | append $allowed_plugins
    | append $authors
    | append $cover_arg
    | append $identifiers
    | append $isbn
    | append $title
  )
  # let result = ^fetch-ebook-metadata ...$args | complete
  # let opf = $result.stdout | from xml
  log debug $"Running: fetch-ebook-metadata ($args | str join ' ')"
  let opf = (
    let result = (^fetch-ebook-metadata ...$args);
    if ($result | is-empty) or ($result | lines --skip-empty | last) == "No results found" {
      log error $"(ansi red)No metadata found!(ansi reset)"
      exit 1
    } else {
      $result | from xml
    }
  )
  {
    opf: $opf,
    cover: (
      if $cover == null {
        null
      } else {
        $cover | rename_image_with_extension
      }
    )
  }
}

export def extract_book_metadata [
  working_directory: directory
]: path -> record<opf: record, cover: path> {
  let book = $in;
  log debug $"book: ($book)"
  let opf_file = ({ parent: $working_directory, stem: ($book | path parse | get stem), extension: "opf" } | path join)
  log debug $"opf: ($opf_file)"
  let cover_file = (
    {
      parent: $working_directory,
      stem: ([($book | path parse | get stem) "-cover"] | str join),
    } | path join
  )
  (
    ^ebook-meta
    --get-cover $cover_file
    --to-opf $opf_file
    $book
  )
  # todo Remove title == "Untitled" and creator == "Unknown"?
  { opf: ($opf_file | open | from xml), cover: ($cover_file | rename_image_with_extension) }
}

# # Use the metadata.opf and cover.ext files for metadata
# export def get_metadata_from_opf [
#   --working-directory: directory
# ]: path -> record<opf: record, cover: path> {
#   let book = $in;
#   let opf_file = ({ parent: $working_directory, stem: ($book | path parse | get stem), extension: "opf" } | path join)
#   let cover_file = ({ parent: $working_directory, stem: ($book | path parse | get stem | $"($in)-cover"), extension: "" } | path join)
#   (
#     ^ebook-meta
#     --get-cover $cover_file
#     --to-opf $opf_file
#     $book
#   )
#   # todo Remove title == "Untitled" and creator == "Unknown"?
#   { opf: ($opf_file | open | from xml), cover: ($cover_file | rename_image_with_extension) }
# }

# Rename an image with the proper extension for its file type
export def rename_image_with_extension [] : path -> path {
  let old = $in
  let components = $old | path parse
  let file_type = ^file --brief $old | split words | first | str downcase
  let new = $old | path parse | update extension $file_type | path join
  mv $old $new
  $new
}

# export def update_book_metadata [
export def fetch_book_metadata [
  working_directory: directory
  --authors: list<string>
  --identifiers: list<string>
  --isbn: string
  --title: string
]: path -> record<book: path, cover: path, opf: record> {
  let book = $in
  # todo Check for metadata.opf and cover.ext files
  # Prefer metadata.opf and cover.ext over embedded metadata and cover
  let current = (
    $book
    | extract_book_metadata $working_directory
    | (
      let input = $in;
      let metadata_opf = $book | path dirname | path join "metadata.opf";
      if ($metadata_opf | path exists) {
        $input | update opf (open $metadata_opf | from xml)
      } else {
        $input
      }
    )
    | (
      let input = $in;
      let covers = (
        ls ($book | path dirname)
        | get name
        | filter {|f|
          let components = $f | path parse
          # todo use a constant for image file extensions
          $components.stem == "cover" and $components.extension in $image_extensions
        }
      );
      if ($covers | is-empty) {
        $input
      } else if ($covers | length) > 1 {
        log error $"Found multiple files looking for the cover image file:\n($covers)\n"
        exit 1
      } else {
        if ($covers | first | path exists) {
          $input | update cover ($covers | first)
        } else {
          $input
        }
      }
    )
  )
  let all_opf_identifiers = (
      $current.opf
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "identifier"
  )
  let isbn = (
    if $isbn == null and ($all_opf_identifiers != null) {
      let all_opf_isbn = (
        $all_opf_identifiers
        | where attributes.scheme == "ISBN"
      )
      if ($all_opf_isbn | is-empty) {
        null
      } else {
        $all_opf_isbn
        | first
        | get content
        | first
        | get content
      }
    } else {
      $isbn
    }
  )
  # if $isbn == null {
  #   log error "fetch_book_metadata currently requires an ISBN to avoid pulling in the wrong data."
  #   exit 1
  # }
  let identifiers = (
    # todo Merge identifiers?
    if $isbn == null and ($all_opf_identifiers != null) {
      let all_opf_non_isbn = (
        $all_opf_identifiers
        | where attributes.scheme != "ISBN"
      )
      if ($all_opf_non_isbn | is-empty) {
        null
      } else {
        $all_opf_non_isbn
        | par-each {|identifier|
          let scheme = $identifier.attributes.scheme;
          let id = $identifier.content | get first | get content;
          { $"($scheme):($id)" }
        }
      }
    } else {
      $identifiers
    }
  )
  let identifier_flags = (
    if $identifiers == null {
      null
    } else {
      $identifiers | par-each {|identifier| $"--identifier=($identifier)" }
    }
  )
  let isbn_flag = (
    if $isbn == null {
      null
    } else {
      $"--isbn=($isbn)"
    }
  )
  let title = (
    if $title == null {
      $current.opf
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "title"
      | first
      | get content
      | first
      | get content
    } else {
      $title
    }
  )
  let title_flag = (
    if $title == null {
      null
    } else {
      $"--title=($title)"
    }
  )
  let title_flag = (
    if $title == null {
      null
    } else {
      $"--title=($title)"
    }
  )
  let authors = (
    if $authors == null {
      $current.opf
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "creator"
      | where attributes.role == "aut"
      | par-each {|creator| $creator | get content | first | get content }
      | sort
    } else {
      $authors
    }
  )
  let authors_flag = (
    if $authors == null {
      null
    } else {
      $"--authors=($authors | str join '&')"
    }
  )
  let isbn_only = false
  let args = (
    [ --opf ]
    | (
      let input = $in;
      if $isbn_only and $isbn_flag != null {
        $input | append $isbn_flag
      } else {
        $input
        | append $isbn_flag
        | append $authors_flag
        | append $title_flag
        | append $identifier_flags
      }
    )
  )
  let updated = (
    # Prefer using the current cover if there is one
    if $current.cover == null {
      (
        fetch-ebook-metadata
        --cover ({ parent: $working_directory, stem: ($book | path parse | get stem | $"($in)-fetched-cover"), extension: "" } | path join)
        # --isbn $isbn
        ...$args
      )
    } else {
      # isbn $isbn
      fetch-ebook-metadata ...$args
    }
  )
  # todo Check if cover is empty or not found?
  let cover_file = (
    if $current.cover == null {
      $updated.cover
    } else {
      $current.cover
    }
  )
  [$cover_file] | optimize_images
  { book: $book, opf: $updated.opf, cover: $cover_file }
}

# Export the book, OPF, and cover files to a directory named after the book
export def export_book_to_directory [
  working_directory: path
] : record<book: path, cover: path, opf: record> -> record<book: path, cover: path, opf: path> {
  let input = $in
  let title = (
    $input.opf
    | get content
    | where tag == "metadata"
    | first
    | get content
    | where tag == "title"
    | first
    | get content
    | first
    | get content
  )
  let target_directory = [$working_directory $title] | path join
  mkdir $target_directory
  let opf = ({ parent: $target_directory, stem: "metadata", extension: "opf" } | path join)
  (
    $input.opf
    | to xml
    | save --force $opf
  )
  let cover = ($input.cover | path parse | update parent $target_directory | update stem "cover" | path join)
  let book = ($input.book | path parse | update parent $target_directory | update stem $title | path join)
  mv $input.cover $cover
  mv $input.book $book
  { book: $book, opf: $opf, cover: $cover }
}

export def embed_book_metadata [
  working_directory: path
] : record<book: path, cover: path, opf: path> -> record<book: path, cover: path, opf: path> {
  let input = $in
  let book_format = ($input.book | path parse | get extension)
  if $book_format != "pdf" {
    ^ebook-meta $input.book --cover $input.cover --from-opf $input.opf
  }
  $input
}

# export def tag_epub [
#     # --allowed-plugins: list<string> # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
#     # --authors: list<string> # A list of authors to use
#     # --cover: path # Path to which to download the cover
#     # --identifiers: list<string> # A list of identifiers
#     # --isbn: string # The unique ComicVine id for the issue
#     # --title: string # The title to use
#     --working-directory: directory
# ]: record<epub: path, opf: record, cover: path> -> path {
#     let epub = $in
#     # let opf_file = ({ parent: $working_directory, stem: ($epub | path parse | get stem), extension: "opf" } | path join)
#     # let cover = ({ parent: $working_directory, stem: ($epub | path parse | get stem), extension: "opf" } | path join)
#     let result = fetch-ebook-metadata
#     log debug $"The fetched metadata for the book (ansi purple_bold)($epub)(ansi reset) is:\n($result.opf)\n"
#     (
#         $result.opf
#         | to xml
#         | save --force $opf_file
#     )
#     (
#         ^ebook-meta
#             $epub
#             # --authors ($authors | str join "&")
#             # --cover
#             --from-opf $"($working_directory)/($comic_vine_issue_id).opf"
#             # --title $title
#     )
#     rm $opf_file
#     # rm $cover
#     $epub
# }

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
    let input_file = $in
    let components = ($input_file | path parse)
    let original_size = (ls $input_file | first | get size)
    let file = (
        $input_file | cbconvert
            --format "jxl"
            --quality 100 # lossless

    )
    let current_size = (ls $file | first | get size)
    let average = (($original_size + $current_size) / 2)
    let percent_difference = ((($original_size - $current_size) / $average) * 100)
    let size_table = [[original current "% difference"]; [$original_size $current_size $percent_difference]]
    log info $"Converted (ansi yellow)($input_file)(ansi reset) to (ansi yellow)($file)(ansi reset) to JPEG-XL: ($size_table)"
    if $current_size > $original_size {
        log warning "JPEG-XL comic archive increased in size compared to the original input file!"
    }
    $file
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
    $components | { parent: $components.parent, stem: ($components.stem + $suffix), extension: "cbz" } | path join
}

# Convert a copy for my primary e-reader:
# Kobo Elipsa 2E: 1404x1872 (Gamma 1.8).
# todo I'm not sure this is even really necessary
# Using the correct resolution does seem to result in much faster page loads.
# Although, maybe that's due to using webp?
# I should verify.
export def convert_for_ereader [
    ereader: string
    working_directory: directory
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
                    parent: $working_directory,
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
                    stem: ($components.stem + $suffix),
                    extension: $components.extension
                }
                | path join
            );
            log debug $"Running command: flatpak run --command=kcc-c2e io.github.ciromattia.kcc --profile KoE --manga-style --forcecolor --format CBZ --output '($temp)' --targetsize 10000 --upscale '($temp)'";
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
                --format (if $image_format in [ "avif" "jxl" "png", ] { "png" } else { "jpeg" })
                --height ($ereader_profiles | where model == $ereader | first | get height)
                --quality 100
                --width ($ereader_profiles | where model == $ereader | first | get width)
        )
    }
    # The output is always a CBZ file.
    $components | update stem ($components.stem + $suffix) | update extension "cbz" | path join
}

# Apparently no sanitization needs to be done?
export def sanitize_minio_filename []: string -> string {
    # $in | str replace --all "!" ""
    $in
}
