# Tests for the tone functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *
use helpers/assertions.nu *

export def test_parse_series_from_group_one_without_index [] {
  let expected = [[name index]; ["The Stormlight Archive" null]]
  assert equal ("The Stormlight Archive" | parse_series_from_group) $expected
}

export def test_parse_series_from_group_one_with_index [] {
  let expected = [[name index]; ["The Stormlight Archive" "1"]]
  assert equal ("The Stormlight Archive #1" | parse_series_from_group) $expected
}

export def test_parse_series_from_group_two_without_index [] {
  let expected = [[name index]; ["The Stormlight Archive" null] ["Cosmere" null]]
  assert equal ("The Stormlight Archive; Cosmere" | parse_series_from_group) $expected
}

export def test_parse_series_from_group_two_with_index [] {
  let expected = [[name index]; ["The Stormlight Archive" "1"] ["Cosmere" "10"]]
  assert equal ("The Stormlight Archive #1; Cosmere #10" | parse_series_from_group) $expected
}

export def test_parse_series_from_group_one_with_index_and_one_without_index [] {
  let expected = [[name index]; ["The Stormlight Archive" "1"] ["Cosmere" null]]
  assert equal ("The Stormlight Archive #1; Cosmere" | parse_series_from_group) $expected
}

export def test_parse_series_from_series_tags_empty_record [] {
  assert equal ({} | parse_series_from_series_tags) null
}

export def test_parse_series_from_series_tags_one_null_series [] {
  assert equal ({series: null, series-part: null} | parse_series_from_series_tags) null
}

export def test_parse_series_from_series_tags_one_series_without_index [] {
  let expected = [[name index]; ["Mistborn" null]]
  assert equal ({series: "Mistborn"} | parse_series_from_series_tags) $expected
}

export def test_parse_series_from_series_tags_one_series_with_index [] {
  let expected = [[name index]; ["Mistborn" "1"]]
  assert equal ({series: "Mistborn", series-part: "1"} | parse_series_from_series_tags) $expected
}

export def test_parse_series_from_series_tags_one_series_with_int_index [] {
  let expected = [[name index]; ["Mistborn" "1"]]
  assert equal ({series: "Mistborn", series-part: 1} | parse_series_from_series_tags) $expected
}

export def test_parse_series_from_series_tags_one_int_series_without_index [] {
  let expected = [[name index]; ["86" null]]
  assert equal ({series: 86} | parse_series_from_series_tags) $expected
}

export def test_parse_series_from_series_tags_one_series_with_null_index [] {
  let expected = [[name index]; ["86" null]]
  assert equal ({series: "86", series-part: null} | parse_series_from_series_tags) $expected
}

export def test_parse_series_from_series_tags_one_mvnm_without_index [] {
  let expected = [[name index]; ["86" null]]
  assert equal ({mvnm: "86"} | parse_series_from_series_tags) $expected
}

export def test_parse_series_from_series_tags_one_mvnm_with_index [] {
  let expected = [[name index]; ["86" "5.1"]]
  assert equal ({mvnm: "86", mvin: 5.1} | parse_series_from_series_tags) $expected
}

export def test_parse_series_from_series_tags_one_mvnm_one_series [] {
  let expected = [[name index]; ["Series One" "1"] ["Series Two" "3"]]
  assert equal ({ mvnm: "Series One", series: "Series Two", series-part: 3, mvin: 1} | parse_series_from_series_tags | sort-by name) $expected
}

export def test_parse_audiobook_metadata_from_tone_picard [] {
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
        ["", "Avery Kidd Waddell", artist, composer]
        ["", "Jim Meskimen", artist, composer]
        ["", "John H. Mayer", artist, composer]
        ["", "Kaleo Griffith", artist, composer]
        ["", "Keith Szarabajka", artist, composer]
        ["", "Kelli Tager", artist, composer]
        ["", "Luis Bermudez", artist, composer]
        ["", "Mia Barron", artist, composer]
        ["", "Nan McNamara", artist, composer]
        ["", "Rachel L. Jacobs", artist, composer]
        ["", "Roxanne Hernandez", artist, composer]
        ["", "Sophie Oda", artist, composer]
        ["", "William Elsman", artist, composer]
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, "primary author"]
        ["f0e00197-4291-40cb-a448-c2f3c86f54c7", "Dan Wells", artist, "primary author"]
        ["b7b9f742-8de0-44fd-afd3-fa536701d27e", "Brandon Sanderson", artist, writer]
        ["f0e00197-4291-40cb-a448-c2f3c86f54c7", "Dan Wells", artist, writer]
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
  assert_equal_deep $actual $expected
}

export def test_parse_audiobook_metadata_from_tone_audiobookshelf [] {
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
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist "primary author"]
        ["" "Akumi Agitogi read by Miranda Parkin, Damien Haas" artist writer]
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
  assert_equal_deep $actual $expected
}

export def test_parse_audiobook_metadata_from_tone_works [] {
  let input = {
    meta: {
      title: "Short Story Collection"
      artist: "Author"
      additionalFields: {
        "musicBrainz Work Id": "a;b;c"
        work: "Work A;;Work C"
        # "[]" was previously written for missing values
        "bookBrainz Work Id": "[];bb;[]"
        "openLibrary Work Id": "OL1W;;"
      }
    }
    audio: {duration: 1500}
    file: {name: "Short Story Collection.m4b"}
  }
  let expected = [
    [id title bookbrainz_work_id open_library_work_id];
    [a "Work A" null "OL1W"]
    [b null bb null]
    [c "Work C" null null]
  ]
  assert equal ($input | parse_audiobook_metadata_from_tone | get track.musicbrainz_works) $expected
}

export def test_parse_audiobook_metadata_from_tracks_metadata_one [] {
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
  assert_equal_deep $actual $expected
}

export def test_parse_audiobook_metadata_from_tracks_metadata_two [] {
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
  assert_equal_deep $actual $expected
}

export def test_convert_series_for_group_tag_one_with_index [] {
  let expected = "Series One #1"
  assert equal ([[name index]; ["Series One" "1"]] | convert_series_for_group_tag) $expected
}

export def test_convert_series_for_group_tag_two_with_index [] {
  let expected = "Series One #1;Mistborn #3"
  assert equal ([[name index]; ["Series One" "1"] ["Mistborn" "3"]] | convert_series_for_group_tag) $expected
}

export def test_convert_series_for_group_tag_one_without_index_one_with_index [] {
  let expected = "Series One;Mistborn #3"
  assert equal ([[name index]; ["Series One" ""] ["Mistborn" "3"]] | convert_series_for_group_tag) $expected
}

export def test_into_tone_format_simple [] {
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
        ["1" "Damien Haas" artist narrator]
        ["2" "Miranda Parkin" artist narrator]
        ["3" "Akumi Agitogi" artist "writer"]
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

export def test_into_tone_format_complex [] {
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
        ["1" "Damien Haas" artist narrator]
        ["2" "Miranda Parkin" artist narrator]
        ["3" "Akumi Agitogi" artist "writer"]
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

export def test_into_tone_format_works [] {
  let input = {
    book: {
      title: "Short Story Collection"
    }
    track: {
      title: "Short Story Collection"
      index: 1
      musicbrainz_works: [
        [id title bookbrainz_work_id open_library_work_id wikidata_work_id];
        ["a" "Work A" null "OL1W" null]
        ["b" "Work B" "bb" null null]
      ]
    }
  }
  let actual = $input | into_tone_format | get meta.additionalFields
  assert equal ($actual | get "MusicBrainz Work Id") "a;b"
  assert equal ($actual | get "work") "Work A;Work B"
  assert equal ($actual | get "BookBrainz Work Id") ";bb"
  assert equal ($actual | get "OpenLibrary Work Id") "OL1W;"
  # The tag is omitted when none of the works have a value
  assert equal ("Wikidata Work Id" in $actual) false
}

export def test_tracks_into_tone_format_one_track [] {
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
        ["1" "Damien Haas" artist narrator]
        ["2" "Miranda Parkin" artist narrator]
        ["3" "Akumi Agitogi" artist "writer"]
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

export def test_tracks_into_tone_format_two_tracks [] {
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
        ["2" "Miranda Parkin" artist narrator]
        ["3" "Akumi Agitogi" artist "writer"]
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
        ["1" "Damien Haas" artist narrator]
        ["2" "Miranda Parkin" artist narrator]
        ["3" "Akumi Agitogi" artist "writer"]
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
