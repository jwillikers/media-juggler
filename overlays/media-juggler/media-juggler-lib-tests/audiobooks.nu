# Tests for the audiobooks functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

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

def test_has_distributor_in_common_no_distributor_left [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Dragonsteel" label publisher]
  ]
  let right: table<id: string, name: string, entity: string, role: string> = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Dragonsteel" label publisher]
  ]
  assert equal ($left | has_distributor_in_common $right) false
}

def test_has_distributor_in_common_no_distributor_right [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Dragonsteel" label publisher]
  ]
  let right: table<id: string, name: string, entity: string, role: string> = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Dragonsteel" label publisher]
  ]
  assert equal ($left | has_distributor_in_common $right) false
}

def test_has_distributor_in_common_no_distributor_both [] {
  let left = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Dragonsteel" label publisher]
  ]
  let right: table<id: string, name: string, entity: string, role: string> = [
    [id name entity role];
    ["3e61c686-61a6-459e-a178-b709ebb9eb10" "Syougo Kinugasa" artist "primary author"]
    ["3e822ea5-fb7e-4048-bffa-f8af76e55538" Tomoseshunsaku artist illustrator]
    ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Dragonsteel" label publisher]
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
  test_has_distributor_in_common_no_distributor_left
  test_has_distributor_in_common_no_distributor_right
  test_has_distributor_in_common_no_distributor_both
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
        tags: [
          [name count scope];
          [chapters 11 release]
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
        tags: [
          [name count scope];
          [chapters 10 release]
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

# Run the tests in this module
export def run_tests [] {
  test_equivalent_track_durations
  test_has_distributor_in_common
  test_audiobooks_with_the_highest_voted_chapters_tag
  test_filter_musicbrainz_chapters_releases
  test_filter_musicbrainz_releases
}
