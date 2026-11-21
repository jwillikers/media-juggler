# Tests for the hardcover functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

const test_data_dir = path self ../test-data

export def test_parse_hardcover_edition_tsukimichi_volume_1 [] {
  let input = (
    open ([$test_data_dir "tsukimichi-volume-1-ebook-edition-hardcover.json"] | path join)
  )
  let expected = {
    issue: 1
    series: "Tsukimichi: Moonlit Fantasy"
    title: "Tsukimichi: Moonlit Fantasy, Vol. 1"
    description: "Makoto Misumi..."
    volume: 2013
    issue_count: 21
    ids: [
      [type, id];
      [hardcover_book_slug, "tsukimichi-moonlit-fantasy-light-novel-vol-1"]
      [hardcover_edition_id, "32336811"]
      [open_library_edition_id, "OL62344989M"]
    ]
    isbn: "9781961788145"
    characters: null
    language: "english"
    forms_of_creative_work: ["light novel"]
    literary_type: "fiction"
    genres: ["adventure" "fantasy" "isekai"]
    tags: []
    publication_date: "2024-03-30"
    publishers: ["Hanashi Media"]
    credits: [
      [person, id, role, primary, language];
      ["Kei Azumi", "1221140", Writer, false, ""]
      ["Mitsuaki Matsumoto", "1221151", Artist, false, ""]
      ["Mitsuaki Matsumoto", "1221151", "Cover Artist", false, ""]
      ["Mitsuaki Matsumoto", "1221151", Cover, false, ""]
      ["Mittt Liu", "724696", Translator, false, ""]
      ["Jasmine Thone", "1251809", Editor, false, ""]
    ]
    series_id: 202585
    primary_series_author: "Kei Azumi"
    _cover_image: [
      0
      ""
      "https://assets.hardcover.app/edition/32336811/0b805f28-8f88-411b-ae96-3ab83e5b9d69.jpg"
      1400
      2061
    ]
  }
  # log debug $"parsed hardcover edition: ($input | parse_hardcover_edition | to nuon)"
  assert equal ($input | parse_hardcover_edition) $expected
}

export def test_standardize_hardcover_title_no_volume [] {
  assert equal ("Spice and Wolf" | standardize_hardcover_title) "Spice and Wolf"
}

export def test_standardize_hardcover_title_light_novel [] {
  assert equal ("Spice and Wolf (Light Novel), Vol. 1" | standardize_hardcover_title) "Spice and Wolf, Vol. 1"
}

export def test_standardize_hardcover_title_manga [] {
  assert equal ("Witch Hat Atelier (Manga), Vol. 2" | standardize_hardcover_title) "Witch Hat Atelier, Vol. 2"
}

export def test_standardize_hardcover_title_manhua [] {
  assert equal ("Heaven Official's Blessing (Manhua), Vol. 1" | standardize_hardcover_title) "Heaven Official's Blessing, Vol. 1"
}

export def test_standardize_hardcover_title_manhwa [] {
  assert equal ("Solo Leveling (Manhwa), Vol. 1" | standardize_hardcover_title) "Solo Leveling, Vol. 1"
}

export def test_standardize_hardcover_title_after_punctuation [] {
  assert equal ("Kaguya-sama: Love Is War! (Manga), Vol. 2" | standardize_hardcover_title) "Kaguya-sama: Love Is War! Vol. 2"
}
