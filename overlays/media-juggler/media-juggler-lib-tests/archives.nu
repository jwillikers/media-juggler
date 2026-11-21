# Tests for the archives functions in media-juggler-lib

use std assert

use ../media-juggler-lib *

export def test_escape_unzip_path_plain [] {
  assert equal ("pages/001.jpg" | escape_unzip_path) "pages/001.jpg"
}

export def test_escape_unzip_path_special_characters [] {
  assert equal ("[Group] Vol? 1*.jpg" | escape_unzip_path) "[[]Group] Vol[?] 1[*].jpg"
}
