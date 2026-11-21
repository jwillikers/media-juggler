# Tests for the acoustid functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

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

export def test_determine_releases_from_acoustid_fingerprint_matches_empty [] {
  assert equal ([] | determine_releases_from_acoustid_fingerprint_matches) null
}

export def test_determine_releases_from_acoustid_fingerprint_matches_one_track_one_release [] {
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

export def test_determine_releases_from_acoustid_fingerprint_matches_one_track_two_releases [] {
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

export def test_determine_releases_from_acoustid_fingerprint_matches_thirteen_tracks_one_release [] {
  let input = [[file, fingerprint, duration, matches]; ["Baccano! Vol. 1 (light novel) - Track 001.mp3", "1", 30090000000ns, [[id, recordings, score]; ["3640c01c-a763-404e-9ec4-c60d28820e01", [[id, releases]; ["a017ad86-9318-4688-93fc-67acd226c24b", [[id]; ["0425322c-c953-477a-9494-affb04314373"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 002.mp3", "2", 1350160000000ns, [[id, recordings, score]; ["30976711-0ae5-431e-8fa7-56aee9d50dd1", [[id, releases]; ["6a10103d-ec54-48f5-b6b2-f1d12938bb9b", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 003.mp3", "3", 509130000000ns, [[id, recordings, score]; ["91b44ea0-f078-4d1e-afee-b0b4a8772316", [[id, releases]; ["8b913142-4a8b-4be8-98f9-d25a2ff1537b", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 004.mp3", "4", 4117130000000ns, [[id, recordings, score]; ["9dd90c27-94f5-4fa7-8ea6-dcd3b7f7d456", [[id, releases]; ["b8655446-d779-4d1c-a8d3-e19b6a4e702f", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 005.mp3", "5", 4542270000000ns, [[id, recordings, score]; ["c88dcadb-328e-4a81-8e70-80177c9834c5", [[id, releases]; ["ee72646d-b260-4e5e-8b45-5de2b5d5daba", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 006.mp3", "6", 1270650000000ns, [[id, recordings, score]; ["9f119955-0341-4d62-a6c5-137dbc99f214", [[id, releases]; ["75486e2b-5cbd-4682-9f37-1f2404d3221a", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 007.mp3", "7", 3357050000000ns, [[id, recordings, score]; ["120dc6ab-ef38-4ac9-a3d4-4e5052ecb7b8", [[id, releases]; ["025f99e5-cde5-4753-ba0c-2391b357b021", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 008.mp3", "8", 1545770000000ns, [[id, recordings, score]; ["95af01f0-1579-460b-998e-cf4b6c2e6f79", [[id, releases]; ["5d80e2ed-8164-4336-869b-0edf82bd6225", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 009.mp3", "9", 4237770000000ns, [[id, recordings, score]; ["27b42309-c46b-450e-a05d-d5f17ae0dc88", [[id, releases]; ["87896433-746e-461d-995c-eb1002376905", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 010.mp3", "10", 751600000000ns, [[id, recordings, score]; ["8f7cd0be-91ac-4d80-ad16-dca82020d6ff", [[id, releases]; ["33137454-1d0b-47ba-8273-ffa3dde7e971", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 011.mp3", "11", 781190000000ns, [[id, recordings, score]; ["c2abc000-8ca0-4029-b8a7-89092d772767", [[id, releases]; ["617223b7-419e-4dfa-923e-21ba9655f39b", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 012.mp3", "12", 361820000000ns, [[id, recordings, score]; ["75cd8d2f-3931-45cc-b4be-23c74d1387b7", [[id, releases]; ["54227782-962c-4a14-825d-8057baf6e6cd", [[id]; ["0425322c-c953-477a-9494-affb04314373"], ["aaca2621-60fc-4534-98e1-494f9e006a49"]]]], 1.0]]], ["Baccano! Vol. 1 (light novel) - Track 013.mp3", "13", 131870000000ns, [[id, recordings, score]; ["e086eb93-e02b-41e6-b882-3ef59824da04", [[id, releases]; ["4f811dc2-3de0-47ce-afbb-3602a21c814c", [[id]; ["0425322c-c953-477a-9494-affb04314373"]]]], 1.0]]]]
  let expected = ["0425322c-c953-477a-9494-affb04314373"]
  assert equal ($input | determine_releases_from_acoustid_fingerprint_matches) $expected
}
