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

# Get the number of pages in a PDF
export def pdf_page_count []: path -> int {
  let pdf = $in
  # ^pdfinfo $pdf | lines --skip-empty | parse --regex '(?P<key>\w+):\W+(?P<value>\w+.*)' | where key == "Pages" | get value
  ^mutool show $pdf trailer/Root/Pages/Count | into int
}

# Get text from a PDF
# export def pdftotext [
#   --first: int # First page to convert
#   --last: int # Last page to convert
# ]: path -> string {
#   let pdf = $in
#   ^pdftotext  -
# }

# RE_NORMAL = re.compile(
#     r'97[89]{1}-?[0-9]{10}|'
#     r'97[89]{1}-[-0-9]{13}|'
#     r'\d{9}[0-9X]{1}|'
#     r'[-0-9X]{10,16}',
#     re.I | re.M | re.S,
# )

# r'^(?:ISBN(?:-1[03])?:? )?(?=[0-9X]{10}$|'
# r'(?=(?:[0-9]+[- ]){3})'
# r'[- 0-9X]{13}$|97[89][0-9]{10}$|'
# r'(?=(?:[0-9]+[- ]){4})'
# r'[- 0-9]{17}$)(?:97[89][- ]?)?[0-9]{1,5}'
# r'[- ]?[0-9]+[- ]?[0-9]+[- ]?[0-9X]$',

# Parse ISBN from text
export def parse_isbn [
]: list<string> -> list<string> {
  let text = $in
  # ISBN 978-1-250-16947-1 (ebook)
  let obvious_isbn = (
    $text
    | parse --regex 'ISBN\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let obvious_isbn = (
    $text
    | parse --regex 'ISBN:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let isbn_numbers = (
    $text
    | parse --regex '(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($isbn_numbers | is-empty) {
    []
  } else {
    $isbn_numbers | get isbn | str replace --all "-" "" | uniq
  }
}

# Convert the first 10 and last 10 pages of a PDF file to text
export def pdf_to_text []: path -> string {
  let pdf = $in
  let pages = $pdf | pdf_page_count
  let text_file = mktemp
  if $pages <= 20 {
    # ^pdftotext $pdf -
    # todo https://bugs.ghostscript.com/show_bug.cgi?id=707651
    ^mutool convert -F text -o $text_file -O mediabox-clip=no $pdf
  } else {
    ^mutool convert -F text -o $text_file -O mediabox-clip=no $pdf $"1-10,($pages - 10)-N"
    # [(^pdftotext -l 10 $pdf -) (^pdftotext -f ($pages - 10) $pdf -)] | str join "\n"
  }
  let text = open $text_file
  rm $text_file
  $text
}

# Convert the first 10 and last 10 pages of an EPUB file to text
export def epub_to_text []: path -> string {
  let epub = $in
  let text_file = mktemp --suffix .txt
  # todo Get a smaller portion of the EPUB's pages?
  ^ebook-convert $epub $text_file
  let text = open $text_file
  rm $text_file
  $text
}

# Convert a PDF or EPUB to text
export def book_to_text []: path -> string {
  let book = $in
  let input_format = $book | path parse | get extension
  if $input_format == "epub" {
    $book | epub_to_text
  } else if $input_format == "pdf" {
    $book | pdf_to_text
  } else {
    null
  }
}

export def isbn_from_images_in_archive [
  working_directory: path
]: path -> list<string> {
  let archive = $in
  let images = $archive | list_image_files_in_archive
  # We start at the back first
  let pages = (
    $images
    | last 10
    | reverse
    | append ($images | first 10)
    | uniq
  )
  # $pages | each {|page|
  #   $page | image_to_text | parse_isbn
  # }
  for page in $pages {
    let image = $archive | extract_file_from_archive $page $working_directory
    let isbn = $image | image_to_text | lines --skip-empty | reverse | parse_isbn
    rm $image
    if ($isbn | is-not-empty) {
      return $isbn
    }
  }
  []
}

# Extract text from an image using OCR
export def image_to_text []: path -> string {
  let image = $in
  ^tesseract $image stdout
}

# todo
# export def isbn_10_to_isbn_13 []: string -> string {
#   str substring 0 11
# }

# export def extract_isbn_from_image []: path -> list<string> {
#   let image = $in
#   $image | image_to_text | lines --skip-empty | parse_isbn
# }

# Extract an ISBN from the pages of CBZ, PDF, or EPUB file
export def isbn_from_pages [
    working_directory: directory # The scratch-space directory to use
]: path -> list<string> {
  let $file = $in
  let input_format = $file | path parse | get extension
  let isbn = (
    if $input_format in ["epub" "pdf"] {
      log debug "Attempting to parse the ISBN from the book's text"
      $file | book_to_text | lines --skip-empty | reverse | parse_isbn
    } else {
      []
    }
  )
  if ($isbn | is-not-empty) {
    return $isbn
  }
  if $input_format in ["cbz" "epub" "zip"] {
    log debug "Attempting to parse the ISBN from the book's images"
    $file | isbn_from_images_in_archive $working_directory
  } else {
    []
  }
}

# Extract the issue from ComicInfo.xml metadata
#
# todo Add tests
export def issue_from_comic_info []: record -> string {
  let comic_info = $in
  let number = $comic_info | get content | where tag == "Number" | get content
  if ($number | is-empty) {
    return null
  }
  if ($number | length) > 1 {
    log warning $"Somehow found multiple Number fields in the ComicInfo.xml metadata: ($number). Ignoring Number fields."
    return null
  }
  let values = $number | first | get content | first
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple values in the Number field of the ComicInfo.xml metadata: ($values). Ignoring Number field."
    return null
  }
  $values | first
}

# Extract the issue year from ComicInfo.xml metadata
#
# todo Add tests
export def issue_year_from_comic_info []: record -> string {
  let comic_info = $in
  let year = $comic_info | get content | where tag == "Year" | get content
  if ($year | is-empty) {
    return null
  }
  if ($year | length) > 1 {
    log warning $"Somehow found multiple Year fields in the ComicInfo.xml metadata: ($year). Ignoring Year fields."
    return null
  }
  let values = $year | first | get content | first
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple years in the Year field of the ComicInfo.xml metadata: ($values). Ignoring Year field."
    return null
  }
  $values | first
}

# Extract the series year from ComicInfo.xml metadata
#
# todo Add tests
export def series_year_from_comic_info []: record -> string {
  let comic_info = $in
  let volume = $comic_info | get content | where tag == "Volume" | get content
  if ($volume | is-empty) {
    return null
  }
  if ($volume | length) > 1 {
    log warning $"Somehow found multiple Volume fields in the ComicInfo.xml metadata: ($volume). Ignoring Volume fields."
    return null
  }
  let values = $volume | first | get content | first
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple volumes in the Volume field of the ComicInfo.xml metadata: ($values). Ignoring Volume field."
    return null
  }
  $values | first
}

# Extract the series from ComicInfo.xml metadata
#
# todo Add tests
export def series_from_comic_info []: record -> string {
  let comic_info = $in
  let series = $comic_info | get content | where tag == "Series" | get content
  if ($series | is-empty) {
    return null
  }
  if ($series | length) > 1 {
    log warning $"Somehow found multiple Series fields in the ComicInfo.xml metadata: ($series). Ignoring Series fields."
    return null
  }
  let values = $series | first | get content | first
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple series in the Series field of the ComicInfo.xml metadata: ($values). Ignoring Series field."
    return null
  }
  $values | first
}

# Extract the ISBN from ComicInfo.xml metadata
#
# The GTIN field stores a value that can be an ISBN.
# todo Add tests
export def isbn_from_comic_info []: record -> string {
  let comic_info = $in
  let gtin = $comic_info | get content | where tag == GTIN
  if ($gtin | is-empty) {
    return null
  }
  let isbn_numbers = ($gtin | first | get content | first | get content) | lines --skip-empty | reverse | parse_isbn
  if ($isbn_numbers | is-empty) {
    return null
  }
  if ($isbn_numbers | length) > 1 {
    log warning $"Somehow found multiple ISBN numbers in the GTIN field of the ComicInfo.xml metadata: ($isbn_numbers). Ignoring GTIN field."
    return null
  }
  $isbn_numbers | first
}

# Inject the ISBN in ComicInfo.xml metadata
#
# The GTIN field stores a value that can be an ISBN.
# todo Add tests
export def add_isbn_to_comic_info [
  isbn: string
]: record -> record {
  let comic_info = $in
  # let gtin = $comic_info | get content | where tag == GTIN
  # if ($gtin | is-empty) {
  #   (
  #     $comic_info
  #     | (
  #       let i = $in;
  #       $i
  #       | update content (
  #         $i
  #         | get content
  #         | append {
  #           tag: GTIN
  #           attributes: {}
  #           content: [
  #             [tag attributes content];
  #             [null null $isbn]
  #           ]
  #         }
  #       )
  #     )
  #   )
  # } else {
    (
      $comic_info
      | (
        let i = $in;
        $i
        | update content (
          $i
          | get content
          | where tag != "GTIN"
          | append {
            tag: "GTIN"
            attributes: {}
            content: [
              [tag attributes content];
              [null null $isbn]
            ]
          }
        )
      )
    )
  # }
}

export def upsert_comic_info [
  field: record<tag: string, value: string>
]: record -> record {
  let comic_info = $in
  (
    $comic_info
    | (
      let i = $in;
      $i
      | update content (
        $i
        | get content
        | where tag != $field.tag
        | append {
          tag: $field.tag
          attributes: {}
          content: [
            [tag attributes content];
            [null null $field.value]
          ]
        }
      )
    )
  )
}

# Extract the title from ComicInfo.xml metadata
#
# todo Add tests
export def title_from_comic_info []: record -> string {
  let comic_info = $in
  let title = $comic_info | get content | where tag == "Title"
  if ($title | is-empty) {
    return null
  }
  let titles = $title | first | get content | first | get content
  if ($titles | is-empty) {
    return null
  }
  if ($titles | length) > 1 {
    log warning $"Somehow found multiple titles in the Title field of the ComicInfo.xml metadata: ($titles). Ignoring Title field."
    return null
  }
  $titles | first
}

# Extract the metadata from an EPUB file in the OPF format
export def opf_from_epub [
  working_directory: directory
]: path -> record {
  let epub = $in
  let opf_file = mktemp # ($epub | path parse | update  | update extension "opf" | path join)
  ^ebook-meta --to-opf $opf_file $epub
  let opf = open $opf_file | from xml
  rm $opf_file
  $opf
}

# Extract the metadata from an EPUB, CBZ, or sidecar OPF or ComicInfo.xml file
#
# The ISBN from a side-car ComicInfo.xml has the highest precedence, followed by a sidecar metadata.opf file.
# Metadata embedded in an EPUB file or a ComicInfo.xml embedded in a CBZ or ZIP archive have the lowest precedence.
# The sidecar metadata.opf and ComicInfo.xml files are assumed to reside in the same directory as the target file.
#
export def get_metadata [
  working_directory: directory # The scratch-space directory to use
]: path -> record {
  let file = $in
  let metadata = {}
  let metadata = (
    let comic_info_file = [($file | path dirname) "ComicInfo.xml"] | path join;
    if ($comic_info_file | path exists) {
      let comic_info = open $comic_info_file
      if $comic_info == null {
        $metadata
      } else {
        $metadata | insert comic_info $comic_info
      }
    } else {
      $metadata
    }
  )

  let metadata = (
    let metadata_opf_file = [($file | path dirname) "metadata.opf"] | path join;
    if ($metadata_opf_file | path exists) {
      let opf = open $metadata_opf_file | from xml
      if $opf == null {
        $metadata
      } else {
        $metadata | insert opf $opf
      }
    } else {
      $metadata
    }
  )

  let input_format = $file | path parse | get extension
  let metadata = (
    if $input_format == "epub" {
      let opf = $file | opf_from_epub $working_directory
      if $opf == null {
        $metadata
      } else {
        $metadata | upsert opf (
          if "opf" in $metadata {
            $metadata | get opf | merge $opf
          } else {
            $opf
          }
        )
      }
    } else if $input_format in ["cbz" "zip"] {
      let comic_info = $file | extract_comic_info_xml $working_directory
      if $comic_info == null {
        $metadata
      } else {
        $metadata | upsert comic_info (
          if "comic_info" in $metadata {
            $metadata | get comic_info | merge $comic_info
          } else {
            $comic_info
          }
        )
      }
    } else {
      $metadata
    }
  )

  $metadata
}

# Extract the ISBN from OPF metadata
#
# todo Add tests
export def isbn_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring metadata."
    return null
  }
  let isbn = $metadata | first | where tag == "identifier" | where attributes.scheme == "ISBN"
  if ($isbn | is-empty) {
    return null
  }
  if ($isbn | length) > 1 {
    log warning $"Somehow found multiple ISBN numbers in the OPF metadata: ($metadata). Ignoring ISBN numbers."
    return null
  }
  let isbn_values = $isbn | first | get content | get content
  if ($isbn_values | is-empty) {
    return null
  }
  if ($isbn_values | length) > 1 {
    log warning $"Somehow found multiple ISBN values in the OPF metadata: ($metadata). Ignoring ISBN numbers."
    return null
  }
  let isbn_numbers = ($isbn_values | first) | lines --skip-empty | reverse | parse_isbn
  if ($isbn_numbers | is-empty) {
    return null
  }
  if ($isbn_numbers | length) > 1 {
    log warning $"Somehow parsed multiple ISBN numbers from the ISBN field of the OPF metadata: ($isbn_numbers). Ignoring ISBN numbers."
    return null
  }
  $isbn_numbers | first
}

# Extract the issue from OPF metadata
#
# todo Add tests
export def issue_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring."
    return null
  }
  let series_index = $metadata | first | get content | where tag == "meta" | where attributes.name == "calibre:series_index" | get attributes | get content
  if ($series_index | is-empty) {
    return null
  }
  if ($series_index | length) > 1 {
    log warning $"Somehow found multiple calibre:series_index field of the OPF metadata: ($series_index). Ignoring."
    return null
  }
  $series_index | first
}

# Extract the issue year from OPF metadata
#
# todo Add tests
export def issue_year_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring metadata."
    return null
  }
  let date = $metadata | first | get content | where tag == "date"
  if ($date | is-empty) {
    return null
  }
  if ($date | length) > 1 {
    log warning $"Somehow found multiple date fields in the OPF metadata: ($date). Ignoring."
    return null
  }
  let values = $date | first | get content | get content
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple values for the date field of the OPF metadata: ($values). Ignoring title field."
    return null
  }
  $values | first | into datetime | format date "%Y"
}

# Extract the series from OPF metadata
#
# todo Add tests
export def series_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring."
    return null
  }
  let series = $metadata | first | get content | where tag == "meta" | where attributes.name == "calibre:series" | get attributes | get content
  if ($series | is-empty) {
    return null
  }
  if ($series | length) > 1 {
    log warning $"Somehow found multiple calibre:series fields of the OPF metadata: ($series). Ignoring."
    return null
  }
  $series | first
}

# Extract the series year from OPF metadata
#
# I don't know how this is actually stored in OPF metadata if it is at all.
# todo Add tests
#
# export def series_year_from_opf []: record -> string {
#   ""
# }

# Extract the title from OPF metadata
#
# todo Add tests
export def title_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring metadata."
    return null
  }
  let title = $metadata | first | get content | where tag == "title"
  if ($title | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple title fields of the OPF metadata: ($title). Ignoring metadata."
    return null
  }
  let titles = $title | first | get content | get content
  if ($titles | is-empty) {
    return null
  }
  if ($titles | length) > 1 {
    log warning $"Somehow found multiple Titles field of the OPF metadata: ($titles). Ignoring title field."
    return null
  }
  $titles | first
}

# Extract the ISBN from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def isbn_from_metadata [
  working_directory: directory # The scratch-space directory to use
]: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let isbn = (
    if "comic_info" in $metadata {
      $metadata.comic_info | isbn_from_comic_info
    } else {
      null
    }
  )

  if $isbn == null {
    if "opf" in $metadata {
      $metadata.opf | isbn_from_opf
    } else {
      null
    }
  } else {
    $isbn
  }
}

# Extract the issue from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def issue_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let issue = (
    if "comic_info" in $metadata {
      $metadata.comic_info | issue_from_comic_info
    } else {
      null
    }
  )

  if $issue == null {
    if "opf" in $metadata {
      $metadata.opf | issue_from_opf
    } else {
      null
    }
  } else {
    $issue
  }
}

# Extract the issue year from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def issue_year_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let issue_year = (
    if "comic_info" in $metadata {
      $metadata.comic_info | issue_year_from_comic_info
    } else {
      null
    }
  )

  if $issue_year == null {
    if "opf" in $metadata {
      $metadata.opf | issue_year_from_opf
    } else {
      null
    }
  } else {
    $issue_year
  }
}

# Extract the series from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def series_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let series = (
    if "comic_info" in $metadata {
      $metadata.comic_info | series_from_comic_info
    } else {
      null
    }
  )

  if $series == null {
    if "opf" in $metadata {
      $metadata.opf | series_from_opf
    } else {
      null
    }
  } else {
    $series
  }
}

# Extract the series year from Comic Info and/or OPF metadata
#
# Don't know how to get the series year from OPF metadata, so the year can only be retrieved from Comic Info.
#
# todo Add tests.
#
export def series_year_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }
  let series_year = (
    if "comic_info" in $metadata {
      $metadata.comic_info | series_year_from_comic_info
    } else {
      null
    }
  )
}

# Extract the title from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def title_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let title = (
    if "comic_info" in $metadata {
      $metadata.comic_info | title_from_comic_info
    } else {
      null
    }
  )

  if $title == null {
    if "opf" in $metadata {
      $metadata.opf | title_from_opf
    } else {
      null
    }
  } else {
    $title
  }
}

# Extract a file from a zip archive
export def extract_file_from_archive [
    file: path
    working_directory: directory # The scratch-space directory to use
]: path -> path {
    let archive = $in
    ^unzip $archive $file -d $working_directory
    [$working_directory $file] | path join
}

# Extract the ComicInfo.xml file from an archive
export def extract_comic_info_xml [
    working_directory: directory # The scratch-space directory to use
]: path -> record {
    let archive = $in
    if not ($archive | has_comic_info) {
      return null
    }
    let comic_info_file = $archive | extract_file_from_archive "ComicInfo.xml" $working_directory
    let comic_info = $comic_info_file | open
    rm $comic_info_file
    $comic_info
}

# Extract the ComicInfo.xml file from an archive
export def extract_comic_info [
    working_directory: directory # The scratch-space directory to use
]: path -> path {
    let archive = $in
    ^unzip $archive "ComicInfo.xml" -d $working_directory
    [$working_directory "ComicInfo.xml"] | path join
}

export def has_comic_info []: [
    path -> bool
] {
  let archive = $in
  (
    $archive
    | list_files_in_archive
    | path basename
    | any {|name| $name == "ComicInfo.xml"}
  )
}

# Inject ComicInfo data into a zip archive
#
# Takes a record containing the archive and ComicInfo.xml file
export def inject_comic_info []: [
  record<archive: path, comic_info: record> -> path
] {
    let input = $in
    if ($input.archive | has_comic_info) {
        ^zip --delete $input.archive "ComicInfo.xml"
    }
    let temporary_directory = mktemp --directory
    let target = [$temporary_directory "ComicInfo.xml"] | path join
    $input.comic_info | to xml | save $target
    ^zip --junk-paths $input.archive $target
    rm $target
    rm $temporary_directory
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
                | parse --regex 'Total:\s+(?P<difference>.+)%\s+(?P<bytes>.+)'
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
            --subset-fonts
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

# Parse metadata from a comic file name
#
# <series> (<series_year>) #<issue> (<issue_year>)
export def metadata_from_comic_filename []: path -> record {
  let file = $in
  let stem = $file | path parse | get stem
  let metadata = (
    $stem
    | parse --regex '(?P<series>.+?)\s+(?:\((?P<series_year>[0-9]+)\)\s+){0,1}#(?P<issue>[0-9]+)(?:\s+\((?P<issue_year>[0-9]+)\)){0,1}'
  )
  if ($metadata | is-empty) {
    null
  } else {
    $metadata | first
  }
}

# Incorporate metadata for ComicTagger in the filename.
export def comic_file_name_from_metadata [
    working_directory: directory
    --issue: string
    --issue-year: string
    --series: string
    --series-year: string
]: path -> path {
    let file = $in
    let metadata = $file | get_metadata $working_directory
    let title = $metadata | title_from_metadata
    if $title != null {
      log debug $"Title from metadata: ($title)"
    }
    let series = (
      if $series == null {
        $metadata | series_from_metadata
      } else {
        $series
      }
    )
    let series_year = (
      if $series_year == null {
        $metadata | series_year_from_metadata
      } else {
        $series_year
      }
    )
    let issue = (
      if $issue == null {
        $metadata | issue_from_metadata
      } else {
        $issue
      }
    )
    let issue_year = (
      if $issue_year == null {
        $metadata | issue_year_from_metadata
      } else {
        $issue_year
      }
    )

    let filename_metadata = $file | metadata_from_comic_filename
    let series = (
      if $series == null {
        if $filename_metadata == null {
          null
        } else {
          $filename_metadata | get series
        }
      } else {
        $series
      }
    )
    let series_year = (
      if $series_year == null {
        if $filename_metadata == null {
          null
        } else {
          $filename_metadata | get series_year
        }
      } else {
        $series_year
      }
    )
    let issue = (
      if $issue == null {
        if $filename_metadata == null {
          null
        } else {
          $filename_metadata | get issue
        }
      } else {
        $issue
      }
    )
    let issue_year = (
      if $issue_year == null {
        if $filename_metadata == null {
          null
        } else {
          $filename_metadata | get issue_year
        }
      } else {
        $issue_year
      }
    )

    let parsed_title = (
      if $title == null {
        null
      } else {
        if ($title | str contains "Volume") {
            (
                $title
                | parse --regex '(?P<series>.+) Volume (?P<issue>[0-9]+)'
                | first
            )
        } else if ($title =~ '.*,*[\s_]+[vV][oO][lL]\.*\s*[0-9]+') {
            (
                $title
                | parse --regex '(?P<series>.+),*[\s_]+[vV][oO][lL]\.*\s*(?P<issue>[0-9]+)'
                | first
            )
        } else if $title =~ ".+ [0-9]+" {
            $title
            | parse --regex '(?P<series>.+) (?P<issue>[0-9]+)'
            | first
        } else {
            { series: $title, issue: 1 }
        }
      }
    )
    if $parsed_title != null {
      log debug $"Parsed the title as (ansi purple)($parsed_title)(ansi reset)"
    }

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
        log error $"Unable to determine the series and issue from the metadata title '($title)'. Pass the Comic Vine issue id with the (ansi green)--comic-vine-issue-id(ansi reset) flag."
        $file
    } else {
        $file | path parse | update stem $"($series) \(($series_year)\) #($issue) \(($issue_year)\)" | path join
    }
}

# List the files in a zip archive
export def list_files_in_archive []: path -> list<path> {
    let archive = $in
    (
      ^unzip -l $archive
      | lines
      | drop nth 0 1
      | drop 2
      | str trim
      | parse "{length}  {date} {time}   {name}"
      | get name
      | uniq
      | sort
    )
}

# List the image files in a zip archive
export def list_image_files_in_archive []: path -> list<path> {
    let archive = $in
    (
      $archive
        | list_files_in_archive
        | path parse
        | where extension in $image_extensions
        | path join
    )
}

# Get the image extension used in a comic book archive
export def get_image_extension []: path -> string {
    let cbz = $in
    let file_extensions = (
        $cbz
        | list_image_files_in_archive
        | path parse
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
    --allowed-plugins: list<string> = ["Kobo Metadata" Goodreads Google "Google Images" "Amazon.com" Edelweiss "Open Library" "Big Book Search"] # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
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
  let args = (
    [ --opf ]
    | (
      let input = $in;
      $input
      | append $isbn_flag
      | append $authors_flag
      | append $title_flag
      | append $identifier_flags
    )
  )
  let updated = (
    # Prefer using the current cover if there is one
    # todo I should probably prefer the highest resolution cover if it is similar to the current one.
    if $current.cover == null {
      (
        fetch-ebook-metadata
        --cover (
          {
            parent: $working_directory
            stem: ($book | path parse | get stem | $"($in)-fetched-cover")
            extension: ""
          } | path join
        )
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
  {
    book: $book
    opf: $updated.opf
    cover: $cover_file
  }
}

# Export the book, OPF, and cover files to a directory named after the book
export def export_book_to_directory [
  working_directory: path
]: [
  record<book: path, cover: path, opf: record>
  ->
  record<book: path, cover: path, opf: path>
] {
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
  {
    book: $book
    opf: $opf
    cover: $cover
  }
}

# todo Pass around opf as metadata instead of a file path.
export def embed_book_metadata [
  working_directory: path
]: [
  record<book: path, cover: path, opf: path> -> record<book: path, cover: path, opf: path>
] {
  let input = $in
  let book_format = ($input.book | path parse | get extension)
  if $book_format == "epub" {
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
