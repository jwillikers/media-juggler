# Tests for the wikidata functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

const test_data_dir = path self ../test-data

export def test_parse_wikidata_edition_and_works_metadata_one_piece_volume_1 [] {
  let input = {
    edition: (open ([$test_data_dir "one-piece-volume-1-ebook-edition-wikidata-item.json"] | path join))
    works: [(open ([$test_data_dir "one-piece-volume-1-work-wikidata-item.json"] | path join))]
  }
  # log debug $"\n($input | parse_wikidata_edition_and_works_metadata | to nuon)\n"
  let expected = {
    comic_info_age_rating: "PG"
    forms_of_creative_work: ["manga" "manga volume"]
    genres: [adventure "comedy drama" "science fantasy"]
    intended_publics: [shōnen]
    language: "english"
    manga: "YesAndRightToLeft"
    publication_date: ("2010-11-02T00:00:00Z" | into datetime --timezone UTC)
    publishers: [
      [wikidata_id, object_named_as];
      ["Q133698002" []]
      ["Q139571225" []]
    ],
    tags: [manga shōnen]
  }
  assert equal ($input | parse_wikidata_edition_and_works_metadata) $expected
}

# todo Should write more tests for parse_wikidata_edition_and_works_metadata
# todo Test main_subject functionality.
