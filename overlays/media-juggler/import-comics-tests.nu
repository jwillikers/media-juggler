#!/usr/bin/env nu

use std assert
use std log

use media-juggler-lib *

let test_data_dir = ([$env.FILE_PWD "test-data"] | path join)

def test_is_identifier_valid_empty_type [] {
  let input = "1595def0-f6aa-4eb2-9f95-089582754f54"
  assert error {|| ($input | is_identifier_valid "")}
}

def test_is_identifier_valid_invalid_type [] {
  let input = "1595def0-f6aa-4eb2-9f95-089582754f54"
  assert error {|| ($input | is_identifier_valid "comicbrainz_edition_id")}
}

def test_is_identifier_valid_bookbrainz_edition_id_valid_empty [] {
  let input = ""
  assert equal ($input | is_identifier_valid "bookbrainz_edition_id") false
}

def test_is_identifier_valid_bookbrainz_edition_id_valid [] {
  let input = "1595def0-f6aa-4eb2-9f95-089582754f54"
  assert equal ($input | is_identifier_valid "bookbrainz_edition_id") true
}

def test_is_identifier_valid_bookbrainz_edition_id_invalid_missing_number [] {
  let input = "1595def0-f6aa-4eb2-9f95-089582754f5"
  assert equal ($input | is_identifier_valid "bookbrainz_edition_id") false
}

def test_is_identifier_valid_bookbrainz_edition_id_invalid_additional_number [] {
  let input = "1595def0-4f6aa-4eb2-9f95-089582754f54"
  assert equal ($input | is_identifier_valid "bookbrainz_edition_id") false
}

def test_is_identifier_valid_bookbrainz_work_id_valid [] {
  let input = "1eddc6be-03b9-45eb-841c-ab8d9d589c94"
  assert equal ($input | is_identifier_valid "bookbrainz_work_id") true
}

def test_is_identifier_valid_bookbrainz_work_id_invalid [] {
  let input = "1eddc6be-03b9-45eb841c-ab8d9d589c94"
  assert equal ($input | is_identifier_valid "bookbrainz_work_id") false
}

def test_is_identifier_valid_comic_vine_issue_id_valid [] {
  let input = "4000-987377"
  assert equal ($input | is_identifier_valid "comic_vine_issue_id") true
}

def test_is_identifier_valid_comic_vine_issue_id_invalid [] {
  let input = "987377"
  assert equal ($input | is_identifier_valid "comic_vine_issue_id") false
}

def test_is_identifier_valid_hardcover_book_slug_valid [] {
  let input = "march-comes-in-like-a-lion-vol-1"
  assert equal ($input | is_identifier_valid "hardcover_book_slug") true
}

def test_is_identifier_valid_hardcover_book_slug_invalid [] {
  let input = "march-comes-in-like-a-lion-vol-1/editions"
  assert equal ($input | is_identifier_valid "hardcover_book_slug") false
}

def test_is_identifier_valid_hardcover_edition_id_valid [] {
  let input = "32873036"
  assert equal ($input | is_identifier_valid "hardcover_edition_id") true
}

def test_is_identifier_valid_hardcover_edition_id_invalid [] {
  let input = "32873036X"
  assert equal ($input | is_identifier_valid "hardcover_edition_id") false
}

def test_is_identifier_valid_metron_issue_id_valid [] {
  let input = "57342"
  assert equal ($input | is_identifier_valid "metron_issue_id") true
}

def test_is_identifier_valid_metron_issue_id_invalid [] {
  let input = "4000-57342"
  assert equal ($input | is_identifier_valid "metron_issue_id") false
}

def test_is_identifier_valid_open_library_edition_id_valid [] {
  let input = "OL6682530M"
  assert equal ($input | is_identifier_valid "open_library_edition_id") true
}

def test_is_identifier_valid_open_library_edition_id_invalid [] {
  let input = "OL1099280W"
  assert equal ($input | is_identifier_valid "open_library_edition_id") false
}

def test_is_identifier_valid_open_library_work_id_valid [] {
  let input = "OL1099280W"
  assert equal ($input | is_identifier_valid "open_library_work_id") true
}

def test_is_identifier_valid_open_library_work_id_invalid [] {
  let input = "OL6682530M"
  assert equal ($input | is_identifier_valid "open_library_work_id") false
}

def test_is_identifier_valid_wikidata_item_id_valid [] {
  let input = "Q1234"
  assert equal ($input | is_identifier_valid "wikidata_item_id") true
}

def test_is_identifier_valid_wikidata_item_id_invalid [] {
  let input = "QQ1234"
  assert equal ($input | is_identifier_valid "wikidata_item_id") false
  let input = "1234"
  assert equal ($input | is_identifier_valid "wikidata_item_id") false
}

def test_is_identifier_valid [] {
  test_is_identifier_valid_empty_type
  test_is_identifier_valid_invalid_type
  test_is_identifier_valid_bookbrainz_edition_id_valid_empty
  test_is_identifier_valid_bookbrainz_edition_id_valid
  test_is_identifier_valid_bookbrainz_edition_id_invalid_missing_number
  test_is_identifier_valid_bookbrainz_edition_id_invalid_additional_number
  test_is_identifier_valid_bookbrainz_work_id_valid
  test_is_identifier_valid_bookbrainz_work_id_invalid
  test_is_identifier_valid_comic_vine_issue_id_valid
  test_is_identifier_valid_comic_vine_issue_id_invalid
  test_is_identifier_valid_metron_issue_id_valid
  test_is_identifier_valid_metron_issue_id_invalid
  test_is_identifier_valid_hardcover_book_slug_valid
  test_is_identifier_valid_hardcover_book_slug_invalid
  test_is_identifier_valid_hardcover_edition_id_valid
  test_is_identifier_valid_hardcover_edition_id_invalid
  test_is_identifier_valid_open_library_edition_id_valid
  test_is_identifier_valid_open_library_edition_id_invalid
  test_is_identifier_valid_open_library_work_id_valid
  test_is_identifier_valid_open_library_work_id_invalid
  test_is_identifier_valid_wikidata_item_id_valid
  test_is_identifier_valid_wikidata_item_id_invalid
}

def test_identifier_from_url_empty_url [] {
  let input = ""
  assert error {|| ($input | identifier_from_url "bookbrainz_edition_id")}
}

def test_identifier_from_url_empty_type [] {
  let input = "https://bookbrainz.org/work/594a8ec2-6301-4c20-ae22-2c43840416b2"
  assert error {|| ($input | identifier_from_url "")}
}

def test_identifier_from_url_invalid_type [] {
  let input = "https://comicbrainz.org/work/594a8ec2-6301-4c20-ae22-2c43840416b2"
  assert error {|| ($input | identifier_from_url "comicbrainz_edition_id")}
}

def test_identifier_from_url_bookbrainz_edition_id_work_url [] {
  let input = "https://bookbrainz.org/work/594a8ec2-6301-4c20-ae22-2c43840416b2"
  assert equal ($input | identifier_from_url "bookbrainz_edition_id") {}
}

def test_identifier_from_url_bookbrainz_edition_id_valid_edition [] {
  let input = "https://bookbrainz.org/edition/594a8ec2-6301-4c20-ae22-2c43840416b2"
  let expected = {
    bookbrainz_edition_id: "594a8ec2-6301-4c20-ae22-2c43840416b2"
  }
  assert equal ($input | identifier_from_url "bookbrainz_edition_id") $expected
}

def test_identifier_from_url_bookbrainz_edition_id_invalid_edition [] {
  let input = "https://bookbrainz.org/edition/594a8ec2-6301-4c20-ae22-2c43840416b22"
  let expected = {}
  assert equal ($input | identifier_from_url "bookbrainz_edition_id") $expected
}

def test_identifier_from_url_bookbrainz_edition_id_invalid_edition_url [] {
  let input = "https://bookbrainz.org/work/594a8ec2-6301-4c20-ae22-2c43840416b2"
  let expected = {}
  assert equal ($input | identifier_from_url "bookbrainz_edition_id") $expected
}

def test_identifier_from_url_bookbrainz_edition_id_valid_edition_http [] {
  let input = "http://bookbrainz.org/edition/594a8ec2-6301-4c20-ae22-2c43840416b2"
  let expected = {
    bookbrainz_edition_id: "594a8ec2-6301-4c20-ae22-2c43840416b2"
  }
  assert equal ($input | identifier_from_url "bookbrainz_edition_id") $expected
}

def test_identifier_from_url_comic_vine_issue_id_series_url [] {
  let input = "comicvine.gamespot.com/march-comes-in-like-a-lion/4050-150064/"
  assert equal ($input | identifier_from_url "comic_vine_issue_id") {}
}

def test_identifier_from_url_bookbrainz_work_id_edition_url [] {
  let input = "https://bookbrainz.org/edition/594a8ec2-6301-4c20-ae22-2c43840416b2"
  assert equal ($input | identifier_from_url "bookbrainz_work_id") {}
}

def test_identifier_from_url_bookbrainz_work_id_valid_work [] {
  let input = "https://bookbrainz.org/work/594a8ec2-6301-4c20-ae22-2c43840416b2"
  let expected = {
    bookbrainz_work_id: "594a8ec2-6301-4c20-ae22-2c43840416b2"
  }
  assert equal ($input | identifier_from_url "bookbrainz_work_id") $expected
}

def test_identifier_from_url_bookbrainz_work_id_invalid_work [] {
  let input = "https://bookbrainz.org/work/594a8ec2-6301-4c20-ae22-2c43840416b2a2"
  let expected = {}
  assert equal ($input | identifier_from_url "bookbrainz_work_id") $expected
}

def test_identifier_from_url_bookbrainz_work_id_invalid_work_url [] {
  let input = "https://bookbrainz.org/edition/594a8ec2-6301-4c20-ae22-2c43840416b2"
  let expected = {}
  assert equal ($input | identifier_from_url "bookbrainz_work_id") $expected
}

def test_identifier_from_url_bookbrainz_work_id_valid_work_http [] {
  let input = "http://bookbrainz.org/work/594a8ec2-6301-4c20-ae22-2c43840416b2"
  let expected = {
    bookbrainz_work_id: "594a8ec2-6301-4c20-ae22-2c43840416b2"
  }
  assert equal ($input | identifier_from_url "bookbrainz_work_id") $expected
}

def test_identifier_from_url_comic_vine_issue_id_valid_issue_slug [] {
  let input = "https://comicvine.gamespot.com/issue/4000-987377"
  let expected = {
    comic_vine_issue_id: "4000-987377"
  }
  assert equal ($input | identifier_from_url "comic_vine_issue_id") $expected
}

def test_identifier_from_url_comic_vine_issue_id_valid_issue [] {
  let input = "https://comicvine.gamespot.com/march-comes-in-like-a-lion-1-volume-1/4000-987377/"
  let expected = {
    comic_vine_issue_id: "4000-987377"
  }
  assert equal ($input | identifier_from_url "comic_vine_issue_id") $expected
}

def test_identifier_from_url_comic_vine_issue_id_invalid_edition [] {
  let input = "https://comicvine.gamespot.com/march-comes-in-like-a-lion-1-volume-1/4050-987377/"
  let expected = {}
  assert equal ($input | identifier_from_url "comic_vine_issue_id") $expected
}

def test_identifier_from_url_comic_vine_issue_id_invalid_issue_url [] {
  let input = "https://comicvine.gamespot.com/march-comes-in-like-a-lion-1-volume-1/4050-987377/"
  let expected = {}
  assert equal ($input | identifier_from_url "comic_vine_issue_id") $expected
}

def test_identifier_from_url_comic_vine_issue_id_valid_issue_http [] {
  let input = "http://comicvine.gamespot.com/march-comes-in-like-a-lion-1-volume-1/4000-987377/"
  let expected = {
    comic_vine_issue_id: "4000-987377"
  }
  assert equal ($input | identifier_from_url "comic_vine_issue_id") $expected
}

def test_identifier_from_url_hardcover_book_slug_edition_url [] {
  let input = "https://hardcover.app/books/march-comes-in-like-a-lion-vol-1/editions/32873036"
  let expected = {
    hardcover_book_slug: "march-comes-in-like-a-lion-vol-1"
  }
  assert equal ($input | identifier_from_url "hardcover_book_slug") $expected
}

def test_identifier_from_url_hardcover_book_slug_valid_book [] {
  let input = "https://hardcover.app/books/march-comes-in-like-a-lion-vol-1"
  let expected = {
    hardcover_book_slug: "march-comes-in-like-a-lion-vol-1"
  }
  assert equal ($input | identifier_from_url "hardcover_book_slug") $expected
}

def test_identifier_from_url_hardcover_book_slug_invalid_book [] {
  let input = "https://hardcover.app/books/march-comes-in-like-a-lion-vol'-1"
  let expected = {}
  assert equal ($input | identifier_from_url "hardcover_book_slug") $expected
}

def test_identifier_from_url_hardcover_book_slug_invalid_book_url [] {
  let input = "https://hardcover.app/editions/march-comes-in-like-a-lion-vol-1"
  let expected = {}
  assert equal ($input | identifier_from_url "hardcover_book_slug") $expected
}

def test_identifier_from_url_hardcover_book_slug_valid_book_http [] {
  let input = "http://hardcover.app/books/march-comes-in-like-a-lion-vol-1"
  let expected = {
    hardcover_book_slug: "march-comes-in-like-a-lion-vol-1"
  }
  assert equal ($input | identifier_from_url "hardcover_book_slug") $expected
}

def test_identifier_from_url_hardcover_edition_id_book_url [] {
  let input = "https://hardcover.app/books/march-comes-in-like-a-lion-vol-1/editions"
  let expected = {}
  assert equal ($input | identifier_from_url "hardcover_edition_id") $expected
}

def test_identifier_from_url_hardcover_edition_id_valid_edition [] {
  let input = "https://hardcover.app/books/march-comes-in-like-a-lion-vol-1/editions/32873036"
  let expected = {
    hardcover_book_slug: "march-comes-in-like-a-lion-vol-1"
    hardcover_edition_id: "32873036"
  }
  assert equal ($input | identifier_from_url "hardcover_edition_id") $expected
}

def test_identifier_from_url_hardcover_edition_id_invalid_edition [] {
  let input = "https://hardcover.app/books/march-comes-in-like-a-lion-vol-1/editions/1234X"
  let expected = {}
  assert equal ($input | identifier_from_url "hardcover_edition_id") $expected
}

def test_identifier_from_url_hardcover_edition_id_invalid_book_url [] {
  let input = "https://hardcover.app/books/march-comes-in-like-a-lion-vol'-1/editions/12345"
  let expected = {}
  assert equal ($input | identifier_from_url "hardcover_edition_id") $expected
}

def test_identifier_from_url_hardcover_edition_id_invalid_edition_url [] {
  let input = "https://hardcover.app/books/march-comes-in-like-a-lion-vol-1/edit/12345"
  let expected = {}
  assert equal ($input | identifier_from_url "hardcover_edition_id") $expected
}

def test_identifier_from_url_hardcover_edition_id_valid_edition_http [] {
  let input = "http://hardcover.app/books/march-comes-in-like-a-lion-vol-1/editions/1234"
  let expected = {
    hardcover_book_slug: "march-comes-in-like-a-lion-vol-1"
    hardcover_edition_id: "1234"
  }
  assert equal ($input | identifier_from_url "hardcover_edition_id") $expected
}

def test_identifier_from_url_metron_issue_id_series_url [] {
  let input = "https://metron.cloud/series/4376/"
  assert equal ($input | identifier_from_url "metron_issue_id") {}
}

def test_identifier_from_url_metron_issue_id_valid_issue [] {
  let input = "https://metron.cloud/issue/57342/"
  let expected = {
    metron_issue_id: "57342"
  }
  assert equal ($input | identifier_from_url "metron_issue_id") $expected
}

def test_identifier_from_url_metron_issue_id_invalid_issue [] {
  let input = "https://metron.cloud/issue/1985-2008-2/"
  let expected = {}
  assert equal ($input | identifier_from_url "metron_issue_id") $expected
}

def test_identifier_from_url_metron_issue_id_invalid_issue_url [] {
  let input = "https://metron.cloud/issues/57342/"
  let expected = {}
  assert equal ($input | identifier_from_url "metron_issue_id") $expected
}

def test_identifier_from_url_metron_issue_id_valid_issue_http [] {
  let input = "http://metron.cloud/issue/57342/"
  let expected = {
    metron_issue_id: "57342"
  }
  assert equal ($input | identifier_from_url "metron_issue_id") $expected
}

def test_identifier_from_url_open_library_edition_id_work_url [] {
  let input = "https://openlibrary.org/works/OL6682530M/Twenty_thousand_leagues_under_the_sea"
  let expected = {}
  assert equal ($input | identifier_from_url "open_library_edition_id") $expected
}

def test_identifier_from_url_open_library_edition_id_short_url [] {
  let input = "https://openlibrary.org/books/OL6682530M"
  let expected = {
    open_library_edition_id: "OL6682530M"
  }
  assert equal ($input | identifier_from_url "open_library_edition_id") $expected
}

def test_identifier_from_url_open_library_edition_id_work_url_with_edition [] {
  let input = "https://openlibrary.org/works/OL8756258W/%E9%8B%BC%E3%81%AE%E9%8C%AC%E9%87%91%E8%A1%93%E5%B8%AB_1?edition=key%3A/books/OL22737139M"
  let expected = {}
  assert equal ($input | identifier_from_url "open_library_edition_id") $expected
}

def test_identifier_from_url_open_library_edition_id_valid_edition [] {
  let input = "https://openlibrary.org/books/OL6682530M/Twenty_thousand_leagues_under_the_sea"
  let expected = {
    open_library_edition_id: "OL6682530M"
  }
  assert equal ($input | identifier_from_url "open_library_edition_id") $expected
}

def test_identifier_from_url_open_library_edition_id_invalid_edition [] {
  let input = "https://openlibrary.org/books/OL6682530W/Twenty_thousand_leagues_under_the_sea"
  let expected = {}
  assert equal ($input | identifier_from_url "open_library_edition_id") $expected
}

def test_identifier_from_url_open_library_edition_id_invalid_edition_url [] {
  let input = "https://openlibrary.org/authors/OL6682530M/Twenty_thousand_leagues_under_the_sea"
  let expected = {}
  assert equal ($input | identifier_from_url "open_library_edition_id") $expected
}

def test_identifier_from_url_open_library_edition_id_valid_edition_http [] {
  let input = "http://openlibrary.org/books/OL6682530M/Twenty_thousand_leagues_under_the_sea"
  let expected = {
    open_library_edition_id: "OL6682530M"
  }
  assert equal ($input | identifier_from_url "open_library_edition_id") $expected
}

def test_identifier_from_url_open_library_work_id_edition_url [] {
  let input = "https://openlibrary.org/books/OL1099280W/Vingt_mille_lieues_sous_les_mers?edition=twentythousandle0000vern_l0i3"
  let expected = {
    open_library_work_id: "OL1099280W"
  }
  assert equal ($input | identifier_from_url "open_library_work_id") $expected
}

def test_identifier_from_url_open_library_work_id_work_url_with_edition [] {
  let input = "https://openlibrary.org/works/OL8756258W/%E9%8B%BC%E3%81%AE%E9%8C%AC%E9%87%91%E8%A1%93%E5%B8%AB_1?edition=key%3A/books/OL22737139M"
  let expected = {
    open_library_work_id: "OL8756258W"
  }
  assert equal ($input | identifier_from_url "open_library_work_id") $expected
}

def test_identifier_from_url_open_library_work_id_short_url [] {
  let input = "https://openlibrary.org/works/OL8756258W"
  let expected = {
    open_library_work_id: "OL8756258W"
  }
  assert equal ($input | identifier_from_url "open_library_work_id") $expected
}

def test_identifier_from_url_open_library_work_id_valid_work [] {
  let input = "https://openlibrary.org/works/OL8756258W/%E9%8B%BC%E3%81%AE%E9%8C%AC%E9%87%91%E8%A1%93%E5%B8%AB_1?edition="
  let expected = {
    open_library_work_id: "OL8756258W"
  }
  assert equal ($input | identifier_from_url "open_library_work_id") $expected
}

def test_identifier_from_url_open_library_work_id_invalid_work [] {
  let input = "https://openlibrary.org/books/OL6682530M/Twenty_thousand_leagues_under_the_sea"
  let expected = {}
  assert equal ($input | identifier_from_url "open_library_work_id") $expected
}

def test_identifier_from_url_open_library_work_id_invalid_work_url [] {
  let input = "https://openlibrary.org/authors/OL6682530W/Twenty_thousand_leagues_under_the_sea"
  let expected = {}
  assert equal ($input | identifier_from_url "open_library_work_id") $expected
}

def test_identifier_from_url_open_library_work_id_valid_work_http [] {
  let input = "http://openlibrary.org/works/OL6682530W/Twenty_thousand_leagues_under_the_sea"
  let expected = {
    open_library_work_id: "OL6682530W"
  }
  assert equal ($input | identifier_from_url "open_library_work_id") $expected
}

def test_identifier_from_url_wikidata_item_id_property_url [] {
  let input = "https://www.wikidata.org/wiki/Property:P276"
  let expected = {}
  assert equal ($input | identifier_from_url "wikidata_item_id") $expected
}

def test_identifier_from_url_wikidata_item_id_valid_item [] {
  let input = "https://www.wikidata.org/wiki/Q139570806"
  let expected = {
    wikidata_item_id: "Q139570806"
  }
  assert equal ($input | identifier_from_url "wikidata_item_id") $expected
}

def test_identifier_from_url_wikidata_item_id_invalid_item [] {
  let input = "https://www.wikidata.org/wiki/QQ139570806"
  let expected = {}
  assert equal ($input | identifier_from_url "wikidata_item_id") $expected
}

def test_identifier_from_url_wikidata_item_id_invalid_item_url [] {
  let input = "https://www.wikidata.org/w/Q139570806"
  let expected = {}
  assert equal ($input | identifier_from_url "wikidata_item_id") $expected
}

def test_identifier_from_url_wikidata_item_id_valid_item_http [] {
  let input = "http://www.wikidata.org/wiki/Q139570806"
  let expected = {
    wikidata_item_id: "Q139570806"
  }
  assert equal ($input | identifier_from_url "wikidata_item_id") $expected
}

def test_identifier_from_url [] {
  test_identifier_from_url_empty_url
  test_identifier_from_url_empty_type
  test_identifier_from_url_invalid_type

  test_identifier_from_url_bookbrainz_edition_id_work_url
  test_identifier_from_url_bookbrainz_edition_id_valid_edition
  test_identifier_from_url_bookbrainz_edition_id_invalid_edition_url
  test_identifier_from_url_bookbrainz_edition_id_valid_edition_http

  test_identifier_from_url_bookbrainz_work_id_edition_url
  test_identifier_from_url_bookbrainz_work_id_valid_work
  test_identifier_from_url_bookbrainz_work_id_invalid_work
  test_identifier_from_url_bookbrainz_work_id_invalid_work_url
  test_identifier_from_url_bookbrainz_work_id_valid_work_http

  test_identifier_from_url_comic_vine_issue_id_series_url
  test_identifier_from_url_comic_vine_issue_id_valid_issue
  test_identifier_from_url_comic_vine_issue_id_valid_issue_slug
  test_identifier_from_url_comic_vine_issue_id_invalid_issue_url
  test_identifier_from_url_comic_vine_issue_id_valid_issue_http

  test_identifier_from_url_hardcover_book_slug_edition_url
  test_identifier_from_url_hardcover_book_slug_valid_book
  test_identifier_from_url_hardcover_book_slug_invalid_book
  test_identifier_from_url_hardcover_book_slug_invalid_book_url
  test_identifier_from_url_hardcover_book_slug_valid_book_http

  test_identifier_from_url_hardcover_edition_id_book_url
  test_identifier_from_url_hardcover_edition_id_valid_edition
  test_identifier_from_url_hardcover_edition_id_invalid_edition
  test_identifier_from_url_hardcover_edition_id_invalid_book_url
  test_identifier_from_url_hardcover_edition_id_invalid_edition_url
  test_identifier_from_url_hardcover_edition_id_valid_edition_http

  test_identifier_from_url_metron_issue_id_series_url
  test_identifier_from_url_metron_issue_id_valid_issue
  test_identifier_from_url_metron_issue_id_invalid_issue
  test_identifier_from_url_metron_issue_id_invalid_issue_url
  test_identifier_from_url_metron_issue_id_valid_issue_http

  test_identifier_from_url_open_library_edition_id_work_url
  test_identifier_from_url_open_library_edition_id_short_url
  test_identifier_from_url_open_library_edition_id_work_url_with_edition
  test_identifier_from_url_open_library_edition_id_valid_edition
  test_identifier_from_url_open_library_edition_id_invalid_edition
  test_identifier_from_url_open_library_edition_id_invalid_edition_url
  test_identifier_from_url_open_library_edition_id_valid_edition_http

  test_identifier_from_url_open_library_work_id_edition_url
  test_identifier_from_url_open_library_work_id_work_url_with_edition
  test_identifier_from_url_open_library_work_id_short_url
  test_identifier_from_url_open_library_work_id_valid_work
  test_identifier_from_url_open_library_work_id_invalid_work
  test_identifier_from_url_open_library_work_id_invalid_work_url
  test_identifier_from_url_open_library_work_id_valid_work_http

  test_identifier_from_url_wikidata_item_id_property_url
  test_identifier_from_url_wikidata_item_id_valid_item
  test_identifier_from_url_wikidata_item_id_invalid_item
  test_identifier_from_url_wikidata_item_id_invalid_item_url
  test_identifier_from_url_wikidata_item_id_valid_item_http
}

def test_identifier_into_url_empty_id [] {
  let input = ""
  assert error {|| ($input | identifier_into_url "bookbrainz_edition_id")}
}

def test_identifier_into_url_empty_type [] {
  let input = "Q1234"
  assert error {|| ($input | identifier_into_url "")}
}

def test_identifier_into_url_invalid_type [] {
  let input = "Q1234"
  assert error {|| ($input | identifier_into_url "comicbrainz_edition_id")}
}

def test_identifier_into_url_bookbrainz_edition_id_valid [] {
  let input = "6a2a8813-8085-4058-8897-f8b89e037106"
  let expected = "https://bookbrainz.org/edition/6a2a8813-8085-4058-8897-f8b89e037106"
  assert equal ($input | identifier_into_url "bookbrainz_edition_id") $expected
}

def test_identifier_into_url_bookbrainz_edition_id_invalid [] {
  let input = "6a2a8813-8085-4058-8897-f8b89e0371067"
  assert error {|| ($input | identifier_into_url "bookbrainz_edition_id")}
}

def test_identifier_into_url_bookbrainz_work_id_valid [] {
  let input = "6a2a8813-8085-4058-8897-f8b89e037106"
  let expected = "https://bookbrainz.org/work/6a2a8813-8085-4058-8897-f8b89e037106"
  assert equal ($input | identifier_into_url "bookbrainz_work_id") $expected
}

def test_identifier_into_url_bookbrainz_work_id_invalid [] {
  let input = "6a2a8813-8085-4058-8897-f8b89e0371067"
  assert error {|| ($input | identifier_into_url "bookbrainz_work_id")}
}

def test_identifier_into_url_comic_vine_issue_id_valid [] {
  let input = "4000-987377"
  let expected = "https://comicvine.gamespot.com/issue/4000-987377"
  assert equal ($input | identifier_into_url "comic_vine_issue_id") $expected
}

def test_identifier_into_url_comic_vine_issue_id_invalid [] {
  let input = "4050-987377"
  assert error {|| ($input | identifier_into_url "comic_vine_issue_id")}
}

def test_identifier_into_url_hardcover_edition_id_valid [] {
  let input = "32873036"
  let expected = "https://hardcover.app/books/march-comes-in-like-a-lion-vol-1/editions/32873036"
  assert equal ($input | identifier_into_url "hardcover_edition_id" --hardcover-book-slug "march-comes-in-like-a-lion-vol-1") $expected
}

def test_identifier_into_url_hardcover_edition_id_invalid [] {
  let input = "32873036-1"
  assert error {|| ($input | identifier_into_url "hardcover_edition_id" --hardcover-book-slug "march-comes-in-like-a-lion-vol-1")}
}

def test_identifier_into_url_hardcover_edition_id_hardcover_book_slug_invalid [] {
  let input = "32873036"
  assert error {|| ($input | identifier_into_url "hardcover_edition_id" --hardcover-book-slug "march-comes-in-like-a-lion-vol-1/editions")}
}

def test_identifier_into_url_hardcover_edition_id_hardcover_book_slug_empty [] {
  let input = "32873036"
  assert error {|| ($input | identifier_into_url "hardcover_edition_id" --hardcover-book-slug "")}
}

def test_identifier_into_url_hardcover_edition_id_hardcover_book_slug_missing [] {
  let input = "32873036"
  assert error {|| ($input | identifier_into_url "hardcover_edition_id")}
}

def test_identifier_into_url_hardcover_book_slug_added_for_wrong_type [] {
  let input = "32873036"
  assert error {|| ($input | identifier_into_url "bookbrainz_edition_id" --hardcover-book-slug "")}
}

def test_identifier_into_url_hardcover_book_slug_valid [] {
  let input = "march-comes-in-like-a-lion-vol-1"
  let expected = "https://hardcover.app/books/march-comes-in-like-a-lion-vol-1"
  assert equal ($input | identifier_into_url "hardcover_book_slug") $expected
}

def test_identifier_into_url_hardcover_book_slug_invalid [] {
  let input = "march-comes-in-like-a-lion-1-volume-1/editions"
  assert error {|| ($input | identifier_into_url "hardcover_book_slug")}
}

def test_identifier_into_url_metron_issue_id_valid [] {
  let input = "57342"
  let expected = "https://metron.cloud/issue/57342"
  assert equal ($input | identifier_into_url "metron_issue_id") $expected
}

def test_identifier_into_url_metron_issue_id_invalid [] {
  let input = "4000-57342"
  assert error {|| ($input | identifier_into_url "metron_issue_id")}
}

def test_identifier_into_url_open_library_edition_id_valid [] {
  let input = "OL60495447M"
  let expected = "https://openlibrary.org/books/OL60495447M"
  assert equal ($input | identifier_into_url "open_library_edition_id") $expected
}

def test_identifier_into_url_open_library_edition_id_invalid [] {
  let input = "OL60495447W"
  assert error {|| ($input | identifier_into_url "open_library_edition_id")}
}

def test_identifier_into_url_open_library_work_id_valid [] {
  let input = "OL60495447W"
  let expected = "https://openlibrary.org/works/OL60495447W"
  assert equal ($input | identifier_into_url "open_library_work_id") $expected
}

def test_identifier_into_url_open_library_work_id_invalid [] {
  let input = "OL60495447M"
  assert error {|| ($input | identifier_into_url "open_library_work_id")}
}

def test_identifier_into_url_wikidata_item_id_valid [] {
  let input = "Q139580959"
  let expected = "https://www.wikidata.org/wiki/Q139580959"
  assert equal ($input | identifier_into_url "wikidata_item_id") $expected
}

def test_identifier_into_url_wikidata_item_id_invalid [] {
  let input = "139580959"
  assert error {|| ($input | identifier_into_url "wikidata_item_id")}
}

def test_identifier_into_url [] {
  test_identifier_into_url_empty_id
  test_identifier_into_url_empty_type
  test_identifier_into_url_invalid_type

  test_identifier_into_url_bookbrainz_edition_id_valid
  test_identifier_into_url_bookbrainz_edition_id_invalid
  test_identifier_into_url_bookbrainz_work_id_valid
  test_identifier_into_url_bookbrainz_work_id_invalid
  test_identifier_into_url_comic_vine_issue_id_valid
  test_identifier_into_url_comic_vine_issue_id_invalid
  test_identifier_into_url_hardcover_edition_id_valid
  test_identifier_into_url_hardcover_edition_id_invalid
  test_identifier_into_url_hardcover_edition_id_hardcover_book_slug_invalid
  test_identifier_into_url_hardcover_edition_id_hardcover_book_slug_empty
  test_identifier_into_url_hardcover_edition_id_hardcover_book_slug_missing
  test_identifier_into_url_hardcover_book_slug_added_for_wrong_type
  test_identifier_into_url_hardcover_book_slug_valid
  test_identifier_into_url_hardcover_book_slug_invalid
  test_identifier_into_url_metron_issue_id_valid
  test_identifier_into_url_metron_issue_id_invalid
  test_identifier_into_url_open_library_edition_id_valid
  test_identifier_into_url_open_library_edition_id_invalid
  test_identifier_into_url_open_library_work_id_valid
  test_identifier_into_url_open_library_work_id_invalid
  test_identifier_into_url_wikidata_item_id_valid
  test_identifier_into_url_wikidata_item_id_invalid
}

def test_from_comic_info_xml [] {
  # test_artist_credit_to_string_baccano_vol_1
  # test_artist_credit_to_string_bakemonogatari_part_01
}

def main [] {
  test_is_identifier_valid
  test_identifier_from_url
  test_identifier_into_url
  # test_from_comic_info_xml
  # test_into_comic_info_xml
  # test_from_metron_info_xml
  # test_into_metron_info_xml
  echo $"(ansi green)All tests passed!(ansi reset)"
}
