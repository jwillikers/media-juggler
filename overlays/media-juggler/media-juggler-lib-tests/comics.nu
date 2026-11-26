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
  # Kavita splits publishers on commas, so the comma is removed from the publisher "Denpa, LLC".
  let expected = (
    $expected
    | update content (
      $expected.content | each {|field|
        if $field.tag == Publisher {
          $field | update content [[tag attributes content]; [null null "Denpa LLC"]]
        } else {
          $field
        }
      }
    )
  )
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
  assert_equal_deep $output $expected
}

# A minimal ComicInfo record as parsed from XML
def comic_info_with [fields: record]: nothing -> record {
  {
    tag: ComicInfo
    attributes: {}
    content: (
      $fields | transpose tag value | each {|field|
        {
          tag: $field.tag
          attributes: {}
          content: [[tag attributes content]; [null null $field.value]]
        }
      }
    )
  }
}

export def test_upsert_comic_info_add_field [] {
  let input = comic_info_with {Series: "March Comes in Like a Lion"}
  let expected = comic_info_with {Series: "March Comes in Like a Lion" Number: "1"}
  assert_equal_deep ($input | upsert_comic_info {tag: Number value: "1"}) $expected
}

export def test_upsert_comic_info_replace_field [] {
  let input = comic_info_with {Series: "Old Series" Number: "1"}
  # The replaced field is moved to the end
  let expected = comic_info_with {Number: "1" Series: "March Comes in Like a Lion"}
  assert_equal_deep ($input | upsert_comic_info {tag: Series value: "March Comes in Like a Lion"}) $expected
}

export def test_upsert_comic_info_converts_value_to_string [] {
  let input = comic_info_with {}
  let expected = comic_info_with {Count: "16"}
  assert_equal_deep ($input | upsert_comic_info {tag: Count value: 16}) $expected
}

export def test_upsert_comic_info_empty_value [] {
  let input = comic_info_with {Series: "March Comes in Like a Lion"}
  assert_equal_deep ($input | upsert_comic_info {tag: Number value: ""}) $input
  assert_equal_deep ($input | upsert_comic_info {tag: Number value: null}) $input
}

export def test_drop_field_comic_info [] {
  let input = comic_info_with {Series: "March Comes in Like a Lion" Number: "1"}
  let expected = comic_info_with {Series: "March Comes in Like a Lion"}
  assert_equal_deep ($input | drop_field_comic_info Number) $expected
}

export def test_drop_field_comic_info_missing_field [] {
  let input = comic_info_with {Series: "March Comes in Like a Lion"}
  assert_equal_deep ($input | drop_field_comic_info Number) $input
}

export def test_upsert_comic_info_content [] {
  let input = comic_info_with {Series: "March Comes in Like a Lion"}
  let pages = [
    [tag attributes content];
    [Page {Image: "0" Type: FrontCover} []]
  ]
  let expected = (
    $input
    | update content {|comic_info|
      $comic_info.content | append {tag: Pages attributes: {} content: $pages}
    }
  )
  assert_equal_deep ($input | upsert_comic_info_content {tag: Pages content: $pages}) $expected
}

export def test_parse_comic_vine_issue_and_volume [] {
  let input = {
    issue: {
      id: 123456
      issue_number: "1"
      name: "Rei Kiriyama's Story"
      description: "<p>The first volume.</p>"
      store_date: "2023-05-01"
      volume: {id: 98765 name: "March Comes in Like a Lion"}
      person_credits: [
        {id: 1 name: "Chica Umino" role: "writer, artist"}
        {id: 2 name: "Some Editor" role: "editor"}
      ]
      character_credits: [
        {id: 10 name: "Rei Kiriyama" api_detail_url: "https://comicvine.gamespot.com/api/character/4005-10/"}
      ]
      image: {original_url: "https://comicvine.gamespot.com/a/uploads/original/1.jpg"}
    }
    volume: {
      start_year: "2023"
      count_of_issues: 16
      publisher: {name: "Denpa"}
    }
  }
  let expected = {
    issue_id: 123456
    issue: "1"
    series: "March Comes in Like a Lion"
    title: "Rei Kiriyama’s Story"
    description: "<p>The first volume.</p>"
    volume: "2023"
    issue_count: 16
    ids: []
    characters: [[name id]; ["Rei Kiriyama" 10]]
    genres: []
    tags: []
    publication_date: ("2023-05-01" | into datetime)
    year: "2023"
    month: "05"
    day: "01"
    publishers: [Denpa]
    credits: [
      [person id role primary language];
      ["Chica Umino" 1 Writer false ""]
      ["Chica Umino" 1 Artist false ""]
      ["Some Editor" 2 Editor false ""]
    ]
    series_id: 98765
    _cover_image: [0 "" "https://comicvine.gamespot.com/a/uploads/original/1.jpg"]
  }
  assert_equal_deep ($input | parse_comic_vine_issue_and_volume) $expected
}

export def test_parse_comic_vine_issue_and_volume_without_name_or_date [] {
  let input = {
    issue: {
      id: 1
      issue_number: "2"
      description: null
      volume: {id: 2 name: "Series"}
      person_credits: []
      character_credits: []
      image: {original_url: ""}
    }
    volume: {start_year: "2020" count_of_issues: 3 publisher: {name: "Publisher"}}
  }
  let actual = $input | parse_comic_vine_issue_and_volume
  assert equal $actual.title null
  assert equal $actual.publication_date null
  assert equal $actual.year null
  assert equal $actual.credits []
}

export def test_into_comic_info_xml_credits_from_hardcover_roles [] {
  let input = open ([$test_data_dir "berserk-volume-43-ebook-edition-hardcover.json"] | path join) | parse_hardcover_edition
  let creators = (
    $input
    | into_comic_info_xml
    | get content
    | where tag in [Writer Penciller Inker Colorist Letterer CoverArtist Editor Translator]
    | each {|field| {tag: $field.tag value: $field.content.0.content} }
    | sort-by tag
  )
  let expected = [
    [tag value];
    [Colorist "Studio Gaga"]
    [CoverArtist "Studio Gaga"]
    [Editor "Carl Gustav Horn"]
    [Inker "Studio Gaga"]
    [Letterer "Studio Cutie"]
    [Penciller "Studio Gaga"]
    [Translator "Duane Johnson"]
    [Writer "Kentaro Miura,Studio Gaga"]
  ]
  assert_equal_deep $creators $expected
}

export def test_sanitize_comic_info_name [] {
  assert equal ("Studio Gaga" | sanitize_comic_info_name) "Studio Gaga"
  assert equal ("Yen Press, LLC" | sanitize_comic_info_name) "Yen Press LLC"
  assert equal (" A ,B " | sanitize_comic_info_name) "A B"
}

export def test_comic_info_manga_value [] {
  assert equal (true | comic_info_manga_value) "Yes"
  assert equal (false | comic_info_manga_value) "No"
  assert equal ("YesAndRightToLeft" | comic_info_manga_value) "YesAndRightToLeft"
}

# Get the value of each field in a ComicInfo record
def comic_info_fields []: record -> record {
  $in.content | reduce --fold {} {|field acc| $acc | insert $field.tag $field.content.0.content }
}

export def test_into_comic_info_xml_for_kavita_manga_volume [] {
  let input = open ([$test_data_dir "berserk-volume-43-ebook-edition-hardcover.json"] | path join) | parse_hardcover_edition | update manga YesAndRightToLeft
  let fields = $input | into_comic_info_xml | comic_info_fields
  # Kavita treats Volume as the volume number and Number as the chapter number, so a manga volume only has a Volume.
  assert equal $fields.Volume "43"
  assert ("Number" not-in $fields)
  # Kavita marks a series completed when it has the volume equal to Count, so Count is only set for completed series.
  assert ("Count" not-in $fields)
  assert equal $fields.Manga "YesAndRightToLeft"
  assert equal $fields.Series "Berserk"
  assert equal $fields.GTIN "9781506757285"
  assert equal $fields.LanguageISO "en"
  assert equal $fields.AgeRating "Teen"
  assert equal $fields.Publisher "Dark Horse Manga"
  assert equal $fields.Web "https://hardcover.app/books/berserk-vol-43/editions/33323254"
  assert equal [$fields.Year $fields.Month $fields.Day] ["2026" "11" "24"]
}

export def test_into_comic_info_xml_manga_boolean [] {
  let input = open ([$test_data_dir "berserk-volume-43-ebook-edition-hardcover.json"] | path join) | parse_hardcover_edition
  assert equal ($input | into_comic_info_xml | comic_info_fields | get Manga) "Yes"
}

export def test_into_comic_info_xml_not_manga_boolean [] {
  let input = open ([$test_data_dir "berserk-volume-43-ebook-edition-hardcover.json"] | path join) | parse_hardcover_edition | update manga false
  let fields = $input | into_comic_info_xml | comic_info_fields
  assert equal $fields.Manga "No"
  # Comics which aren't manga are numbered by issue
  assert equal $fields.Number "43"
}

export def test_into_comic_info_xml_names_with_commas [] {
  let input = (
    open ([$test_data_dir "berserk-volume-43-ebook-edition-hardcover.json"] | path join)
    | parse_hardcover_edition
    | update publishers ["Yen Press, LLC"]
    | update credits {|metadata| $metadata.credits | append {person: "Doe, Jane" id: "1" role: Editor primary: false language: ""} }
  )
  let fields = $input | into_comic_info_xml | comic_info_fields
  assert equal $fields.Publisher "Yen Press LLC"
  assert equal $fields.Editor "Carl Gustav Horn,Doe Jane"
}
