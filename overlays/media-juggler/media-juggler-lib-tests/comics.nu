# Tests for the comics functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *
use helpers/assertions.nu *

const test_data_dir = path self ../test-data

export def test_from_comic_info_xml_march_comes_in_like_a_lion_vol_1 [] {
  let input = open ([$test_data_dir "March Comes in Like a Lion v001_ComicInfo.xml"] | path join)
  let $expected = {
    issue_id: "4000-987377"
    series: "March Comes in Like a Lion"
    issue: "1"
    credits: [
      [person, role, primary, language];
      ["Chica Umino", Artist, false, ""]
      ["Chica Umino", Cover, false, ""]
      ["Chica Umino", Writer, false, ""]
      ["Jocelyne Allen", Translator, false, ""]
    ]
    ids: [
      [type, id];
      [bookbrainz_edition_id, "594a8ec2-6301-4c20-ae22-2c43840416b2"]
      [comic_vine_issue_id, "4000-987377"]
      [hardcover_book_slug, "march-comes-in-like-a-lion-vol-1"]
      [hardcover_edition_id, "32873036"]
      [open_library_edition_id, "OL61662902M"]
      [wikidata_item_id, "Q139556252"]
    ]
    language: "american english"
    isbn: "9781634428132"
    manga: "YesAndRightToLeft"
    description: "Summary of March Comes in Like a Lion.

## Chapter Titles
* Chapter 1
* Chapter 2
* Chapter 3
* Chapter 10: Over the Cuckoo&apos;s Nest"
    publication_date: ("2023-05-01T00:00:00" | into datetime --timezone UTC)
    publishers: ["Denpa, LLC"]
    imprints: ["Denpa"]
    year: "2023"
    month: "05"
    day: "01"
    genres: [
      coming-of-age
      romance
      "slice of life"
    ]
    tags: [
      seinen
      shogi
    ],
    page_count: "187"
  }
  assert_equal_deep ($input | from_comic_info_xml) $expected
}

# Not exported, so the test runner skips it.
# todo Fill in the expected metadata and enable this test.
def test_from_metron_info_xml_march_comes_in_like_a_lion_vol_1 [] {
  let input = open ([$test_data_dir "March Comes in Like a Lion v001_MetronInfo.xml"] | path join)
  let $expected = {

  }
  # assert equal ($input | from_metron_info_xml) $expected
}

export def test_into_comic_info_xml_march_comes_in_like_a_lion_vol_1 [] {
  let $input = {
    series: "March Comes in Like a Lion"
    issue: "1"
    description: "Summary of March Comes in Like a Lion.

## Chapter Titles
* Chapter 1
* Chapter 2
* Chapter 3
* Chapter 10: Over the Cuckoo&apos;s Nest"
    # publication_date: ("2023-05-01" | into datetime --timezone UTC)
    year: "2023"
    month: "05"
    day: "01"
    publication_date: ("2023-05-01" | into datetime)
    volume: "2023"
    issue_count: "4"
    credits: [
      [person role primary language];
      # ["Chica Umino" Inker false ""]
      # ["Chica Umino" Penciller false ""]
      ["Chica Umino" Artist false ""]
      ["Chica Umino" Cover false ""]
      ["Chica Umino" Writer false ""]
      ["Jocelyne Allen" Translator false ""]
    ]
    # narrative: [
    #   [locations];
    #   [[Japan]]
    # ]
    genres: [coming-of-age romance "slice of life"]
    tags: [seinen shogi]
    ids: [
      [type id];
      ["bookbrainz_edition_id" "594a8ec2-6301-4c20-ae22-2c43840416b2"]
      ["comic_vine_issue_id" "4000-987377"]
      ["hardcover_book_slug" "march-comes-in-like-a-lion-vol-1"]
      ["hardcover_edition_id" "32873036"]
      ["wikidata_item_id" "Q139556252"]
      ["open_library_edition_id" "OL61662902M"]
    ]
    page_count: 187
    language: "american english"
    isbn: "9781634428132"
    # format: "digital"
    manga: "YesAndRightToLeft"
    publishers: ["Denpa, LLC"]
    imprints: ["Denpa"]
    # is_manga: true
    # page_reading_order: "right_to_left"
    # age_rating: "Everyone"
    # publisher: {
    #   name: "Denpa, LLC"
    #   imprint: "Denpa"
    # }
    comment: "Tagged with ComicTagger 1.6.0b11.dev0 using info from Comic Vine on 2026-04-25 15:19:05. [Issue ID 987377]"
    # series_groups: ["Example Series Group", "Another"]
    # story_arc: {
    #   name: "Example Story Arc"
    #   number: 1
    # }
    # alternative_series: {
    #   name: "Example Alternative Series"
    #   count: 1
    # }
  }
  let expected = open ([$test_data_dir "March Comes in Like a Lion v001_ComicInfo.xml"] | path join)
  # log debug $"output: \n($input | into_comic_info_xml | to xml)\n"
  # log debug $"output: \n($input | into_comic_info_xml | to nuon)\n"
  let output = ($input | into_comic_info_xml)
  # Notes field is based on date and time as well as version.
  # Just make sure it contains the Comic Vine ID in the required format.
  assert ("ComicVine [CVDB987377]" in ($output.content | where tag == "Notes" | first | get content | first | get content))
  let output = (
    $output
    | update content (
      $output.content | where tag != Notes
    )
  )
  assert equal $output $expected
}
