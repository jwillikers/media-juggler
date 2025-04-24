#!/usr/bin/env nu

use std assert
use std log

use media-juggler-lib *

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
    album: "Dark One: Forgotten"
    albumArtist: "Brandon Sanderson and Dan Wells performed by various narrators"
    artist: "Brandon Sanderson; Dan Wells"
    composer: "Mia Barron, Luis Bermudez, William Elsman, Kaleo Griffith, Roxanne Hernandez, Rachel L. Jacobs, John H. Mayer, Nan McNamara, Jim Meskimen, Sophie Oda, Keith Szarabajka, Kelli Tager, Avery Kidd Waddell"
    comment: "Brandon Sanderson and Dan Wells Purchased from Libro.fm."
    discNumber: 1
    discTotal: 1
    recordingDate: "2023-01-10T00:00:00"
    sortArtist: "Sanderson, Brandon and Wells, Dan performed by various narrators"
    sortAlbumArtist: "Sanderson, Brandon and Wells, Dan performed by various narrators"
    sortComposer: "Jourgensen, Erik"
    title: "Dark One: Forgotten"
    trackNumber: 1
    trackTotal: 1
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
      media: "Digital Media"
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
      label: "MAINFRAME;rb media RECORDED BOOKS ORIGINAL"
      publisher: "MAINFRAME;rb media RECORDED BOOKS ORIGINAL"
      engineer: "Anthony Cozzi;Vincent Early;Tom Pinkava;Timothy Waldner"
      "musicBrainz Album Artist Id": "b7b9f742-8de0-44fd-afd3-fa536701d27e;f0e00197-4291-40cb-a448-c2f3c86f54c7"
      "musicBrainz Artist Id": "b7b9f742-8de0-44fd-afd3-fa536701d27e;f0e00197-4291-40cb-a448-c2f3c86f54c7"
      "acoustid Fingerprint": "XXXX"
      "©work": "Dark One: Forgotten"
      "©dir": "Max Epstein;David Pace"
    }
    file: "/home/listener/audiobooks/Dark One: Forgotten/Dark One: Forgotten.m4b"
  }
  let expected = {
    book: {
      title: "Dark One: Forgotten"
      artist_credit: "Brandon Sanderson and Dan Wells performed by various narrators"
      artist_credit_sort: "Sanderson, Brandon and Wells, Dan performed by various narrators"
      comment: "Brandon Sanderson and Dan Wells Purchased from Libro.fm."
      publication_date: ("2023-01-10T00:00:00" | into datetime)
      musicbrainz_release_country: "XW"
      musicbrainz_release_status: "official"
      media: "Digital Media"
      script: "Latn"
      series: [{
        name: "Dark One, performed by various narrators"
        index: "1"
      }]
      barcode: "9781980062875"
      musicbrainz_release_types: ["other" "audio drama"]
      musicbrainz_release_group_id: "4220489d-2bd0-4618-84a8-bdac1b968b1c"
      musicbrainz_release_id: "549a0455-4698-472f-97f3-7bb75fbe7343"
      musicbrainz_artist_ids: ["b7b9f742-8de0-44fd-afd3-fa536701d27e" "f0e00197-4291-40cb-a448-c2f3c86f54c7"]
      publishers: ["MAINFRAME" "rb media RECORDED BOOKS ORIGINAL"]
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
    }
    track: {
      title: "Dark One: Forgotten"
      artist_credit: "Brandon Sanderson; Dan Wells"
      artist_credit_sort: "Sanderson, Brandon and Wells, Dan performed by various narrators"
      writers: ["Brandon Sanderson" "Dan Wells"]
      narrators: [
        "Mia Barron"
        "Luis Bermudez"
        "William Elsman"
        "Kaleo Griffith"
        "Roxanne Hernandez"
        "Rachel L. Jacobs"
        "John H. Mayer"
        "Nan McNamara"
        "Jim Meskimen"
        "Sophie Oda"
        "Keith Szarabajka"
        "Kelli Tager"
        "Avery Kidd Waddell"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      performers: ["Erik Jourgensen"]
      musicbrainz_track_id: "a3a37da7-f2fa-4938-b827-d3c8d213d08c"
      musicbrainz_release_track_id: "a442811c-582b-429c-b7d9-072736be42ac"
      musicbrainz_work_ids: ["e8eba2f2-cb32-4f55-82cc-b35aa1272b5a"]
      producers: ["Max Epstein" "Matt Flynn" "David Pace"]
      engineers: ["Anthony Cozzi" "Vincent Early" "Tom Pinkava" "Timothy Waldner"]
      musicbrainz_artist_ids: ["b7b9f742-8de0-44fd-afd3-fa536701d27e" "f0e00197-4291-40cb-a448-c2f3c86f54c7"]
      acoustid_fingerprint: "XXXX"
      file: "/home/listener/audiobooks/Dark One: Forgotten/Dark One: Forgotten.m4b"
    }
  }
  let actual = $input | parse_audiobook_metadata_from_tone

  # todo Make a better comparison function for tests and use it here.
  # for column in ($expected.book | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | get $column)
  # }
  assert equal $actual.book $expected.book
  # for column in ($expected.track | columns) {
  #   assert equal ($actual.track | get $column) ($expected.track | get $column)
  # }
  assert equal $actual.track $expected.track
  assert equal $actual $expected
}

def test_parse_audiobook_metadata_from_tone_audiobookshelf [] {
  let input = {
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
      [0, 27000, "Opening Credits"]
      [27000, 454000, Prologue]
      [481000, 3042000, "Chapter 1: Nightmares and Disquieting Shadows"]
      [3523000, 3492000, "Chapter 2: The Chestnut-Haired Man"]
      [7015000, 3052000, "Chapter 3: To the Usuba Household, Part 1"]
      [10067000, 3406000, "Chapter 4: To the Usuba Household, Part 2"]
      [13473000, 2567000, "Chapter 5: Light in the Darkness"]
      [16040000, 2689000, "Chapter 6: Truth-Revealing Party"]
      [18729000, 810000, Epilogue]
      [19539000, 116992, "End Credits"]
    ]
    embeddedPictures: [
      [code mimetype];
      [13, image/jpeg]
    ]
    file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
  }
  let expected = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
      chapters: [
        [start length title];
        [0, 27000, "Opening Credits"]
        [27000, 454000, Prologue]
        [481000, 3042000, "Chapter 1: Nightmares and Disquieting Shadows"]
        [3523000, 3492000, "Chapter 2: The Chestnut-Haired Man"]
        [7015000, 3052000, "Chapter 3: To the Usuba Household, Part 1"]
        [10067000, 3406000, "Chapter 4: To the Usuba Household, Part 2"]
        [13473000, 2567000, "Chapter 5: Light in the Darkness"]
        [16040000, 2689000, "Chapter 6: Truth-Revealing Party"]
        [18729000, 810000, Epilogue]
        [19539000, 116992, "End Credits"]
      ]
    }
    track: {
      title: "My Happy Marriage, Vol. 2"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13, image/jpeg]
      ]
      file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
    }
  }
  let actual = $input | parse_audiobook_metadata_from_tone

  # todo Make a better comparison function for tests and use it here.
  # for column in ($expected.book | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | get $column)
  # }
  assert equal $actual.book $expected.book
  # for column in ($expected.track | columns) {
  #   assert equal ($actual.track | get $column) ($expected.track | get $column)
  # }
  assert equal $actual.track $expected.track
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
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13, image/jpeg]
      ]
    }
  }]
  let expected = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
    }
    tracks: [{
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
    }]
  }
  let actual = $input | parse_audiobook_metadata_from_tracks_metadata

  # todo Make a better comparison function for tests and use it here.
  # for column in ($expected.book | first | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | first | get $column)
  # }
  assert equal $actual.book $expected.book
  for expected_track in $expected.tracks {
    for column in ($expected_track | columns) {
      assert equal (($actual.tracks | where index == $expected_track.index | first) | get $column) ($expected_track | get $column)
    }
  }
  assert equal $actual.tracks $expected.tracks
  assert equal $actual $expected
}

def test_parse_audiobook_metadata_from_tracks_metadata_two [] {
  let input = [{
    book: {
      title: "My Happy Marriage, Vol. 2"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13, image/jpeg]
      ]
    }
  }, {
    book: {
      title: "My Happy Marriage, Vol. 2"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 002"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 2
      embedded_pictures: [
        [code mimetype];
        [13, image/jpeg]
      ]
    }
  }]
  let expected = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
    }
    tracks: [{
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
    }, {
      title: "My Happy Marriage, Vol. 2 - Track 002"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 2
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
    }]
  }
  let actual = $input | parse_audiobook_metadata_from_tracks_metadata

  # todo Make a better comparison function for tests and use it here.
  # for column in ($expected.book | first | columns) {
  #   assert equal ($actual.book | get $column) ($expected.book | first | get $column)
  # }
  assert equal $actual.book $expected.book
  for expected_track in $expected.tracks {
    for column in ($expected_track | columns) {
      assert equal (($actual.tracks | where index == $expected_track.index | first) | get $column) ($expected_track | get $column)
    }
  }
  assert equal $actual.tracks $expected.tracks
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
  assert equal ([[name index]; ["Series One" null] ["Mistborn" "3"]] | convert_series_for_group_tag) $expected
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
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
    }
  }
  let expected = {
    album: "My Happy Marriage, Vol. 2"
    comment: "Akumi Agitogi Purchased from Libro.fm."
    group: "My Happy Marriage #2;Test Series 2 #5"
    genre: "Fiction;Fantasy"
    publisher: "Yen Audio"
    publishingDate: "2025-01-01T00:00:00+00:00" # todo Make UTC?
    title: "My Happy Marriage, Vol. 2 - Track 001"
    composer: "Damien Haas;Miranda Parkin"
    narrator: "Damien Haas;Miranda Parkin"
    trackNumber: 1
    embeddedPictures: [
      [code mimetype];
      [13 image/jpeg]
    ]
  }
  assert equal ($input | into_tone_format) $expected
}

def test_into_tone_format_complex [] {
  let input = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      writers: [
        "Akumi Agitogi"
      ]
    }
    track: {
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      writers: [
        "Akumi Agitogi"
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
    }
  }
  let expected = {
    album: "My Happy Marriage, Vol. 2"
    albumArtist: "Akumi Agitogi"
    comment: "Akumi Agitogi Purchased from Libro.fm."
    group: "My Happy Marriage #2;Test Series 2 #5"
    genre: "Fiction;Fantasy"
    publisher: "Yen Audio"
    publishingDate: "2025-01-01T00:00:00+00:00" # todo Make UTC?
    title: "My Happy Marriage, Vol. 2 - Track 001"
    artist: "Akumi Agitogi"
    composer: "Damien Haas;Miranda Parkin"
    narrator: "Damien Haas;Miranda Parkin"
    trackNumber: 1
    embeddedPictures: [
      [code mimetype];
      [13 image/jpeg]
    ]
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
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      writers: [
        "Akumi Agitogi"
      ]
    }
    tracks: [{
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      writers: [
        "Akumi Agitogi"
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
    }]
  }
  let expected = [{
    file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
    metadata: {
      album: "My Happy Marriage, Vol. 2"
      albumArtist: "Akumi Agitogi"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      group: "My Happy Marriage #2;Test Series 2 #5"
      genre: "Fiction;Fantasy"
      publisher: "Yen Audio"
      publishingDate: "2025-01-01T00:00:00+00:00" # todo Make UTC?
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist: "Akumi Agitogi"
      composer: "Damien Haas;Miranda Parkin"
      narrator: "Damien Haas;Miranda Parkin"
      trackNumber: 1
      embeddedPictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
    }
  }]
  assert equal ($input | tracks_into_tone_format) $expected
}

def test_tracks_into_tone_format_two_tracks [] {
  let input = {
    book: {
      title: "My Happy Marriage, Vol. 2"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      publication_date: ("2025-01-01T00:00:00Z" | into datetime)
      series: [{
        name: "My Happy Marriage"
        index: "2"
      }, {
        name: "Test Series 2"
        index: "5"
      }]
      genres: ["Fiction" "Fantasy"]
      publishers: ["Yen Audio"]
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      writers: [
        "Akumi Agitogi"
      ]
    }
    tracks: [{
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist_credit: "Akumi Agitogi read by Miranda Parkin, Damien Haas"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      writers: [
        "Akumi Agitogi"
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 1
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
    }, {
      title: "My Happy Marriage, Vol. 2 - Track 002"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      writers: [
        "Akumi Agitogi"
      ]
      narrators: [
        "Damien Haas"
        "Miranda Parkin"
      ]
      index: 2
      embedded_pictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
      file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 2.mp3"
    }]
  }
  let expected = [{
    file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 1.mp3"
    metadata: {
      album: "My Happy Marriage, Vol. 2"
      albumArtist: "Akumi Agitogi"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      group: "My Happy Marriage #2;Test Series 2 #5"
      genre: "Fiction;Fantasy"
      publisher: "Yen Audio"
      publishingDate: "2025-01-01T00:00:00+00:00" # todo Make UTC?
      title: "My Happy Marriage, Vol. 2 - Track 001"
      artist: "Akumi Agitogi"
      composer: "Damien Haas;Miranda Parkin"
      narrator: "Damien Haas;Miranda Parkin"
      trackNumber: 1
      embeddedPictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
    }
  }, {
    file: "/home/listener/audiobooks/My Happy Marriage, Vol. 2/track 2.mp3"
    metadata: {
      album: "My Happy Marriage, Vol. 2"
      albumArtist: "Akumi Agitogi"
      comment: "Akumi Agitogi Purchased from Libro.fm."
      group: "My Happy Marriage #2;Test Series 2 #5"
      genre: "Fiction;Fantasy"
      publisher: "Yen Audio"
      publishingDate: "2025-01-01T00:00:00+00:00" # todo Make UTC?
      title: "My Happy Marriage, Vol. 2 - Track 002"
      artist: "Akumi Agitogi"
      composer: "Damien Haas;Miranda Parkin"
      narrator: "Damien Haas;Miranda Parkin"
      trackNumber: 2
      embeddedPictures: [
        [code mimetype];
        [13 image/jpeg]
      ]
    }
  }]
  assert equal ($input | tracks_into_tone_format | sort-by metadata.trackNumber) $expected
}

def test_tracks_into_tone_format [] {
  test_tracks_into_tone_format_one_track
  test_tracks_into_tone_format_two_tracks
}

def test_parse_series_from_release_group_no_series [] {
  let input = {
    title: "The Rithmatist"
    secondary-types: [Audiobook]
    relations: []
    id: "1bc6aeda-1b14-4968-adea-1e651d710a42"
    secondary-type-ids: ["499a387e-6195-333e-91c0-9592bfec535e"]
    primary-type: Other
    disambiguation: ""
    first-release-date: "2013-05-14"
    primary-type-id: "4fc3be2b-de1e-396b-a933-beb8f1607a22"
  }
  assert equal ($input | parse_series_from_release_group) null
}

def test_parse_series_from_release_group_one_series_without_index [] {
  let input = {
    relations: [
      [type end ordering-key attribute-values attributes direction series source-credit ended type-id begin target-credit target-type attribute-ids];
      [
        "part of"
        null
        2
        {}
        []
        forward
        {
          id: "e3e2cf21-988e-4c2e-a849-3ea4e32f94bf"
          name: "Mushoku Tensei: Jobless Reincarnation, read by Cliff Kirk"
          type: "Release group series"
          disambiguation: "unabridged"
          "type-id": "4c1c4949-7b6c-3a2d-9d54-a50a27e4fa77"
        }
        ""
        false
        "01018437-91d8-36b9-bf89-3f885d53b5bd"
        null
        ""
        series
        {}
      ]
    ]
    title: "Mushoku Tensei: Jobless Reincarnation – A Journey of Two Lifetimes"
    id: "d2afbb83-ae96-4386-96a0-bfd0dc7cc94e"
    "first-release-date": "2025-03-27"
    "secondary-type-ids": [
      "499a387e-6195-333e-91c0-9592bfec535e"
    ]
    disambiguation: "light novel, English"
    "primary-type-id": "4fc3be2b-de1e-396b-a933-beb8f1607a22"
    "primary-type": Other
    "secondary-types": [Audiobook]
  }
  let expected = [[name index]; ["Mushoku Tensei: Jobless Reincarnation, read by Cliff Kirk" null]]
  assert equal ($input | parse_series_from_release_group | sort-by name) $expected
}

def test_parse_series_from_release_group_two_series_with_indices [] {
  let input = {
    title: "The Final Empire"
    primary-type-id: "4fc3be2b-de1e-396b-a933-beb8f1607a22"
    secondary-type-ids: ["499a387e-6195-333e-91c0-9592bfec535e"]
    id: "09fecc17-56bb-4ddc-8621-647eedfba3fc"
    secondary-types: [Audiobook]
    disambiguation: ""
    relations: [
      {
        attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}
        ordering-key: 1
        target-type: series
        end: null
        type: "part of"
        source-credit: ""
        attributes: [number]
        ended: false,
        type-id: "01018437-91d8-36b9-bf89-3f885d53b5bd"
        series: {
          type-id: "4c1c4949-7b6c-3a2d-9d54-a50a27e4fa77"
          disambiguation: ""
          type: "Release group series"
          id: "7af5299a-1bd8-4b7f-9039-3f140b8f27e7"
          name: "Mistborn Original Trilogy, read by Michael Kramer"
        }
        target-credit: ""
        direction: forward
        attribute-values: {number: "1"}
        begin: null
      } {
        target-type: series
        end: null
        type: "part of"
        source-credit: ""
        attributes: [number]
        attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}
        ordering-key: 1
        attribute-values: {number: "1"}
        begin: null
        ended: false
        type-id: "01018437-91d8-36b9-bf89-3f885d53b5bd"
        series: {
          id: "b32b354a-60a5-4563-932b-27cc354f3dac"
          name: "Mistborn, read by Michael Kramer"
          disambiguation: ""
          type-id: "4c1c4949-7b6c-3a2d-9d54-a50a27e4fa77"
          type: "Release group series"
        }
        target-credit: ""
        direction: forward
      }
    ]
    primary-type: Other
    first-release-date: "2008-12-23"
  }
  let expected = [[name index]; ["Mistborn Original Trilogy, read by Michael Kramer" "1"] ["Mistborn, read by Michael Kramer", "1"]]
  assert equal ($input | parse_series_from_release_group | sort-by name) $expected
}

def test_parse_series_from_release_group [] {
  test_parse_series_from_release_group_no_series
  test_parse_series_from_release_group_one_series_without_index
  test_parse_series_from_release_group_two_series_with_indices
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
    [fingerprint duration matches];
    [
      "fingerprint"
      25555sec
      [[acoustid_track_id release_ids score];
        [
          "85ccd755-283f-4d11-91fb-74ebdd3111e9"
          ["b2c93465-beb1-4037-92ca-eab9d63ccdda"]
          1.0
        ]
      ]
    ]
  ]
  let expected = ["b2c93465-beb1-4037-92ca-eab9d63ccdda"]
  assert equal ($input | determine_releases_from_acoustid_fingerprint_matches) $expected
}

def test_determine_releases_from_acoustid_fingerprint_matches_one_track_two_releases [] {
  let input = [
    [fingerprint duration matches];
    [
      "fingerprint"
      25555sec
      [[acoustid_track_id release_ids score];
        [
          "85ccd755-283f-4d11-91fb-74ebdd3111e9"
          [
            "b2c93465-beb1-4037-92ca-eab9d63ccdda"
            "b3c12345-beb1-4037-92ca-eab9d63bbcc1"
          ]
          1.0
        ]
      ]
    ]
  ]
  let expected = [
    "b2c93465-beb1-4037-92ca-eab9d63ccdda"
    "b3c12345-beb1-4037-92ca-eab9d63bbcc1"
  ]
  assert equal ($input | determine_releases_from_acoustid_fingerprint_matches) $expected
}

def test_determine_releases_from_acoustid_fingerprint_matches_thirteen_tracks_one_release [] {
  let input = [
    [fingerprint duration matches];
    [
      "AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_01XB"
      30090000000ns
      [
        [acoustid_track_id, release_ids, score];
        [
          "3640c01c-a763-404e-9ec4-c60d28820e01"
          ["0425322c-c953-477a-9494-affb04314373"]
          1.0
        ]
      ]
    ]
    [
      "AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_02XB"
      1350160000000ns
      [
        [acoustid_track_id, release_ids, score];
        [
          "30976711-0ae5-431e-8fa7-56aee9d50dd1"
          [
            "0425322c-c953-477a-9494-affb04314373"
            "aaca2621-60fc-4534-98e1-494f9e006a49"
          ]
          1.0
        ]
      ]
    ]
    [
      "AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_03XB"
      509130000000ns
      [
        [acoustid_track_id, release_ids, score];
        [
          "91b44ea0-f078-4d1e-afee-b0b4a8772316"
          [
            "0425322c-c953-477a-9494-affb04314373"
            "aaca2621-60fc-4534-98e1-494f9e006a49"
          ]
          1.0
        ]
      ]
    ]
    [
      "AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_04XB"
      4117130000000ns
      [
        [acoustid_track_id, release_ids, score];
        [
          "9dd90c27-94f5-4fa7-8ea6-dcd3b7f7d456"
          [
            "0425322c-c953-477a-9494-affb04314373"
            "aaca2621-60fc-4534-98e1-494f9e006a49"
          ]
          1.0
        ]
      ]
    ]
    [
      "AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_05XB"
      4542270000000ns
      [
        [acoustid_track_id, release_ids, score];
        [
          "c88dcadb-328e-4a81-8e70-80177c9834c5"
          [
            "0425322c-c953-477a-9494-affb04314373"
            "aaca2621-60fc-4534-98e1-494f9e006a49"
          ]
          1.0
        ]
      ]
    ]
    [
      "AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_06XB"
      1270650000000ns
      [
        [acoustid_track_id, release_ids, score];
        [
          "9f119955-0341-4d62-a6c5-137dbc99f214"
          [
            "0425322c-c953-477a-9494-affb04314373"
            "aaca2621-60fc-4534-98e1-494f9e006a49"
          ]
          1.0
        ]
      ]
    ]
    [
      "AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_07XB"
      3357050000000ns
      [
        [acoustid_track_id, release_ids, score];
        [
          "120dc6ab-ef38-4ac9-a3d4-4e5052ecb7b8"
          [
            "0425322c-c953-477a-9494-affb04314373"
            "aaca2621-60fc-4534-98e1-494f9e006a49"
          ]
          1.0
        ]
      ]
    ]
    ["AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_08XB", 1545770000000ns, [[acoustid_track_id, release_ids, score]; ["95af01f0-1579-460b-998e-cf4b6c2e6f79", ["0425322c-c953-477a-9494-affb04314373", "aaca2621-60fc-4534-98e1-494f9e006a49"], 1.0]]]
    ["AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_09XB", 4237770000000ns, [[acoustid_track_id, release_ids, score]; ["27b42309-c46b-450e-a05d-d5f17ae0dc88", ["0425322c-c953-477a-9494-affb04314373", "aaca2621-60fc-4534-98e1-494f9e006a49"], 1.0]]]
    ["AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_10XB", 751600000000ns, [[acoustid_track_id, release_ids, score]; ["8f7cd0be-91ac-4d80-ad16-dca82020d6ff", ["0425322c-c953-477a-9494-affb04314373", "aaca2621-60fc-4534-98e1-494f9e006a49"], 1.0]]]
    ["AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_11XB", 781190000000ns, [[acoustid_track_id, release_ids, score]; ["c2abc000-8ca0-4029-b8a7-89092d772767", ["0425322c-c953-477a-9494-affb04314373", "aaca2621-60fc-4534-98e1-494f9e006a49"], 1.0]]]
    ["AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_12XB", 361820000000ns, [[acoustid_track_id, release_ids, score]; ["75cd8d2f-3931-45cc-b4be-23c74d1387b7", ["0425322c-c953-477a-9494-affb04314373", "aaca2621-60fc-4534-98e1-494f9e006a49"], 1.0]]]
    [
      "AQAA3ZOShVmSTAl8hjjzwUc3MYi74YFGH2FxPA_13XB", 131870000000ns, [[acoustid_track_id, release_ids, score]; ["e086eb93-e02b-41e6-b882-3ef59824da04", ["0425322c-c953-477a-9494-affb04314373"], 1.0]]
    ]
  ]
  let expected = [
    "0425322c-c953-477a-9494-affb04314373"
  ]
  assert equal ($input | determine_releases_from_acoustid_fingerprint_matches) $expected
}

def test_determine_releases_from_acoustid_fingerprint_matches [] {
  test_determine_releases_from_acoustid_fingerprint_matches_empty
  test_determine_releases_from_acoustid_fingerprint_matches_one_track_one_release
  test_determine_releases_from_acoustid_fingerprint_matches_one_track_two_releases
  test_determine_releases_from_acoustid_fingerprint_matches_thirteen_tracks_one_release
}

def test_parse_narrators_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ($env.FILE_PWD | path join "bakemonogatari_part_01_release.json")
  let expected = [
    "Cristina Vee"
    "Erica Mendez"
    "Erik Kimerer"
    "Keith Silverstein"
  ]
  assert equal ($input | parse_narrators_from_musicbrainz_release | sort) $expected
}

def test_parse_narrators_from_musicbrainz_release [] {
  test_parse_narrators_from_musicbrainz_release_bakemonogatari_part_01
}

# def test_parse_musicbrainz_release_baccano [] {
#   let input = placeholder
# }

# def test_parse_musicbrainz_release [] {
#   test_parse_musicbrainz_release_baccano
# }

def main []: {
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
  test_parse_series_from_release_group
  test_parse_release_ids_from_acoustid_response
  test_determine_releases_from_acoustid_fingerprint_matches
  test_parse_narrators_from_musicbrainz_release
  # test_parse_musicbrainz_release
  echo "All tests passed!"
}
