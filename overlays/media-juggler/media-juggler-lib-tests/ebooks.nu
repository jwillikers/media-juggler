# Tests for the ebooks functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

const test_data_dir = path self ../test-data

def test_from_opf_xml_march_comes_in_like_a_lion_volume_1_pdf [] {
  let input = open ([$test_data_dir "march-comes-in-like-a-lion-volume-1-pdf-metadata.opf"] | path join) | from xml
  let expected = {
    credits: [
      [creator, role, primary, language];
      ["Chica Umino", Writer, true, ""]
    ]
    publishers: ["Denpa"]
    genres: [
      coming-of-age
      romance
      "slice of life"
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
      [hardcover_book_slug, "march-comes-in-like-a-lion-volume-1"]
      [hardcover_edition_id, "30930924"]
      [comic_vine_issue_id, "987377"]
      [comic_vine_volume_id, "150064"]
      [bookbrainz_edition_id, "594a8ec2-6301-4c20-ae22-2c43840416b2"]
      [wikidata_item_id, "Q139556252"]
      [epub_uuid, "2494c4ca-6fb6-459f-baca-26de4d2df70e"]
    ],
    series: "March Comes in Like a Lion",
    issue: "1",
    isbn: "9781634428132"
  }
  # log debug $"\n($input | from_opf_xml | to nuon)\n"
  assert equal ($input | from_opf_xml) $expected
}

def test_from_opf_xml_march_comes_in_like_a_lion_volume_1_epub_3_2_pdf [] {
  let input = open ([$test_data_dir "march-comes-in-like-a-lion-volume-1-pdf-metadata-epub-3.2.opf"] | path join) | from xml
  let expected = {
    credits: [
      [creator, role, primary, language];
      ["Chica Umino", Writer, true, ""]
      ["Chica Umino", Artist, false, ""]
      ["Jocelyne Allen", Translator, false, ""]
    ]
    publishers: ["Denpa"]
    genres: [
      coming-of-age
      romance
      "slice of life"
    ]
    language: "english"
    title: "March Comes in Like a Lion, Vol. 1",
    description: "Rei Kiriyama...

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
      [hardcover_book_slug, "march-comes-in-like-a-lion-volume-1"]
      [hardcover_edition_id, "30930924"]
      [comic_vine_issue_id, "987377"]
      [comic_vine_volume_id, "150064"]
      [bookbrainz_edition_id, "594a8ec2-6301-4c20-ae22-2c43840416b2"]
      [wikidata_item_id, "Q139556252"]
      [epub_uuid, "2494c4ca-6fb6-459f-baca-26de4d2df70e"]
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
  test_from_opf_xml_march_comes_in_like_a_lion_volume_1_epub_3_2_pdf
}

def test_to_opf_xml_march_comes_in_like_a_lion_volume_1_pdf [] {
  let input = {
    credits: [
      # todo Should I start using the ID field here and using sort-by with that?
      [person, role, primary, language];
      ["Chica Umino", Writer, true, ""]
      ["Chica Umino", Artist, true, ""]
      ["Jocelyne Allen", Translator, false, ""]
    ]
    publishers: ["Denpa"]
    genres: [
      coming-of-age
      romance
      "slice of life"
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
      [epub_uuid "a1b0d67e-2e81-4df5-9e67-a64cbe366809"]
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
  let expected = {
    tag: "package"
    attributes: {
      "unique-identifier": "bookid"
      version: "3.0"
    },
    content: [
      [tag, attributes, content];
      [
        metadata,
        {
          "xmlns:calibre": "http://calibre.kovidgoyal.net/2009/metadata"
          "xmlns:dc": "http://purl.org/dc/elements/1.1/"
          "xmlns:opf": "http://www.idpf.org/2007/opf"
        },
        [
          [tag, attributes, content];
          [
            dc:date
            {}
            [
              [tag, attributes, content];
              [null, null, "2023-05-01T05:00:00+00:00"]
            ]
          ]
          [
            dc:description
            {}
            [
              [tag, attributes, content];
              [
                null,
                null,
                "Rei Kiriyama is a child prodigy. Rei Kiriyama is also an orphan who lives alone in an empty apartment. Rei Kiriyama is a teen working in an adult's world.

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
              ]
            ]
          ],
          [dc:identifier, {id: "hardcover-edition-identifier"}, [[tag, attributes, content]; [null, null, "30930924"]]]
          [dc:identifier, {id: "comicvine-identifier"}, [[tag, attributes, content]; [null, null, "987377"]]]
          [dc:identifier, {id: "wikidata-edition-identifier"}, [[tag, attributes, content]; [null, null, "Q139556252"]]]
          [dc:identifier {id: "hardcover-slug-identifier"} [[tag, attributes, content]; [null, null, "march-comes-in-like-a-lion-volume-1"]]]
          [dc:identifier {id: "hardcover-identifier"} [[tag, attributes, content]; [null, null, "march-comes-in-like-a-lion-volume-1"]]]
          [dc:identifier, {} [[tag, attributes, content]; [null, null, "url:https://bookbrainz.org/edition/594a8ec2-6301-4c20-ae22-2c43840416b2"]]]
          [dc:identifier, {} [[tag, attributes, content]; [null, null, "url:https://comicvine.gamespot.com/issue/4000-987377"]]]
          [dc:identifier, {} [[tag, attributes, content]; [null, null, "url:https://hardcover.app/books/march-comes-in-like-a-lion-volume-1/editions/30930924"]]]
          [dc:identifier, {} [[tag, attributes, content]; [null, null, "url:https://www.wikidata.org/wiki/Q139556252"]]]
          [dc:identifier, {"opf:scheme": "ISBN" id: "isbn-identifier"}, [[tag, attributes, content]; [null, null, "urn:isbn:9781634428132"]]]
          [dc:identifier, {id: "bookbrainz-edition-identifier"}, [[tag, attributes, content]; [null, null, "urn:uuid:594a8ec2-6301-4c20-ae22-2c43840416b2"]]]
          [dc:identifier, {id: "bookid"}, [[tag, attributes, content]; [null, null, "urn:uuid:a1b0d67e-2e81-4df5-9e67-a64cbe366809"]]]
          # [identifier {scheme: HARDCOVER-ID} [[tag, attributes, content]; [null, null, "908381"]]]
          # [identifier, {scheme: COMICVINE-VOLUME}, [[tag, attributes, content]; [null, null, "150064"]]]
          [dc:language {} [[tag, attributes, content]; [null, null, eng]]]
          [dc:publisher {} [[tag, attributes, content]; [null, null, Denpa]]]
          [dc:subject, {}, [[tag, attributes, content]; [null, null, coming-of-age]]]
          [dc:subject, {}, [[tag, attributes, content]; [null, null, romance]]]
          [dc:subject, {}, [[tag, attributes, content]; [null, null, "slice of life"]]]
          [dc:title, {}, [[tag, attributes, content]; [null, null, "March Comes in Like a Lion, Vol. 1"]]]
          [meta, {name: "calibre:series", content: "March Comes in Like a Lion"}, []]
          [meta, {name: "calibre:series_index", content: "1"}, []]
          [
            "meta"
            {
              refines: "#series-id-1"
              property: "group-position"
            }
            [
              [tag, attributes, content];
              [null null "1"]
            ]
          ]
          [meta, {refines: "#isbn-identifier" property: "identifier-type" scheme: "onix:codelist5"}, [[tag, attributes, content]; [null, null, "15"]]]
          [meta, {refines: "#bookbrainz-edition-identifier", property: "identifier-type"}, [[tag, attributes, content]; [null, null, "BOOKBRAINZ-EDITION"]]]
          [meta, {refines: "#comicvine-identifier", property: "identifier-type"}, [[tag, attributes, content]; [null, null, "COMICVINE"]]]
          [meta, {refines: "#hardcover-identifier", property: "identifier-type"}, [[tag, attributes, content]; [null, null, "HARDCOVER"]]]
          [meta, {refines: "#hardcover-edition-identifier", property: "identifier-type"}, [[tag, attributes, content]; [null, null, "HARDCOVER-EDITION"]]]
          [meta, {refines: "#hardcover-slug-identifier", property: "identifier-type"}, [[tag, attributes, content]; [null, null, "HARDCOVER-SLUG"]]]
          [
            "meta"
            {
              property: "belongs-to-collection"
              id: "series-id-1"
            }
            [
              [tag, attributes, content];
              [null null "March Comes in Like a Lion"]
            ]
          ]
          [meta, {refines: "#wikidata-edition-identifier", property: "identifier-type"}, [[tag, attributes, content]; [null, null, "WIKIDATA-EDITION"]]]
          [
            dc:creator,
            {
              # role: aut,
              # file-as: "Umino, Chica"
              id: "id-creator-0"
            },
            [
              [tag, attributes, content];
              [null, null, "Chica Umino"]
            ]
          ],
          [
            "meta"
            {
              refines: "#id-creator-0"
              property: "role"
              scheme: "marc:relators"
            }
            [
              [tag, attributes, content];
              [null, null, author]
            ]
          ]
          [
            "meta"
            {
              refines: "#id-creator-0"
              property: "role"
              scheme: "marc:relators"
            }
            [
              [tag, attributes, content];
              [null, null, artist]
            ]
          ]
          [
            dc:creator,
            {
              id: "id-creator-1"
            },
            [
              [tag, attributes, content];
              [null, null, "Jocelyne Allen"]
            ]
          ],
          [
            "meta"
            {
              refines: "#id-creator-1"
              property: "role"
              scheme: "marc:relators"
            }
            [
              [tag, attributes, content];
              [null, null, translator]
            ]
          ]
        ]
      ]
    ]
  }
  # log debug $"\n($input | to_opf_xml | to nuon)\n"
  # assert equal ($input | to_opf_xml | get content | first | get content.tag | uniq) ($expected | get content | first | get content.tag | uniq)
  let output = $input | to_opf_xml
  # log debug $"\n($output.content | where tag == metadata | first | get content | where tag == meta | to nuon)\n"
  let timestamps = (
    $output.content | where tag == metadata | first | get content | where {|it| $it.tag == "meta" and ($it | get --optional attributes.property) == "dcterms:modified"}
  )
  assert equal ($timestamps | length) 1
  let timestamp = $timestamps | first | get content.content | first
  assert ($timestamp =~ "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z")
  let output = $output | update content (
    $output.content | where tag != metadata | prepend (
      let metadata = $output.content | where tag == metadata | first;
      $metadata | update content ($metadata.content | where {|it| not ($it.tag == "meta" and ($it | get --optional attributes.property) == "dcterms:modified") })
    )
  )
  # log debug $"output: ($output | get content | first | get content | where tag == "meta" | to json)"
  assert equal ($output | get content | first | get content | where tag == "dc:creator") ($expected | get content | first | get content | where tag == "dc:creator")
  assert equal ($output | get content | first | get content | where tag == "dc:description") ($expected | get content | first | get content | where tag == "dc:description")
  assert equal ($output | get content | first | get content | where tag == "dc:date") ($expected | get content | first | get content | where tag == "dc:date")
  assert equal ($output | get content | first | get content | where tag == "dc:language") ($expected | get content | first | get content | where tag == "dc:language")
  $output | get content | first | get content | where tag == "dc:identifier" | zip ($expected | get content | first | get content | where tag == "dc:identifier") | each {|it|
    assert equal $it.0 $it.1
  }
  assert equal ($output | get content | first | get content | where tag == "dc:identifier") ($expected | get content | first | get content | where tag == "dc:identifier")
  $output | get content | first | get content | where tag == "meta" | zip ($expected | get content | first | get content | where tag == "meta") | each {|it|
    assert equal $it.0 $it.1
  }
  assert equal ($output | get content | first | get content | where tag == "meta") ($expected | get content | first | get content | where tag == "meta")
  assert equal ($output | get content | first | get content | where tag == "dc:subject") ($expected | get content | first | get content | where tag == "dc:subject")
  assert equal ($output | get content | first | get content) ($expected | get content | first | get content)
  assert equal $output $expected
}

def test_to_opf_xml [] {
  test_to_opf_xml_march_comes_in_like_a_lion_volume_1_pdf
}

# Run the tests in this module
export def run_tests [] {
  test_from_opf_xml
  test_to_opf_xml
}
