# Tests for the text functions in media-juggler-lib

use std assert

use ../media-juggler-lib *
use helpers/fixtures.nu *

export def test_pdf_page_count [] {
  let directory = mktemp --directory --tmpdir
  let pdf = $directory | path join "book.pdf" | create_pdf ["One" "Two" "Three"]
  assert equal ($pdf | pdf_page_count) 3
  rm --recursive $directory
}

export def test_pdf_to_text_short [] {
  let directory = mktemp --directory --tmpdir
  let pdf = $directory | path join "book.pdf" | create_pdf ["First page" "Second page"]
  let text = $pdf | pdf_to_text | lines | str trim
  assert ("First page" in $text)
  assert ("Second page" in $text)
  rm --recursive $directory
}

export def test_pdf_to_text_only_first_and_last_ten_pages [] {
  let directory = mktemp --directory --tmpdir
  let pdf = $directory | path join "book.pdf" | create_pdf (1..25 | each {|page| $"Page ($page)" })
  let text = $pdf | pdf_to_text | lines | str trim
  for page in [1 10 15 25] {
    assert ($"Page ($page)" in $text) $"Page ($page) should be converted"
  }
  for page in [11 12 13 14] {
    assert ($"Page ($page)" not-in $text) $"Page ($page) shouldn't be converted"
  }
  rm --recursive $directory
}

export def test_book_to_text_pdf [] {
  let directory = mktemp --directory --tmpdir
  let pdf = $directory | path join "book.pdf" | create_pdf ["Some text"]
  assert ("Some text" in ($pdf | book_to_text | lines | str trim))
  rm --recursive $directory
}

export def test_book_to_text_unsupported_format [] {
  assert equal ("book.mobi" | book_to_text) null
}

export def test_image_to_text [] {
  let directory = mktemp --directory --tmpdir
  let image = $directory | path join "page.pdf" | create_pdf ["ISBN 978-1-250-16947-1"] | render_pdf_page
  assert str contains ($image | image_to_text) "978-1-250-16947-1"
  rm --recursive $directory
}

export def test_image_to_text_missing_file [] {
  assert equal ("missing.png" | image_to_text) null
}

export def test_isbn_from_pages_pdf [] {
  let directory = mktemp --directory --tmpdir
  let pdf = $directory | path join "book.pdf" | create_pdf ["Chapter 1" "ISBN 978-1-250-16947-1 (ebook)"]
  assert equal ($pdf | isbn_from_pages $directory) ["9781250169471"]
  rm --recursive $directory
}

export def test_isbn_from_pages_cbz [] {
  let directory = mktemp --directory --tmpdir
  let page = $directory | path join "002.pdf" | create_pdf ["ISBN 978-1-250-16947-1"] | render_pdf_page
  let cover = $directory | path join "001.png" | create_image 300 200
  let cbz = $directory | path join "comic.cbz" | create_zip ["001.png" "002.png"]
  let working_directory = $directory | path join "work"
  mkdir $working_directory
  assert equal ($cbz | isbn_from_pages $working_directory) ["9781250169471"]
  rm --recursive $directory
}

export def test_isbn_from_pages_cbz_without_isbn [] {
  let directory = mktemp --directory --tmpdir
  let cover = $directory | path join "001.png" | create_image 300 200
  let cbz = $directory | path join "comic.cbz" | create_zip ["001.png"]
  let working_directory = $directory | path join "work"
  mkdir $working_directory
  assert equal ($cbz | isbn_from_pages $working_directory) []
  rm --recursive $directory
}
