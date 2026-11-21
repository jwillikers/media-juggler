# Tests for the images functions in media-juggler-lib

use std assert

use ../media-juggler-lib *
use helpers/fixtures.nu *

export def test_get_image_dimensions [] {
  let directory = mktemp --directory --tmpdir
  let image = $directory | path join "image.png" | create_image 120 80
  assert equal ($image | get_image_dimensions) {width: 120 height: 80}
  rm --recursive $directory
}

export def test_get_image_dimensions_missing_file [] {
  assert equal ("missing.png" | get_image_dimensions) null
}

export def test_get_images_dimensions [] {
  let directory = mktemp --directory --tmpdir
  let images = [
    ($directory | path join "a.png" | create_image 120 80)
    ($directory | path join "b.png" | create_image 60 40)
  ]
  assert equal ($images | get_images_dimensions) [[width height]; [120 80] [60 40]]
  rm --recursive $directory
}

export def test_image_data_hash [] {
  let directory = mktemp --directory --tmpdir
  let white = $directory | path join "white.png" | create_image 10 10 white
  let white_copy = $directory | path join "white-copy.png" | create_image 10 10 white
  let black = $directory | path join "black.png" | create_image 10 10 black
  assert equal ($white | image_data_hash) ($white_copy | image_data_hash)
  assert not equal ($white | image_data_hash) ($black | image_data_hash)
  rm --recursive $directory
}

export def test_rename_image_with_extension [] {
  let directory = mktemp --directory --tmpdir
  # Create a PNG image, and then give it the wrong extension
  let image = $directory | path join "cover.jpg"
  mv ($directory | path join "cover.png" | create_image 10 10) $image
  let renamed = $image | rename_image_with_extension
  assert equal $renamed ($directory | path join "cover.png")
  assert ($renamed | path exists)
  assert not ($image | path exists)
  rm --recursive $directory
}

export def test_rename_image_with_extension_missing_file [] {
  assert equal ("missing.jpg" | rename_image_with_extension) null
}

export def test_get_image_extension [] {
  let directory = mktemp --directory --tmpdir
  "" | save ($directory | path join "001.png")
  "" | save ($directory | path join "002.png")
  "" | save ($directory | path join "ComicInfo.xml")
  let cbz = $directory | path join "comic.cbz" | create_zip ["001.png" "002.png" "ComicInfo.xml"]
  assert equal ($cbz | get_image_extension) "png"
  rm --recursive $directory
}

export def test_get_image_extension_jpg_and_jpeg [] {
  let directory = mktemp --directory --tmpdir
  "" | save ($directory | path join "001.jpg")
  "" | save ($directory | path join "002.jpeg")
  let cbz = $directory | path join "comic.cbz" | create_zip ["001.jpg" "002.jpeg"]
  assert equal ($cbz | get_image_extension) "jpeg"
  rm --recursive $directory
}

export def test_get_image_extension_mixed [] {
  let directory = mktemp --directory --tmpdir
  "" | save ($directory | path join "001.jpg")
  "" | save ($directory | path join "002.png")
  let cbz = $directory | path join "comic.cbz" | create_zip ["001.jpg" "002.png"]
  assert equal ($cbz | get_image_extension) null
  rm --recursive $directory
}
