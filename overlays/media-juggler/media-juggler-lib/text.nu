# Functions for extracting text from books and images, i.e. to find ISBNs

use std log

use archives.nu *
use constants.nu *
use identifiers.nu *

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
  let text_file = mktemp --suffix .txt --tmpdir
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
  let images = $archive | list_files_in_archive_with_extensions $image_extensions
  # We start at the back first
  let pages = (
    $images
    # Filter out thumbnail images that have stems that end with '-thumb'
    | where {|image| not ($image | path parse | get stem | str ends-with '-thumb') }
    | last 10
    | reverse
    | append (
      $images
      # Filter out thumbnail images that have stems that end with '-thumb'
      | where {|image| not ($image | path parse | get stem | str ends-with '-thumb') }
      | first 10
    )
    | uniq
  )
  # $pages | each {|page|
  #   $page | image_to_text | parse_isbn
  # }
  for page in $pages {
    let image = $archive | extract_file_from_archive $page $working_directory
    if $image == null {
      return []
    }
    let image_text = $image | image_to_text
    if $image_text == null {
      return []
    }
    let isbn = $image_text | lines --skip-empty | reverse | parse_isbn
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
  let result = do {^tesseract $image stdout} | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^tesseract \"($image)\" stdout(ansi reset)\n($result.stderr)\n"
    return null
  }
  $result.stdout
}

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
