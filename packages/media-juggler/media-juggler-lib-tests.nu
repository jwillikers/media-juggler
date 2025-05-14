#!/usr/bin/env nu

use std assert
use std log

use media-juggler-lib *

let test_data_dir = ([$env.FILE_PWD "test-data"] | path join)

def test_round_to_second_using_cumulative_offset [] {
  let durations = [
    30069ms
    7191ms
    1144834ms
    1148453ms
    1005383ms
    340334ms
    1055909ms
    889571ms
    1210090ms
    1239241ms
    554999ms
    727045ms
    369422ms
    502728ms
    # 1529081ms
    # 770116ms
    # 596937ms
    # 608757ms
    # 463980ms
    # 1105896ms
    # 1235574ms
    # 70392ms
    # 95833ms
  ]
  let expected = [
    30sec # Down cumulative offset: -69
    7sec # Down cumulative offset: -191 - 69 = -260
    1145sec # Up (1145000 - 1144834 = 166) cumulative offset: (-260 + 166 = -94)
    1149sec # Up (1149000 - 1148453 = 547) cumulative offset: (-94 + 547 = 453)
    1005sec # Down (1005000 - 1005383 = -383) cumulative offset: (453 + -383 = 70)
    340sec # Down (340000 - 340334 = -334) cumulative offset: (70 + -334 = -264)
    1056sec # Up (1056000 - 1055909 = 91) cumulative offset: (-264 + 91 = -173)
    890sec # Up (890000 - 889571 = 429) cumulative offset: (-173 + 429 = 256)
    1210sec # Down (1210000 - 1210090 = -90) cumulative offset: (256 + -90 = 166)
    1239sec # Down (1239000 - 1239241 = -241) cumulative offset: (166 + -241 = -75)
    555sec # Up (555000 - 554999 = 1) cumulative offset: (-75 + 1 = -74)
    727sec # Down cumulative offset: (-74 + (727000 - 727045) = -119)
    370sec # Up cumulative offset: (-119 + (370000 - 369422) = 459)
    502sec # Down cumulative offset: (459 + (502000 - 502728) = -269)
    # 1529081ms
    # 770116ms
    # 596937ms
    # 608757ms
    # 463980ms
    # 1105896ms
    # 1235574ms
    # 70392ms
    # 95833ms
  ]
  assert equal ($durations | round_to_second_using_cumulative_offset) $expected
}

def test_parse_series_from_group_one_without_index [] {
  let expected = [[name index]; ["The Stormlight Archive" null]]
  assert equal ("The Stormlight Archive" | parse_series_from_group) $expected
}

def test_parse_series_from_group_one_with_index [] {
  let expected = [[name index]; ["The Stormlight Archive" "1"]]
  assert equal ("The Stormlight Archive #1" | parse_series_from_group) $expected
}

def test_parse_series_from_group_two_without_index [] {
  let expected = [[name index]; ["The Stormlight Archive" null] ["Cosmere" null]]
  assert equal ("The Stormlight Archive; Cosmere" | parse_series_from_group) $expected
}

def test_parse_series_from_group_two_with_index [] {
  let expected = [[name index]; ["The Stormlight Archive" "1"] ["Cosmere" "10"]]
  assert equal ("The Stormlight Archive #1; Cosmere #10" | parse_series_from_group) $expected
}

def test_parse_series_from_group_one_with_index_and_one_without_index [] {
  let expected = [[name index]; ["The Stormlight Archive" "1"] ["Cosmere" null]]
  assert equal ("The Stormlight Archive #1; Cosmere" | parse_series_from_group) $expected
}

def test_parse_series_from_group [] {
  test_parse_series_from_group_one_without_index
  test_parse_series_from_group_one_with_index
  test_parse_series_from_group_two_without_index
  test_parse_series_from_group_two_with_index
  test_parse_series_from_group_one_with_index_and_one_without_index
}

def test_parse_series_from_series_tags_empty_record [] {
  assert equal ({} | parse_series_from_series_tags) null
}

def test_parse_series_from_series_tags_one_null_series [] {
  assert equal ({series: null, series-part: null} | parse_series_from_series_tags) null
}

def test_parse_series_from_series_tags_one_series_without_index [] {
  let expected = [[name index]; ["Mistborn" null]]
  assert equal ({series: "Mistborn"} | parse_series_from_series_tags) $expected
}

def test_parse_series_from_series_tags_one_series_with_index [] {
  let expected = [[name index]; ["Mistborn" "1"]]
  assert equal ({series: "Mistborn", series-part: "1"} | parse_series_from_series_tags) $expected
}

def test_parse_series_from_series_tags_one_series_with_int_index [] {
  let expected = [[name index]; ["Mistborn" "1"]]
  assert equal ({series: "Mistborn", series-part: 1} | parse_series_from_series_tags) $expected
}

def test_parse_series_from_series_tags_one_int_series_without_index [] {
  let expected = [[name index]; ["86" null]]
  assert equal ({series: 86} | parse_series_from_series_tags) $expected
}

def test_parse_series_from_series_tags_one_series_with_null_index [] {
  let expected = [[name index]; ["86" null]]
  assert equal ({series: "86", series-part: null} | parse_series_from_series_tags) $expected
}

def test_parse_series_from_series_tags_one_mvnm_without_index [] {
  let expected = [[name index]; ["86" null]]
  assert equal ({mvnm: "86"} | parse_series_from_series_tags) $expected
}

def test_parse_series_from_series_tags_one_mvnm_with_index [] {
  let expected = [[name index]; ["86" "5.1"]]
  assert equal ({mvnm: "86", mvin: 5.1} | parse_series_from_series_tags) $expected
}

def test_parse_series_from_series_tags_one_mvnm_one_series [] {
  let expected = [[name index]; ["Series One" "1"] ["Series Two" "3"]]
  assert equal ({ mvnm: "Series One", series: "Series Two", series-part: 3, mvin: 1} | parse_series_from_series_tags | sort-by name) $expected
}

def test_parse_series_from_series_tags [] {
  test_parse_series_from_series_tags_empty_record
  test_parse_series_from_series_tags_one_null_series
  test_parse_series_from_series_tags_one_series_without_index
  test_parse_series_from_series_tags_one_series_with_null_index
  test_parse_series_from_series_tags_one_series_with_index
  test_parse_series_from_series_tags_one_series_with_int_index
  test_parse_series_from_series_tags_one_int_series_without_index
  test_parse_series_from_series_tags_one_mvnm_without_index
  test_parse_series_from_series_tags_one_mvnm_with_index
  test_parse_series_from_series_tags_one_mvnm_one_series
}

def test_upsert_if_present_same_column [] {
  let expected = {key: "value"}
  assert equal ({} | upsert_if_present key {key: "value"}) $expected
}

def test_upsert_if_present_different_column [] {
  let expected = {different: "value"}
  assert equal ({} | upsert_if_present different {key: "value"} key) $expected
}

def test_upsert_if_present_null_value [] {
  assert equal ({} | upsert_if_present different {key: null} key) {}
}

def test_upsert_if_present_missing_column [] {
  assert equal ({} | upsert_if_present different {} key) {}
}

def test_upsert_if_present [] {
  test_upsert_if_present_same_column
  test_upsert_if_present_different_column
  test_upsert_if_present_null_value
  test_upsert_if_present_missing_column
}

def test_upsert_if_value_null [] {
  assert equal ({} | upsert_if_value key null) {}
}

def test_upsert_if_value_empty [] {
  assert equal ({} | upsert_if_value key []) {}
}

def test_upsert_if_value_something [] {
  assert equal ({} | upsert_if_value key "something") {key: "something"}
}

def test_upsert_if_value [] {
  test_upsert_if_value_null
  test_upsert_if_value_empty
  test_upsert_if_value_something
}

def test_parse_audiobook_metadata_from_tone_picard [] {
  let input = {
    meta: {
      album: "Dark One: Forgotten"
      albumArtist: "Brandon Sanderson; Dan Wells"
      artist: "Brandon Sanderson; Dan Wells"
      composer: "Mia Barron; Luis Bermudez; William Elsman; Kaleo Griffith; Roxanne Hernandez; Rachel L. Jacobs; John H. Mayer; Nan McNamara; Jim Meskimen; Sophie Oda; Keith Szarabajka; Kelli Tager; Avery Kidd Waddell"
      comment: "Brandon Sanderson and Dan Wells Purchased from Libro.fm."
      discNumber: 1
      discTotal: 1
      recordingDate: "2023-01-10T00:00:00"
      title: "Dark One: Forgotten"
      trackNumber: 1
      trackTotal: 1
      label: "MAINFRAME;rb media RECORDED BOOKS ORIGINAL"
      publisher: "MAINFRAME;rb media RECORDED BOOKS ORIGINAL"
      media: "Digital Media"
      chapters: [
        [start length title];
        [0 2708010 "Dark One - Track 001"]
        [2708010 1712091 "Dark One - Track 002"]
        [4420101 1679778 "Dark One - Track 003"]
        [6099879 2120072 "Dark One - Track 004"]
        [8219951 1921254 "Dark One - Track 005"]
        [10141205 1691272 "Dark One - Track 006"]
        [11832477 1800124 "Dark One - Track 007"]
        [13632601 2100376 "Dark One - Track 008"]
        [15732977 1866658 "Dark One - Track 009"]
        [17599635 1747879 "Dark One - Track 010"]
        [19347514 2095543 "Dark One - Track 011"]
        [21443057 2044186 "Dark One - Track 012"]
        [23487243 102452 "Dark One - Track 013"]
      ]
      embeddedPictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      additionalFields: {
        "musicBrainz Album Release Country": "XW"
        series: "Dark One, performed by various narrators"
        "series-part": 1
        originalyear: "2023"
        script: "Latn"
        "musicBrainz Album Status": "official"
        originaldate: "2023-01-10"
        barcode: "9781980062875"
        performer: "Erik Jourgensen"
        "musicBrainz Album Type": "other;audio drama"
        writer: "Brandon Sanderson;Dan Wells"
        artists: "Brandon Sanderson;Dan Wells"
        "musicBrainz Release Group Id": "4220489d-2bd0-4618-84a8-bdac1b968b1c"
        "musicBrainz Album Id": "549a0455-4698-472f-97f3-7bb75fbe7343"
        "musicBrainz Track Id": "a3a37da7-f2fa-4938-b827-d3c8d213d08c"
        "musicBrainz Release Track Id": "a442811c-582b-429c-b7d9-072736be42ac"
        "musicBrainz Work Id": "e8eba2f2-cb32-4f55-82cc-b35aa1272b5a"
        producer: "Max Epstein;Matt Flynn;David Pace"
        engineer: "Anthony Cozzi;Vincent Early;Tom Pinkava;Timothy Waldner"
        "musicBrainz Album Artist Id": "b7b9f742-8de0-44fd-afd3-fa536701d27e;f0e00197-4291-40cb-a448-c2f3c86f54c7"
        "musicBrainz Artist Id": "b7b9f742-8de0-44fd-afd3-fa536701d27e;f0e00197-4291-40cb-a448-c2f3c86f54c7"
        "acoustid Fingerprint": "XXXX"
        "©work": "Dark One: Forgotten"
        "©dir": "Max Epstein;David Pace"
      }
    }
    audio: {
      duration: 1500
    }
    file: "/home/listener/audiobooks/Dark One: Forgotten/Dark One: Forgotten.m4b"
  }
  let expected = {
    book: {
      title: "Dark One: Forgotten"
      contributors: [
        [id name entity role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"]
        ["f0e00197-4291-40cb-a448-c2f3c86f54c7", "Dan Wells", artist, "primary author"]
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" "label" "distributor"]
      ]
      comment: "Brandon Sanderson and Dan Wells Purchased from Libro.fm."
      publication_date: ("2023-01-10T00:00:00" | into datetime)
      musicbrainz_release_country: "XW"
      musicbrainz_release_status: "official"
      script: "Latn"
      series: [
        [name index];
        ["Dark One, performed by various narrators" "1"]
      ]
      isbn: "9781980062875"
      musicbrainz_release_types: ["other" "audio drama"]
      musicbrainz_release_group_id: "4220489d-2bd0-4618-84a8-bdac1b968b1c"
      musicbrainz_release_id: "549a0455-4698-472f-97f3-7bb75fbe7343"
      publishers: [[name]; ["MAINFRAME"] ["rb media RECORDED BOOKS ORIGINAL"]]
      chapters: [
        [index start length title];
        [0 0ms 2708010ms "Dark One - Track 001"]
        [1 2708010ms 1712091ms "Dark One - Track 002"]
        [2 4420101ms 1679778ms "Dark One - Track 003"]
        [3 6099879ms 2120072ms "Dark One - Track 004"]
        [4 8219951ms 1921254ms "Dark One - Track 005"]
        [5 10141205ms 1691272ms "Dark One - Track 006"]
        [6 11832477ms 1800124ms "Dark One - Track 007"]
        [7 13632601ms 2100376ms "Dark One - Track 008"]
        [8 15732977ms 1866658ms "Dark One - Track 009"]
        [9 17599635ms 1747879ms "Dark One - Track 010"]
        [10 19347514ms 2095543ms "Dark One - Track 011"]
        [11 21443057ms 2044186ms "Dark One - Track 012"]
        [12 23487243ms 102452ms "Dark One - Track 013"]
      ]
    }
    track: {
      title: "Dark One: Forgotten"
      contributors: [
        [id, name, entity, role];
        ["", "Mia Barron", artist, composer]
        ["", "Luis Bermudez", artist, composer]
        ["", "William Elsman", artist, composer]
        ["", "Kaleo Griffith", artist, composer]
        ["", "Roxanne Hernandez", artist, composer]
        ["", "Rachel L. Jacobs", artist, composer]
        ["", "John H. Mayer", artist, composer]
        ["", "Nan McNamara", artist, composer]
        ["", "Jim Meskimen", artist, composer]
        ["", "Sophie Oda", artist, composer]
        ["", "Keith Szarabajka", artist, composer]
        ["", "Kelli Tager", artist, composer]
        ["", "Avery Kidd Waddell", artist, composer]
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer]
        ["f0e00197-4291-40cb-a448-c2f3c86f54c7", "Dan Wells", artist, writer]
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"]
        ["f0e00197-4291-40cb-a448-c2f3c86f54c7", "Dan Wells", artist, "primary author"]
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      media: "Digital Media"
      musicbrainz_recording_id: "a3a37da7-f2fa-4938-b827-d3c8d213d08c"
      musicbrainz_track_id: "a442811c-582b-429c-b7d9-072736be42ac"
      musicbrainz_works: [[id]; ["e8eba2f2-cb32-4f55-82cc-b35aa1272b5a"]]
      acoustid_fingerprint: "XXXX"
      duration: 1500000000ns
      file: "/home/listener/audiobooks/Dark One: Forgotten/Dark One: Forgotten.m4b"
      disc_number: 1
    }
  }
  let actual = $input | parse_audiobook_metadata_from_tone

  # todo Make a better comparison function for tests and use it here.
  # for column in ($expected.book | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | get $column)
  # }
  # assert equal $actual.book $expected.book
  # for column in ($expected.track | columns) {
  #   assert equal ($actual.track | get $column) ($expected.track | get $column)
  # }
  # for column in ($actual.track | columns) {
  #   assert equal ($actual.track | get $column) ($expected.track | get $column)
  # }
  # assert equal $actual.track $expected.track
  assert equal $actual $expected
}

def test_parse_audiobook_metadata_from_tone_audiobookshelf [] {
  let input = {
    meta: {
      album: "My Happy Marriage, Vol. 2"
      albumArtist: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      artist: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      composer: "Damien Haas, Miranda Parkin"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      copyright: "Yen Audio"
      description: "Akumi Agitogi Purchased from Libro.fm."
      discNumber: 1
      discTotal: 1
      genre: "Fiction; Fantasy"
      group: "My Happy Marriage #2; Test Series 2 #5"
      itunesMediaType: "audiobook"
      itunesPlayGap: "noGap"
      recordingDate: "2025-01-01T00:00:00Z"
      title: "My Happy Marriage, Vol. 2"
      trackNumber: 1
      chapters: [
        [start length title];
        [0 27000 "Opening Credits"]
        [27000 454000 Prologue]
        [481000 3042000 "Chapter 1: Nightmares and Disquieting Shadows"]
        [3523000 3492000 "Chapter 2: The Chestnut-Haired Man"]
        [7015000 3052000 "Chapter 3: To the Usuba Household, Part 1"]
        [10067000 3406000 "Chapter 4: To the Usuba Household, Part 2"]
        [13473000 2567000 "Chapter 5: Light in the Darkness"]
        [16040000 2689000 "Chapter 6: Truth-Revealing Party"]
        [18729000 810000 Epilogue]
        [19539000 116992 "End Credits"]
      ]
      embeddedPictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
    }
    audio: {
      duration: 1500
    }
    file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
  }
  let expected = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" "artist" "primary author"]
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" "label" "distributor"]
      ]
      description: "Akumi Agitogi Purchased from Libro.fm."
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage" "2"]
        ["Test Series 2" "5"]
      ]
      genres: ["Fiction" "Fantasy"]
      publishers: [[name]; ["Yen Audio"]]
      chapters: [
        [index start length title];
        [0 0ms 27000ms "Opening Credits"]
        [1 27000ms 454000ms Prologue]
        [2 481000ms 3042000ms "Chapter 1: Nightmares and Disquieting Shadows"]
        [3 3523000ms 3492000ms "Chapter 2: The Chestnut-Haired Man"]
        [4 7015000ms 3052000ms "Chapter 3: To the Usuba Household, Part 1"]
        [5 10067000ms 3406000ms "Chapter 4: To the Usuba Household, Part 2"]
        [6 13473000ms 2567000ms "Chapter 5: Light in the Darkness"]
        [7 16040000ms 2689000ms "Chapter 6: Truth-Revealing Party"]
        [8 18729000ms 810000ms Epilogue]
        [9 19539000ms 116992ms "End Credits"]
      ]
    }
    track: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["" "Damien Haas, Miranda Parkin" artist composer]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist writer]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist "primary author"]
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13, image/jpeg]
      ]
      duration: 1500000000ns
      file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
      disc_number: 1
    }
  }
  let actual = $input | parse_audiobook_metadata_from_tone

  # todo Make a better comparison function for tests and use it here.
  # for column in ($expected.book | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | get $column)
  # }
  # for column in ($actual.book | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | get $column)
  # }
  # assert equal $actual.book.chapters $expected.book.chapters
  # assert equal $actual.book $expected.book
  # for column in ($expected.track | columns) {
  #   assert equal ($actual.track | get $column) ($expected.track | get $column)
  # }
  # assert equal $actual.track $expected.track
  assert equal $actual $expected
}

def test_parse_audiobook_metadata_from_tone [] {
  test_parse_audiobook_metadata_from_tone_picard
  test_parse_audiobook_metadata_from_tone_audiobookshelf
}

def test_parse_audiobook_metadata_from_tracks_metadata_one [] {
  let input = [{
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage", "2"]
        ["Test Series 2", "5"]
      ]
      genres: ["Fiction" "Fantasy"]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13, image/jpeg]
      ]
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 001"
      index: 1
      contributors: [
        [id name entity role];
        ["" "Damien Haas, Miranda Parkin" artist composer]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist writer]
      ]
    }
  }]
  let expected = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage", "2"]
        ["Test Series 2", "5"]
      ]
      genres: ["Fiction" "Fantasy"]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      total_tracks: 1
    }
    tracks: [{
      title: "My Happy Marriage, Vol. 2 - Track 001"
      contributors: [
        [id name entity role];
        ["" "Damien Haas, Miranda Parkin" artist composer]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist writer]
      ]
      index: 1
    }]
  }
  let actual = $input | parse_audiobook_metadata_from_tracks_metadata

  # todo Make a better comparison function for tests and use it here.
  # for column in ($expected.book | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | get $column)
  # }
  # assert equal $actual.book $expected.book
  # for expected_track in $expected.tracks {
  #   for column in ($expected_track | columns) {
  #     assert equal (($actual.tracks | where index == $expected_track.index | first) | get $column) ($expected_track | get $column)
  #   }
  # }
  # assert equal $actual.tracks $expected.tracks
  assert equal $actual $expected
}

def test_parse_audiobook_metadata_from_tracks_metadata_two [] {
  let input = [{
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" "artist" "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage", "2"]
        ["Test Series 2", "5"]
      ]
      genres: ["Fiction" "Fantasy"]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13, image/jpeg]
      ]
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 001"
      index: 1
      contributors: [
        [id name entity role];
        ["" "Damien Haas, Miranda Parkin" artist composer]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist writer]
      ]
    }
  }, {
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" "artist" "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage", "2"]
        ["Test Series 2", "5"]
      ]
      genres: ["Fiction" "Fantasy"]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13, image/jpeg]
      ]
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 002"
      contributors: [
        [id name entity role];
        ["" "Damien Haas, Miranda Parkin" artist composer]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist writer]
      ]
      index: 2
    }
  }]
  let expected = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" "artist" "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage", "2"]
        ["Test Series 2", "5"]
      ]
      genres: ["Fiction" "Fantasy"]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      total_tracks: 2
    }
    tracks: [{
      title: "My Happy Marriage, Vol. 2 - Track 001"
      index: 1
      contributors: [
        [id name entity role];
        ["" "Damien Haas, Miranda Parkin" artist composer]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist writer]
      ]
    }, {
      title: "My Happy Marriage, Vol. 2 - Track 002"
      index: 2
      contributors: [
        [id name entity role];
        ["" "Damien Haas, Miranda Parkin" artist composer]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist writer]
      ]
    }]
  }
  let actual = $input | parse_audiobook_metadata_from_tracks_metadata

  # todo Make a better comparison function for tests and use it here.
  # for column in ($expected.book | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | get $column)
  # }
  # for column in ($expected.book | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | get $column)
  # }
  # assert equal $actual.book $expected.book
  # for expected_track in $expected.tracks {
  #   for column in ($expected_track | columns) {
  #     assert equal (($actual.tracks | where index == $expected_track.index | first) | get $column) ($expected_track | get $column)
  #   }
  # }
  # assert equal $actual.tracks $expected.tracks
  assert equal $actual $expected
}

def test_parse_audiobook_metadata_from_tracks_metadata [] {
  test_parse_audiobook_metadata_from_tracks_metadata_one
  test_parse_audiobook_metadata_from_tracks_metadata_two
}

def test_convert_series_for_group_tag_one_with_index [] {
  let expected = "Series One #1"
  assert equal ([[name index]; ["Series One" "1"]] | convert_series_for_group_tag) $expected
}

def test_convert_series_for_group_tag_two_with_index [] {
  let expected = "Series One #1;Mistborn #3"
  assert equal ([[name index]; ["Series One" "1"] ["Mistborn" "3"]] | convert_series_for_group_tag) $expected
}

def test_convert_series_for_group_tag_one_without_index_one_with_index [] {
  let expected = "Series One;Mistborn #3"
  assert equal ([[name index]; ["Series One" ""] ["Mistborn" "3"]] | convert_series_for_group_tag) $expected
}

def test_convert_series_for_group_tag [] {
  test_convert_series_for_group_tag_one_with_index
  test_convert_series_for_group_tag_two_with_index
  test_convert_series_for_group_tag_one_without_index_one_with_index
}

def test_into_tone_format_simple [] {
  let input = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage" "2"]
        ["Test Series 2" "5"]
      ]
      genres: [
        [name count];
        ["Fantasy" 1]
        ["Fiction" 1]
      ]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      total_discs: 1
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 001"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "writer"]
        ["1" "Damien Haas" artist narrator]
        ["2" "Miranda Parkin" artist narrator]
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "My Happy Marriage, Vol. 2/track 1.mp3"
      disc_number: 1
    }
  }
  let expected = {
    meta: {
      album: "My Happy Marriage, Vol. 2"
      albumArtist: "Akumi Agitogi"
      artist: "Akumi Agitogi"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      group: "My Happy Marriage #2;Test Series 2 #5"
      genre: "Fantasy;Fiction"
      publisher: "Yen Audio"
      label: "Yen Audio"
      publishingDate: "2025-01-01T00:00:00Z"
      recordingDate: "2025-01-01T00:00:00Z"
      title: "My Happy Marriage, Vol. 2 - Track 001"
      composer: "Damien Haas;Miranda Parkin"
      narrator: "Damien Haas;Miranda Parkin"
      trackNumber: 1
      embeddedPictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      discNumber: 1
      totalDiscs: 1
      additionalFields: {
        "MusicBrainz Album Artist Id": "3"
        publisher: "Yen Audio"
        "MusicBrainz Artist Id": "3"
        writer: "Akumi Agitogi"
      }
    }
  }
  assert equal ($input | into_tone_format) $expected
}

def test_into_tone_format_complex [] {
  # todo Make this test more complex
  let input = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage" "2"]
        ["Test Series 2" "5"]
      ]
      genres: [
        [name count];
        ["Fantasy" 1]
        ["Fiction" 1]
      ]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      total_discs: 1
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 001"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "writer"]
        ["1" "Damien Haas" artist narrator]
        ["2" "Miranda Parkin" artist narrator]
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "My Happy Marriage, Vol. 2/track 1.mp3"
      disc_number: 1
    }
  }
  let expected = {
    meta: {
      album: "My Happy Marriage, Vol. 2"
      albumArtist: "Akumi Agitogi"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      group: "My Happy Marriage #2;Test Series 2 #5"
      genre: "Fantasy;Fiction"
      publisher: "Yen Audio"
      label: "Yen Audio"
      publishingDate: "2025-01-01T00:00:00Z"
      recordingDate: "2025-01-01T00:00:00Z"
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist: "Akumi Agitogi"
      composer: "Damien Haas;Miranda Parkin"
      narrator: "Damien Haas;Miranda Parkin"
      trackNumber: 1
      embeddedPictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      additionalFields: {
        "MusicBrainz Album Artist Id": "3"
        publisher: "Yen Audio"
        "MusicBrainz Artist Id": "3"
        writer: "Akumi Agitogi"
      }
      discNumber: 1
      totalDiscs: 1
    }
  }
  assert equal ($input | into_tone_format) $expected
}

def test_into_tone_format [] {
  test_into_tone_format_simple
  test_into_tone_format_complex
}

def test_tracks_into_tone_format_one_track [] {
  let input = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage" "2"]
        ["Test Series 2" "5"]
      ]
      genres: [
        [name count];
        ["Fantasy" 1]
        ["Fiction" 1]
      ]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      total_discs: 1
    }
    tracks: [{
      title: "My Happy Marriage, Vol. 2 - Track 001"
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "writer"]
        ["1" "Damien Haas" artist narrator]
        ["2" "Miranda Parkin" artist narrator]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "My Happy Marriage, Vol. 2/track 1.mp3"
      disc_number: 1
    }]
  }
  let expected = [{
    metadata: {
      meta: {
        album: "My Happy Marriage, Vol. 2"
        albumArtist: "Akumi Agitogi"
        artist: "Akumi Agitogi"
        comment: "Akumi Agitogi Purchased from Libro.fm."
        group: "My Happy Marriage #2;Test Series 2 #5"
        genre: "Fantasy;Fiction"
        publisher: "Yen Audio"
        label: "Yen Audio"
        publishingDate: "2025-01-01T00:00:00Z"
        recordingDate: "2025-01-01T00:00:00Z"
        title: "My Happy Marriage, Vol. 2 - Track 001"
        composer: "Damien Haas;Miranda Parkin"
        narrator: "Damien Haas;Miranda Parkin"
        trackNumber: 1
        embeddedPictures: [
          [code mimetype];
          [13 image/jpeg]
        ]
        discNumber: 1
        totalDiscs: 1
        additionalFields: {
          "MusicBrainz Album Artist Id": "3"
          publisher: "Yen Audio"
          "MusicBrainz Artist Id": "3"
          writer: "Akumi Agitogi"
        }
      }
    }
    file: "My Happy Marriage, Vol. 2/track 1.mp3"
  }]
  assert equal ($input | tracks_into_tone_format) $expected
}

def test_tracks_into_tone_format_two_tracks [] {
  let input = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "primary author"]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [
        [name index];
        ["My Happy Marriage" "2"]
        ["Test Series 2" "5"]
      ]
      genres: [
        [name count];
        ["Fantasy" 1]
        ["Fiction" 1]
      ]
      publishers: [
        [name id];
        ["Yen Audio" "608ea796-44de-4cf2-9b2c-45a797bbabfb"]
      ]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      total_discs: 1
    }
    tracks: [{
      title: "My Happy Marriage, Vol. 2 - Track 001"
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "writer"]
        ["2" "Miranda Parkin" artist narrator]
      ]
      comment: "Akumi Agitogi Purchased from Libro.fm."
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "My Happy Marriage, Vol. 2/track 1.mp3"
      disc_number: 1
    }, {
      title: "My Happy Marriage, Vol. 2 - Track 002"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      contributors: [
        [id name entity role];
        ["3" "Akumi Agitogi" artist "writer"]
        ["1" "Damien Haas" artist narrator]
        ["2" "Miranda Parkin" artist narrator]
      ]
      index: 2
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "My Happy Marriage, Vol. 2/track 2.mp3"
      disc_number: 1
    }]
  }
  let expected = [{
    file: "My Happy Marriage, Vol. 2/track 1.mp3"
    metadata: {
      meta: {
        album: "My Happy Marriage, Vol. 2"
        albumArtist: "Akumi Agitogi"
        artist: "Akumi Agitogi"
        comment: "Akumi Agitogi Purchased from Libro.fm."
        group: "My Happy Marriage #2;Test Series 2 #5"
        genre: "Fantasy;Fiction"
        publisher: "Yen Audio"
        label: "Yen Audio"
        publishingDate: "2025-01-01T00:00:00Z"
        recordingDate: "2025-01-01T00:00:00Z"
        title: "My Happy Marriage, Vol. 2 - Track 001"
        composer: "Miranda Parkin"
        narrator: "Miranda Parkin"
        trackNumber: 1
        embeddedPictures: [
          [code mimetype];
          [13 image/jpeg]
        ]
        discNumber: 1
        totalDiscs: 1
        additionalFields: {
          "MusicBrainz Album Artist Id": "3"
          publisher: "Yen Audio"
          "MusicBrainz Artist Id": "3"
          writer: "Akumi Agitogi"
        }
      }
    }
  }, {
    file: "My Happy Marriage, Vol. 2/track 2.mp3"
    metadata: {
      meta: {
        album: "My Happy Marriage, Vol. 2"
        albumArtist: "Akumi Agitogi"
        artist: "Akumi Agitogi"
        comment: "Akumi Agitogi Purchased from Libro.fm."
        group: "My Happy Marriage #2;Test Series 2 #5"
        genre: "Fantasy;Fiction"
        publisher: "Yen Audio"
        label: "Yen Audio"
        publishingDate: "2025-01-01T00:00:00Z"
        recordingDate: "2025-01-01T00:00:00Z"
        title: "My Happy Marriage, Vol. 2 - Track 002"
        composer: "Damien Haas;Miranda Parkin"
        narrator: "Damien Haas;Miranda Parkin"
        trackNumber: 2
        embeddedPictures: [
          [code mimetype];
          [13 image/jpeg]
        ]
        discNumber: 1
        totalDiscs: 1
        additionalFields: {
          "MusicBrainz Album Artist Id": "3"
          publisher: "Yen Audio"
          "MusicBrainz Artist Id": "3"
          writer: "Akumi Agitogi"
        }
      }
    }
  }]
  assert equal ($input | tracks_into_tone_format | sort-by metadata.meta.trackNumber) $expected
}

def test_tracks_into_tone_format [] {
  test_tracks_into_tone_format_one_track
  test_tracks_into_tone_format_two_tracks
}

def test_parse_release_ids_from_acoustid_response_no_track [] {
  let input = {
    results: []
    status: "ok"
  }
  assert equal ($input | parse_release_ids_from_acoustid_response) []
}

def test_parse_release_ids_from_acoustid_response_one_track_imperfect_score [] {
  let input = {
    results: [
      [id releases score];
      [
        "85ccd755-283f-4d11-91fb-74ebdd3111e9"
        [
          [id];
          ["b2c93465-beb1-4037-92ca-eab9d63ccdda"]
        ]
        0.99
      ]
    ]
    status: ok
  }
  let expected = [
    [acoustid_track_id release_ids score];
    [
      "85ccd755-283f-4d11-91fb-74ebdd3111e9"
      [
        "b2c93465-beb1-4037-92ca-eab9d63ccdda"
      ]
      0.99
    ]
  ]
  assert equal ($input | parse_release_ids_from_acoustid_response) $expected
}

def test_parse_release_ids_from_acoustid_response_one_track_with_one_release [] {
  let input = {
    results: [
      [id releases score];
      [
        "85ccd755-283f-4d11-91fb-74ebdd3111e9"
        [
          [id];
          ["b2c93465-beb1-4037-92ca-eab9d63ccdda"]
        ]
        1.0
      ]
    ]
    status: ok
  }
  let expected = [
    [acoustid_track_id release_ids score];
    [
      "85ccd755-283f-4d11-91fb-74ebdd3111e9"
      [
        "b2c93465-beb1-4037-92ca-eab9d63ccdda"
      ]
      1.0
    ]
  ]
  assert equal ($input | parse_release_ids_from_acoustid_response) $expected
}

def test_parse_release_ids_from_acoustid_response_one_track_with_two_releases [] {
  let input = {
    results: [
      [id releases score];
      [
        "85ccd755-283f-4d11-91fb-74ebdd3111e9"
        [
          [id];
          ["b2c93465-beb1-4037-92ca-eab9d63ccdda"]
          ["2f167f9c-d4df-4980-9cb2-876a98f829ef"]
        ]
        1.0
      ]
    ]
    status: ok
  }
  let expected = [
    [acoustid_track_id release_ids score];
    [
      "85ccd755-283f-4d11-91fb-74ebdd3111e9"
      [
        "b2c93465-beb1-4037-92ca-eab9d63ccdda"
        "2f167f9c-d4df-4980-9cb2-876a98f829ef"
      ]
      1.0
    ]
  ]
  assert equal ($input | parse_release_ids_from_acoustid_response) $expected
}

def test_parse_release_ids_from_acoustid_response_two_tracks [] {
  let input = {
    results: [
      [id releases score];
      [
        "85ccd755-283f-4d11-91fb-74ebdd3111e9"
        [
          [id];
          ["b2c93465-beb1-4037-92ca-eab9d63ccdda"]
        ]
        1.0
      ]
      [
        "966dd29f-cb04-4149-811e-078aec5e5835"
        [
          [id];
          ["8833a504-5703-4918-b44a-b82f7ce5eb8f"]
          ["540db13d-c371-49a2-902a-1c1d8ff87dc4"]
        ]
        1.0
      ]
    ]
    status: ok
  }
  let expected = [
    [acoustid_track_id release_ids score];
    [
      "85ccd755-283f-4d11-91fb-74ebdd3111e9"
      [
        "b2c93465-beb1-4037-92ca-eab9d63ccdda"
      ]
      1.0
    ]
    [
      "966dd29f-cb04-4149-811e-078aec5e5835"
      [
        "8833a504-5703-4918-b44a-b82f7ce5eb8f"
        "540db13d-c371-49a2-902a-1c1d8ff87dc4"
      ]
      1.0
    ]
  ]
  assert equal ($input | parse_release_ids_from_acoustid_response) $expected
}

def test_parse_release_ids_from_acoustid_response [] {
  test_parse_release_ids_from_acoustid_response_no_track
  test_parse_release_ids_from_acoustid_response_one_track_imperfect_score
  test_parse_release_ids_from_acoustid_response_one_track_with_one_release
  test_parse_release_ids_from_acoustid_response_one_track_with_two_releases
  test_parse_release_ids_from_acoustid_response_two_tracks
}

def test_determine_releases_from_acoustid_fingerprint_matches_empty [] {
  assert equal ([] | determine_releases_from_acoustid_fingerprint_matches) null
}

def test_determine_releases_from_acoustid_fingerprint_matches_one_track_one_release [] {
  let input = [
    [file fingerprint duration matches];
    [
      "/var/home/jordan/Downloads/musicbrainz/Monogatari/Bakemonogatari, Part 1/BAKEMONOGATARI part 1.m4b"
      "fingerprint"
      24700730000000ns
      [
        [id recordings score];
        [
          "ad5a8d74-6bc7-44ed-8435-7ec5b65b60e5"
          [
            [id releases];
            [
              "6e0a0c34-250a-4b13-a564-0072af584de9"
              [
                [id];
                ["cf2bec53-6d2a-4be6-bb34-886e3cad7e07"]
              ]
            ]
          ]
          1.0
        ]
      ]
    ]
  ]
  let expected = ["cf2bec53-6d2a-4be6-bb34-886e3cad7e07"]
  assert equal ($input | determine_releases_from_acoustid_fingerprint_matches) $expected
}

def test_determine_releases_from_acoustid_fingerprint_matches_one_track_two_releases [] {
  let input = [
    [file fingerprint duration matches];
    [
      "/var/home/jordan/Downloads/musicbrainz/Monogatari/Bakemonogatari, Part 1/BAKEMONOGATARI part 1.m4b"
      "fingerprint"
      24700730000000ns
      [
        [id recordings score];
        [
          "ad5a8d74-6bc7-44ed-8435-7ec5b65b60e5"
          [
            [id releases];
            [
              "6e0a0c34-250a-4b13-a564-0072af584de9"
              [
                [id];
                ["b2c93465-beb1-4037-92ca-eab9d63ccdda"]
                ["cf2bec53-6d2a-4be6-bb34-886e3cad7e07"]
              ]
            ]
          ]
          1.0
        ]
      ]
    ]
  ]
  let expected = [
    "b2c93465-beb1-4037-92ca-eab9d63ccdda"
    "cf2bec53-6d2a-4be6-bb34-886e3cad7e07"
  ]
  assert equal ($input | determine_releases_from_acoustid_fingerprint_matches) $expected
}

def test_determine_releases_from_acoustid_fingerprint_matches_thirteen_tracks_one_release [] {
  let input = [[file, fingerprint, duration, matches]; ["Baccano! Vol. 1 (light novel) - Track 001.mp3", "1", 30090000000ns, [[id, recordings, score]; ["3640c01c-a763-404e-9ec4-c60d28820e01", [[id, releases]; ["a017ad86-9318-4688-93fc-67acd226c24b", [[id]; ["0425322c-c953-477a-9494-affb04314373"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 002.mp3", "2", 1350160000000ns, [[id, recordings, score]; ["30976711-0ae5-431e-8fa7-56aee9d50dd1", [[id, releases]; ["6a10103d-ec54-48f5-b6b2-f1d12938bb9b", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 003.mp3", "3", 509130000000ns, [[id, recordings, score]; ["91b44ea0-f078-4d1e-afee-b0b4a8772316", [[id, releases]; ["8b913142-4a8b-4be8-98f9-d25a2ff1537b", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 004.mp3", "4", 4117130000000ns, [[id, recordings, score]; ["9dd90c27-94f5-4fa7-8ea6-dcd3b7f7d456", [[id, releases]; ["b8655446-d779-4d1c-a8d3-e19b6a4e702f", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 005.mp3", "5", 4542270000000ns, [[id, recordings, score]; ["c88dcadb-328e-4a81-8e70-80177c9834c5", [[id, releases]; ["ee72646d-b260-4e5e-8b45-5de2b5d5daba", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 006.mp3", "6", 1270650000000ns, [[id, recordings, score]; ["9f119955-0341-4d62-a6c5-137dbc99f214", [[id, releases]; ["75486e2b-5cbd-4682-9f37-1f2404d3221a", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 007.mp3", "7", 3357050000000ns, [[id, recordings, score]; ["120dc6ab-ef38-4ac9-a3d4-4e5052ecb7b8", [[id, releases]; ["025f99e5-cde5-4753-ba0c-2391b357b021", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 008.mp3", "8", 1545770000000ns, [[id, recordings, score]; ["95af01f0-1579-460b-998e-cf4b6c2e6f79", [[id, releases]; ["5d80e2ed-8164-4336-869b-0edf82bd6225", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 009.mp3", "9", 4237770000000ns, [[id, recordings, score]; ["27b42309-c46b-450e-a05d-d5f17ae0dc88", [[id, releases]; ["87896433-746e-461d-995c-eb1002376905", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 010.mp3", "10", 751600000000ns, [[id, recordings, score]; ["8f7cd0be-91ac-4d80-ad16-dca82020d6ff", [[id, releases]; ["33137454-1d0b-47ba-8273-ffa3dde7e971", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 011.mp3", "11", 781190000000ns, [[id, recordings, score]; ["c2abc000-8ca0-4029-b8a7-89092d772767", [[id, releases]; ["617223b7-419e-4dfa-923e-21ba9655f39b", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 012.mp3", "12", 361820000000ns, [[id, recordings, score]; ["75cd8d2f-3931-45cc-b4be-23c74d1387b7", [[id, releases]; ["54227782-962c-4a14-825d-8057baf6e6cd", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 013.mp3", "13", 131870000000ns, [[id, recordings, score]; ["e086eb93-e02b-41e6-b882-3ef59824da04", [[id, releases]; ["4f811dc2-3de0-47ce-afbb-3602a21c814c", [[id]; ["0425322c-c953-477a-9494-affb04314373"]]]], 1.0]]]]
  let expected = ["0425322c-c953-477a-9494-affb04314373"]
  assert equal ($input | determine_releases_from_acoustid_fingerprint_matches) $expected
}

def test_determine_releases_from_acoustid_fingerprint_matches [] {
  test_determine_releases_from_acoustid_fingerprint_matches_empty
  test_determine_releases_from_acoustid_fingerprint_matches_one_track_one_release
  test_determine_releases_from_acoustid_fingerprint_matches_one_track_two_releases
  test_determine_releases_from_acoustid_fingerprint_matches_thirteen_tracks_one_release
}

def test_parse_works_from_musicbrainz_relations_bakemonogatari_part_01 [] {
  let input = (
    open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
    | get media
    | get tracks
    | flatten
    | get recording
    | get relations
    | flatten
  )
  let expected = [[iswcs, disambiguation, relations, type-id, languages, id, language, title, type, attributes]; [[], "light novel, English", [{artist: {type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", sort-name: "Ransom, Ko", disambiguation: translator, country: null, type: Person, id: "3192a6d6-bf15-434e-bfea-827865a3cc0a", name: "Ko Ransom"}, type-id: "da6c5d8a-ce13-474d-9375-61feb29039a5", ended: false, direction: backward, target-credit: "", begin: null, attribute-values: {}, attribute-ids: {}, target-type: artist, end: null, source-credit: "", attributes: [], type: translator}, {target-type: artist, end: null, type: writer, source-credit: "", attributes: [], attribute-ids: {}, attribute-values: {}, begin: null, artist: {id: "2c7b9427-6776-4969-8028-5de988724659", name: 西尾維新, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", sort-name: NISIOISIN, disambiguation: "Japanese novelist", country: JP, type: Person}, ended: false, type-id: "a255bca1-b157-4518-9108-7b147dc3fc68", target-credit: NISIOISIN, direction: backward}, {type: "part of", source-credit: "", attributes: [number], end: null, target-type: series, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, ordering-key: 1, attribute-values: {number: "1"}, begin: null, target-credit: "", direction: backward, ended: false, series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322", name: Bakemonogatari}, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0"}, {attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, ordering-key: 1, type: "part of", source-credit: "", attributes: [number], end: null, target-type: series, target-credit: "", direction: backward, ended: false, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", series: {type-id: "b689f694-6305-3d78-954d-df6759a1877b", disambiguation: "light novel, English", type: "Work series", id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3", name: Monogatari}, attribute-values: {number: "1"}, begin: null}, {attributes: [number], source-credit: "", type: "part of", end: null, target-type: series, ordering-key: 2, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, begin: null, attribute-values: {number: "1"}, direction: backward, target-credit: "", type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef", name: "Monogatari Series: First Season"}, ended: false}, {attribute-ids: {}, target-type: url, url: {id: "817e90a9-f58e-48ce-8ea8-e3aed01ed308", resource: "https://bookbrainz.org/work/ae3d4e16-7524-456d-a72f-318a1700b2ad"}, end: null, attributes: [], source-credit: "", type: BookBrainz, type-id: "0ea7cf4e-93dd-4bc4-b748-0f1073cf951c", ended: false, direction: backward, target-credit: "", begin: null, attribute-values: {}}, {attribute-ids: {}, target-type: url, end: null, url: {id: "da650123-1830-464d-ae2d-3063278a5430", resource: "https://openlibrary.org/works/OL19749568W"}, type: "other databases", attributes: [], source-credit: "", ended: false, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", target-credit: "", direction: backward, attribute-values: {}, begin: null}, {attribute-ids: {}, target-type: url, type: "other databases", source-credit: "", attributes: [], url: {id: "08766fc9-4f13-4a68-8070-1f8c76d8530b", resource: "https://www.librarything.com/work/18801353"}, end: null, target-credit: "", direction: backward, ended: false, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", attribute-values: {}, begin: null}, {target-type: work, type: "other version", source-credit: "", attributes: [translated], end: null, attribute-ids: {translated: "ed11fcb1-5a18-4e1d-b12c-633ed19c8ee1"}, attribute-values: {}, begin: null, target-credit: "", work: {type: Prose, attributes: [], title: 化物語（上）, language: null, id: "35d328d1-7d5d-4c2c-a1e1-47dda806de3e", languages: [], disambiguation: "light novel", type-id: "78a8e727-edc2-35b9-8829-a46111ef6df9", iswcs: []}, direction: backward, ended: false, type-id: "7440b539-19ab-4243-8c03-4f5942ca2218"}], "78a8e727-edc2-35b9-8829-a46111ef6df9", [eng], "1f1a315c-49fe-4d4c-9c07-1903a113f984", eng, "Bakemonogatari: Monster Tale, Part 01", Prose, []]]
  assert equal ($input | parse_works_from_musicbrainz_relations) $expected
}

def test_parse_works_from_musicbrainz_relations [] {
  test_parse_works_from_musicbrainz_relations_bakemonogatari_part_01
}

def test_parse_contributor_by_type_from_musicbrainz_relations_bakemonogatari_part_01_narrators [] {
  let input = (
    open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
    | get media
    | get tracks
    | flatten
    | get recording
    | get relations
    | flatten
    | uniq
  )
  let expected = [
    [name id];
    ["Cristina Vee" "9fac1f69-0044-4b51-ad1c-6bee4c749b91"]
    ["Erica Mendez" "91225f09-2f8e-4aee-8718-9329cac8ef03"]
    ["Erik Kimerer" "ac830008-5b9c-4f98-ae2b-cac499c40ad8"]
    ["Keith Silverstein" "9c1e9bd5-4ded-4944-8190-1fec6e530e64"]
  ]
  assert equal ($input | parse_contributor_by_type_from_musicbrainz_relations artist vocal "spoken vocals" | sort-by name) $expected
}

def test_parse_contributor_by_type_from_musicbrainz_relations [] {
  test_parse_contributor_by_type_from_musicbrainz_relations_bakemonogatari_part_01_narrators
}

def test_parse_contributors_from_work_relations_bakemonogatari_part_01 [] {
  let input = [{end: null, ended: false, target-credit: "", begin: null, type: translator, attributes: [], attribute-ids: {}, target-type: artist, artist: {country: null, name: "Ko Ransom", id: "3192a6d6-bf15-434e-bfea-827865a3cc0a", disambiguation: translator, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", sort-name: "Ransom, Ko", type: Person}, type-id: "da6c5d8a-ce13-474d-9375-61feb29039a5", direction: backward, source-credit: "", attribute-values: {}}, {target-credit: NISIOISIN, begin: null, type: writer, end: null, ended: false, attribute-values: {}, direction: backward, source-credit: "", attributes: [], attribute-ids: {}, type-id: "a255bca1-b157-4518-9108-7b147dc3fc68", artist: {country: JP, name: 西尾維新, disambiguation: "Japanese novelist", id: "2c7b9427-6776-4969-8028-5de988724659", type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", sort-name: NISIOISIN, type: Person}, target-type: artist}, {ended: false, end: null, type: "part of", target-credit: "", begin: null, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", target-type: series, attributes: [number], ordering-key: 1, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attribute-values: {number: "1"}, direction: backward, source-credit: "", series: {disambiguation: "light novel, English", id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322", name: Bakemonogatari, type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series"}}, {series: {type: "Work series", type-id: "b689f694-6305-3d78-954d-df6759a1877b", name: Monogatari, id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3", disambiguation: "light novel, English"}, source-credit: "", direction: backward, attribute-values: {number: "1"}, ordering-key: 1, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attributes: [number], target-type: series, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", target-credit: "", begin: null, type: "part of", end: null, ended: false}, {ordering-key: 2, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attributes: [number], target-type: series, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", series: {disambiguation: "light novel, English", id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef", name: "Monogatari Series: First Season", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series"}, source-credit: "", direction: backward, attribute-values: {number: "1"}, end: null, ended: false, begin: null, target-credit: "", type: "part of"}, {end: null, ended: false, begin: null, target-credit: "", type: BookBrainz, attributes: [], attribute-ids: {}, url: {id: "817e90a9-f58e-48ce-8ea8-e3aed01ed308", resource: "https://bookbrainz.org/work/ae3d4e16-7524-456d-a72f-318a1700b2ad"}, type-id: "0ea7cf4e-93dd-4bc4-b748-0f1073cf951c", target-type: url, attribute-values: {}, direction: backward, source-credit: ""}, {target-type: url, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", url: {resource: "https://openlibrary.org/works/OL19749568W", id: "da650123-1830-464d-ae2d-3063278a5430"}, attribute-ids: {}, attributes: [], source-credit: "", direction: backward, attribute-values: {}, ended: false, end: null, type: "other databases", begin: null, target-credit: ""}, {direction: backward, source-credit: "", attribute-values: {}, target-type: url, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", url: {resource: "https://www.librarything.com/work/18801353", id: "08766fc9-4f13-4a68-8070-1f8c76d8530b"}, attributes: [], attribute-ids: {}, type: "other databases", target-credit: "", begin: null, ended: false, end: null}, {ended: false, end: null, type: "other version", target-credit: "", work: {title: 化物語（上）, type-id: "78a8e727-edc2-35b9-8829-a46111ef6df9", language: null, attributes: [], disambiguation: "light novel", id: "35d328d1-7d5d-4c2c-a1e1-47dda806de3e", type: Prose, iswcs: [], languages: []}, begin: null, target-type: work, type-id: "7440b539-19ab-4243-8c03-4f5942ca2218", attribute-ids: {translated: "ed11fcb1-5a18-4e1d-b12c-633ed19c8ee1"}, attributes: [translated], source-credit: "", direction: backward, attribute-values: {}}]
  let expected = [
    [name id entity role];
    ["Ko Ransom", "3192a6d6-bf15-434e-bfea-827865a3cc0a", artist, translator]
    ["NISIOISIN" "2c7b9427-6776-4969-8028-5de988724659" artist writer]
  ]
  assert equal ($input | parse_contributors | sort-by name) $expected
}

def test_parse_contributors [] {
  test_parse_contributors_from_work_relations_bakemonogatari_part_01
}

def test_parse_musicbrainz_artist_credit_bakemonogatari_part_01 [] {
  let input = [{name: NISIOISIN, artist: {disambiguation: "Japanese novelist", id: "2c7b9427-6776-4969-8028-5de988724659", name: 西尾維新, country: JP, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", type: Person, sort-name: NISIOISIN}, joinphrase: " read by "}, {name: "Erik Kimerer", joinphrase: "", artist: {sort-name: "Kimerer, Erik", type: Person, name: "Erik Kimerer", country: US, disambiguation: "voice actor", id: "ac830008-5b9c-4f98-ae2b-cac499c40ad8", type-id: "b6e035f4-3ce9-331c-97df-83397230b0df"}}]
  let expected = [
    [index name id];
    [0 "NISIOISIN" "2c7b9427-6776-4969-8028-5de988724659"]
    [1 "Erik Kimerer" "ac830008-5b9c-4f98-ae2b-cac499c40ad8"]
  ]
  assert equal ($input | parse_musicbrainz_artist_credit) $expected
}

def test_parse_musicbrainz_artist_credit [] {
  test_parse_musicbrainz_artist_credit_bakemonogatari_part_01
}

def test_parse_series_from_musicbrainz_relations_bakemonogatari_part_01_work_relations [] {
  let input = [{attribute-ids: {}, begin: null, target-credit: "", target-type: artist, artist: {name: "Ko Ransom", sort-name: "Ransom, Ko", id: "3192a6d6-bf15-434e-bfea-827865a3cc0a", country: null, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", disambiguation: translator, type: Person}, ended: false, type-id: "da6c5d8a-ce13-474d-9375-61feb29039a5", source-credit: "", direction: backward, type: translator, end: null, attributes: [], attribute-values: {}}, {target-credit: NISIOISIN, begin: null, target-type: artist, artist: {name: 西尾維新, id: "2c7b9427-6776-4969-8028-5de988724659", sort-name: NISIOISIN, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", disambiguation: "Japanese novelist", type: Person, country: JP}, type-id: "a255bca1-b157-4518-9108-7b147dc3fc68", ended: false, attribute-ids: {}, end: null, type: writer, attributes: [], attribute-values: {}, source-credit: "", direction: backward}, {target-type: s, target-credit: "", begin: null, ended: false, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attributes: [number], attribute-values: {number: "1"}, ordering-key: 1, end: null, type: "part of", source-credit: "", series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", name: Bakemonogatari, id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"}, direction: backward}, {direction: backward, source-credit: "", series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", name: Monogatari, id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3"}, ordering-key: 1, attribute-values: {number: "1"}, attributes: [number], type: "part of", end: null, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", ended: false, target-type: series, begin: null, target-credit: ""}, {source-credit: "", series: {id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef", name: "Monogatari Series: First Season", type: "Work series", type-id: "b689f694-6305-3d78-954d-df6759a1877b", disambiguation: "light novel, English"}, direction: backward, ordering-key: 2, attribute-values: {number: "1"}, attributes: [number], type: "part of", end: null, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, target-type: series, begin: null, target-credit: "", type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", ended: false}, {attribute-values: {}, attributes: [], end: null, type: BookBrainz, url: {resource: "https://bookbrainz.org/work/ae3d4e16-7524-456d-a72f-318a1700b2ad", id: "817e90a9-f58e-48ce-8ea8-e3aed01ed308"}, direction: backward, source-credit: "", ended: false, type-id: "0ea7cf4e-93dd-4bc4-b748-0f1073cf951c", target-type: url, begin: null, target-credit: "", attribute-ids: {}}, {attribute-ids: {}, ended: false, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", target-credit: "", begin: null, target-type: url, direction: backward, source-credit: "", type: "other databases", end: null, attributes: [], attribute-values: {}, url: {resource: "https://openlibrary.org/works/OL19749568W", id: "da650123-1830-464d-ae2d-3063278a5430"}}, {direction: backward, source-credit: "", end: null, type: "other databases", attributes: [], attribute-values: {}, url: {id: "08766fc9-4f13-4a68-8070-1f8c76d8530b", resource: "https://www.librarything.com/work/18801353"}, attribute-ids: {}, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", ended: false, target-credit: "", begin: null, target-type: url}, {target-type: work, target-credit: "", begin: null, ended: false, type-id: "7440b539-19ab-4243-8c03-4f5942ca2218", attribute-ids: {translated: "ed11fcb1-5a18-4e1d-b12c-633ed19c8ee1"}, work: {title: 化物語（上）, language: null, iswcs: [], id: "35d328d1-7d5d-4c2c-a1e1-47dda806de3e", type-id: "78a8e727-edc2-35b9-8829-a46111ef6df9", attributes: [], disambiguation: "light novel", languages: [], type: Prose}, attributes: [translated], attribute-values: {}, type: "other version", end: null, source-credit: "", direction: backward}, {source-credit: "", direction: backward, attributes: [], attribute-values: {}, end: null, type: translator, attribute-ids: {}, target-type: artist, target-credit: "", begin: null, type-id: "da6c5d8a-ce13-474d-9375-61feb29039a5", ended: false, artist: {country: null, disambiguation: translator, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", type: Person, name: "Ko Ransom", id: "3192a6d6-bf15-434e-bfea-827865a3cc0a", sort-name: "Ransom, Ko"}}, {direction: backward, source-credit: "", end: null, type: writer, attribute-values: {}, attributes: [], attribute-ids: {}, artist: {sort-name: NISIOISIN, id: "2c7b9427-6776-4969-8028-5de988724659", name: 西尾維新, type: Person, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", disambiguation: "Japanese novelist", country: JP}, ended: false, type-id: "a255bca1-b157-4518-9108-7b147dc3fc68", begin: null, target-credit: NISIOISIN, target-type: artist}, {series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", name: Bakemonogatari, id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"}, source-credit: "", direction: backward, type: "part of", end: null, attributes: [number], attribute-values: {number: "1"}, ordering-key: 1, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, begin: null, target-credit: "", target-type: series, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", ended: false}, {ended: false, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", target-type: series, target-credit: "", begin: null, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attribute-values: {number: "1"}, ordering-key: 1, attributes: [number], end: null, type: "part of", direction: backward, source-credit: "", series: {id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3", name: Monogatari, type: "Work series", type-id: "b689f694-6305-3d78-954d-df6759a1877b", disambiguation: "light novel, English"}}, {type: "part of", end: null, attributes: [number], ordering-key: 2, attribute-values: {number: "1"}, series: {type-id: "b689f694-6305-3d78-954d-df6759a1877b", disambiguation: "light novel, English", type: "Work series", name: "Monogatari Series: First Season", id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef"}, source-credit: "", direction: backward, begin: null, target-credit: "", target-type: series, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", ended: false, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}}, {source-credit: "", direction: backward, url: {resource: "https://bookbrainz.org/work/ae3d4e16-7524-456d-a72f-318a1700b2ad", id: "817e90a9-f58e-48ce-8ea8-e3aed01ed308"}, attribute-values: {}, attributes: [], type: BookBrainz, end: null, attribute-ids: {}, target-type: url, begin: null, target-credit: "", type-id: "0ea7cf4e-93dd-4bc4-b748-0f1073cf951c", ended: false}, {attribute-ids: {}, target-type: url, begin: null, target-credit: "", type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", ended: false, source-credit: "", direction: backward, url: {resource: "https://openlibrary.org/works/OL19749568W", id: "da650123-1830-464d-ae2d-3063278a5430"}, attribute-values: {}, attributes: [], type: "other databases", end: null}, {ended: false, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", begin: null, target-credit: "", target-type: url, attribute-ids: {}, end: null, type: "other databases", attribute-values: {}, attributes: [], url: {id: "08766fc9-4f13-4a68-8070-1f8c76d8530b", resource: "https://www.librarything.com/work/18801353"}, direction: backward, source-credit: ""}, {work: {languages: [], type: Prose, type-id: "78a8e727-edc2-35b9-8829-a46111ef6df9", disambiguation: "light novel", attributes: [], iswcs: [], id: "35d328d1-7d5d-4c2c-a1e1-47dda806de3e", language: null, title: 化物語（上）}, attribute-values: {}, attributes: [translated], type: "other version", end: null, source-credit: "", direction: backward, target-type: work, begin: null, target-credit: "", ended: false, type-id: "7440b539-19ab-4243-8c03-4f5942ca2218", attribute-ids: {translated: "ed11fcb1-5a18-4e1d-b12c-633ed19c8ee1"}}]
  let expected = [
    [name id index];
    ["Bakemonogatari" "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "1"]
    ["Monogatari" "05ef20c8-9286-4b53-950f-eac8cbb32dc3" "1"]
    ["Monogatari Series: First Season" "6660f123-24a0-46c7-99bf-7ff5dc11ceef" "1"]
  ]
  assert equal ($input | parse_series_from_musicbrainz_relations | sort-by name) $expected
}

def test_parse_series_from_musicbrainz_relations [] {
  test_parse_series_from_musicbrainz_relations_bakemonogatari_part_01_work_relations
}

def test_parse_series_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  let expected = [
    [name id index];
    ["Monogatari, read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein" "2c867f6d-09db-477e-99f1-aa7725239720" "3"]
    ["Bakemonogatari, read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein" "94b16acb-7f06-42e1-96ac-7ff970972238" "1"]
    ["Bakemonogatari" "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "1"]
    ["Monogatari" "05ef20c8-9286-4b53-950f-eac8cbb32dc3" "1"]
    ["Monogatari Series: First Season" "6660f123-24a0-46c7-99bf-7ff5dc11ceef" "1"]
  ]
  let actual = $input | parse_series_from_musicbrainz_release ["release", "release-group", "works"]
  assert equal ($actual | take 2) ($expected | take 2)
  assert equal ($actual | skip 2 | sort-by name) ($expected | skip 2)
}

def test_parse_series_from_musicbrainz_release [] {
  test_parse_series_from_musicbrainz_release_bakemonogatari_part_01
}

def test_parse_audible_asin_from_url_non_audible_url [] {
  let input = "https://www.inaudible.com/pd/B0CQ3759C3"
  assert equal ($input | parse_audible_asin_from_url) null
}

def test_parse_audible_asin_from_url_short_url [] {
  let input = "https://www.audible.com/pd/B0CQ3759C3"
  let expected = "B0CQ3759C3"
  assert equal ($input | parse_audible_asin_from_url) $expected
}

def test_parse_audible_asin_from_url_long_url [] {
  let input = "https://www.audible.com/pd/Wind-and-Truth-Audiobook/B0CQ3759C3?eac_link=rtndJl"
  let expected = "B0CQ3759C3"
  assert equal ($input | parse_audible_asin_from_url) $expected
}

def test_parse_audible_asin_from_url [] {
  test_parse_audible_asin_from_url_non_audible_url
  test_parse_audible_asin_from_url_short_url
  test_parse_audible_asin_from_url_long_url
}

def test_parse_audible_asin_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  assert equal ($input | parse_audible_asin_from_musicbrainz_release) []
}

def test_parse_audible_asin_from_musicbrainz_release_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = ["B0CRSPBW6X"]
  assert equal ($input | parse_audible_asin_from_musicbrainz_release) $expected
}

def test_parse_audible_asin_from_musicbrainz_release [] {
  test_parse_audible_asin_from_musicbrainz_release_baccano_vol_1
  test_parse_audible_asin_from_musicbrainz_release_bakemonogatari_part_01
}

def test_parse_tags_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  let expected = [
    [name count];
    ["chapters" 1]
    ["fiction" 1]
    ["light novel" 1]
    ["mystery" 1]
    ["paranormal" 1]
    ["psychological" 1]
    ["romance" 1]
    ["school life" 1]
    ["supernatural" 1]
    ["unabridged" 1]
    ["vampire" 1]
  ]
  assert equal ($input | parse_tags_from_musicbrainz_release) $expected
}

def test_parse_tags_from_musicbrainz_release_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = [
    [name count];
    ["adventure" 1]
    ["fantasy" 1]
    ["fiction" 1]
    ["historical fantasy" 1]
    ["light novel" 1]
    ["mystery" 1]
    ["paranormal" 1]
    ["supernatural" 1]
    ["unabridged" 1]
    ["urban fantasy" 1]
  ]
  assert equal ($input | parse_tags_from_musicbrainz_release) $expected
}

def test_parse_tags_from_musicbrainz_release [] {
  test_parse_tags_from_musicbrainz_release_baccano_vol_1
  test_parse_tags_from_musicbrainz_release_bakemonogatari_part_01
}

def test_parse_genres_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  let expected = [
    [name count];
    ["fiction" 1]
    ["light novel" 1]
    ["mystery" 1]
    ["paranormal" 1]
    ["psychological" 1]
    ["romance" 1]
    ["school life" 1]
    ["supernatural" 1]
    ["vampire" 1]
  ]
  assert equal ($input | parse_tags_from_musicbrainz_release) $expected
}

def test_parse_genres_from_musicbrainz_release_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = [
    [name count];
    ["adventure" 1]
    ["fantasy" 1]
    ["fiction" 1]
    ["historical fantasy" 1]
    ["light novel" 1]
    ["mystery" 1]
    ["paranormal" 1]
    ["supernatural" 1]
    ["urban fantasy" 1]
  ]
  assert equal ($input | parse_tags_from_musicbrainz_release) $expected
}

def test_parse_genres_from_musicbrainz_release_only_genres_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = []
  assert equal ($input | parse_genres --musicbrainz-genres-only) $expected
}

def test_parse_genres_from_musicbrainz_release [] {
  test_parse_genres_from_musicbrainz_release_baccano_vol_1
  test_parse_genres_from_musicbrainz_release_bakemonogatari_part_01
  test_parse_genres_from_musicbrainz_release_only_genres_baccano_vol_1
}

def test_parse_chapters_from_musicbrainz_release_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = [
    [index start length title];
    [0 0ms 22996000ms "Baccano! Vol. 1: The Rolling Bootlegs"]
  ]
  assert equal ($input | parse_chapters_from_musicbrainz_release) $expected
}

def test_parse_chapters_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  let expected = [
    [index start length title];
    [0 0ms 15000ms "Opening Credits"]
    [1, 15000000000ns, 55000000000ns, Copyright]
    [2, 70000000000ns, 370000000000ns, "Chapter One: Hitagi Crab, Chapter 001"]
    [3, 440000000000ns, 904000000000ns, "Chapter One: Hitagi Crab, Chapter 002"]
    [4, 1344000000000ns, 1437000000000ns, "Chapter One: Hitagi Crab, Chapter 003"]
    [5, 2781000000000ns, 1581000000000ns, "Chapter One: Hitagi Crab, Chapter 004"]
    [6, 4362000000000ns, 2430000000000ns, "Chapter One: Hitagi Crab, Chapter 005"]
    [7, 6792000000000ns, 1958000000000ns, "Chapter One: Hitagi Crab, Chapter 006"]
    [8, 8750000000000ns, 692000000000ns, "Chapter One: Hitagi Crab, Chapter 007"]
    [9, 9442000000000ns, 68000000000ns, "Chapter One: Hitagi Crab, Chapter 008"]
    [10, 9510000000000ns, 439000000000ns, "Chapter Two: Mayoi Snail, Chapter 001"]
    [11, 9949000000000ns, 2782000000000ns, "Chapter Two: Mayoi Snail, Chapter 002"]
    [12, 12731000000000ns, 1420000000000ns, "Chapter Two: Mayoi Snail, Chapter 003"]
    [13, 14151000000000ns, 1678000000000ns, "Chapter Two: Mayoi Snail, Chapter 004"]
    [14, 15829000000000ns, 1863000000000ns, "Chapter Two: Mayoi Snail, Chapter 005"]
    [15, 17692000000000ns, 3922000000000ns, "Chapter Two: Mayoi Snail, Chapter 006"]
    [16, 21614000000000ns, 1354000000000ns, "Chapter Two: Mayoi Snail, Chapter 007"]
    [17, 22968000000000ns, 1319000000000ns, "Chapter Two: Mayoi Snail, Chapter 008"]
    [18, 24287000000000ns, 154000000000ns, "Chapter Two: Mayoi Snail, Chapter 009"]
    [19, 24441000000000ns, 230000000000ns, Afterword]
    [20, 24671000000000ns, 30000000000ns, "End Credits"]
  ]
  assert equal ($input | parse_chapters_from_musicbrainz_release) $expected
}

def test_parse_chapters_from_musicbrainz_release [] {
  test_parse_chapters_from_musicbrainz_release_baccano_vol_1
  test_parse_chapters_from_musicbrainz_release_bakemonogatari_part_01
}

def test_parse_chapters_from_tone_baccano_vol_1 [] {
  let input = [
    [index start length title];
    [0 0 15000 "Opening Credits"]
  ]
  let expected = [
    [index start length title];
    [0 0ms 15000ms "Opening Credits"]
  ]
  assert equal ($input | parse_chapters_from_tone) $expected
}

def test_parse_chapters_from_tone [] {
  test_parse_chapters_from_tone_baccano_vol_1
}

def test_chapters_into_tone_format_baccano_vol_1 [] {
  let input = [
    [index start length title];
    [0 0ms 15000ms "Opening Credits"]
  ]
  let expected = [
    [index start length title subtitle];
    [0 0 15000 "Opening Credits" ""]
  ]
  assert equal ($input | chapters_into_tone_format) $expected
}

def test_chapters_into_tone_format [] {
  test_chapters_into_tone_format_baccano_vol_1
}

def test_parse_musicbrainz_release_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = {
    book: {
      musicbrainz_release_id: "64801f58-229a-49f9-9d2d-6a44684ebe38"
      musicbrainz_release_group_id: "4b745bd7-49f7-46d7-bf47-52e9d27b121b"
      musicbrainz_release_types: [
        other
        audiobook
      ]
      title: "Baccano! Vol. 1: The Rolling Bootlegs"
      contributors: [
        [name id entity role];
        ["Ryohgo Narita" "efc0e95e-2d3e-4219-8ebb-28ed3751e6ab" artist "primary author"]
        ["Katsumi Enami" "9d82c45c-5383-4e19-b868-516ce05d3e60" artist illustrator]
        ["Audible Inc." "926e2da3-af75-4571-8159-fcceb8a0aed3" label distributor]
      ]
      musicbrainz_release_country: "XW"
      musicbrainz_release_status: "official"
      amazon_asin: "B0CRSJ8RQV"
      audible_asin: "B0CRSPBW6X"
      genres: [
        [name count];
        [adventure 1]
        [fantasy 1]
        [fiction 1]
        ["historical fantasy" 1]
        ["light novel" 1]
        [mystery 1]
        [paranormal 1]
        [supernatural 1]
        ["urban fantasy" 1]
      ],
      tags: [
        [name count];
        [unabridged 1]
      ],
      release_tags: [
        [name count];
        [unabridged 1]
      ],
      publication_date: ("2024-05-14T00:00:00-05:00" | into datetime)
      series: [
        [name id index];
        [
          "Baccano! read by Michael Butler Murray"
          "762cd100-5319-4f9e-8a97-c7f71ae66ad7"
          "1"
        ]
      ]
      front_cover_available: true
      publishers: [
        [id name];
        ["608ea796-44de-4cf2-9b2c-45a797bbabfb" "Yen Audio"]
      ]
      total_discs: 1
      total_tracks: 1
      packaging: "None"
      script: "Latn"
      language: "eng"
    }
    tracks: [
      [
        index
        disc_number
        media
        musicbrainz_track_id
        title
        musicbrainz_recording_id
        genres
        tags
        musicbrainz_works
        contributors
        duration
      ];
      [
        1
        1
        "Digital Media"
        "81c1f9ae-d00d-4ac3-8dd4-058369c94ae3"
        "Baccano! Vol. 1: The Rolling Bootlegs"
        "7c7064d1-fd42-414c-a8d3-52cce1e58ad1"
        [
          [name count];
          [adventure 1]
          [fantasy 1]
          [fiction 1]
          ["historical fantasy" 1]
          ["light novel" 1]
          [mystery 1]
          [paranormal 1]
          [supernatural 1]
          ["urban fantasy" 1]
        ]
        [
          [name count];
          [unabridged 1]
        ]
        [[id title bookbrainz_work_id]; ["4b5f1fcc-1765-43c3-89f9-a20998cfb5a4" "Baccano!, Vol. 1: The Rolling Bootlegs" "9edfaf35-77dc-4ad5-aa15-d048f8609b17"]]
        [
          [id, name, entity, role];
          ["efc0e95e-2d3e-4219-8ebb-28ed3751e6ab", "Ryohgo Narita", artist, writer]
          ["22c39a37-28b7-4ff2-aa0b-67f93279a1ef", "Michael Butler Murray", artist, narrator]
          ["5cfde560-3992-4706-9fad-fc20c11c97fa", "Taylor Engel", artist, translator]
        ]
        22996000000000ns
      ]
    ]
  }
  let actual = ($input | parse_musicbrainz_release)
  # assert equal ($actual | get book | columns) ($expected | get book | columns)
  # assert equal ($actual | get book | get genres) ($expected | get book | get genres)
  # assert equal ($actual | get book | get tags) ($expected | get book | get tags)
  # assert equal ($actual | get book | get release_tags) ($expected | get book | get release_tags)
  # assert equal ($actual | get book | get series) ($expected | get book | get series)
  # assert equal ($actual | get book | get contributors) ($expected | get book | get contributors)
  # assert equal ($actual | get book) ($expected | get book)
  # assert equal ($actual | get tracks | first | columns) ($expected | get tracks | first | columns)
  # assert equal ($actual | get tracks | first | get contributors) ($expected | get tracks | first | get contributors)
  # assert equal ($actual | get tracks | first | get musicbrainz_works) ($expected | get tracks | first | get musicbrainz_works)
  # assert equal ($actual | get tracks | first) ($expected | get tracks | first)
  # assert equal ($actual | get tracks) ($expected | get tracks)
  assert equal $actual $expected
}

def test_parse_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  let expected = {
    book: {
      musicbrainz_release_id: "b2c07b6e-0f22-44b1-a87a-99e0f9c9623b"
      musicbrainz_release_group_id: "b931acdb-2292-4f34-9dfa-151e33ae17a7"
      musicbrainz_release_types:
      [
        other
        audiobook
      ]
      title: "Bakemonogatari: Monster Tale, Part 01"
      contributors: [
        [id name entity role];
        ["2c7b9427-6776-4969-8028-5de988724659" NISIOISIN artist "primary author"]
        ["ac830008-5b9c-4f98-ae2b-cac499c40ad8" "Erik Kimerer" artist narrator]
        ["91225f09-2f8e-4aee-8718-9329cac8ef03" "Erica Mendez" artist narrator]
        ["9c1e9bd5-4ded-4944-8190-1fec6e530e64" "Keith Silverstein" artist narrator]
        ["9fac1f69-0044-4b51-ad1c-6bee4c749b91" "Cristina Vee" artist narrator]
        ["4448c994-30ba-4095-8b6b-6068c3cc2152" VOFAN artist illustrator]
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
        ["47375c4f-1441-4e35-a700-b2d975a95b98" "Kodansha USA" label publisher]
      ]
      isbn: "9781949980523"
      musicbrainz_release_country: "XW"
      musicbrainz_release_status: "official"
      genres: [
        [name count];
        [fiction 1]
        ["light novel" 1]
        [mystery 1]
        [paranormal 1]
        [psychological 1]
        [romance 1]
        ["school life" 1]
        [supernatural 1]
        [vampire 1]
      ]
      tags: [
        [name count];
        [chapters 1]
        [unabridged 1]
      ]
      release_tags: [
        [name count];
        [chapters 1]
        [unabridged 1]
      ]
      publication_date: ("2020-03-24T00:00:00-05:00" | into datetime)
      series: [
        [name id index];
        [
          "Monogatari, read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"
          "2c867f6d-09db-477e-99f1-aa7725239720"
          "3"
        ] [
          "Bakemonogatari, read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"
          "94b16acb-7f06-42e1-96ac-7ff970972238"
          "1"
        ]
      ]
      chapters: [[index, start, length, title]; [0, 0ns, 15000000000ns, "Opening Credits"], [1, 15000000000ns, 55000000000ns, Copyright], [2, 70000000000ns, 370000000000ns, "Chapter One: Hitagi Crab, Chapter 001"], [3, 440000000000ns, 904000000000ns, "Chapter One: Hitagi Crab, Chapter 002"], [4, 1344000000000ns, 1437000000000ns, "Chapter One: Hitagi Crab, Chapter 003"], [5, 2781000000000ns, 1581000000000ns, "Chapter One: Hitagi Crab, Chapter 004"], [6, 4362000000000ns, 2430000000000ns, "Chapter One: Hitagi Crab, Chapter 005"], [7, 6792000000000ns, 1958000000000ns, "Chapter One: Hitagi Crab, Chapter 006"], [8, 8750000000000ns, 692000000000ns, "Chapter One: Hitagi Crab, Chapter 007"], [9, 9442000000000ns, 68000000000ns, "Chapter One: Hitagi Crab, Chapter 008"], [10, 9510000000000ns, 439000000000ns, "Chapter Two: Mayoi Snail, Chapter 001"], [11, 9949000000000ns, 2782000000000ns, "Chapter Two: Mayoi Snail, Chapter 002"], [12, 12731000000000ns, 1420000000000ns, "Chapter Two: Mayoi Snail, Chapter 003"], [13, 14151000000000ns, 1678000000000ns, "Chapter Two: Mayoi Snail, Chapter 004"], [14, 15829000000000ns, 1863000000000ns, "Chapter Two: Mayoi Snail, Chapter 005"], [15, 17692000000000ns, 3922000000000ns, "Chapter Two: Mayoi Snail, Chapter 006"], [16, 21614000000000ns, 1354000000000ns, "Chapter Two: Mayoi Snail, Chapter 007"], [17, 22968000000000ns, 1319000000000ns, "Chapter Two: Mayoi Snail, Chapter 008"], [18, 24287000000000ns, 154000000000ns, "Chapter Two: Mayoi Snail, Chapter 009"], [19, 24441000000000ns, 230000000000ns, Afterword], [20, 24671000000000ns, 30000000000ns, "End Credits"]]
      front_cover_available: true
      publishers: [
        [id name];
        ["0ba425d2-adf8-4fb9-bc3e-2d24215f7374", "Vertical"]
      ]
      total_discs: 1
      total_tracks: 21
      packaging: "None"
      script: "Latn"
      language: "eng"
    }
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration]; [1, 1, "Digital Media", "1af64466-4b91-4d49-8c48-743c8bbdc542", "Opening Credits", "ddf19afa-8d0a-4d7d-95f5-c6f0ad6daaf5", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 15000000000ns], [2, 1, "Digital Media", "7a41a13e-18f2-48a2-943e-ab65e646800b", Copyright, "19af78c6-fa48-4b1d-b211-c916dbdb29cc", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 55000000000ns], [3, 1, "Digital Media", "ee624e13-4ba9-4ebb-ae65-f3bb4da8f09c", "Chapter One: Hitagi Crab, Chapter 001", "6a9b6fcf-bcdf-4077-9f92-21153773ae7c", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 370000000000ns], [4, 1, "Digital Media", "e54e6d65-a8ef-481a-b5cc-e1df1b34fd34", "Chapter One: Hitagi Crab, Chapter 002", "eff08c59-06fe-4b4c-8f12-923d8228fa45", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 904000000000ns], [5, 1, "Digital Media", "1fe66e7b-defe-4f6a-89ba-a63e46bd57d2", "Chapter One: Hitagi Crab, Chapter 003", "17cc0da0-ee32-4686-81b7-85202cc29775", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1437000000000ns], [6, 1, "Digital Media", "5790db34-a353-4648-9c90-b067f4c97b18", "Chapter One: Hitagi Crab, Chapter 004", "359596d6-213a-49e2-a0b4-1c01968ca660", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1581000000000ns], [7, 1, "Digital Media", "4a96c1b7-20a9-4e39-becf-56dfe96423a0", "Chapter One: Hitagi Crab, Chapter 005", "83fb8681-62eb-4b31-9269-bf2e2d3703d0", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 2430000000000ns], [8, 1, "Digital Media", "f68880dd-fd54-459e-a3f6-32a0c405cc93", "Chapter One: Hitagi Crab, Chapter 006", "99a7fc25-4765-4df7-951e-7f6e870cab85", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1958000000000ns], [9, 1, "Digital Media", "46f366db-03b8-47e3-822b-e5088bdb6194", "Chapter One: Hitagi Crab, Chapter 007", "85176035-3856-443f-bb17-d602d0b6a4c0", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 692000000000ns], [10, 1, "Digital Media", "c2ee3a84-58c2-4152-a420-7d55d58bd05e", "Chapter One: Hitagi Crab, Chapter 008", "a201d5c4-a6f7-4609-abc2-dcb54052c7ea", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 68000000000ns], [11, 1, "Digital Media", "88981d2d-9af9-4bf9-a96a-e040b9afe48b", "Chapter Two: Mayoi Snail, Chapter 001", "59f48ed4-bfbf-4b4c-8df5-d5133366da4d", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 439000000000ns], [12, 1, "Digital Media", "c11d5faa-4893-4825-98b3-c1b200957800", "Chapter Two: Mayoi Snail, Chapter 002", "bda5b5e5-9ed2-4ce2-9221-c8797e1247d8", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 2782000000000ns], [13, 1, "Digital Media", "ce379ad4-e31c-4ae8-83ea-c5ebe4ed57ec", "Chapter Two: Mayoi Snail, Chapter 003", "6dee17b8-2198-44df-8841-a0f311771623", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1420000000000ns], [14, 1, "Digital Media", "a6a8838d-4b2f-4e4c-8c3b-58b6aa2df200", "Chapter Two: Mayoi Snail, Chapter 004", "01aadb9b-055c-4839-b8da-b7f146493b23", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1678000000000ns], [15, 1, "Digital Media", "c688dcc3-5200-4fd7-8566-15fc29b75c09", "Chapter Two: Mayoi Snail, Chapter 005", "7feca352-c937-4220-8dee-28ebfaa3bc6d", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1863000000000ns], [16, 1, "Digital Media", "9822b36c-d3dc-4f4a-b200-5519c09fae62", "Chapter Two: Mayoi Snail, Chapter 006", "5798acc6-7724-4af8-9078-89c475a12ed2", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 3922000000000ns], [17, 1, "Digital Media", "9e2f4206-f380-4a50-8d3f-43faf675e429", "Chapter Two: Mayoi Snail, Chapter 007", "d3396b1a-5896-4c39-b5d9-37d478a7f4f9", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1354000000000ns], [18, 1, "Digital Media", "85e22b41-9038-4fe0-acaa-adfd8d5d60c5", "Chapter Two: Mayoi Snail, Chapter 008", "60ee765c-41d4-477a-b6b4-85d280c953d5", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1319000000000ns], [19, 1, "Digital Media", "1948d583-f1c3-4997-9234-fe96479dd0a5", "Chapter Two: Mayoi Snail, Chapter 009", "88df0c01-8617-4796-a41b-ad4463fd0cc7", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 154000000000ns], [20, 1, "Digital Media", "0146128e-31d1-4e37-be88-cebc09f178dd", Afterword, "5b57067e-a537-4075-bb59-2240af0fcc97", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 230000000000ns], [21, 1, "Digital Media", "ab132164-d144-4c71-97f1-b35966da72a5", "End Credits", "3b927907-6b99-4437-920c-70f387a0437e", [[id, title, bookbrainz_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "817e90a9-f58e-48ce-8ea8-e3aed01ed308"]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 30000000000ns]]
  }
  let actual = ($input | parse_musicbrainz_release)
  # assert equal ($actual | get book | columns) ($expected | get book | columns)
  # assert equal ($actual | get book | get genres) ($expected | get book | get genres)
  # assert equal ($actual | get book | get tags) ($expected | get book | get tags)
  # assert equal ($actual | get book | get release_tags) ($expected | get book | get release_tags)
  # assert equal ($actual | get book | get chapters) ($expected | get book | get chapters)
  # assert equal ($actual | get book | get series) ($expected | get book | get series)
  # assert equal ($actual | get book | get contributors) ($expected | get book | get contributors)
  # assert equal ($actual | get book | get publishers) ($expected | get book | get publishers)
  # assert equal ($actual | get book) ($expected | get book)
  # # log info $"($actual | get tracks | to nuon)"
  # assert equal ($actual | get tracks) ($expected | get tracks)
  assert equal $actual $expected
}

def test_parse_musicbrainz_release [] {
  test_parse_musicbrainz_release_baccano_vol_1
  test_parse_musicbrainz_release_bakemonogatari_part_01
}

def test_equivalent_track_durations_one_track_different [] {
  let left = [
    [index duration];
    [1 3.9sec]
  ]
  let right = [
    [index duration];
    [1 0.005sec]
  ]
  assert equal ($left | equivalent_track_durations $right) false
}

def test_equivalent_track_durations_one_track_equivalent [] {
  let left = [
    [index duration];
    [0 3sec]
  ]
  let right = [
    [index duration];
    [0 0.005sec]
  ]
  assert equal ($left | equivalent_track_durations $right) true
}

def test_equivalent_track_durations_two_tracks_equivalent [] {
  let left = [
    [index duration];
    [0 3sec]
    [1 15sec]
  ]
  let right = [
    [index duration];
    [0 0.005sec]
    [1 15sec]
  ]
  assert equal ($left | equivalent_track_durations $right) true
}

def test_equivalent_track_durations_one_empty [] {
  let left = []
  let right = [
    [index duration];
    [0 1sec]
    [1 2sec]
  ]
  assert equal ($left | equivalent_track_durations $right) false
}

def test_equivalent_track_durations_inconsistent_number_of_tracks [] {
  let left = [
    [index duration];
    [0 1sec]
    [1 2sec]
    [2 4.5sec]
  ]
  let right = [
    [index duration];
    [0 1sec]
    [1 2sec]
  ]
  assert equal ($left | equivalent_track_durations $right) false
}

def test_equivalent_track_durations_inconsistent_indices [] {
  let left = [
    [index duration];
    [0 1sec]
    [1 2sec]
    [2 4.5sec]
  ]
  let right = [
    [index duration];
    [0 1sec]
    [1 2sec]
    [3 5sec]
  ]
  assert equal ($left | equivalent_track_durations $right) false
}

def test_equivalent_track_durations_several_tracks_within_threshold [] {
  let left = [
    [index duration];
    [0 1sec]
    [1 2sec]
    [2 4.5sec]
    [3 6sec]
    [4 10sec]
    [5 15sec]
    [6 2sec]
  ]
  let right = [
    [index duration];
    [0 0.5sec]
    [1 2sec]
    [2 5sec]
    [3 3sec]
    [4 10sec]
    [5 15sec]
    [6 2sec]
  ]
  assert equal ($left | equivalent_track_durations $right) true
}

def test_equivalent_track_durations_several_tracks_one_outside_threshold [] {
  let left = [
    [index duration];
    [0 1sec]
    [1 2sec]
    [2 4.5sec]
    [3 6sec]
    [4 10sec]
    [5 15sec]
    [6 2sec]
  ]
  let right = [
    [index duration];
    [0 0.5sec]
    [0 2sec]
    [0 5sec]
    [0 2.99sec]
    [0 10sec]
    [0 15sec]
    [0 2sec]
  ]
  assert equal ($left | equivalent_track_durations $right) false
}

def test_equivalent_track_durations_duplicate_indices [] {
  let left = [
    [index duration];
    [0 1sec]
    [1 2sec]
    [2 4.5sec]
    [2 6sec]
    [3 10sec]
  ]
  let right = [
    [index duration];
    [0 0.5sec]
    [1 2sec]
    [2 5sec]
    [3 3sec]
    [3 10sec]
  ]
  assert equal ($left | equivalent_track_durations $right) false
}

def test_equivalent_track_durations_duplicate_indices_left [] {
  let left = [
    [index duration];
    [0 1sec]
    [1 2sec]
    [2 4.5sec]
    [2 6sec]
    [3 10sec]
  ]
  let right = [
    [index duration];
    [0 0.5sec]
    [1 2sec]
    [2 5sec]
    [3 3sec]
    [4 10sec]
  ]
  assert equal ($left | equivalent_track_durations $right) false
}

def test_equivalent_track_durations [] {
  test_equivalent_track_durations_one_track_different
  test_equivalent_track_durations_one_track_equivalent
  test_equivalent_track_durations_one_empty
  test_equivalent_track_durations_two_tracks_equivalent
  test_equivalent_track_durations_inconsistent_number_of_tracks
  test_equivalent_track_durations_inconsistent_indices
  test_equivalent_track_durations_several_tracks_within_threshold
  test_equivalent_track_durations_several_tracks_one_outside_threshold
  test_equivalent_track_durations_duplicate_indices
  test_equivalent_track_durations_duplicate_indices_left
}

def test_has_distributor_in_common_both_empty [] {
  let left = []
  let right = []
  assert equal ($left | has_distributor_in_common $right) true
}

def test_has_distributor_in_common_right_empty [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
  ]
  let right = []
  assert equal ($left | has_distributor_in_common $right) false
}

def test_has_distributor_in_common_left_empty [] {
  let left = []
  let right = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
  ]
  assert equal ($left | has_distributor_in_common $right) false
}

def test_has_distributor_in_common_none [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["926e2da3-af75-4571-8159-fcceb8a0aed3" "Audible Inc." label distributor]
  ]
  let right = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
  ]
  assert equal ($left | has_distributor_in_common $right) false
}

def test_has_distributor_in_common_same_name_different_id [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e9" "Libro.fm" label distributor]
  ]
  let right = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
  ]
  assert equal ($left | has_distributor_in_common $right) false
}

def test_has_distributor_in_common_same_id_different_entity [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e9" "Libro.fm" label distributor]
  ]
  let right = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" artist distributor]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
  ]
  assert equal ($left | has_distributor_in_common $right) false
}

def test_has_distributor_in_common_one [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
  ]
  let right = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
  ]
  assert equal ($left | has_distributor_in_common $right) true
}

def test_has_distributor_in_common_name_only_left [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["" "Libro.fm" label distributor]
  ]
  let right = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
  ]
  assert equal ($left | has_distributor_in_common $right) true
}

def test_has_distributor_in_common_name_only_right [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
  ]
  let right: table<id: string, name: string, entity: string, role: string> = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["" "Libro.fm" label distributor]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
  ]
  assert equal ($left | has_distributor_in_common $right) true
}

def test_has_distributor_in_common [] {
  test_has_distributor_in_common_left_empty
  test_has_distributor_in_common_right_empty
  test_has_distributor_in_common_both_empty
  test_has_distributor_in_common_none
  test_has_distributor_in_common_one
  test_has_distributor_in_common_same_name_different_id
  test_has_distributor_in_common_same_id_different_entity
  test_has_distributor_in_common_name_only_left
  test_has_distributor_in_common_name_only_right
}

def test_audiobooks_with_the_highest_voted_chapters_tag_empty_tags [] {
  let input = [
    [id tags];
    ["x" []]
    ["y" []]
  ]
  let expected = null
  assert equal ($input | audiobooks_with_the_highest_voted_chapters_tag) $expected
}

def test_audiobooks_with_the_highest_voted_chapters_tag_no_chapters_tag [] {
  let input = [
    [id tags];
    ["x" [[name count]; [chapter 1]]]
    ["y" [[name count]; [chapterz 3]]]
    ["z" [[name count]; [chaps 2]]]
  ]
  let expected = null
  assert equal ($input | audiobooks_with_the_highest_voted_chapters_tag) $expected
}

def test_audiobooks_with_the_highest_voted_chapters_tag_one [] {
  let input = [
    [id tags];
    ["x" [[name count]; [chapters 1]]]
  ]
  let expected = ["x"]
  assert equal ($input | audiobooks_with_the_highest_voted_chapters_tag) $expected
}

def test_audiobooks_with_the_highest_voted_chapters_tag_one_with_highest [] {
  let input = [
    [id tags];
    ["x" [[name count]; [chapters 1] [unabridged 1]]]
    ["y" [[name count]; [chapters 3] [unabridged 1]]]
    ["z" [[name count]; [chapters 2] [unabridged 1]]]
  ]
  let expected = ["y"]
  assert equal ($input | audiobooks_with_the_highest_voted_chapters_tag) $expected
}

def test_audiobooks_with_the_highest_voted_chapters_tag_two_with_highest [] {
  let input = [
    [id tags];
    ["u" [[name count]; [chapters 1]]]
    ["x" [[name count]; [chapters 3]]]
    ["y" [[name count]; [chapters 2]]]
    ["z" [[name count]; [chapters 3]]]
  ]
  let expected = ["x" "z"]
  assert equal ($input | audiobooks_with_the_highest_voted_chapters_tag) $expected
}

def test_audiobooks_with_the_highest_voted_chapters_tag [] {
  test_audiobooks_with_the_highest_voted_chapters_tag_empty_tags
  test_audiobooks_with_the_highest_voted_chapters_tag_no_chapters_tag
  test_audiobooks_with_the_highest_voted_chapters_tag_one
  test_audiobooks_with_the_highest_voted_chapters_tag_one_with_highest
  test_audiobooks_with_the_highest_voted_chapters_tag_two_with_highest
}

def test_filter_musicbrainz_chapters_releases_bad_length [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      isbn: "9781501915925",
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 1,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file, duration_, title_, index_, musicbrainz_works_, contributors_, disc_number_, musicbrainz_track_id_, audio_duration];
      [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, 1, [[id]; ["39d174df-2902-44f0-ae68-7c86828c6cdc"]], [{id: "", name: "Alyssa Bresnahan", entity: artist, role: composer}, {id: "", name: "Alyssa Bresnahan", entity: artist, role: narrator}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: writer, entity: artist}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: "primary author", entity: artist}], 1, "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", 89818818000000ns]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 192000000000ns, "Opening Credits"]
          [1, 192000000000ns, 1448000000000ns, Prologue]
          [2, 1640000000000ns, 1616000000000ns, "Chapter 1"]
          [3, 3256000000000ns, 1156000000000ns, "Chapter 2"]
          [4, 4412000000000ns, 1615000000000ns, "Chapter 3"]
          [5, 6027000000000ns, 835000000000ns, "Chapter 4"]
          [6, 6862000000000ns, 1570000000000ns, "Chapter 5"]
          [7, 8432000000000ns, 1809000000000ns, "Chapter 6"]
          [8, 10241000000000ns, 1683000000000ns, "Chapter 7"]
          [9, 11924000000000ns, 1272000000000ns, "Chapter 8"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 10,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 192000000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 1448000000000ns]
        [3, 1, "Digital Media", "6f44d2f1-238b-4f61-9456-4d165226a213", "Chapter 1", "05aace3e-9cd2-44eb-83b8-4f49a9011826", 1616000000000ns]
        [4, 1, "Digital Media", "87b1a4f1-8ea8-4cb7-8279-446e4ae0cf9e", "Chapter 2", "7dfdc8fd-33c0-4495-a9d4-76b9470df66d", 1156000000000ns]
        [5, 1, "Digital Media", "7eeea13d-26fe-4208-9949-7fa4fdf7bc08", "Chapter 3", "97751c32-dbbb-4dad-b6db-0e4682292d7a", 1615000000000ns]
        [6, 1, "Digital Media", "76d9494d-cdcc-46dd-8eb6-07e71ebbca4f", "Chapter 4", "e4fc2743-3c63-4fb3-9fd1-a080dcfdaa32", 835000000000ns]
        [7, 1, "Digital Media", "05579453-b000-4fef-bc82-60a384eccd86", "Chapter 5", "9fbad9fa-24a9-488c-b4bb-d1dcc93960f6", 1570000000000ns]
        [8, 1, "Digital Media", "659d3d11-cca8-4726-80d1-63df4bfc6217", "Chapter 6", "f82d4088-cfbc-49bc-9aa8-d8dc7ed843d9", 1809000000000ns]
        [9, 1, "Digital Media", "186b8bff-b9c6-4499-bb8a-6b91751cb15c", "Chapter 7", "14236704-7f5b-4a6f-85bc-09feb5ad162d", 1683000000000ns]
        [10, 1, "Digital Media", "2d1e805e-7d24-4b27-af72-a430f359cc7d", "Chapter 8", "56fab383-4486-4aaa-b634-31b0f7b36f32", 1272000000000ns]
      ]
    ]
  ]
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) null
}

def test_filter_musicbrainz_chapters_releases_one_match [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      isbn: "9781501915925",
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 1,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file, duration_, title_, index_, musicbrainz_works_, contributors_, disc_number_, musicbrainz_track_id_, audio_duration];
      [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, 1, [[id]; ["39d174df-2902-44f0-ae68-7c86828c6cdc"]], [{id: "", name: "Alyssa Bresnahan", entity: artist, role: composer}, {id: "", name: "Alyssa Bresnahan", entity: artist, role: narrator}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: writer, entity: artist}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: "primary author", entity: artist}], 1, "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", 89818818000000ns]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 192000000000ns, "Opening Credits"]
          [1, 192000000000ns, 8981881.80ms, Prologue]
          [2, 1640000000000ns, 8981881.80ms, "Chapter 1"]
          [3, 3256000000000ns, 8981881.80ms, "Chapter 2"]
          [4, 4412000000000ns, 8981881.80ms, "Chapter 3"]
          [5, 6027000000000ns, 8981881.80ms, "Chapter 4"]
          [6, 6862000000000ns, 8981881.80ms, "Chapter 5"]
          [7, 8432000000000ns, 8981881.80ms, "Chapter 6"]
          [8, 10241000000000ns, 8981881.80ms, "Chapter 7"]
          [9, 11924000000000ns, 8981881.80ms, "Chapter 8"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 10,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 8981881.80ms]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 8981881.80ms]
        [3, 1, "Digital Media", "6f44d2f1-238b-4f61-9456-4d165226a213", "Chapter 1", "05aace3e-9cd2-44eb-83b8-4f49a9011826", 8981881.80ms]
        [4, 1, "Digital Media", "87b1a4f1-8ea8-4cb7-8279-446e4ae0cf9e", "Chapter 2", "7dfdc8fd-33c0-4495-a9d4-76b9470df66d", 8981881.80ms]
        [5, 1, "Digital Media", "7eeea13d-26fe-4208-9949-7fa4fdf7bc08", "Chapter 3", "97751c32-dbbb-4dad-b6db-0e4682292d7a", 8981881.80ms]
        [6, 1, "Digital Media", "76d9494d-cdcc-46dd-8eb6-07e71ebbca4f", "Chapter 4", "e4fc2743-3c63-4fb3-9fd1-a080dcfdaa32", 8981881.80ms]
        [7, 1, "Digital Media", "05579453-b000-4fef-bc82-60a384eccd86", "Chapter 5", "9fbad9fa-24a9-488c-b4bb-d1dcc93960f6", 8981881.80ms]
        [8, 1, "Digital Media", "659d3d11-cca8-4726-80d1-63df4bfc6217", "Chapter 6", "f82d4088-cfbc-49bc-9aa8-d8dc7ed843d9", 8981881.80ms]
        [9, 1, "Digital Media", "186b8bff-b9c6-4499-bb8a-6b91751cb15c", "Chapter 7", "14236704-7f5b-4a6f-85bc-09feb5ad162d", 8981881.80ms]
        [10, 1, "Digital Media", "2d1e805e-7d24-4b27-af72-a430f359cc7d", "Chapter 8", "56fab383-4486-4aaa-b634-31b0f7b36f32", 8981881.80ms]
      ]
    ]
  ]
  let expected = $candidates
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) $expected
}

def test_filter_musicbrainz_chapters_releases_one_track [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      isbn: "9781501915925",
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 1,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file];
      [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b"]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 192000000000ns, "Opening Credits"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 1,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 89818818000000ns]
      ]
    ]
  ]
  let expected = null
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) $expected
}

def test_filter_musicbrainz_chapters_releases_audible_asin [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      audible_asin: "B018UG5HJY"
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 1,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file];
      [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b"]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccddb",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        audible_asin: "B018UG5HJY",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
  ]
  let expected = ($candidates | skip)
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) $expected
}

def test_filter_musicbrainz_chapters_releases_chapter_tags [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      isbn: "9781501915925",
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 1,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file];
      [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b"]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        release_tags: [
          [name count];
          [chapters 11]
        ]
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccddb",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        release_tags: [
          [name count];
          [chapters 10]
        ]
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
  ]
  let expected = ($candidates | drop)
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) $expected
}

def test_filter_musicbrainz_chapters_releases_distributor [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      isbn: "9781501915925",
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 1,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file, duration_, title_, index_, musicbrainz_works_, contributors_, disc_number_, musicbrainz_track_id_, audio_duration];
      [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, 1, [[id]; ["39d174df-2902-44f0-ae68-7c86828c6cdc"]], [{id: "", name: "Alyssa Bresnahan", entity: artist, role: composer}, {id: "", name: "Alyssa Bresnahan", entity: artist, role: narrator}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: writer, entity: artist}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: "primary author", entity: artist}], 1, "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", 89818818000000ns]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-ed9d75c5d2e9", "Audible Inc.", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccddb",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
  ]
  let expected = ($candidates | skip)
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) $expected
}

def test_filter_musicbrainz_chapters_releases_duration [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      isbn: "9781501915925",
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 1,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file, duration_, title_, index_, musicbrainz_works_, contributors_, disc_number_, musicbrainz_track_id_, audio_duration];
      [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, 1, [[id]; ["39d174df-2902-44f0-ae68-7c86828c6cdc"]], [{id: "", name: "Alyssa Bresnahan", entity: artist, role: composer}, {id: "", name: "Alyssa Bresnahan", entity: artist, role: narrator}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: writer, entity: artist}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: "primary author", entity: artist}], 1, "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", 89818818000000ns]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44914409000000ns]
      ]
    ]
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccddb",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
  ]
  let expected = ($candidates | skip)
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) $expected
}

def test_filter_musicbrainz_chapters_releases_two_match [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      isbn: "9781501915925",
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 1,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file, duration_, title_, index_, musicbrainz_works_, contributors_, disc_number_, musicbrainz_track_id_, audio_duration];
      [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, 1, [[id]; ["39d174df-2902-44f0-ae68-7c86828c6cdc"]], [{id: "", name: "Alyssa Bresnahan", entity: artist, role: composer}, {id: "", name: "Alyssa Bresnahan", entity: artist, role: narrator}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: writer, entity: artist}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: "primary author", entity: artist}], 1, "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", 89818818000000ns]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccddb",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 2,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 44909409000000ns]
        [2, 1, "Digital Media", "537e4c04-cb5d-41bc-a72a-bbec2ab7982a", Prologue, "a9dffc82-f3b8-4fca-8cfe-c912ae2e5f6f", 44909409000000ns]
      ]
    ]
  ]
  let expected = $candidates
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) $expected
}


def test_filter_musicbrainz_chapters_releases_one_match_multiple_tracks [] {
  let target = {
    book: {
      musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
      musicbrainz_release_group_id: "17c8e3b8-0c8c-4366-bd71-062632b08d01",
      musicbrainz_release_types: [other, audiobook],
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"],
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      isbn: "9781501915925",
      musicbrainz_release_country: XW,
      musicbrainz_release_status: official,
      publication_date: 2015-12-03T00:00:00-05:00,
      front_cover_available: true,
      publishers: [
        [id, name]; ["57c8b42f-b98c-4aaa-ac7c-e1a207ba1d4b", "Recorded Books"]
      ],
      total_discs: 1,
      total_tracks: 3,
      packaging: None,
      script: Latn,
      language: eng
    },
    tracks: [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 9979868666666ns]
        [2, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Chapter 1", "f98ad230-27c4-40ba-901a-050ef006e7a6", 9979868666666ns]
        [3, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Chapter 2", "f98ad230-27c4-40ba-901a-050ef006e7a7", 9979868666666ns]
      # [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, file, duration_, title_, index_, musicbrainz_works_, contributors_, disc_number_, musicbrainz_track_id_, audio_duration];
      # [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, 1, [[id]; ["39d174df-2902-44f0-ae68-7c86828c6cdc"]], [{id: "", name: "Alyssa Bresnahan", entity: artist, role: composer}, {id: "", name: "Alyssa Bresnahan", entity: artist, role: narrator}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: writer, entity: artist}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: "primary author", entity: artist}], 1, "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", 9979868666666ns]
      # [2, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, 1, [[id]; ["39d174df-2902-44f0-ae68-7c86828c6cdc"]], [{id: "", name: "Alyssa Bresnahan", entity: artist, role: composer}, {id: "", name: "Alyssa Bresnahan", entity: artist, role: narrator}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: writer, entity: artist}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: "primary author", entity: artist}], 1, "7518f05f-7d2e-4922-b15a-b08b3e1e8d71", 9979868666666ns]
      # [3, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", [[id, title]; ["39d174df-2902-44f0-ae68-7c86828c6cdc", Warbreaker]], [[id, name, entity, role]; ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer], ["87dcb3cb-4460-45ba-8d2c-7a80fd11ed12", "Alyssa Bresnahan", artist, narrator]], 89819000000000ns, "/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, 1, [[id]; ["39d174df-2902-44f0-ae68-7c86828c6cdc"]], [{id: "", name: "Alyssa Bresnahan", entity: artist, role: composer}, {id: "", name: "Alyssa Bresnahan", entity: artist, role: narrator}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: writer, entity: artist}, {name: "Brandon Sanderson", id: "b7b9f742-8de0-44fd-afd3-fa536701d27e", role: "primary author", entity: artist}], 1, "7518f05f-7d2e-4922-b15a-b08b3e1e8d72", 9979868666666ns]
    ]
  }
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccdda",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 17963763600000ns, "Opening Credits"]
          [1, 17963763600000ns, 17963763600000ns, "Prologue"]
          [2, (17963763600000ns * 2), 17963763600000ns, "Chapter 1"]
          [3, (17963763600000ns * 3), 17963763600000ns, "Chapter 1"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 5,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 5987921200000ns]
        [2, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Chapter 1", "f98ad230-27c4-40ba-901a-050ef006e7a6", 5987921200000ns]
        [3, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Chapter 2", "f98ad230-27c4-40ba-901a-050ef006e7a7", 5987921200000ns]
        [4, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Chapter 3", "f98ad230-27c4-40ba-901a-050ef006e7a8", 5987921200000ns]
        [5, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "End Credits", "f98ad230-27c4-40ba-901a-050ef006e7a9", 5987921200000ns]
      ]
    ]
    [
      {
        musicbrainz_release_id: "b2c93465-beb1-4037-92ca-eab9d63ccddb",
        title: Warbreaker,
        contributors: [
          [id name entity role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        isbn: "9781501915925",
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        chapters: [
          [index, start, length, title];
          [0, 0ns, 44909409000000ns, "Opening Credits"]
          [1, 44909409000000ns, 44909409000000ns, "Prologue"]
        ]
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 5,
        packaging: None,
        script: Latn,
        language: eng
      }, [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Opening Credits", "f98ad230-27c4-40ba-901a-050ef006e7a5", 5987921200000ns]
        [2, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Chapter 1", "f98ad230-27c4-40ba-901a-050ef006e7a6", 5987921200000ns]
        [3, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Chapter 2", "f98ad230-27c4-40ba-901a-050ef006e7a7", 5987921200000ns]
        [4, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "Chapter 3", "f98ad230-27c4-40ba-901a-050ef006e7a8", 5987921200000ns]
        [5, 1, "Digital Media", "0abac227-6092-4e50-bc82-804d47b40acb", "End Credits", "f98ad230-27c4-40ba-901a-050ef006e7a9", 5987921200000ns]
      ]
    ]
  ]
  let expected = $candidates
  assert equal ($candidates | filter_musicbrainz_chapters_releases $target) $expected
}

def test_filter_musicbrainz_chapters_releases [] {
  test_filter_musicbrainz_chapters_releases_bad_length
  test_filter_musicbrainz_chapters_releases_one_match
  test_filter_musicbrainz_chapters_releases_one_track
  test_filter_musicbrainz_chapters_releases_audible_asin
  test_filter_musicbrainz_chapters_releases_chapter_tags
  test_filter_musicbrainz_chapters_releases_distributor
  test_filter_musicbrainz_chapters_releases_duration
  test_filter_musicbrainz_chapters_releases_one_match_multiple_tracks
}

def test_filter_musicbrainz_releases_audible_asin [] {
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "7f062d66-c1cf-4627-9b92-77cc51efe32c",
        title: Warbreaker,
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        audible_asin: "B018UG5HJY",
        publication_date: 2015-12-03T00:00:00-05:00,
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 1,
        packaging: None,
        script: Latn,
        language: eng
      },
      [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "904e46dc-b3cc-4355-b331-447a649e10c7", Warbreaker, "8a33806d-8385-4856-8642-fe02c0e3e3f8", 89818818000000ns]
      ]
    ],
    [
      {
        musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
        title: Warbreaker,
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 1,
        packaging: None,
        script: Latn, language: eng
      },
      [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", 89818818000000ns]
      ]
    ]
  ]
  let metadata = {
    book: {
      title: Warbreaker,
      audible_asin: "B018UG5HJY",
      comment: "Brandon Sanderson Purchased from Libro.fm.",
      publication_date: 2015-01-01T00:00:00+00:00,
      chapters: [
        [index, start, length, title];
        [0, 0ns, 191713000000ns, "Warbreaker - Track 001"],
        [1, 191713000000ns, 1448411000000ns, "Warbreaker - Track 002"],
        [2, 1640124000000ns, 1616222000000ns, "Warbreaker - Track 003"],
        [3, 3256346000000ns, 1155788000000ns, "Warbreaker - Track 004"],
        [4, 4412134000000ns, 1614890000000ns, "Warbreaker - Track 005"],
        [5, 6027024000000ns, 835135000000ns, "Warbreaker - Track 006"],
        [6, 6862159000000ns, 1570064000000ns, "Warbreaker - Track 007"],
        [7, 8432223000000ns, 1808588000000ns, "Warbreaker - Track 008"],
        [8, 10240811000000ns, 1683435000000ns, "Warbreaker - Track 009"],
        [9, 11924246000000ns, 1272163000000ns, "Warbreaker - Track 010"],
        [10, 13196409000000ns, 1430622000000ns, "Warbreaker - Track 011"]],
        total_tracks: 1
      },
      tracks: [
        [file, duration, title, contributors, index];
        ["/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, [[name, id, role, entity]; ["Brandon Sanderson", "", writer, artist]], 1]
      ]
  }
  let expected = ["7f062d66-c1cf-4627-9b92-77cc51efe32c"]
  assert equal ($candidates | filter_musicbrainz_releases $metadata) $expected
}

def test_filter_musicbrainz_releases_distributor [] {
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "7f062d66-c1cf-4627-9b92-77cc51efe32c",
        title: Warbreaker,
        contributors: [
          [id, name, entity, role];
          ["926e2da3-af75-4571-8159-fcceb8a0aed3", "Audible Inc.", label, distributor]
        ],
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 1,
        packaging: None,
        script: Latn,
        language: eng
      },
      [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", 89818818000000ns]
      ]
    ],
    [
      {
        musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
        title: Warbreaker,
        contributors: [
          [id, name, entity, role];
          ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
        ],
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 1,
        packaging: None,
        script: Latn, language: eng
      },
      [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", 89818818000000ns]
      ]
    ]
  ]
  let metadata = {
    book: {
      title: Warbreaker,
      contributors: [
        [id, name, entity, role];
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8", "Libro.fm", label, distributor]
      ],
      comment: "Brandon Sanderson Purchased from Libro.fm.",
      publication_date: 2015-01-01T00:00:00+00:00,
      chapters: [
        [index, start, length, title];
        [0, 0ns, 191713000000ns, "Warbreaker - Track 001"],
        [1, 191713000000ns, 1448411000000ns, "Warbreaker - Track 002"],
        [2, 1640124000000ns, 1616222000000ns, "Warbreaker - Track 003"],
        [3, 3256346000000ns, 1155788000000ns, "Warbreaker - Track 004"],
        [4, 4412134000000ns, 1614890000000ns, "Warbreaker - Track 005"],
        [5, 6027024000000ns, 835135000000ns, "Warbreaker - Track 006"],
        [6, 6862159000000ns, 1570064000000ns, "Warbreaker - Track 007"],
        [7, 8432223000000ns, 1808588000000ns, "Warbreaker - Track 008"],
        [8, 10240811000000ns, 1683435000000ns, "Warbreaker - Track 009"],
        [9, 11924246000000ns, 1272163000000ns, "Warbreaker - Track 010"],
        [10, 13196409000000ns, 1430622000000ns, "Warbreaker - Track 011"]],
        total_tracks: 1
      },
      tracks: [
        [file, duration, title, contributors, index];
        ["/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, [[name, id, role, entity]; ["Brandon Sanderson", "", writer, artist]], 1]
      ]
  }
  let expected = ["2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7"]
  assert equal ($candidates | filter_musicbrainz_releases $metadata) $expected
}

def test_filter_musicbrainz_releases_track_duration [] {
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "7f062d66-c1cf-4627-9b92-77cc51efe32c",
        title: Warbreaker,
        musicbrainz_release_country: XW, musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 1,
        packaging: None,
        script: Latn,
        language: eng
      },
      [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "904e46dc-b3cc-4355-b331-447a649e10c7", Warbreaker, "8a33806d-8385-4856-8642-fe02c0e3e3f8", 89824000000000ns]
      ]
    ],
    [
      {
        musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
        title: Warbreaker,
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 1,
        packaging: None,
        script: Latn, language: eng
      },
      [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", 89819000000000ns]
      ]
    ]
  ]
  let metadata = {
    book: {
      title: Warbreaker,
      comment: "Brandon Sanderson Purchased from Libro.fm.",
      publication_date: 2015-01-01T00:00:00+00:00,
      chapters: [
        [index, start, length, title];
        [0, 0ns, 191713000000ns, "Warbreaker - Track 001"],
        [1, 191713000000ns, 1448411000000ns, "Warbreaker - Track 002"],
        [2, 1640124000000ns, 1616222000000ns, "Warbreaker - Track 003"],
        [3, 3256346000000ns, 1155788000000ns, "Warbreaker - Track 004"],
        [4, 4412134000000ns, 1614890000000ns, "Warbreaker - Track 005"],
        [5, 6027024000000ns, 835135000000ns, "Warbreaker - Track 006"],
        [6, 6862159000000ns, 1570064000000ns, "Warbreaker - Track 007"],
        [7, 8432223000000ns, 1808588000000ns, "Warbreaker - Track 008"],
        [8, 10240811000000ns, 1683435000000ns, "Warbreaker - Track 009"],
        [9, 11924246000000ns, 1272163000000ns, "Warbreaker - Track 010"],
        [10, 13196409000000ns, 1430622000000ns, "Warbreaker - Track 011"]],
        total_tracks: 1
      },
      tracks: [
        [file, duration, title, contributors, index];
        ["/var/home/jordan/Downloads/Warbreaker.m4b", 89818818000000ns, Warbreaker, [[name, id, role, entity]; ["Brandon Sanderson", "", writer, artist]], 1]
      ]
  }
  let expected = ["2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7"]
  assert equal ($candidates | filter_musicbrainz_releases $metadata) $expected
}

def test_filter_musicbrainz_releases_multiple_tracks_one_match_with_near_durations [] {
  let candidates = [
    [book, tracks];
    [
      {
        musicbrainz_release_id: "7f062d66-c1cf-4627-9b92-77cc51efe32c",
        title: Warbreaker,
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 5,
        packaging: None,
        script: Latn,
        language: eng
      },
      [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", 17963763600000ns]
        [2, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d71", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be50", 17965.76sec]
        [3, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d72", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be51", 17960.75sec]
        [4, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d73", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be52", 17963.76sec]
        [5, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d74", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be53", 17963.76sec]
      ]
    ],
    [
      {
        musicbrainz_release_id: "2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7",
        title: Warbreaker,
        musicbrainz_release_country: XW,
        musicbrainz_release_status: official,
        publication_date: 2015-12-03T00:00:00-05:00,
        front_cover_available: true,
        total_discs: 1,
        total_tracks: 5,
        packaging: None,
        script: Latn,
        language: eng
      },
      [
        [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, duration];
        [1, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d70", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be49", 17963763600000ns]
        [2, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d71", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be50", 17965.76sec]
        [3, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d72", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be51", 17961.76sec]
        [4, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d73", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be52", 17963.76sec]
        [5, 1, "Digital Media", "7518f05f-7d2e-4922-b15a-b08b3e1e8d74", Warbreaker, "bd99e8ae-a776-46b8-af84-fe93e1b6be53", 17965.76sec]
      ]
    ]
  ]
  let metadata = {
    book: {
      title: Warbreaker,
      comment: "Brandon Sanderson Purchased from Libro.fm.",
      publication_date: 2015-01-01T00:00:00+00:00,
      chapters: [
        [index, start, length, title];
        [0, 0ns, 191713000000ns, "Warbreaker - Track 001"],
        [1, 191713000000ns, 1448411000000ns, "Warbreaker - Track 002"],
        [2, 1640124000000ns, 1616222000000ns, "Warbreaker - Track 003"],
        [3, 3256346000000ns, 1155788000000ns, "Warbreaker - Track 004"],
        [4, 4412134000000ns, 1614890000000ns, "Warbreaker - Track 005"],
        [5, 6027024000000ns, 835135000000ns, "Warbreaker - Track 006"],
        [6, 6862159000000ns, 1570064000000ns, "Warbreaker - Track 007"],
        [7, 8432223000000ns, 1808588000000ns, "Warbreaker - Track 008"],
        [8, 10240811000000ns, 1683435000000ns, "Warbreaker - Track 009"],
        [9, 11924246000000ns, 1272163000000ns, "Warbreaker - Track 010"],
        [10, 13196409000000ns, 1430622000000ns, "Warbreaker - Track 011"]],
        total_tracks: 5
      },
      tracks: [
        [file, duration, title, contributors, index];
        ["/var/home/jordan/Downloads/Warbreaker 1.m4b", 17963763600000ns, Warbreaker, [[name, id, role, entity]; ["Brandon Sanderson", "", writer, artist]], 1]
        ["/var/home/jordan/Downloads/Warbreaker 2.m4b", 17963763600000ns, Warbreaker, [[name, id, role, entity]; ["Brandon Sanderson", "", writer, artist]], 2]
        ["/var/home/jordan/Downloads/Warbreaker 3.m4b", 17963763600000ns, Warbreaker, [[name, id, role, entity]; ["Brandon Sanderson", "", writer, artist]], 3]
        ["/var/home/jordan/Downloads/Warbreaker 4.m4b", 17963763600000ns, Warbreaker, [[name, id, role, entity]; ["Brandon Sanderson", "", writer, artist]], 4]
        ["/var/home/jordan/Downloads/Warbreaker 5.m4b", 17963763600000ns, Warbreaker, [[name, id, role, entity]; ["Brandon Sanderson", "", writer, artist]], 5]
      ]
  }
  let expected = ["2eae5bdf-6c19-4ade-b7fa-e0672b0d59a7"]
  assert equal ($candidates | filter_musicbrainz_releases $metadata) $expected
}

def test_filter_musicbrainz_releases [] {
  test_filter_musicbrainz_releases_distributor
  test_filter_musicbrainz_releases_audible_asin
  test_filter_musicbrainz_releases_track_duration
  test_filter_musicbrainz_releases_multiple_tracks_one_match_with_near_durations
}

def test_parse_container_and_audio_codec_from_ffprobe_output_aax [] {
  let input = open ([$test_data_dir "ffprobe_output_aax.json"] | path join)
  let expected = {
    audio_codec: "aac"
    container: "mov,mp4,m4a,3gp,3g2,mj2"
    audio_channel_layout: null
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_flac [] {
  let input = open ([$test_data_dir "ffprobe_output_flac.json"] | path join)
  let expected = {
    audio_codec: "flac"
    container: "flac"
    audio_channel_layout: "stereo"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_m4b_aac [] {
  let input = open ([$test_data_dir "ffprobe_output_m4b_aac.json"] | path join)
  let expected = {
    audio_codec: "aac"
    container: "mov,mp4,m4a,3gp,3g2,mj2"
    audio_channel_layout: "mono"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_mp3 [] {
  let input = open ([$test_data_dir "ffprobe_output_mp3.json"] | path join)
  let expected = {
    audio_codec: "mp3"
    container: "mp3"
    audio_channel_layout: "mono"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_oga_flac [] {
  let input = open ([$test_data_dir "ffprobe_output_oga_flac.json"] | path join)
  let expected = {
    audio_codec: "flac"
    container: "ogg"
    audio_channel_layout: "stereo"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_opus [] {
  let input = open ([$test_data_dir "ffprobe_output_opus.json"] | path join)
  let expected = {
    audio_codec: "opus"
    container: "ogg"
    audio_channel_layout: "stereo"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_wav [] {
  let input = open ([$test_data_dir "ffprobe_output_wav.json"] | path join)
  let expected = {
    audio_codec: "pcm_s16le"
    container: "wav"
    audio_channel_layout: null
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output [] {
  test_parse_container_and_audio_codec_from_ffprobe_output_aax
  test_parse_container_and_audio_codec_from_ffprobe_output_flac
  test_parse_container_and_audio_codec_from_ffprobe_output_m4b_aac
  test_parse_container_and_audio_codec_from_ffprobe_output_mp3
  test_parse_container_and_audio_codec_from_ffprobe_output_oga_flac
  test_parse_container_and_audio_codec_from_ffprobe_output_opus
  test_parse_container_and_audio_codec_from_ffprobe_output_wav
}

def test_parse_musicbrainz_series_monogatari_work [] {
  let input = open ([$test_data_dir "monogatari_work_series.json"] | path join)
  let expected = {
    id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
    name: "Monogatari"
    parent_series: []
    subseries: [
      [id name];
      ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
      ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
    ]
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      [supernatural, 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ($input | parse_musicbrainz_series) $expected
}

def test_parse_musicbrainz_series_monogatari_first_season_work [] {
  let input = open ([$test_data_dir "monogatari_first_season_work_series.json"] | path join)
  let expected = {
    id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
    name: "Monogatari Series: First Season"
    parent_series: [
      [id name];
      ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
    ]
    subseries: [
      [id name];
      ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
    ]
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      [supernatural, 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ($input | parse_musicbrainz_series) $expected
}

def test_parse_musicbrainz_series_bakemonogatari_work [] {
  let input = open ([$test_data_dir "bakemonogatari_work_series.json"] | path join)
  let expected = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name];
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ($input | parse_musicbrainz_series) $expected
}

def test_parse_musicbrainz_series [] {
  test_parse_musicbrainz_series_monogatari_work
  test_parse_musicbrainz_series_monogatari_first_season_work
  test_parse_musicbrainz_series_bakemonogatari_work
}

def test_fetch_and_parse_musicbrainz_series_cached [] {
  let cache = {|series_id, update|
    if ($series_id == "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322") {
      {
        id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
        name: "Bakemonogatari"
        parent_series: [
          [id name];
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ]
        subseries: []
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          ["speculative fiction", 1],
          [vampire, 1]
        ]
        tags: []
      }
    }
  }
  let expected = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name];
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ("0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" | fetch_and_parse_musicbrainz_series $cache) $expected
}

def test_fetch_and_parse_musicbrainz_series [] {
  test_fetch_and_parse_musicbrainz_series_cached
}

def test_build_series_tree_up_three_levels [] {
  let monogatari_series_cache = {|series_id, update|
    log info $"$series_id: ($series_id)"
    if $series_id == "05ef20c8-9286-4b53-950f-eac8cbb32dc3" {
      {
        id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
        name: "Monogatari"
        parent_series: []
        subseries: [
          [id name];
          ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
          ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
        ]
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        tags: []
      }
    } else if $series_id == "6660f123-24a0-46c7-99bf-7ff5dc11ceef" {
      {
        id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
        name: "Monogatari Series: First Season"
        parent_series: [
          [id name];
          ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
        ]
        subseries: [
          [id name];
          ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
        ]
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        tags: []
      }
    } else if $series_id == "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" {
      {
        id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
        name: "Bakemonogatari"
        parent_series: [
          [id name];
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ]
        subseries: []
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          ["speculative fiction", 1],
          [vampire, 1]
        ]
        tags: []
      }
    }
  }
  let expected = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name parent_series subseries genres tags];
      [
        "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
        "Monogatari Series: First Season"
        [
          [id name parent_series subseries genres tags];
          [
            "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
            "Monogatari"
            []
            [
              [id name];
              ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
              ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
              ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
            ]
            [
              [name, count];
              [fiction, 1],
              ["light novel", 1],
              [mystery, 1],
              [paranormal, 1],
              [psychological, 1],
              [romance, 1],
              ["school life", 1],
              [supernatural, 1],
              [vampire, 1]
            ]
            []
          ]
        ]
        [
          [id name];
          ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
        ]
        [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        []
      ]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  let input = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name];
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ($input | build_series_tree_up 5 $monogatari_series_cache) $expected
}

def test_build_series_tree_up_three_levels_2 [] {
  let monogatari_series_cache = {|series_id, update|
    log info $"$series_id: ($series_id)"
    if $series_id == "05ef20c8-9286-4b53-950f-eac8cbb32dc3" {
      {
        id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
        name: "Monogatari"
        parent_series: []
        subseries: [
          [id name];
          ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
          ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
        ]
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        tags: []
      }
    } else if $series_id == "6660f123-24a0-46c7-99bf-7ff5dc11ceef" {
      {
        id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
        name: "Monogatari Series: First Season"
        parent_series: [
          [id name];
          ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
        ]
        subseries: [
          [id name];
          ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
        ]
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        tags: []
      }
    } else if $series_id == "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" {
      {
        id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
        name: "Bakemonogatari"
        parent_series: [
          [id name];
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ]
        subseries: []
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          ["speculative fiction", 1],
          [vampire, 1]
        ]
        tags: []
      }
    }
  }
  let expected = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name parent_series subseries genres tags];
      [
        "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
        "Monogatari Series: First Season"
        [
          [id name parent_series subseries genres tags];
          [
            "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
            "Monogatari"
            []
            [
              [id name];
              ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
              ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
              ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
            ]
            [
              [name, count];
              [fiction, 1],
              ["light novel", 1],
              [mystery, 1],
              [paranormal, 1],
              [psychological, 1],
              [romance, 1],
              ["school life", 1],
              [supernatural, 1],
              [vampire, 1]
            ]
            []
          ]
        ]
        [
          [id name];
          ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
        ]
        [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        []
      ]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  let input = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name];
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ($input | build_series_tree_up 5 $monogatari_series_cache) $expected
}

# def test_build_series_tree_up_max_depth [] {
#   let expected = {
#     id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
#     name: "Bakemonogatari"
#     parent_series: [
#       [id name parent_series subseries genres tags];
#       [
#         "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
#         "Monogatari Series: First Season"
#         [
#           # [id name];
#           # ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
#           [id name parent_series subseries genres tags];
#           [
#             "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
#             "Monogatari"
#             []
#             [
#               [id name];
#               ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
#               ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
#               ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
#             ]
#             [
#               [name, count];
#               [fiction, 1],
#               ["light novel", 1],
#               [mystery, 1],
#               [paranormal, 1],
#               [psychological, 1],
#               [romance, 1],
#               ["school life", 1],
#               [supernatural, 1],
#               [vampire, 1]
#             ]
#             []
#           ]
#         ]
#         [
#           [id name];
#           ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
#         ]
#         [
#           [name, count];
#           [fiction, 1],
#           ["light novel", 1],
#           [mystery, 1],
#           [paranormal, 1],
#           [psychological, 1],
#           [romance, 1],
#           ["school life", 1],
#           [supernatural, 1],
#           [vampire, 1]
#         ]
#         []
#       ]
#     ]
#     subseries: []
#     genres: [
#       [name, count];
#       [fiction, 1],
#       ["light novel", 1],
#       [mystery, 1],
#       [paranormal, 1],
#       [psychological, 1],
#       [romance, 1],
#       ["school life", 1],
#       ["speculative fiction", 1],
#       [vampire, 1]
#     ]
#     tags: []
#   }
#   let input = {
#     id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
#     name: "Bakemonogatari"
#     parent_series: [
#       [id name];
#       ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
#     ]
#     subseries: []
#     genres: [
#       [name, count];
#       [fiction, 1],
#       ["light novel", 1],
#       [mystery, 1],
#       [paranormal, 1],
#       [psychological, 1],
#       [romance, 1],
#       ["school life", 1],
#       ["speculative fiction", 1],
#       [vampire, 1]
#     ]
#     tags: []
#   }
#   assert equal ($input | build_series_tree_up 4 $monogatari_series_cache) $expected
# }

def test_build_series_tree_up [] {
  test_build_series_tree_up_three_levels
  # test_build_series_tree_up_three_levels_2
  # test_build_series_tree_up_max_depth
}

def test_organize_subseries_two_subseries [] {
  let input = [
    [id name parent_series subseries genres tags];
    [
      "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
      "Monogatari"
      []
      [
        [id name];
        ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
        ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
      ]
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        [supernatural, 1],
        [vampire, 1]
      ]
      []
    ]
    [
      "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
      "Monogatari Series: First Season"
      [
        [id name];
        ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
      ]
      [
        [id name];
        ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
      ]
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        [supernatural, 1],
        [vampire, 1]
      ]
      []
    ]
    [
      "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
      "Bakemonogatari"
      [
        [id name];
        ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
      ]
      []
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        ["speculative fiction", 1],
        [vampire, 1]
      ]
      []
    ]
  ]
  let expected = [
    [id name parent_series subseries genres tags];
    [
      "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
      "Monogatari"
      []
      [
        [id name];
        ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
        ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
      ]
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        [supernatural, 1],
        [vampire, 1]
      ]
      []
    ]
    [
      "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
      "Monogatari Series: First Season"
      [
        [id name];
        ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
      ]
      [
        [id name];
        ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
      ]
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        [supernatural, 1],
        [vampire, 1]
      ]
      []
    ]
    [
      "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
      "Bakemonogatari"
      [
        [id name];
        ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
      ]
      []
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        ["speculative fiction", 1],
        [vampire, 1]
      ]
      []
    ]
  ]
  assert equal ($input | organize_subseries) $expected
}

def test_organize_subseries [] {
  # test_organize_subseries_one_series
  # test_organize_subseries_one_subseries
  test_organize_subseries_two_subseries
}

def test_parse_musicbrainz_work_c7a83643-33a3-48ab-b54e-f56554359802 [] {
  let input = open ([$test_data_dir "work_c7a83643-33a3-48ab-b54e-f56554359802.json"] | path join)
  let expected = {
    id: "c7a83643-33a3-48ab-b54e-f56554359802"
    title: "Full Metal Panic! Volume 1: Fighting Boy Meets Girl"
    language: "eng"
    genres: [
      [name, count];
      [action, 1],
      [fiction, 1],
      ["light novel", 1],
      [mecha, 1],
      [military, 1]
    ]
    tags: []
  }
  assert equal ($input | parse_musicbrainz_work) $expected
}

def test_parse_musicbrainz_work [] {
  test_parse_musicbrainz_work_c7a83643-33a3-48ab-b54e-f56554359802
}

def test_is_ssh_path_simple_ssh_path [] {
  let input = "meerkat:/var/home/media"
  assert ($input | is_ssh_path)
}

def test_is_ssh_path_simple_local_path [] {
  let input = "/var/home/media"
  assert not ($input | is_ssh_path)
}

def test_is_ssh_path_server_no_path [] {
  let input = "meerkat:"
  assert not ($input | is_ssh_path)
}

def test_is_ssh_path_server_root_path_depth_one [] {
  let input = "meerkat:/var"
  assert ($input | is_ssh_path)
}

def test_is_ssh_path_server_relative_path_depth_one [] {
  let input = "meerkat:dir"
  assert ($input | is_ssh_path)
}

def test_is_ssh_path_server_relative_path_depth_two [] {
  let input = "meerkat:one/two"
  assert ($input | is_ssh_path)
}

def test_is_ssh_path_local_absolute_path_with_colon [] {
  let input = "/var/o:ne/two"
  assert not ($input | is_ssh_path)
}

def test_is_ssh_path_local_relative_path_with_colon [] {
  let input = "one/t:wo"
  assert not ($input | is_ssh_path)
}

def test_is_ssh_path_relative_path_starts_with_colon [] {
  let input = ":one/two"
  assert not ($input | is_ssh_path)
}

def test_is_ssh_path_absolute_path_starts_with_colon [] {
  let input = ":/one/two"
  assert not ($input | is_ssh_path)
}

def test_is_ssh_path [] {
  test_is_ssh_path_simple_ssh_path
  test_is_ssh_path_simple_local_path
  test_is_ssh_path_server_no_path
  test_is_ssh_path_server_root_path_depth_one
  test_is_ssh_path_server_relative_path_depth_one
  test_is_ssh_path_server_relative_path_depth_two
  test_is_ssh_path_local_absolute_path_with_colon
  test_is_ssh_path_local_relative_path_with_colon
  test_is_ssh_path_relative_path_starts_with_colon
  test_is_ssh_path_absolute_path_starts_with_colon
}

def test_split_ssh_path_simple_ssh_path [] {
  let input = "meerkat:/var/home/media"
  let expected = {
    server: "meerkat"
    path: "/var/home/media"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_simple_local_path [] {
  let input = "/var/home/media"
  let expected = {
    server: null
    path: "/var/home/media"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_server_no_path [] {
  let input = "meerkat:"
  let expected = {
    server: null
    path: "meerkat:"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_server_root_path_depth_one [] {
  let input = "meerkat:/var"
  let expected = {
    server: "meerkat"
    path: "/var"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_server_relative_path_depth_one [] {
  let input = "meerkat:dir"
  let expected = {
    server: "meerkat"
    path: "dir"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_server_relative_path_depth_two [] {
  let input = "meerkat:one/two"
  let expected = {
    server: "meerkat"
    path: "one/two"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_local_absolute_path_with_colon [] {
  let input = "/var/o:ne/two"
  let expected = {
    server: null
    path: "/var/o:ne/two"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_local_relative_path_with_colon [] {
  let input = "one/t:wo"
  let expected = {
    server: null
    path: "one/t:wo"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_relative_path_starts_with_colon [] {
  let input = ":one/two"
  let expected = {
    server: null
    path: ":one/two"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path_absolute_path_starts_with_colon [] {
  let input = ":/one/two"
  let expected = {
    server: null
    path: ":/one/two"
  }
  assert equal ($input | split_ssh_path) $expected
}

def test_split_ssh_path [] {
  test_split_ssh_path_simple_ssh_path
  test_split_ssh_path_simple_local_path
  test_split_ssh_path_server_no_path
  test_split_ssh_path_server_root_path_depth_one
  test_split_ssh_path_server_relative_path_depth_one
  test_split_ssh_path_server_relative_path_depth_two
  test_split_ssh_path_local_absolute_path_with_colon
  test_split_ssh_path_local_relative_path_with_colon
  test_split_ssh_path_relative_path_starts_with_colon
  test_split_ssh_path_absolute_path_starts_with_colon
}

def main [] {
  test_upsert_if_present
  test_upsert_if_value
  test_round_to_second_using_cumulative_offset
  test_parse_series_from_group
  test_parse_series_from_series_tags
  test_parse_audiobook_metadata_from_tone
  test_parse_audiobook_metadata_from_tracks_metadata
  test_convert_series_for_group_tag
  test_into_tone_format
  test_tracks_into_tone_format
  test_determine_releases_from_acoustid_fingerprint_matches
  test_parse_works_from_musicbrainz_relations
  test_parse_contributor_by_type_from_musicbrainz_relations
  test_parse_contributors
  test_parse_musicbrainz_artist_credit
  test_parse_series_from_musicbrainz_relations
  test_parse_series_from_musicbrainz_release
  test_parse_audible_asin_from_url
  test_parse_audible_asin_from_musicbrainz_release
  test_parse_tags_from_musicbrainz_release
  test_parse_chapters_from_tone
  test_chapters_into_tone_format
  test_parse_chapters_from_musicbrainz_release
  # todo Add tests for Baccano! Vol. 1 for parsing things.
  test_parse_musicbrainz_release
  test_equivalent_track_durations
  test_has_distributor_in_common
  test_audiobooks_with_the_highest_voted_chapters_tag
  test_filter_musicbrainz_chapters_releases
  test_filter_musicbrainz_releases
  test_parse_container_and_audio_codec_from_ffprobe_output
  test_parse_musicbrainz_work
  test_parse_musicbrainz_series
  test_fetch_and_parse_musicbrainz_series
  test_build_series_tree_up
  # test_organize_subseries
  # todo test_escape_special_lucene_characters
  # todo test_append_to_musicbrainz_query
  test_is_ssh_path
  test_split_ssh_path
  echo "All tests passed!"
}
