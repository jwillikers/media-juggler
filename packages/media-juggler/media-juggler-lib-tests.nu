#!/usr/bin/env nu

use std assert

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
  echo "All tests passed!"
}
