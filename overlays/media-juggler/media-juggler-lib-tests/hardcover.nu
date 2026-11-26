# Tests for the hardcover functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *
use helpers/assertions.nu *

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
    # The series isn't marked as completed, so the count isn't final.
    total_issue_count: null
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
  assert_equal_deep ($input | parse_hardcover_edition) $expected
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

export def test_parse_hardcover_contribution_standardized_role [] {
  let input = {
    contribution: "Artist: Touch-up"
    primary_override: null
    contributor_role: {name: Artist primary: false}
    contributor_specialization: {name: Touch-up}
  }
  assert equal ($input | parse_hardcover_contribution) {role: Artist specialization: Touch-up primary: false}
}

export def test_parse_hardcover_contribution_primary_role [] {
  let input = {
    contribution: Mangaka
    primary_override: null
    contributor_role: {name: Mangaka primary: true}
    contributor_specialization: null
  }
  assert equal ($input | parse_hardcover_contribution) {role: Mangaka specialization: null primary: true}
}

export def test_parse_hardcover_contribution_primary_override [] {
  let input = {
    contribution: "Original Story"
    primary_override: true
    contributor_role: {name: "Original Story" primary: false}
    contributor_specialization: null
  }
  assert equal ($input | parse_hardcover_contribution | get primary) true
  let input = $input | update primary_override false | update contributor_role {name: Author primary: true}
  assert equal ($input | parse_hardcover_contribution | get primary) false
}

export def test_parse_hardcover_contribution_legacy_string [] {
  assert equal ({contribution: "Illustrator"} | parse_hardcover_contribution) {role: Illustrator specialization: null primary: false}
}

export def test_parse_hardcover_contribution_legacy_string_with_specialization [] {
  assert equal ({contribution: "Artist: Touch-up"} | parse_hardcover_contribution) {role: Artist specialization: Touch-up primary: false}
}

export def test_parse_hardcover_contribution_legacy_without_role [] {
  assert equal ({contribution: null} | parse_hardcover_contribution) {role: Author specialization: null primary: false}
}

export def test_hardcover_contribution_roles_author [] {
  assert equal ({role: Author specialization: null} | hardcover_contribution_roles) [Writer]
  assert equal ({role: Author specialization: Lead} | hardcover_contribution_roles) [Writer]
}

export def test_hardcover_contribution_roles_original_story [] {
  assert equal ({role: "Original Story" specialization: null} | hardcover_contribution_roles) [Writer]
}

export def test_hardcover_contribution_roles_mangaka [] {
  assert equal ({role: Mangaka specialization: null} | hardcover_contribution_roles) [Writer Artist "Cover Artist" Cover]
}

export def test_hardcover_contribution_roles_illustrator [] {
  assert equal ({role: Illustrator specialization: null} | hardcover_contribution_roles) [Artist]
  assert equal ({role: Illustrator specialization: Assistant} | hardcover_contribution_roles) [Artist]
}

export def test_hardcover_contribution_roles_cover_artist [] {
  assert equal ({role: "Cover Artist" specialization: null} | hardcover_contribution_roles) ["Cover Artist" Cover Artist]
  assert equal ({role: "Cover Artist" specialization: Variant} | hardcover_contribution_roles) ["Cover Artist" Cover Artist]
}

export def test_hardcover_contribution_roles_cover_specialization [] {
  assert equal ({role: Colorist specialization: Cover} | hardcover_contribution_roles) ["Cover Artist" Cover Artist]
  assert equal ({role: Penciller specialization: Cover} | hardcover_contribution_roles) ["Cover Artist" Cover Artist]
  assert equal ({role: Illustrations specialization: Cover} | hardcover_contribution_roles) ["Cover Artist" Cover Artist]
}

export def test_hardcover_contribution_roles_lettering [] {
  assert equal ({role: Lettering specialization: null} | hardcover_contribution_roles) [Letterer]
  assert equal ({role: Letterer specialization: Cover} | hardcover_contribution_roles) [Letterer]
}

export def test_hardcover_contribution_roles_translation [] {
  assert equal ({role: Translation specialization: null} | hardcover_contribution_roles) [Translator]
  assert equal ({role: Translator specialization: Revised} | hardcover_contribution_roles) [Translator]
}

export def test_hardcover_contribution_roles_editor [] {
  assert equal ({role: Editor specialization: Executive} | hardcover_contribution_roles) [Editor]
  assert equal ({role: "Series Editor" specialization: null} | hardcover_contribution_roles) [Editor]
}

export def test_hardcover_contribution_roles_unmapped_specializations [] {
  assert equal ({role: Artist specialization: Touch-up} | hardcover_contribution_roles) ["Artist • Touch-up"]
  assert equal ({role: Translator specialization: "Original Story"} | hardcover_contribution_roles) ["Translator • Original Story"]
}

export def test_hardcover_contribution_roles_unmapped_role [] {
  assert equal ({role: Supervisor specialization: null} | hardcover_contribution_roles) [Supervisor]
  assert equal ({role: Consultant specialization: Historical} | hardcover_contribution_roles) ["Consultant • Historical"]
}

export def test_parse_hardcover_edition_berserk_volume_43_credits [] {
  let input = open ([$test_data_dir "berserk-volume-43-ebook-edition-hardcover.json"] | path join)
  let expected = [
    [person id role primary language];
    ["Kōji Mori" "656937" Supervisor false ""]
    ["Duane Johnson" "336068" Translator false ""]
    ["Studio Cutie" "405193" "Artist • Touch-up" false ""]
    ["Studio Cutie" "405193" Letterer false ""]
    ["Carl Gustav Horn" "378276" Editor false ""]
    ["Kentaro Miura" "252214" Writer true ""]
    ["Studio Gaga" "656935" Writer true ""]
    ["Studio Gaga" "656935" Artist true ""]
    ["Studio Gaga" "656935" "Cover Artist" true ""]
    ["Studio Gaga" "656935" Cover true ""]
  ]
  assert_equal_deep ($input | parse_hardcover_edition | get credits) $expected
}

export def test_parse_hardcover_edition_berserk_volume_43_is_valid_comic [] {
  let input = open ([$test_data_dir "berserk-volume-43-ebook-edition-hardcover.json"] | path join)
  assert equal ($input | parse_hardcover_edition | validate_book_metadata hardcover comic) {valid: true errors: []}
}

export def test_parse_hardcover_edition_issue_count_ongoing_series [] {
  let metadata = berserk_volume_43_edition | parse_hardcover_edition
  # The number of books so far is used to put books from a series in the same directory.
  assert equal $metadata.issue_count 43
  # The count isn't final for an ongoing series, so it isn't used for the Count in ComicInfo.xml.
  assert equal $metadata.total_issue_count null
}

export def test_parse_hardcover_edition_issue_count_completed_series [] {
  let metadata = berserk_volume_43_edition | update book.featured_book_series.series.is_completed true | parse_hardcover_edition
  assert equal $metadata.issue_count 43
  assert equal $metadata.total_issue_count 43
}

# The Berserk, Vol. 43 edition from Hardcover, which is only identified as manga by the Manga genre
def berserk_volume_43_edition []: nothing -> record {
  open ([$test_data_dir "berserk-volume-43-ebook-edition-hardcover.json"] | path join)
}

# Remove the Manga genre from an edition from Hardcover
def remove_manga_genre []: record -> record {
  let edition = $in
  $edition | update book.cached_tags.Genre ($edition.book.cached_tags.Genre | where tag != Manga)
}

# Add a tag to the cached tags in a category for an edition from Hardcover
def add_cached_tag [category: string tag: string]: record -> record {
  let edition = $in
  let cached_tags = $edition.book.cached_tags
  $edition | update book.cached_tags (
    $cached_tags | update $category (
      $cached_tags | get $category | append {
        tag: $tag
        count: 1
        tagSlug: ($tag | str downcase)
        category: $category
        categorySlug: ($category | str downcase)
        spoilerRatio: 0.0
      }
    )
  )
}

export def test_parse_hardcover_edition_manga_from_manga_genre [] {
  let metadata = berserk_volume_43_edition | parse_hardcover_edition
  assert equal $metadata.manga true
  assert equal $metadata.forms_of_creative_work ["manga volume"]
}

export def test_parse_hardcover_edition_not_manga_without_manga_genre [] {
  let metadata = berserk_volume_43_edition | remove_manga_genre | parse_hardcover_edition
  assert equal $metadata.manga false
  assert not ("manga volume" in $metadata.forms_of_creative_work)
}

export def test_parse_hardcover_edition_manga_from_lowercase_manga_genre [] {
  let metadata = berserk_volume_43_edition | remove_manga_genre | add_cached_tag Genre manga | parse_hardcover_edition
  assert equal $metadata.manga true
}

export def test_parse_hardcover_edition_manga_from_manga_tag [] {
  let metadata = berserk_volume_43_edition | remove_manga_genre | add_cached_tag Tag Manga | parse_hardcover_edition
  assert equal $metadata.manga true
}

export def test_parse_hardcover_edition_manga_from_title [] {
  let metadata = berserk_volume_43_edition | remove_manga_genre | update title "Berserk (Manga), Vol. 43" | parse_hardcover_edition
  assert equal $metadata.manga true
}

export def test_parse_hardcover_edition_manga_from_series_name [] {
  let metadata = berserk_volume_43_edition | remove_manga_genre | update book.featured_book_series.series.name "Berserk (Manga)" | parse_hardcover_edition
  assert equal $metadata.manga true
}

export def test_parse_hardcover_edition_manga_only_for_graphic_novels [] {
  # Book category 1 is "book" instead of "graphic novel"
  let metadata = berserk_volume_43_edition | update book.book_category_id 1 | parse_hardcover_edition
  assert equal ($metadata | get --optional manga) null
}
