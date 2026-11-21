# Tests for the archives functions in media-juggler-lib

use std assert

use ../media-juggler-lib *
use helpers/fixtures.nu *

export def test_escape_unzip_path_plain [] {
  assert equal ("pages/001.jpg" | escape_unzip_path) "pages/001.jpg"
}

export def test_escape_unzip_path_special_characters [] {
  assert equal ("[Group] Vol? 1*.jpg" | escape_unzip_path) "[[]Group] Vol[?] 1[*].jpg"
}

# Create a directory with an archive containing some files
def create_archive_directory []: nothing -> record<directory: path, archive: path> {
  let directory = mktemp --directory --tmpdir
  mkdir ($directory | path join "pages")
  "cover" | save ($directory | path join "cover.jpg")
  "page 1" | save ($directory | path join "pages" "001.png")
  "page 2" | save ($directory | path join "pages" "002 [extra].png")
  "<ComicInfo/>" | save ($directory | path join "ComicInfo.xml")
  let archive = $directory | path join "comic.cbz" | create_zip ["cover.jpg" "pages/001.png" "pages/002 [extra].png" "ComicInfo.xml"]
  {directory: $directory archive: $archive}
}

export def test_list_files_in_archive [] {
  let test = create_archive_directory
  let expected = ["ComicInfo.xml" "cover.jpg" "pages/001.png" "pages/002 [extra].png"]
  assert equal ($test.archive | list_files_in_archive) $expected
  rm --recursive $test.directory
}

export def test_list_files_in_archive_with_extensions [] {
  let test = create_archive_directory
  assert equal ($test.archive | list_files_in_archive_with_extensions [png]) ["pages/001.png" "pages/002 [extra].png"]
  assert equal ($test.archive | list_files_in_archive_with_extensions [xml]) ["ComicInfo.xml"]
  rm --recursive $test.directory
}

export def test_number_of_images_in_archive [] {
  let test = create_archive_directory
  assert equal ($test.archive | number_of_images_in_archive) 3
  rm --recursive $test.directory
}

export def test_extract_file_from_archive [] {
  let test = create_archive_directory
  let destination = $test.directory | path join "extracted"
  mkdir $destination
  let file = $test.archive | extract_file_from_archive "pages/002 [extra].png" $destination
  assert equal $file ($destination | path join "pages/002 [extra].png")
  assert equal (open --raw $file) "page 2"
  rm --recursive $test.directory
}

export def test_extract_file_from_archive_missing_file [] {
  let test = create_archive_directory
  let destination = $test.directory | path join "extracted"
  mkdir $destination
  assert equal ($test.archive | extract_file_from_archive "missing.png" $destination) null
  rm --recursive $test.directory
}

export def test_add_file_to_archive [] {
  let test = create_archive_directory
  "page 3" | save ($test.directory | path join "pages" "003.png")
  do {
    cd $test.directory
    assert equal ("comic.cbz" | add_file_to_archive "pages/003.png") "comic.cbz"
  }
  assert ("pages/003.png" in ($test.archive | list_files_in_archive))
  rm --recursive $test.directory
}

export def test_unzip [] {
  let test = create_archive_directory
  let destination = $test.directory | path join "extracted"
  mkdir $destination
  let files = $test.archive | unzip $destination | sort
  let expected = ["ComicInfo.xml" "cover.jpg" "pages/001.png" "pages/002 [extra].png"] | each {|file| $destination | path join $file }
  assert equal $files $expected
  assert equal (open --raw ($destination | path join "cover.jpg")) "cover"
  rm --recursive $test.directory
}
