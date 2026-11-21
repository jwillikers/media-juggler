# Tests for the metadata functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

export def test_parse_genres_and_tags_empty_genres_empty_tags [] {
  let input = {
    genres: []
    tags: []
  }
  let expected = $input
  assert equal ($input | parse_genres_and_tags) $expected
}

export def test_parse_genres_and_tags_genres_empty_tags [] {
  let input = {
    genres: [
      [name count];
      ["dark fantasy" 1]
      ["fiction" 2]
      ["fantasy" 2]
    ]
    tags: []
  }
  let expected = {
    genres: [
      [name count];
      ["fantasy" 2]
      ["fiction" 2]
      ["dark fantasy" 1]
    ]
    tags: []
  }
  assert equal ($input | parse_genres_and_tags) $expected
}

export def test_parse_genres_and_tags_empty_genres_tags [] {
  let input = {
    genres: []
    tags: [
      [name count];
      ["dark fantasy" 1]
      ["fiction" 2]
      ["fantasy" 2]
      ["unabridged" 1]
    ]
  }
  let expected = {
    genres: [
      [name count];
      ["fantasy" 2]
      ["fiction" 2]
      ["dark fantasy" 1]
    ]
    tags: [
      [name count];
      ["unabridged" 1]
    ]
  }
  assert equal ($input | parse_genres_and_tags) $expected
}

export def test_parse_genres_and_tags_genres_tags [] {
  let input = {
    genres: [
      [name count];
      ["special" 1]
      ["fiction" 3]
    ]
    tags: [
      [name count];
      ["dark fantasy" 1]
      ["fiction" 2]
      ["fantasy" 2]
      ["unabridged" 1]
      ["explicit" 2]
      ["abridged" 2]
    ]
  }
  let expected = {
    genres: [
      [name count];
      ["fiction" 3]
      ["fantasy" 2]
      ["dark fantasy" 1]
      ["special" 1]
    ]
    tags: [
      [name count];
      ["abridged" 2]
      ["explicit" 2]
      ["unabridged" 1]
    ]
  }
  assert equal ($input | parse_genres_and_tags) $expected
}

export def test_from_language_code_unsupported_code [] {
  let input = "english"
  assert error {|| $input | from_language_code $iso_language_codes_map}
}

export def test_from_language_code_duplicate_languages [] {
  let input = "engl"
  let codes = [
    [language iso_639_1 iso_639_3];
    ["english" "en" "eng"]
    ["english" "en" "eng"]
  ]
  assert error {|| $input | from_language_code $codes}
}

export def test_from_language_code_en [] {
  let input = "en"
  let expected = "english"
  assert equal ($input | from_language_code $iso_language_codes_map) $expected
}

export def test_from_language_code_eng [] {
  let input = "eng"
  let expected = "english"
  assert equal ($input | from_language_code $iso_language_codes_map) $expected
}

export def test_into_language_code_unsupported_language [] {
  let input = "spanglish"
  let codes = [
    [language iso_639_1 iso_639_3];
    ["english" "en" "eng"]
  ]
  assert error {|| $input | into_language_code iso_639_1 $codes}
}

export def test_into_language_code_unsupported_language_code [] {
  let input = "english"
  let codes = [
    [language iso_639_1 iso_639_3];
    ["english" "en" "eng"]
  ]
  assert error {|| $input | into_language_code ietf_null $codes}
}

export def test_into_language_code_duplicate_languages [] {
  let input = "en"
  let codes = [
    [language iso_639_1 iso_639_3];
    ["english" "en" "eng"]
    ["english" "en" "eng"]
  ]
  assert error {|| $input | into_language_code iso_639_1 $codes}
}

export def test_into_language_code_en [] {
  let input = "english"
  let expected = "en"
  assert equal ($input | into_language_code iso_639_1 $iso_language_codes_map) $expected
}

export def test_into_language_code_eng [] {
  let input = "english"
  let expected = "eng"
  assert equal ($input | into_language_code iso_639_3 $iso_language_codes_map) $expected
}

export def test_sanitize_genres_or_tags_empty_allowlist [] {
  let input = [coming-of-age fantasy romantasy]
  assert error {|| $input | sanitize_genres_or_tags []}
}

export def test_sanitize_genres_or_tags_empty_input [] {
  let input = []
  assert equal ($input | sanitize_genres_or_tags $genre_allowlist) []
}

export def test_sanitize_genres_or_tags_duplicate_tags [] {
  let input = [coming-of-age fantasy romantasy]
  let allowlist = [
    [name aliases];
    [coming-of-age ["coming of age"]]
    [fantasy []]
    ["romantic fantasy" [romantasy fantasy]]
  ]
  assert error {|| $input | sanitize_genres_or_tags $allowlist}
}

export def test_sanitize_genres_or_tags_simple [] {
  let input = [coming-of-age fantasy romantasy]
  let allowlist = [
    [name aliases];
    [coming-of-age ["coming of age"]]
    [fantasy []]
    ["romantic fantasy" [romantasy]]
  ]
  let expected = ["coming-of-age" fantasy "romantic fantasy"]
  assert equal ($input | sanitize_genres_or_tags $allowlist) $expected
}

export def test_sanitize_genres_or_tags_case [] {
  let input = ["Coming of Age" Fantasy Romantasy]
  let allowlist = [
    [name aliases];
    [coming-of-age ["coming of age"]]
    [fantasy []]
    ["Romantic Fantasy" [romantasy]]
  ]
  let expected = ["Romantic Fantasy" coming-of-age fantasy]
  assert equal ($input | sanitize_genres_or_tags $allowlist) $expected
}
