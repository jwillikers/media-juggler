# A collection of helpful utility functions

use std log

export const media_juggler_version = "0.0.1"

export const user_agent = $"MediaJuggler/($media_juggler_version) \( https://github.com/jwillikers/media-juggler \)"

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

# todo Use a confidence rating for all ISBN results and use that to determine the most likely candidates?
# Parse ISBN from text
export def parse_isbn [
]: list<string> -> list<string> {
  let text = $in

  # todo Fix this so that ISBN's occurring after the first one on this line are still eligible?
  # Avoid the ISBN preview in Tor books like this:
  # A Tor Hardcover ISBN    978-0-3128-51408
  let text = (
    $text | filter {
      |l| not ($l | str contains "A Tor Hardcover ISBN")
    }
  )

  # ISBN 978-1-250-16947-1 (ebook)
  # 978-1-250-16947-1 (ebook)
  # eISBN 978-1-6374-1067-7
  # eISBN
  # ISBN: 978-1-250-16947-1

  # ISBN-13: 978-1-7185-0186-7 (ebook)
  let obvious_isbn = (
    $text
    | parse --regex 'ISBN-13:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # ebook ISBN: xxx
  let obvious_isbn = (
    $text
    | parse --regex 'ebook ISBN:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # ISBN xxx (ebook)
  let obvious_isbn = (
    $text
    | parse --regex 'ISBN\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let obvious_isbn = (
    $text
    | parse --regex '(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # eISBN 978-1-6374-1067-7
  let obvious_isbn = (
    $text
    | parse --regex 'eISBN\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
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
  let values = $number | first | get content
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
  let values = $year | first | get content
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
  let values = $volume | first | get content
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
  let values = $series | first | get content
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
  let tags = $comic_info | get content | where tag == "Title"
  if ($tags | is-empty) {
    return null
  }
  let titles = $tags | first | get content | get content
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
  let metadata = $opf | get content | where tag == "metadata" | get content
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

# Extract the issue datetime from OPF metadata
#
# todo Add tests
export def issue_datetime_from_opf []: record -> string {
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
  $values | first | into datetime
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
      let exact = $metadata.opf | issue_datetime_from_opf
      # For some reason, this appears to be a placeholder and should be ignored
      if $exact == ("2013-03-04T11:00:00+00:00" | into datetime) {
        null
      } else {
        $exact | format date "%Y"
      }
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

    let image_files = (glob --no-dir --no-symlink $"($working_directory)/epub/**/*.{($image_extensions | str join ',')}") | sort | path parse
    if ($image_files | is-empty) {
      log error $"No images found under the directory (ansi yellow)($working_directory)/epub/(ansi reset)"
      return null
    }

    let covers = $image_files | where stem =~ 'cover'
    let pages = $image_files | where stem !~ 'cover'
    let pages = $covers | append $pages

    let number_of_digits = (($pages | length) - 1) | into string | str length

    let image_subdirectory = (mktemp --directory)
    log debug $"Organizing images for the CBZ file in the directory (ansi yellow)($image_subdirectory)(ansi reset)"

    # Rename everything for consistency.
    let pages = (
      $pages | enumerate | each {|p|
        let old_page = $p.item | path join
        let new_page = {
          parent: $image_subdirectory
          stem: (
            "page_" + ($p.index | fill --alignment r --character '0' --width $number_of_digits)
          )
          extension: $p.item.extension
        } | path join
        mv --no-clobber $old_page $new_page
        $new_page
      }
    )
    log debug $"Pages (ansi yellow)($pages)(ansi reset)"
    log debug $"Compressing the contents of the directory (ansi yellow)($image_subdirectory)(ansi reset) into the CBZ file (ansi yellow)($cbz)(ansi reset)"
    log debug $"Running command: ^zip -jqr ($cbz) ($image_subdirectory)"
    ^zip -jqr $cbz $image_subdirectory
    rm --force --recursive ($working_directory | path join "epub")
    rm --force --recursive $image_subdirectory
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
        } else if ($title =~ '.*[\s,_]+[vV][oO][lL]\.*\s*[0-9]+') {
            (
                $title
                | parse --regex '(?P<series>.+?)[\s,_]+[vV][oO][lL]\.*\s*(?P<issue>[0-9]+)'
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
    let result = (^fetch-ebook-metadata ...$args | complete);
    if $result.exit_code == 0 {
      $result.stdout | from xml
    } else if ($result.stderr | lines --skip-empty | last) == "No results found" {
      log debug $"(ansi red)No metadata found!(ansi reset)"
      null
    } else {
      log error $"fetch-ebook-metadata failed with the exit code (ansi red)($result.exit_code)(ansi reset): ($result.stderr)"
      null
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
  let book = $in
  log debug $"book: ($book)"
  let opf_file = mktemp --suffix ".xml"
  # let opf_file = (
  #   {
  #     parent: $working_directory
  #     # stem: ($book | path parse | get stem)
  #     # stem: "metadata"
  #     extension: "opf"
  #   } | path join
  # )
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
  let opf = $opf_file | open
  rm $opf_file
  {
    opf: $opf
    cover: ($cover_file | rename_image_with_extension)
  }
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
  --allowed-plugins: list<string>
  --authors: list<string>
  --identifiers: list<string>
  --isbn: string
  --title: string
]: path -> record<book: path, cover: path, opf: record> {
  let book = $in
  # todo Check for metadata.opf and cover.ext files
  # todo Use ComicInfo.xml as well here?
  # Prefer metadata.opf and cover.ext over embedded metadata and cover
  let current = (
    $book
    | extract_book_metadata $working_directory
    | (
      let input = $in;
      let metadata_opf = $book | path dirname | path join "metadata.opf";
      if ($metadata_opf | path exists) {
        $input | update opf (
          $input | merge (open $metadata_opf | from xml)
        )
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
    # [ --opf ]
    []
    | (
      let input = $in;
      $input
      | append $isbn_flag
      | append $authors_flag
      | append $title_flag
      | append $identifier_flags
      # | append (
      #   if $isbn == null {
      #     $authors_flag
      #   }
      # )
      # | append (
      #   if $isbn == null {
      #     $title_flag
      #   }
      # )
      # | append (
      #   if $isbn == null {
      #     $identifier_flags
      #   }
      # )
    )
  )
  let updated = (
    # Prefer using the current cover if there is one
    # todo I should probably prefer the highest resolution cover if it is similar to the current one.
    if $current.cover == null {
      (
        fetch-ebook-metadata
        --allowed-plugins $allowed_plugins
        --cover (
          {
            parent: $working_directory
            stem: ($book | path parse | get stem | $"($in)-fetched-cover")
            extension: ""
          } | path join
        )
        ...$args
      )
    } else {
      fetch-ebook-metadata --allowed-plugins $allowed_plugins ...$args
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
  # todo Handle missing title?
  let sanitized_title_for_filename = $title | str replace --all "/" "-"
  let target_directory = [$working_directory $sanitized_title_for_filename] | path join
  mkdir $target_directory
  let opf = (
    {
      parent: $target_directory
      stem: "metadata"
      extension: "opf"
    } | path join
  )
  (
    $input.opf
    | to xml
    | save --force $opf
  )
  let cover = (
    $input.cover
    | path parse
    | update parent $target_directory
    | update stem "cover"
    | path join
  )
  let book = (
    $input.book
    | path parse
    | update parent $target_directory
    | update stem $sanitized_title_for_filename
    | path join
  )
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

# Parse series from the group metadata tag
#
# audiobookshelf stores series in a semicolon-separated list in the group field
# The index in the series is preceded by a hash sign.
export def parse_series_from_group []: string -> table<name: string, index: string> {
  $in | split row ";" | str trim | each {|series|
    if "#" in $series {
      $series | parse '{name} #{index}'
    } else {
      [[name index]; [$series null]]
    }
  } | flatten
}

# Parse series from the series / series-part and mvnm / mvin tags from the additionalFields metadata
export def parse_series_from_series_tags []: record -> table<name: string, index: string> {
  let additionalFields = $in
  if "mvnm" in $additionalFields and $additionalFields.mvnm != null {
    [
      [name index];
      [
        ($additionalFields.mvnm | into string)
        (if "mvin" in $additionalFields and $additionalFields.mvin != null {$additionalFields.mvin | into string})
      ]
    ]
  } | append (
    if "series" in $additionalFields and $additionalFields.series != null {
      [
        [name index];
        [
          ($additionalFields.series | into string)
          (if "series-part" in $additionalFields and $additionalFields.series-part != null {$additionalFields.series-part | into string})
        ]
      ]
    }
  ) | (let i = $in; if ($i | is-empty) {null} else {$i})
}

# Upsert a value in the input record if a value is present for the given column in the source record
#
# The source column may be omitted when it has the same name as the destination column.
export def upsert_if_present [
  destination_column: string
  source: record
  source_column: string = ""
]: record -> record {
  let source_column = (
    if $source_column == null or ($source_column | is-empty) {
      $destination_column
    } else {
      $source_column
    }
  )
  $in | (
    let input = $in;
    if $source_column in $source and (($source | get $source_column) != null) {
      $input | upsert $destination_column ($source | get $source_column)
    } else {
      $input
    }
  )
}

# Upsert a value in the input record if the value is not null or empty
export def upsert_if_value [
  destination_column: string
  value: any
]: record -> record {
  $in | (
    let input = $in;
    if ($value | is-empty) {
      $input
    } else {
      $input | upsert $destination_column $value
    }
  )
}

# Parse audiobook metadata from tone for a single file into a standard format
#
# todo Parse using a generic schema?
export def parse_audiobook_metadata_from_tone []: record -> record {
  let all_metadata = $in
  let metadata = $all_metadata | get meta
  let narrators = (
    ["composer" "narrator"] | par-each {|type|
      if $type in $metadata {
        $metadata | get $type | split row "," | str trim
      }
    } | flatten | uniq
  )
  let series = (
    let group_series = (
      if "group" in $metadata {
        $metadata.group | parse_series_from_group
      }
    );
    let series = (
      if "additionalFields" in $metadata {
        $metadata.additionalFields | parse_series_from_series_tags
      }
    );
    # The first series should be considered the primary series
    [] | append $series | append $group_series | uniq
  )
  let genres = (
    if "genre" in $metadata {
      $metadata.genre | split row ";" | str trim
    }
  )
  let tags = (
    if "additionalFields" in $metadata and "tags" in $metadata.additionalFields {
      $metadata.additionalFields.tags | split row ";" | str trim
    }
  )
  let publication_date = (
    if "recordingDate" in $metadata {
      $metadata.recordingDate | into datetime
    } else if "additionalFields" in $metadata and "originaldate" in $metadata.additionalFields {
      $metadata.additionalFields.originaldate | into datetime
    } else if "additionalFields" in $metadata and "originalyear" in $metadata.additionalFields {
      ($metadata.additionalFields.originalyear + "-01-01") | into datetime
    }
  )
  let writers = (
    if "additionalFields" in $metadata and "writer" in $metadata.additionalFields {
      $metadata.additionalFields.writer | split row ";" | str trim
    }
  )
  let publishers = (
    # MusicBrainz may have multiple set
    let publishers = (
      if "additionalFields" in $metadata and publisher in $metadata.additionalFields {
        $metadata.additionalFields.publisher | split row ";" | str trim
      }
    );
    let labels = (
      if "additionalFields" in $metadata and label in $metadata.additionalFields {
        $metadata.additionalFields.label | split row ";" | str trim
      }
    );
    # audiobookshelf stores the publisher in the copyright field.
    # I don't think there can be multiple here.
    let copyright = (
      if copyright in $metadata {
        $metadata.copyright
      }
    );
    [] | append $publishers | append $labels | append $copyright | uniq
  )
  # let publication_date = (
  #     let date = $metadata.recordingDate | into datetime;
  #     let month = $date | format date '%m' | into int;
  #     let day = $date | format date '%d' | into int;
  #     if $month == 1 and $day == 1 {
  #     }
  # )

  let musicbrainz_album_types = (
    if "additionalFields" in $metadata and "musicBrainz Album Type" in $metadata.additionalFields {
      $metadata.additionalFields."musicBrainz Album Type" | split row ";" | str trim
    }
  )
  let musicbrainz_album_artist_ids = (
    if "additionalFields" in $metadata and "musicBrainz Album Artist Id" in $metadata.additionalFields {
      $metadata.additionalFields."musicBrainz Album Artist Id" | split row ";" | str trim
    }
  )
  let musicbrainz_track_artist_ids = (
    if "additionalFields" in $metadata and "musicBrainz Artist Id" in $metadata.additionalFields {
      $metadata.additionalFields."musicBrainz Artist Id" | split row ";" | str trim
    }
  )
  let producers = (
    if "additionalFields" in $metadata and "producer" in $metadata.additionalFields {
      $metadata.additionalFields.producer | split row ";" | str trim
    }
  )
  let engineers = (
    if "additionalFields" in $metadata and "engineer" in $metadata.additionalFields {
      $metadata.additionalFields.engineer | split row ";" | str trim
    }
  )
  let performers = (
    if "additionalFields" in $metadata and "performer" in $metadata.additionalFields {
      $metadata.additionalFields.performer | split row ";" | str trim
    }
  )
  let musicbrainz_work_ids = (
    if "additionalFields" in $metadata and "musicBrainz Work Id" in $metadata.additionalFields {
      $metadata.additionalFields."musicBrainz Work Id" | split row ";" | str trim
    }
  )

  let duration = (
    $all_metadata | get audio.duration | into int | into duration --unit ms
  )

  # todo Is it worth parsing additionalFields artists field?

  let book = (
    {}
    | upsert_if_present title $metadata album
    | upsert_if_present subtitle $metadata
    | upsert_if_present artist_credit $metadata albumArtist
    | upsert_if_present artist_credit_sort $metadata sortAlbumArtist
    | upsert_if_present comment $metadata
    | upsert_if_present language $metadata lang
    | upsert_if_present language $metadata
    | upsert_if_present isbn $metadata
    | upsert_if_present amazon_asin $metadata asin
    | upsert_if_present audible_asin $metadata
    | upsert_if_value publishers $publishers
    | upsert_if_value publication_date $publication_date
    | upsert_if_value series $series
    | upsert_if_value genres $genres
    | upsert_if_value musicbrainz_release_types $musicbrainz_album_types
    | upsert_if_value musicbrainz_artist_ids $musicbrainz_album_artist_ids
    | (
      let input = $in;
      if additionalFields in $metadata {
        $input
        | upsert_if_present media $metadata.additionalFields
        | upsert_if_present script $metadata.additionalFields
        | upsert_if_present barcode $metadata.additionalFields
        | upsert_if_present musicbrainz_release_group_id $metadata.additionalFields "musicBrainz Release Group Id"
        | upsert_if_present musicbrainz_release_id $metadata.additionalFields "musicBrainz Album Id"
        | upsert_if_present musicbrainz_release_country $metadata.additionalFields "musicBrainz Album Release Country"
        | upsert_if_present musicbrainz_release_status $metadata.additionalFields "musicBrainz Album Status"
        | upsert_if_value tags $tags
      } else {
        $input
      }
    )
    | (
      let input = $in;
      if chapters in $metadata and ($metadata.chapters | is-not-empty) {
        $input | upsert chapters ($metadata.chapters | sort-by start)
      } else {
        $input
      }
    )
  );
  let track = (
    {
      # The path of the track on the filesystem is used internally
      file: $all_metadata.file
      duration: $duration
    }
    | upsert_if_present title $metadata
    | upsert_if_present artist_credit $metadata artist
    | upsert_if_present artist_credit_sort $metadata sortArtist
    | upsert_if_present index $metadata trackNumber
    | upsert_if_present embedded_pictures $metadata embeddedPictures
    | upsert_if_value musicbrainz_work_ids $musicbrainz_work_ids
    | upsert_if_value musicbrainz_artist_ids $musicbrainz_track_artist_ids
    | upsert_if_value writers $writers
    | upsert_if_value narrators $narrators
    | upsert_if_value producers $producers
    | upsert_if_value engineers $engineers
    | upsert_if_value performers $performers
    | (
      let input = $in;
      if additionalFields in $metadata {
        $input
        | upsert_if_present acoustid_fingerprint $metadata.additionalFields "acoustid Fingerprint"
        | upsert_if_present acoustid_track_id $metadata.additionalFields "acoustid Id"
        | upsert_if_present musicbrainz_recording_id $metadata.additionalFields "musicBrainz Track Id"
        | upsert_if_present musicbrainz_track_id $metadata.additionalFields "musicBrainz Release Track Id"
      } else {
        $input
      }
    )
  );
  {
      book: $book
      track: $track
  }
}

# Get metadata from a file with tone
export def tone_dump []: path -> record {
  let file = $in | path expand
  let result = do {^tone dump --format json $file} | complete
  if $result.exit_code != 0 {
    log info $"Error running '^tone dump --format json ($file)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  $result.stdout | from json
}

# Parse audiobook metadata for a single file into a standard format
export def parse_audiobook_metadata_from_file []: path -> record {
  let file = $in | path expand
  let tone_output = $file | tone_dump
  if ($tone_output | is-empty) {
    return null
  }
  $tone_output | upsert file $file | parse_audiobook_metadata_from_tone
}

# Parse audiobook metadata from a list of individual tracks' metadata
export def parse_audiobook_metadata_from_tracks_metadata []: list<record> -> record {
  let metadata = $in | sort-by track.index
  # The book metadata should match across all tracks.
  # Narrators and writers for each track need to be combined to produce the narrators and writers for the book.
  let book = $metadata | get book | reduce {|it, acc|
    # todo Log a warning here if the book data doesn't match?
    # Or, just use the item with the most occurrences?
    $acc | merge $it
  }
  # tracks are just the separate tracks brought together
  let tracks = $metadata | get track # | sort-by index
  let cumulative_tracks_metadata = (
    $tracks | reduce --fold {narrators: [], writers: [], embedded_pictures: []} {|it, acc|
      let embedded_pictures = (
        if "embedded_pictures" in $it {
          $acc.embedded_pictures | append $it.embedded_pictures | uniq
        } else {
          $acc.embedded_pictures
        }
      );
      let narrators = (
        if "narrators" in $it {
          $acc.narrators | append $it.narrators | uniq
        } else {
          $acc.narrators
        }
      );
      let writers = (
        if "writers" in $it {
          $acc.writers | append $it.writers | uniq
        } else {
          $acc.writers
        }
      );
      {
        narrators: $narrators
        writers: $writers
        embedded_pictures: $embedded_pictures
      }
    }
  )

  let book = (
    $book
    | upsert_if_value narrators $cumulative_tracks_metadata.narrators
    | upsert_if_value writers $cumulative_tracks_metadata.writers
    | upsert_if_value embedded_pictures $cumulative_tracks_metadata.embedded_pictures
  )
  {
      book: $book
      tracks: $tracks
  }
}

# Parse audiobook metadata from a list of audio files correlating to the tracks of the audiobook
export def parse_audiobook_metadata_from_files []: list<path> -> record {
    let files = $in
    let metadata = $files | par-each {|file|
        $file | parse_audiobook_metadata_from_file
    }
    $metadata | parse_audiobook_metadata_from_tracks_metadata
}

# Convert the series table to a value suitable for the group tag
export def convert_series_for_group_tag []: table<name: string, index: string> -> string {
  let series = $in
  $series | each {|s|
    if index in $s and ($s.index | is-not-empty) {
      $s.name + " #" + $s.index
    } else {
      $s.name
    }
  } | str join ";"
}

# Convert the internal audiobook metadata representation of a track into the format required for tone
#
# The input metadata should be for an individual track, with a book and track record at the top level.
# The returned record contains a file key for the path of the file on disk and a metadata key for the metadata for tone.
#
# audiobookshelf and Picard use a semicolon followed by a space to separate multiple values, I think.
# Technically, I think ID3v2.4 is supposed to use a null byte, but tone doesn't seem to support that.
export def into_tone_format []: record -> record {
  let metadata = $in
  let group = (
    if series in $metadata.book and $metadata.book.series != null {
      $metadata.book.series | convert_series_for_group_tag
    }
  )
  let publication_date = (
    if publication_date in $metadata.book and ($metadata.book.publication_date | is-not-empty) {
      $metadata.book.publication_date | format date '%+'
    }
  )
  let additionalFields = (
    {}
    # book metadata
    | upsert_if_value tags ($metadata.book | get --ignore-errors tags | str join ";")
    | upsert_if_value "musicBrainz Album Type" ($metadata.book | get --ignore-errors musicbrainz_release_types | str join ";")
    | upsert_if_value "musicBrainz Album Artist Id" ($metadata.book | get --ignore-errors musicbrainz_artist_ids | str join ";")
    | upsert_if_present "musicBrainz Release Group Id" $metadata.book musicbrainz_release_group_id
    | upsert_if_present "musicBrainz Album Id" $metadata.book musicbrainz_release_id
    | upsert_if_present "musicBrainz Album Release Country" $metadata.book musicbrainz_release_country
    | upsert_if_present "musicBrainz Album Status" $metadata.book musicbrainz_release_status
    | upsert_if_present script $metadata.book
    | upsert_if_present media $metadata.book
    | upsert_if_present chapters $metadata.book
    # track metadata
    | upsert_if_present "AcoustID Fingerprint" $metadata.track acoustid_fingerprint
    | upsert_if_present "AcoustID Id" $metadata.track acoustid_track_id
    | upsert_if_present "musicBrainz Track Id" $metadata.track musicbrainz_recording_id
    | upsert_if_present "musicBrainz Release Track Id" $metadata.track musicbrainz_track_id
    | upsert_if_value "musicBrainz Artist Id" ($metadata.track | get --ignore-errors musicbrainz_artist_ids | str join ";")
    | upsert_if_value "musicBrainz Work Id" ($metadata.track | get --ignore-errors musicbrainz_work_ids | str join ";")
    | upsert_if_value producers ($metadata.track | get --ignore-errors producers | str join ";")
    | upsert_if_value engineers ($metadata.track | get --ignore-errors engineers | str join ";")
    | upsert_if_value performers ($metadata.track | get --ignore-errors performers | str join ";")
    # | upsert_if_value performers ($metadata.track | get --ignore-errors performers | str join ";")
    # todo illustrators, translators, adapters, editors
  )
  {
    meta: (
      {}
      #
      # book metadata
      #
      | upsert_if_present album $metadata.book title
      | upsert_if_present subtitle $metadata.book
      | upsert_if_value albumArtist ($metadata.book | get --ignore-errors writers | get name | str join ";")
      # | upsert_if_present artist_credit_sort $metadata.book
      | upsert_if_present language $metadata.book
      | upsert_if_present description $metadata.book
      | upsert_if_present comment $metadata.book
      | upsert_if_value group $group
      | upsert_if_value genre ($metadata.book | get --ignore-errors genres | str join ";")
      # todo I'm not sure audiobookshelf supports multiple values for the publisher
      | upsert_if_value publisher ($metadata.book | get --ignore-errors publishers | str join ";")
      | upsert_if_value publishingDate $publication_date
      | upsert_if_present asin $metadata.book amazon_asin
      | upsert_if_present audible_asin $metadata.book
      | upsert_if_present isbn $metadata.book
      #
      # track metadata
      #
      | upsert_if_present title $metadata.track
      | upsert_if_present trackNumber $metadata.track index
      | upsert_if_value artist ($metadata.track | get --ignore-errors writers | get --ignore-errors name | str join ";")
      | upsert_if_value narrator ($metadata.track | get --ignore-errors narrators | get --ignore-errors name | str join ";")
      # Use the composer field for the narrators for audiobookshelf
      | upsert_if_value composer ($metadata.track | get --ignore-errors narrators | get --ignore-errors name | str join ";")
      | upsert_if_present embeddedPictures $metadata.track embedded_pictures
      #
      # additionalFields
      #
      | upsert_if_value additionalFields $additionalFields
    )
  }
}

# Convert the metadata for a set of tracks into a format suitable for tone
#
# The input data should be in the form of a book and a list of tracks.
# The returned records will contain the metadata for tone under the metadata key.
# The other key, file, will contain the path to the track on disk.
export def tracks_into_tone_format []: record<book: record, tracks: table> -> table<metadata: record<meta: record>, file: path> {
  let metadata = $in
  $metadata.tracks | par-each {|track|
    {
      book: $metadata.book
      track: $track
    } | into_tone_format | (
      let input = $in;
      {
        metadata: $input
        # Keep the association between the track and its path on disk.
        file: $track.file
      }
    )
  } # | sort-by metadata.trackNumber
}

# Calculate the AcoustID of an audio file or files with the fpcalc utility
#
# fpcalc is part of the chromaprint package.
#
# Returns a record containing the duration and the fingerprint.
export def fpcalc []: list<path> -> table<file: path, fingerprint: string, duration: duration> {
  $in | par-each {|file|
    let file = $file | path expand
    let result = do {^fpcalc -json $file} | complete
    if $result.exit_code != 0 {
      log error $"Error running '^fpcalc -json ($file)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      return null
    }
    let track = $result.stdout | from json
    {
      file: $file
      fingerprint: $track.fingerprint
      duration: (($track.duration * 1000) | math round | into duration --unit ms)
    }
  }
}

# Tag an audio file with tone using the provided metadata
export def tone_tag [
  file: path
  ...tone_args: string
]: record -> path {
  let metadata = $in
  let tone_json = mktemp --suffix ".json" --tmpdir
  $metadata | save --force $tone_json
  let result = do {
    (
      ^tone tag
          # todo When tone is new enough?
          # --id $isbn | amazon_asin | audible_asin?
          # --meta-chapters-file $chapters_file
          # --meta-cover-file $cover_file
          --meta-tone-json-file $tone_json
          # --meta-remove-property "comment"
          ...$tone_args
          $file
    )
  } | complete
  if $result.exit_code != 0 {
    log error $"Error running '^tone tag --meta-tone-json-file ($tone_json) (...$tone_args) ($file)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }

  rm $tone_json

  $file
}

# Tag audio files with tone using the provided metadata
export def tone_tag_tracks [
  working_directory: directory
  ...tone_args: string
]: record -> list<path> {
  $in | tracks_into_tone_format | par-each {|track|
    $track.metadata | tone_tag $track.file ...$tone_args
  }
}

### MusicBrainz functions

# Functions prefixed with "fetch_" are used to query the MusicBrainz API.
# Functions prefixed with "parse_" are used to parse responses from the MusicBrainz API without making any external calls.
# This allows using unit tests for the functions prefixed with "parse_".

# Get the Release Group Series to which a Release Group belongs
export def parse_series_from_release_group []: record -> table<name: string, index: string> {
  let release_group_series = (
    $in
    | get relations
    | where series.type == "Release group series"
    | where type == "part of"
  )
  if ($release_group_series | is-empty) {
    return null
  }

  $release_group_series | par-each {|relation|
    {
      name: $relation.series.name
      index: ($relation.attribute-values | get --ignore-errors number)
    }
  }
}

# Get the release group to which a release belongs
export def fetch_musicbrainz_release_group_for_release []: string -> table {
  let release_id = $in
  let url = "https://musicbrainz.org/ws/2/release-group/"
  let query = $"reid:($release_id)" | url encode
  http get --headers [User-Agent $user_agent Accept "application/json"] $"($url)/?query=($query)"
}

# Fetch the front cover image of a release from the Cover Art Archive
export def fetch_release_front_cover [
  working_directory: directory
  size: string = original # original, 1200, 500, or 250
  --retries: int = 3
  --retry-delay: duration = 3sec
]: string -> path {
  let release_id = $in
  let url = "https://coverartarchive.org/release"
  let request = {http get --full --headers [User-Agent $user_agent] $"($url)/($release_id)"}
  let response = retry_http $request $retries $retry_delay
  let cover = $response | get body | get images | where front == true | select id image thumbnails | first

  # thumbnail sizes are 1200, 500, and 250
  let download_url = (
    if $size == "original" {
      $cover | get image
    } else {
      $cover | get thumbnails | get $size
    }
  )
  let filename = $download_url | url parse | get path | path basename
  let destination = $working_directory | path join $filename
  http get --headers [User-Agent $user_agent] $download_url | save --force $destination
  $destination
}

# Fetch a release group from MusicBrainz by ID
export def fetch_musicbrainz_release_group [
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  let release_group_id = $in
  let url = "https://musicbrainz.org/ws/2/release-group"
  let request = {http get --full --headers [User-Agent $user_agent Accept "application/json"] $"($url)/($release_group_id)/?inc=series-rels"}
  retry_http $request $retries $retry_delay
}

# Get a Release with all of the gory details
export def fetch_musicbrainz_release [
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> table {
  let release_id = $in
  let url = "https://musicbrainz.org/ws/2/release"
  let includes = [
    artist-credits
    labels
    recordings
    release-groups
    media
    genres
    tags
    release-group-rels
    work-rels
    series-rels
    genre-rels
    artist-rels
    recording-level-rels
    release-group-level-rels
    work-level-rels
    url-rels # for Audible ASIN
  ]
  let request = {http get --full --headers [User-Agent $user_agent Accept "application/json"] $"($url)/($release_id)/?inc=($includes | str join '+')"}
  retry_http $request $retries $retry_delay
}

# Parse the ASIN out of an Audible URL
export def parse_audible_asin_from_url []: string -> string {
  let url = $in
  let parsed = $url | url parse
  if ($parsed.host | str starts-with "www.audible.") {
    $parsed | get path | path parse | get stem
  }
}


# Call a function, retrying up to the given number of retries
export def retry [
  request: closure # The function to call
  should_retry: closure # A closure which determines whether to retry or not based on the result of the request closure. True means retry, false means stop.
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
] nothing -> any {
  for attempt in 1..($retries - 1) {
    let response = do $request
    if not (do $should_retry $response) {
      return $response
    }
    sleep $delay
  }
  do $request
}

# Make an http call, retrying up to the given number of retries
export def retry_http [
  request: closure # The function to call
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
  http_status_codes_to_retry: list<int> = [408 429 500 502 503 504] # HTTP status codes where the request will be retries
] nothing -> any {
  let should_retry = {|result|
    $result.status in $http_status_codes_to_retry
  }
  retry $request $should_retry $retries $delay
}

# Parses release and recording ids from an AcoustID server response
#
# Takes an AcoustID server response as input.
# export def parse_release_ids_from_acoustid_response []: record<results: table<id: string, releases: table<id: string>, score: float>, status: string> -> table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float> {
#   let response = $in
#   if $response.status != "ok" {
#     log error $"Received response with status (ansi red)($response.status)(ansi reset) querying the AcoustID server"
#     return null
#   }
#   $response.results
# }

# Find release and recording ids linked to an AcoustID fingerprint
#
# Requires an AcoustID application API key.
export def fetch_release_ids_by_acoustid_fingerprint [
  client_key: string # The application API key for the AcoustID server
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: record<file: path, duration: duration, fingerprint: string> -> record<file: path, http_response: table, result: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> {
  let input = $in
  let url = "https://api.acoustid.org/v2/lookup"

  let duration_seconds = ($input.duration / 1sec) | math round
  let payload = $"format=json&meta=recordingids+releaseids&client=($client_key)&fingerprint=($input.fingerprint)&duration=($duration_seconds)"
  let request = {||
    $payload
    | ^gzip --stdout
    | http post --content-type application/x-www-form-urlencoded --full --headers [Content-Encoding gzip] $url
  }

  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error looking up AcoustID fingerprint at ($url) with payload ($payload): ($error.debug.msg)"
      return null
    }
  )

  if ($response.status != 200) {
    return {file: $input.file, "http_response": $response, result: null}
  }

  {
    file: $input.file
    http_response: $response
    result: ($response | get body)
  }
}

# Find the MusicBrainz releases linked to a set of AcoustID fingerprints
#
# Requires an AcoustID application API key.
# retries: int = 3 # The number of retries to attempt for a failed lookup request
export def fetch_release_ids_by_acoustid_fingerprints [
  client_key: string # The application API key for the AcoustID server
  threshold: float = 1.0 # A float value between zero and one, the minimum score required to be considered a match
  fail_fast = true # Immediately return null when a fingerprint has no matches that meet the threshold score
  api_requests_per_second: int = 3 # The number of API requests to make per second. AcoustID only permits up to three requests per second.
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: table<file: path, duration: duration, fingerprint: string> -> table<file: path, fingerprint: string, duration: duration, matches: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> {
  $in | chunks $api_requests_per_second | each {|chunk|
    let matches = (
      $chunk | par-each {|fingerprint|
        let result = $fingerprint | fetch_release_ids_by_acoustid_fingerprint $client_key --retries $retries --retry-delay $retry_delay
        if $result == null {
          log error $"Failed to lookup AcoustID fingerprint on the AcoustID server."
          return null
        }
        if $result.http_response.status != 200 {
          if $result.http_response.status in [401 403] {
            log error $"Failed to lookup AcoustID fingerprint on the AcoustID server. HTTP status code ($result.http_response.status). Check the client API key is correct."
            return null
          }
          log error $"Failed to lookup AcoustID fingerprint on the AcoustID server. HTTP status code ($result.http_response.status)."
          return null
        }
        let match = $result.result.results | where score >= $threshold
        if $fail_fast and ($match | is-empty) {
          return null
        }
        {
          file: $result.file
          fingerprint: $fingerprint.fingerprint
          duration: $fingerprint.duration
          matches: $match
        }
      }
    )
    sleep 1sec
    $matches
  } | flatten
}

# Attempt to find a release based on the AcoustID fingerprints of a set of tracks
#
# Takes as input a table of AcoustID fingerprints, track durations, and matches.
# This is the output of the fetch_release_ids_by_acoustid_fingerprints function.
#
# Returns the releases to which all tracks belong.
export def determine_releases_from_acoustid_fingerprint_matches []: table<file: path, fingerprint: string, duration: duration, matches: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> -> list<string> {
  let tracks = $in
  if ($tracks | is-empty) {
    return null
  }
  let all_possible_release_ids = $tracks | get matches | flatten | get recordings | flatten | get releases | flatten | get id | uniq
  $all_possible_release_ids | filter {|release_id|
    $tracks | all {|track|
      $release_id in ($track | get matches | get recordings | flatten | get releases | flatten | get id)
    }
  }
}

# Parse narrators from MusicBrainz recording and release relationship data
export def parse_narrators_from_musicbrainz_relations []: list -> table {
  let relations = $in
  (
    $relations
    | where target-type == "artist"
    | where type == "vocal"
    | filter {|rel| "spoken vocals" in $rel.attributes}
    # attribute-credits is used for specific characters, which isn't useful for tagging yet
    | select artist target-credit # attribute-credits
    | uniq
    | par-each {|narrator|
      let name = (
        if "target-credit" in $narrator and ($narrator.target-credit | is-not-empty) {
          $narrator.target-credit
        } else {
          $narrator.artist.name
        }
      )
      {
        name: $name
        id: $narrator.artist.id
      }
    }
  )
}

# Parse the works from MusicBrainz recording relationships
export def parse_works_from_musicbrainz_relations []: list -> table {
  let relations = $in
  (
    $relations
    | where target-type == "work"
    | where type == "performance"
    | get work
    | uniq
  )
}

# Parse writers from MusicBrainz work relationships
export def parse_writers_from_musicbrainz_work_relations []: list -> table {
  let relations = $in
  let writers = (
    $relations
    | where target-type == "artist"
    | where type == "writer"
  )
  if ($writers | is-empty) {
    return null
  }
  $writers | par-each {|writer|
    let name = (
      if "target-credit" in $writer and ($writer.target-credit | is-not-empty) {
        $writer.target-credit
      } else {
        $writer.artist.name
      }
    )
    {
      name: $name
      id: $writer.artist.id
    }
  }
  | sort-by name
  | uniq
}

# Parse narrators from MusicBrainz release and track data
export def parse_narrators_from_musicbrainz_release []: record -> table {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  (
    $metadata
    | get media
    | get tracks
    | flatten
    | get recording
    | get relations
    | flatten
    # Append the release relationships
    | append ($metadata | get relations)
    | parse_narrators_from_musicbrainz_relations
  )
}

# Parse writers from MusicBrainz release and track data
export def parse_writers_from_musicbrainz_release []: record -> table {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  (
    $metadata
    | get media
    | get tracks
    | flatten
    | get recording
    | get relations
    | flatten
    | parse_works_from_musicbrainz_relations
    | get relations
    | flatten
    | parse_writers_from_musicbrainz_work_relations
  )
}

# Parse series from MusicBrainz relationships
#
# Multiple series are sorted according to index, in descending order.
# The goal of this is to order subseries after parent series.
# Of course, this won't help where indices are missing or indices match.
export def parse_series_from_musicbrainz_relations [] table -> table<id: string, name: string, index: string> {
  let relations = $in
  let series = (
    $relations
    | where target-type == "series"
    | where type == "part of"
  )
  if ($series | is-empty) {
    return null
  }
  $series | par-each {|s|
    let name = (
      if "target-credit" in $s and ($s.target-credit | is-not-empty) {
        $s.target-credit
      } else {
        $s.series.name
      }
    )
    {
      name: $name
      id: $s.series.id
      index: ($s.attribute-values | get --ignore-errors number)
    }
  } | uniq | sort-by --reverse index
}

# Parse series from MusicBrainz release, release group, and works
#
# The series are returned in the order of relevance:
# 1. release
# 2. release group
# 3. work
#
# Multiple series of the same type a further sorted according to index, in descending order.
# The goal of this is to order subseries after parent series.
# Of course, this won't help where indices are missing or indices match.
# Unfortunately, separate lookups for each series are necessary to determine if a series is a subseries.
export def parse_series_from_musicbrainz_release []: record -> table {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  (
    []
    | append (
      $metadata
      | get relations
      | parse_series_from_musicbrainz_relations
    )
    | append (
      $metadata
      | get release-group
      | get relations
      | parse_series_from_musicbrainz_relations
    )
    | append (
      $metadata
      | get media
      | get tracks
      | flatten
      | get recording
      | get relations
      | flatten
      | parse_works_from_musicbrainz_relations
      | get relations
      | flatten
      | parse_series_from_musicbrainz_relations
    )
  )
}

# Parse tags from a MusicBrainz release, release group, and recordings
#
# The genres should also be parsed from associated series and works, but these require separate API calls.
#
# MusicBrainz doesn't really provide genres for audiobooks yet, so most genres are directly imported from tags.
export def parse_tags_from_musicbrainz_release [
  --only-genres # Parse only genres instead of using tags
]: record -> table {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  if $only_genres {
    (
      []
      | append (
        $metadata
        | get --ignore-errors genres
      )
      | append (
        $metadata
        | get --ignore-errors release-group
        | get --ignore-errors genres
      )
      # recordings
      | append (
        $metadata
        | get media
        | get tracks
        | flatten
        | get recording
        | get --ignore-errors genres
        | flatten
      )
      | get --ignore-errors name
      | uniq
      | sort
    )
  } else {
    (
      []
      | append (
        $metadata
        | get --ignore-errors tags
      )
      | append (
        $metadata
        | get --ignore-errors release-group
        | get --ignore-errors tags
      )
      # recordings
      | append (
        $metadata
        | get media
        | get tracks
        | flatten
        | get recording
        | get --ignore-errors tags
        | flatten
      )
      | get --ignore-errors name
      | uniq
      | filter {|tag|
        $tag != "unabridged"
      }
      | sort
    )
  }
}

# Parse the artist names and ids from the MusicBrainz artist credits
export def parse_musicbrainz_artist_credit []: list -> table {
  $in | enumerate | select index item.artist.id item.name | rename index id name
}

# Parse an Audible ASIN from the URL relationships in a MusicBrainz Release
export def parse_audible_asin_from_musicbrainz_release []: record -> list<string> {
  let metadata = $in
  if relations not-in $metadata {
    return null
  }
  let purchase_urls = (
    $metadata
    | get relations
    | where target-type == url
    | filter {|r|
      $r.type | str starts-with purchase
    }
  )
  if ($purchase_urls | is-empty) {
    return null
  }
  $purchase_urls | get url | get resource | par-each {|url|
    $url | parse_audible_asin_from_url
  }
}

# Parse the data of a MusicBrainz release
export def parse_musicbrainz_release []: record -> record {
  let metadata = $in

  let release_artist_credits = (
    if "artist-credit" in $metadata and ($metadata.artist-credit | is-not-empty) {
      $metadata.artist-credit | parse_musicbrainz_artist_credit
    }
  )

  # todo Pull in translators, adapters, engineers, and producers?

  # Track metadata
  let tracks = (
    $metadata
    | get media
    | get tracks
    | flatten
    | par-each {|track|
      let length = (
        if "length" in $track.recording {
          $track.recording.length | into duration --unit ms
        }
      );

      let track_artist_credits = (
        if "artist-credit" in $track.recording and ($track.recording.artist-credit | is-not-empty) {
          $track.recording.artist-credit | parse_musicbrainz_artist_credit
        }
      )
      let narrators = (
        $track.recording.relations
        | parse_narrators_from_musicbrainz_relations
        # Prefer the name in the track artist credit here, followed by the name in the release artist credit.
        | join $track_artist_credits id
        | join $release_artist_credits id
        | rename name id track_artist_credit_index track_artist_credit release_artist_credit_index release_artist_credit
        | sort-by track_artist_credit_index release_artist_credit_index name
        | each {|narrator|
          let name = (
            if ($narrator.track_artist_credit | is-not-empty) {
              $narrator.track_artist_credit
            } else if ($narrator.release_artist_credit | is-not-empty) {
              $narrator.release_artist_credit
            } else {
              $narrator.name
            }
          )
          # If there is more than one artist credit for the same artist, that would be really bizarre.
          # In that case, just going with the first one.
          {
            id: $narrator.id
            name: $name
          }
        }
      )
      let works = $track.recording.relations | parse_works_from_musicbrainz_relations;
      let musicbrainz_work_ids = (
        if ($works | is-not-empty) {
          $works | get id | uniq
        }
      )
      let writers = (
        # Put orders in the order of the track credit, then release credit, then alphabetical by sort name
        if ($works | is-not-empty) and "relations" in "works" {
          (
            $works
            | get relations
            | parse_writers_from_musicbrainz_work_relations
            # Prefer the name in the track artist credit here, followed by the name in the release artist credit.
            | join $track_artist_credits id
            | join $release_artist_credits id
            | rename name id track_artist_credit_index track_artist_credit release_artist_credit_index release_artist_credit
            | sort-by track_artist_credit_index release_artist_credit_index name
            | each {|writer|
              let name = (
                if ($writer.track_artist_credit | is-not-empty) {
                  $writer.track_artist_credit
                } else if ($writer.release_artist_credit | is-not-empty) {
                  $writer.release_artist_credit
                } else {
                  $writer.name
                }
              )
              # If there is more than one artist credit for the same artist, that would be really bizarre.
              # In that case, just going with the first one.
              {
                id: $writer.id
                name: $name
              }
            }
          )
        }
      )
      let genres = (
        $track
        | get recording
        | get --ignore-errors tags
        | get --ignore-errors name
        | uniq
        | filter {|tag|
          $tag != "unabridged"
        }
      )
      let musicbrainz_artist_ids = $track | get --ignore-errors artist-credit.artist.id | uniq
      (
        {
          index: $track.position
        }
        | upsert_if_present musicbrainz_track_id $track id
        | upsert_if_present title $track
        | upsert_if_present musicbrainz_recording_id $track.recording id
        | upsert_if_value genres $genres
        | upsert_if_value musicbrainz_work_ids $musicbrainz_work_ids
        # This needs to just be the writers ids for audiobookshelf...
        # | upsert_if_value musicbrainz_artist_ids $musicbrainz_artist_ids
        | upsert_if_value narrators $narrators
        | upsert_if_value writers $writers
        | upsert_if_value duration $length
        # AcoustID metadata may be supplemented in the provided track metadata
        | upsert_if_present acoustid_fingerprint $track
        | upsert_if_present acoustid_track_id $track
      )
    }
    | sort-by index
  )

  let narrators = (
    $metadata
    | parse_narrators_from_musicbrainz_release
    | join $release_artist_credits id
    | rename name id release_artist_credit_index release_artist_credit
    | sort-by release_artist_credit_index name
    | each {|narrator|
      let name = (
        if ($narrator.release_artist_credit | is-not-empty) {
          $narrator.release_artist_credit
        } else {
          $narrator.name
        }
      )
      {
        id: $narrator.id
        name: $name
      }
    }
  )
  let writers = (
    $metadata
    | parse_writers_from_musicbrainz_release
    | join $release_artist_credits id
    | rename name id release_artist_credit_index release_artist_credit
    | sort-by release_artist_credit_index name
    | each {|writer|
      let name = (
        if ($writer.release_artist_credit | is-not-empty) {
          $writer.release_artist_credit
        } else {
          $writer.name
        }
      )
      {
        id: $writer.id
        name: $name
      }
    }
  )
  let publication_date = (
    if "date" in $metadata {
      $metadata | get date | into datetime
    }
  )
  let publishers = (
    # todo Also check for publishers in the release relationships.
    if "label-info" in $metadata and "label" in $metadata.label-info {
      $metadata.label-info.label.name
    }
  )

  let series = $metadata | parse_series_from_musicbrainz_release

  let audible_asin = (
    let audible_asins = $metadata | parse_audible_asin_from_musicbrainz_release;
    # We just kind of ignore all besides the first when there are multiple
    # todo At least log when there are multiple.
    if ($audible_asins | is-not-empty) {
      $audible_asins | first
    }
  )
  let genres = $metadata | parse_tags_from_musicbrainz_release

  # Chapters can come from multi-track releases, otherwise, they need to found in another release
  # todo Attempt to look up chapters from related release for m4b files
  let chapters = (
    if ($tracks | length) > 1 {
      $metadata | get media | chapters_from_musicbrainz_release_media
    }
  )

  let front_cover_available = (
    "cover-art-archive" in $metadata and $metadata.cover-art-archive.front
  )

  let musicbrainz_artist_ids = $metadata | get --ignore-errors artist-credit.artist.id | uniq
  let musicbrainz_release_types = (
    []
    | append (
      $metadata
      | get --ignore-errors release-group.primary-type
    )
    | append (
      $metadata
      | get --ignore-errors release-group.secondary-types
    )
  )

  # Book metadata
  let book = (
    {}
    | upsert_if_present musicbrainz_release_id $metadata id
    | upsert_if_present musicbrainz_release_group_id $metadata.release-group id
    | upsert_if_value musicbrainz_release_types $musicbrainz_release_types
    | upsert_if_present title $metadata
    | upsert_if_value writers $writers
    | upsert_if_present isbn $metadata barcode
    | upsert_if_present musicbrainz_release_country $metadata country
    | upsert_if_present musicbrainz_release_status $metadata status
    | upsert_if_present amazon_asin $metadata asin
    | upsert_if_value audible_asin $audible_asin
    | upsert_if_value genres $genres
    | upsert_if_value publication_date $publication_date
    | upsert_if_value series $series
    | upsert_if_value chapters $chapters
    | upsert_if_value front_cover_available $front_cover_available
    # This needs to just be the writers ids for audiobookshelf...
    # | upsert_if_value musicbrainz_artist_ids $musicbrainz_artist_ids
    | (
      let input = $in;
      if "text-representation" in $metadata {
        $input
        | upsert_if_present script $metadata.text-representation
        | upsert_if_present language $metadata.text-representation
      } else {
        $input
      }
    )
  )

  {
    book: $book
    tracks: $tracks
  }
}

# Fetch the given release id from MusicBrainz and parse it into a normalized data structure
export def fetch_and_parse_musicbrainz_release [
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  $in | fetch_musicbrainz_release --retries $retries --retry-delay $retry_delay | get body | parse_musicbrainz_release
}


# Get the embedded AcoustID fingerprint or calculate it for the audio files which do not have one.
export def get_acoustid_fingerprint [
  ignore_existing = false # Recalculate the AcoustID even when the tag exists
]: list<path> -> table<file: path, fingerprint: string, duration: duration> {
  let files = $in
  $files | par-each {|file|
    let metadata = $file | parse_audiobook_metadata_from_file
    let fingerprint = (
      if (
        not $ignore_existing
        and "acoustid_fingerprint" in $metadata.track
        and ($metadata.track.acoustid_fingerprint | is-not-empty)
        and "duration" in $metadata.track
        and ($metadata.track.duration | is-not-empty)
      ) {
        {
          file: $file
          fingerprint: $metadata.track.acoustid_fingerprint
          duration: $metadata.track.duration
        }
      }
    )
    if ($fingerprint | is-empty) {
      [$file] | fpcalc | first
    } else {
      $fingerprint
    }
  }
}

# Tag the files of an audiobook using their AcoustID fingerprints.
#
#
export def tag_audiobook_from_acoustid [
  audiobook_files: list<path>
  client_key: string # The application API key for the AcoustID server
  working_directory
  fail_fast = true # Immediately return null when a fingerprint has no matches that meet the threshold score
  --ignore-existing-acoustid-fingerprints # Recalculate AcoustID fingerprints for all files
  --threshold: float = 1.0 # A float value between zero and one, the minimum score required to be considered a match
  --api-requests-per-second: int = 3 # The number of API requests to make per second. AcoustID only permits up to three requests per second.
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
  # --working-directory: directory
]: nothing -> list<path> {
  let acoustid_fingerprints = (
    $audiobook_files | get_acoustid_fingerprint $ignore_existing_acoustid_fingerprints
  )
  log info $"acoustid_fingerprints: ($acoustid_fingerprints)"
  let acoustid_responses = (
    $acoustid_fingerprints
    | fetch_release_ids_by_acoustid_fingerprints $client_key $threshold $fail_fast $api_requests_per_second --retries $retries --retry-delay $retry_delay
  )
  if ($acoustid_responses | is-empty) {
    log error "AcoustID responses missing"
    return null
  }
  log info $"acoustid_responses: ($acoustid_responses)"
  let release_ids = $acoustid_responses | determine_releases_from_acoustid_fingerprint_matches
  if ($release_ids | is-empty) {
    log error "No common release ids found for the AcoustID fingerprints"
    return null
  } else if ($release_ids | length) > 1 {
    log error $"Multiple release ids found for the AcoustID fingerprints: ($release_ids)"
    return null
  }
  let release_id = $release_ids | first
  let track_recordings_for_release = (
    $acoustid_responses | flatten | each {|track|
      let recording_ids = (
        $track
        | get matches
        | get recordings
        | filter {|recording|
          $release_id in ($recording.releases.id)
        }
        | get id
      );
      {
        file: $track.file
        id: $track.matches.id
        recordings: $recording_ids
      }
    }
  )
  let each_track_has_exactly_one_recording_for_the_release = $track_recordings_for_release | all {|track|
    ($track.recordings | length) == 1
  }
  if (not $each_track_has_exactly_one_recording_for_the_release) {
    log info "Failed to link each AcoustID track to exactly one recording for the release"
    return null
  }
  let file_metadata = (
    $track_recordings_for_release
    | flatten
    | rename file acoustid_track_id musicbrainz_recording_id
    | select file acoustid_track_id musicbrainz_recording_id
    | join $acoustid_fingerprints file
    | rename file acoustid_track_id musicbrainz_recording_id acoustid_fingerprint duration
    | par-each {|track|
      {
        file: $track.file
        acoustid_track_id: $track.acoustid_track_id
        acoustid_fingerprint: $track.acoustid_fingerprint
        musicbrainz_recording_id: $track.musicbrainz_recording_id
        audio_duration: $track.duration
      }
    }
  )
  log info $"file_metadata: ($file_metadata)"
  $file_metadata | tag_audiobook_files_by_musicbrainz_release_id ($release_ids | first) $working_directory
}

# Tag the given audio files using the given MusicBrainz release id
#
# The individual audio files should be provided in a table as input.
# The file key should be used for the path of each file on disk.
#
# The table can also include the MusicBrainz Recording ID using the musicbrainz_recording_id key.
# This ensures that each track is associated with the correct recording.
# It's particularly useful for associating files with recordings using AcoustID fingerprints.
# Without the MusicBrainz Recording ID, tracks must be provided in the correct order as they appear on the release.
# The tracks will be checked against their expected durations in this case to ensure correctness.
#
# In addition to the musicbrainz_recording_id key, the acoustid_fingerprint, audio_duration, and acoustid_track_id tags can also be included.
# The acoustid_fingerprint and acoustid_track_id will be embedded in the files with the other metadata.
# The audio_duration value is used to avoid recalculating the duration of the audio.
export def tag_audiobook_files_by_musicbrainz_release_id [
  release_id: string
  working_directory: directory
  duration_threshold: duration = 2sec # The acceptable difference in track length of the file vs. the length of the track in MusicBrainz
  --retries: int = 3
  --retry-delay: duration = 5sec
]: table -> list<path> {
  let audiobook_files = $in
  # let current_metadata = (
  #   $audiobook_files | parse_audiobook_metadata_from_files
  # )
  let metadata = (
    $release_id | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay
  )
  # log info $"audiobook_files: ($audiobook_files)"
  # log info $"audiobook_files.metadata.track: ($audiobook_files.metadata.track)"
  let tracks = (
    if (
      "musicbrainz_recording_id" in ($audiobook_files | columns)
      and ($audiobook_files.musicbrainz_recording_id | is-not-empty)
    ) {
      log info "Joining!!!"
      $metadata.tracks | join $audiobook_files musicbrainz_recording_id
    } else {
      let enumerated_audiobook_files = (
        $audiobook_files | enumerate | each {|f|
          {
            index: ($f.index + 1)
            file: $f.item.file
          }
        }
      )
      $metadata.tracks | join $enumerated_audiobook_files index
    }
  )
  log info $"tracks: ($tracks)"
  for track in $tracks {
    let duration = (
      if "audio_duration" in $track and ($track.audio_duration | is-not-empty) {
        $track.audio_duration
      } else {
        $track.file | tone_dump | get audio.duration | into int | into duration --unit ms
      }
    )
    if ($track.duration - $duration | math abs) > $duration_threshold {
      log error $"The (ansi green)($track)(ansi reset) is ($duration) long, but the MusicBrainz track is ($track.duration) long, which is outside the acceptable duration threshold of ($duration_threshold)"
      return null
    }
  }
  let front_cover = (
    if "front_cover_available" in $metadata.book and $metadata.book.front_cover_available {
      $metadata.book.musicbrainz_release_id | fetch_release_front_cover $working_directory
    }
  )
  # todo Best effort to search for and find associated chapters for single track releases.
  let files = $metadata | update tracks $tracks | tone_tag_tracks $working_directory "--meta-cover-file" $front_cover

  # Clean up
  if ($front_cover | is-not-empty) {
    rm $front_cover
  }

  $files
}

# Using metadata from the audio tracks, search for a MusicBrainz release
# export def search_for_musicbrainz_release []: record -> table {
# }

##### chapterz.nu #####

# Get a list of start offsets from a list of durations
export def lengths_to_start_offsets []: list<duration> -> list<duration> {
  let lengths = $in | enumerate
  $lengths | each {|i|
      $lengths | where index < $i.index | reduce --fold 0ms {|it,acc|
          $it.item + $acc
      }
  }
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

# Parse chapters out of MusicBrainz recordings data.
# $release | get media
export def chapters_from_musicbrainz_release_media []: table -> string {
  (
    $in
    | get tracks
    | flatten
    | each {|recording|
      # Unfortunately, lengths are in seconds and not milliseconds.
      let time = ($recording.length | into duration --unit ms | lengths_to_start_offsets | each {|t| $t | format_chapter_duration})
      $"($time) ($recording.title)"
    }
    | str join "\n"
  )
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

# Parse the Part, Chapter, and Title portions of a chapter.
export def parse_chapter_title []: string -> record<part: string, part_title: string, chapter: string, chapter_title: string, chapter_part: string> {
    let input = $in
    let split = str index-of "/"
    (
        $input
        # todo Split into multiple rows if there's a '/'.
        | parse --regex '(?<part>Part \w+)?(?<part_title>: \"[\w\s]+\")?(?:,\s)?(?<chapter>[\w\s/]+(?:\s\d+)?)(?<chapter_title>: \"[\w\s]+\")?(?:,\s)?(?<chapter_part>Part \d+)?'
        | each {|c|
            {
                part: $c.part
                part_title: (
                    $c.part_title
                    | str trim --char ':' --left
                    | str trim --left
                    | str trim --char '"'
                    | str trim --char "'"
                )
                chapter: $c.chapter
                chapter_title: (
                    $c.chapter_title
                    | str trim --char ':' --left
                    | str trim --left
                    | str trim --char '"'
                    | str trim --char "'"
                )
                chapter_part: $c.chapter_part
            }
        }
        | first
    )
}

##### End chapterz.nu #####
