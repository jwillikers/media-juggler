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

def test_from_comic_info_xml_march_comes_in_like_a_lion_vol_1 [] {
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
    publisher: "Denpa, LLC"
    imprint: "Denpa"
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
  let output = $input | from_comic_info_xml
  # log debug $"\n($output | to nuon)\n"
  assert equal ($output | columns | sort) ($expected | columns | sort)
  $output | columns | sort | each {|key|
    assert equal ($output | get $key) ($expected | get $key)
  }
  # assert equal $output $expected
}

def test_from_comic_info_xml [] {
  test_from_comic_info_xml_march_comes_in_like_a_lion_vol_1
}

def test_from_metron_info_xml_march_comes_in_like_a_lion_vol_1 [] {
  let input = open ([$test_data_dir "March Comes in Like a Lion v001_MetronInfo.xml"] | path join)
  let $expected = {

  }
  # assert equal ($input | from_metron_info_xml) $expected
}

def test_from_metron_info_xml [] {
  test_from_metron_info_xml_march_comes_in_like_a_lion_vol_1
}

def test_into_comic_info_xml_march_comes_in_like_a_lion_vol_1 [] {
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
    publisher: "Denpa, LLC"
    imprint: "Denpa"
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

def test_into_comic_info_xml [] {
  test_into_comic_info_xml_march_comes_in_like_a_lion_vol_1
}

def test_from_language_code_unsupported_code [] {
  let input = "english"
  assert error {|| $input | from_language_code $iso_language_codes_map}
}

def test_from_language_code_duplicate_languages [] {
  let input = "engl"
  let codes = [
    [language iso_639_1 iso_639_3];
    ["english" "en" "eng"]
    ["english" "en" "eng"]
  ]
  assert error {|| $input | from_language_code $codes}
}

def test_from_language_code_en [] {
  let input = "en"
  let expected = "english"
  assert equal ($input | from_language_code $iso_language_codes_map) $expected
}

def test_from_language_code_eng [] {
  let input = "eng"
  let expected = "english"
  assert equal ($input | from_language_code $iso_language_codes_map) $expected
}

def test_from_language_code [] {
  test_from_language_code_unsupported_code
  test_from_language_code_duplicate_languages
  test_from_language_code_en
  test_from_language_code_eng
}

def test_into_language_code_unsupported_language [] {
  let input = "spanglish"
  let codes = [
    [language iso_639_1 iso_639_3];
    ["english" "en" "eng"]
  ]
  assert error {|| $input | into_language_code iso_639_1 $codes}
}

def test_into_language_code_unsupported_language_code [] {
  let input = "english"
  let codes = [
    [language iso_639_1 iso_639_3];
    ["english" "en" "eng"]
  ]
  assert error {|| $input | into_language_code ietf_null $codes}
}

def test_into_language_code_duplicate_languages [] {
  let input = "en"
  let codes = [
    [language iso_639_1 iso_639_3];
    ["english" "en" "eng"]
    ["english" "en" "eng"]
  ]
  assert error {|| $input | into_language_code iso_639_1 $codes}
}

def test_into_language_code_en [] {
  let input = "english"
  let expected = "en"
  assert equal ($input | into_language_code iso_639_1 $iso_language_codes_map) $expected
}

def test_into_language_code_eng [] {
  let input = "english"
  let expected = "eng"
  assert equal ($input | into_language_code iso_639_3 $iso_language_codes_map) $expected
}

def test_into_language_code [] {
  test_into_language_code_unsupported_language
  test_into_language_code_unsupported_language_code
  test_into_language_code_duplicate_languages
  test_into_language_code_en
  test_into_language_code_eng
}

def test_from_opf_xml_march_comes_in_like_a_lion_volume_1_pdf [] {
  let input = open ([$test_data_dir "march-comes-in-like-a-lion-volume-1-pdf-metadata.opf"] | path join) | from xml
  let expected = {
    credits: [
      [creator, role, primary, language];
      ["Chica Umino", Writer, true, ""]
    ]
    publisher: "Denpa"
    genres: [
      "Character Driven"
      "Comics"
      "Loveable Characters"
      "Not Diverse Characters"
      "Strong Character Development"
      "Weak Character Development"
    ]
    language: "english"
    title: "March Comes in Like a Lion, Vol. 1",
    description: "Rei Kiriyama is a child prodigy. Rei Kiriyama is also an orphan who lives alone in an empty apartment. Rei Kiriyama is a teen working in an adult's world.

Life is complicated for Rei. He's an up-and-coming shogi (Japanese chess) player on the verge of turning pro but he has no homelife or much of a life period outside his board game but thankfully with the help of some life-long friends he has an opportunity start all over again.

Note: This volume was released digitally (05/03/2023) before paperback (06/06/2023).

## Chapter Titles
* Chapter 1: Rei Kiriyama
* Chapter 2: A Riverside Town
* Chapter 3: Akari
* Chapter 4: The Other Side of the Bridge
* Chapter 5: Harunobu
* Chapter 6: Beyond the Night Sky
* Chapter 7: Hina
* Chapter 8: VS.
* Chapter 9: Contract
* Chapter 10: Over the Cuckoo's Nest"
    publication_date: (2023-05-01T05:00:00+00:00 | into datetime)
    ids: [
      [type, id];
      [hardcover_book_slug, "march-comes-in-like-a-lion-volume-1"],
      [hardcover_edition_id, "30930924"],
      [comic_vine_issue_id, "987377"],
      [bookbrainz_edition_id, "594a8ec2-6301-4c20-ae22-2c43840416b2"],
      [wikidata_item_id, "Q139556252"]
    ],
    series: "March Comes in Like a Lion",
    issue: "1",
    isbn: "9781634428132"
  }
  # log debug $"\n($input | from_opf_xml | to nuon)\n"
  assert equal ($input | from_opf_xml) $expected
}

def test_from_opf_xml [] {
  test_from_opf_xml_march_comes_in_like_a_lion_volume_1_pdf
}

def main [] {
  test_is_identifier_valid
  test_identifier_from_url
  test_identifier_into_url
  test_from_language_code
  test_into_language_code
  test_into_comic_info_xml
  test_from_opf_xml
  test_from_comic_info_xml
  # test_from_metron_info_xml
  # test_into_metron_info_xml
  echo $"(ansi green)All tests passed!(ansi reset)"
}
