# Tests for the chapters functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

const test_data_dir = path self ../test-data

def test_lengths_to_start_offsets [] {
  assert equal ([] | lengths_to_start_offsets) []
  assert equal ([5min] | lengths_to_start_offsets) [0ms]
  assert equal ([30sec 5min 1hr 2ms] | lengths_to_start_offsets) [0ms 30sec 330sec 3930sec]
}

def test_format_chapter_duration [] {
  assert equal (0ms | format_chapter_duration) "00:00:00.000"
  assert equal (1ms | format_chapter_duration) "00:00:00.001"
  assert equal (59999ms | format_chapter_duration) "00:00:59.999"
  assert equal (1min | format_chapter_duration) "00:01:00.000"
  assert equal (3723004ms | format_chapter_duration) "01:02:03.004"
  assert equal (100hr | format_chapter_duration) "100:00:00.000"
}

def test_chapters_from_musicbrainz_release_media [] {
  let media = [
    {
      tracks: [
        {title: "Opening Credits" length: 30069}
        {title: "Chapter 1" length: 1144834}
      ]
    }
    {
      tracks: [
        {title: "Chapter 2" length: 1148453}
        {title: "Closing Credits" length: 7191}
      ]
    }
  ]
  let expected = [
    "00:00:00.000 Opening Credits"
    "00:00:30.069 Chapter 1"
    "00:19:34.903 Chapter 2"
    "00:38:43.356 Closing Credits"
  ] | str join "\n"
  assert equal ($media | chapters_from_musicbrainz_release_media) $expected
}

# Generate a reproducible list of track durations between 1 second and 2 hours using a linear congruential generator.
def pseudo_random_durations [count: int] {
  1..$count | reduce --fold {seed: 42 durations: []} {|_, acc|
    let seed = ($acc.seed * 1103515245 + 12345) mod 2147483648
    {
      seed: $seed
      durations: ($acc.durations | append (($seed mod 7199000 + 1000) * 1ms))
    }
  } | get durations
}

def test_round_to_second_using_cumulative_offset_edge_cases [] {
  assert equal ([] | round_to_second_using_cumulative_offset) []
  assert equal ([10sec 20sec] | round_to_second_using_cumulative_offset) [10sec 20sec]
  # Ties round down when there is no accumulated offset.
  assert equal ([500ms] | round_to_second_using_cumulative_offset) [0sec]
  # The accumulated offset is kept from drifting from the total.
  let durations = [1400ms 1400ms 1400ms 1400ms 1400ms]
  let rounded = $durations | round_to_second_using_cumulative_offset
  assert equal $rounded [1sec 2sec 1sec 2sec 1sec]
  assert equal ($rounded | math sum) 7sec
}

def test_round_to_second_using_cumulative_offset_does_not_accumulate_error [] {
  # Rounding every track up or down on its own lets the error grow with each track.
  # The total of the rounded durations must stay within half a second of the actual total at every track.
  for durations in [
    (pseudo_random_durations 500)
    # Every track rounding up on its own.
    (1..200 | each { 1600ms })
    # Every track rounding down on its own.
    (1..200 | each { 1400ms })
    # Every track exactly between two seconds.
    (1..200 | each { 2500ms })
  ] {
    let rounded = $durations | round_to_second_using_cumulative_offset
    assert equal ($rounded | length) ($durations | length)
    assert ($rounded | all {|d| $d mod 1sec == 0ms })
    let actual_start_offsets = $durations | append 0ms | lengths_to_start_offsets
    let rounded_start_offsets = $rounded | append 0ms | lengths_to_start_offsets
    $actual_start_offsets | zip $rounded_start_offsets | enumerate | each {|it|
      let error = ($it.item.1 - $it.item.0) | math abs
      assert ($error <= 500ms) $"Accumulated rounding error of ($error) after ($it.index) tracks"
    }
  }
}

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

def test_combine_chapter_parts_none [] {
  let input = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 340334ms]
  ]
  let expected = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 340334ms]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_combine_one_chapter [] {
  let input = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2, Part 1" 7191ms]
    [3 "Chapter 2, Part 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Chapter 4" 340334ms]
  ]
  let expected = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 1152025ms]
    [3 "Chapter 3" 1148453ms]
    [4 "Chapter 4" 340334ms]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_combine_two_chapters [] {
  let input = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2, Part 1" 7191ms]
    [3 "Chapter 2, Part 2" 1144834ms]
    [4 "Chapter 3, Part 1" 1148453ms]
    [5 "Chapter 3, Part 2" 340334ms]
  ]
  let expected = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 1152025ms]
    [3 "Chapter 3" 1488787ms]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_combine_one_chapter_three_parts [] {
  let input = [
    [index title duration];
    [1 "Part 1, Part 1" 30069ms]
    [2 "Part 1, Part 2" 7191ms]
    [3 "Part 1, Part 3" 1144834ms]
    [4 "Part 2" 1148453ms]
    [5 "Part 3" 340334ms]
  ]
  let expected = [
    [index title duration];
    [1 "Part 1" 1182094ms]
    [2 "Part 2" 1148453ms]
    [3 "Part 3" 340334ms]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_non_one_based_index [] {
  let input = [
    [index title duration];
    [0 "Chapter 1, Part 1" 1min]
    [1 "Chapter 1, Part 2" 2min]
    [2 "Chapter 2" 3min]
  ]
  let expected = [
    [index title duration];
    [0 "Chapter 1" 3min]
    [1 "Chapter 2" 3min]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_non_adjacent [] {
  # Only consecutive parts of the same chapter are combined.
  let input = [
    [index title duration];
    [1 "Chapter 1, Part 1" 1min]
    [2 "Chapter 2" 2min]
    [3 "Chapter 1, Part 2" 3min]
  ]
  let expected = [
    [index title duration];
    [1 "Chapter 1" 1min]
    [2 "Chapter 2" 2min]
    [3 "Chapter 1" 3min]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts [] {
  test_combine_chapter_parts_non_one_based_index
  test_combine_chapter_parts_non_adjacent
  test_combine_chapter_parts_none
  test_combine_chapter_parts_combine_one_chapter
  test_combine_chapter_parts_combine_two_chapters
  test_combine_chapter_parts_combine_one_chapter_three_parts
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

def test_has_default_chapters_audible [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 340334ms]
  ]
  assert equal ($chapters | has_default_chapters) true

  let chapters = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Epilogue / Closing Credits" 340334ms]
  ]
  assert equal ($chapters | has_default_chapters) false
}

def test_has_default_chapters_libro_fm [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 30069ms]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 340334ms]
  ]
  assert equal ($chapters | has_default_chapters) true

  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 340334ms]
  ]
  assert equal ($chapters | has_default_chapters) false
}

def test_has_default_chapters_empty [] {
  assert equal ([] | has_default_chapters) false
}

def test_has_default_chapters [] {
  test_has_default_chapters_empty
  test_has_default_chapters_audible
  test_has_default_chapters_libro_fm
}

def test_rename_chapters_audible [] {
  let chapters = [
    [index title duration];
    [1 "Prologue" 5min]
    [2 "Chapter 1" 15min]
    [3 "Chapter 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Epilogue" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 5min]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters) $expected

  let chapters = [
    [index title duration];
    [1 "Chapter 1" 1155053ms]
    [2 "Chapter 2" 418842ms]
    [3 "Chapter 3" 1404064ms]
    [4 "Chapter 4" 538424ms]
    [5 "Chapter 5" 325212ms]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 1155053ms]
    [2 "Chapter 2" 418842ms]
    [3 "Chapter 3" 1404064ms]
    [4 "Chapter 4" 538424ms]
    [5 "Chapter 5 / Closing Credits" 325212ms]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_libro_fm [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 5min]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_separate_opening_credits [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 44sec]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 44sec]
    [2 "Chapter 1" 15min]
    [3 "Chapter 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Chapter 4 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_separate_end_credits [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 5min]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 30sec]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 5min]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Closing Credits" 30sec]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_separate_credits [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 44sec]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 15sec]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 44sec]
    [2 "Chapter 1" 15min]
    [3 "Chapter 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Closing Credits" 15sec]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_offset [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Prologue" 5min]
    [2 "Chapter 1" 7191ms]
    [3 "Chapter 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Chapter 4 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters --offset 1) $expected

  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 29sec]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 7191ms]
    [4 "Hogfather - Track 004" 1144834ms]
    [5 "Hogfather - Track 005" 1148453ms]
    [6 "Hogfather - Track 006" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 29sec]
    [2 "Chapter -1" 7191ms]
    [3 "Epigraph" 7191ms]
    [4 "Chapter 1" 1144834ms]
    [5 "Chapter 2" 1148453ms]
    [6 "Chapter 3 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters --offset 3) $expected
}

def test_rename_chapters_prefix [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 'Opening Credits / Part One: "ABC", Chapter 1' 5min]
    [2 'Part One: "ABC", Chapter 2' 7191ms]
    [3 'Part One: "ABC", Chapter 3' 1144834ms]
    [4 'Part One: "ABC", Chapter 4' 1148453ms]
    [5 'Part One: "ABC", Chapter 5 / Closing Credits' 30min]
  ]
  assert equal ($chapters | rename_chapters --prefix 'Part One: "ABC", ') $expected
}

def test_rename_chapters_suffix [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 'Opening Credits / Chapter 1: ""' 5min]
    [2 'Chapter 2: ""' 7191ms]
    [3 'Chapter 3: ""' 1144834ms]
    [4 'Chapter 4: ""' 1148453ms]
    [5 'Chapter 5: "" / Closing Credits' 30min]
  ]
  assert equal ($chapters | rename_chapters --suffix ': ""') $expected
}

def test_rename_chapters_prefix_suffix [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5sec]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 5sec]
    [2 'Part One: "ABC", Chapter 1: ""' 7191ms]
    [3 'Part One: "ABC", Chapter 2: ""' 1144834ms]
    [4 'Part One: "ABC", Chapter 3: ""' 1148453ms]
    [5 'Part One: "ABC", Chapter 4: "" / Closing Credits' 30min]
  ]
  assert equal ($chapters | rename_chapters --prefix 'Part One: "ABC", ' --suffix ': ""') $expected
}

def test_rename_chapters_chapter_word [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Part 1" 5min]
    [2 "Part 2" 7191ms]
    [3 "Part 3" 1144834ms]
    [4 "Part 4" 1148453ms]
    [5 "Part 5 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters --chapter-word "Part") $expected
}

def test_rename_chapters_single_chapter [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 5hr]
  ]
  assert equal ($chapters | rename_chapters) $chapters
}

def test_rename_chapters_unsorted [] {
  let chapters = [
    [index title duration];
    [3 "Chapter 3" 15min]
    [1 "Chapter 1" 5min]
    [2 "Chapter 2" 15min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 5min]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3 / Closing Credits" 15min]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_prologue [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 30sec]
    [2 "Chapter 2" 5min]
    [3 "Chapter 3" 15min]
    [4 "Chapter 4" 15min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 30sec]
    [2 "Prologue" 5min]
    [3 "Chapter 1" 15min]
    [4 "Chapter 2 / Closing Credits" 15min]
  ]
  assert equal ($chapters | rename_chapters --offset 2) $expected
}

def test_rename_chapters_requires_one_based_indices [] {
  let chapters = [
    [index title duration];
    [0 "Chapter 1" 5min]
    [1 "Chapter 2" 15min]
  ]
  assert error {|| $chapters | rename_chapters }
}

def test_rename_chapters [] {
  test_rename_chapters_single_chapter
  test_rename_chapters_unsorted
  test_rename_chapters_prologue
  test_rename_chapters_requires_one_based_indices
  test_rename_chapters_audible
  test_rename_chapters_libro_fm
  test_rename_chapters_separate_opening_credits
  test_rename_chapters_separate_end_credits
  test_rename_chapters_separate_credits
  test_rename_chapters_offset
  test_rename_chapters_prefix
  test_rename_chapters_suffix
  test_rename_chapters_prefix_suffix
  test_rename_chapters_chapter_word
}

def chapter_title [
  chapter: string
  --part: any = null
  --part-title: string = ""
  --chapter-title: string = ""
  --chapter-part: any = null
] {
  {
    part: $part
    part_title: $part_title
    chapter: $chapter
    chapter_title: $chapter_title
    chapter_part: $chapter_part
  }
}

def test_unquote [] {
  assert equal ('"Quoted"' | unquote) "Quoted"
  assert equal ("'Quoted'" | unquote) "Quoted"
  assert equal ('“Quoted”' | unquote) "Quoted"
  assert equal ('  "Quoted"  ' | unquote) "Quoted"
  assert equal ("Unquoted" | unquote) "Unquoted"
  assert equal ("What's Next?" | unquote) "What's Next?"
  assert equal ('"Mismatched' | unquote) '"Mismatched'
  assert equal ('""' | unquote) ""
  assert equal ("" | unquote) ""
}

def test_parse_chapter_title_all_parts [] {
  let chapter = 'Part One: "The First Part", Chapter 1: "The First Chapter", Part 1'
  let expected = {
    part: "Part One"
    part_title: "The First Part"
    chapter: "Chapter 1"
    chapter_title: "The First Chapter"
    chapter_part: "Part 1"
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_chapter_only [] {
  let chapter = 'Chapter 1'
  let expected = {
    part: null
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: ""
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_chapter_with_name [] {
  let chapter = 'Chapter 1: "First Chapter"'
  let expected = {
    part: null
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: "First Chapter"
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_chapter_part [] {
  let chapter = 'Chapter 1, Part 1'
  let expected = {
    part: null
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: ""
    chapter_part: "Part 1"
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_part_chapter [] {
  let chapter = 'Part One, Chapter 1'
  let expected = {
    part: "Part One"
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: ""
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_opening_credits [] {
  let chapter = 'Opening Credits'
  let expected = {
    part: null
    part_title: ""
    chapter: "Opening Credits"
    chapter_title: ""
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_opening_credits_chapter_one [] {
  let chapter = 'Opening Credits / Chapter 1'
  let expected = {
    part: null
    part_title: ""
    chapter: "Opening Credits / Chapter 1"
    chapter_title: ""
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_unquoted_title [] {
  assert equal ("Chapter 1: Piranesi" | parse_chapter_title) (chapter_title "Chapter 1" --chapter-title "Piranesi")
  assert equal ("Chapter 7: Matthew Rose Sorensen" | parse_chapter_title) (chapter_title "Chapter 7" --chapter-title "Matthew Rose Sorensen")
  assert equal ("Chapter 4: 16" | parse_chapter_title) (chapter_title "Chapter 4" --chapter-title "16")
}

def test_parse_chapter_title_punctuation [] {
  assert equal ("Chapter 3: What's Next?" | parse_chapter_title) (chapter_title "Chapter 3" --chapter-title "What's Next?")
  assert equal ("Chapter 3: \"What's Next?\"" | parse_chapter_title) (chapter_title "Chapter 3" --chapter-title "What's Next?")
  assert equal ("Chapter 1: Foo: Bar" | parse_chapter_title) (chapter_title "Chapter 1" --chapter-title "Foo: Bar")
  assert equal ("Chapter 1: Mr. Norrell, Esq." | parse_chapter_title) (chapter_title "Chapter 1" --chapter-title "Mr. Norrell, Esq.")
  assert equal ("Chapter 1: AC/DC" | parse_chapter_title) (chapter_title "Chapter 1" --chapter-title "AC/DC")
  assert equal ('Chapter 1: “Curly Quotes”' | parse_chapter_title) (chapter_title "Chapter 1" --chapter-title "Curly Quotes")
}

def test_parse_chapter_title_chapter_part_with_title [] {
  assert equal ("Chapter 2: The Other, Part 1" | parse_chapter_title) (chapter_title "Chapter 2" --chapter-title "The Other" --chapter-part "Part 1")
  assert equal ('Chapter 2: "The Other", Part 12' | parse_chapter_title) (chapter_title "Chapter 2" --chapter-title "The Other" --chapter-part "Part 12")
  assert equal ("Chapter 4: 16, Part 2" | parse_chapter_title) (chapter_title "Chapter 4" --chapter-title "16" --chapter-part "Part 2")
}

def test_parse_chapter_title_unquoted_part_title [] {
  assert equal ("Part One: Beginnings, Chapter 1: The Start" | parse_chapter_title) (
    chapter_title "Chapter 1" --part "Part One" --part-title "Beginnings" --chapter-title "The Start"
  )
}

def test_parse_chapter_title_quoted_commas_and_slashes [] {
  assert equal ('Part One: "Beginnings, Endings", Chapter 1: "Either / Or", Part 2' | parse_chapter_title) (
    chapter_title "Chapter 1" --part "Part One" --part-title "Beginnings, Endings" --chapter-title "Either / Or" --chapter-part "Part 2"
  )
}

def test_parse_chapter_title_combined_tracks [] {
  assert equal ("Epigraph / Chapter 1: Piranesi" | parse_chapter_title) (chapter_title "Epigraph / Chapter 1" --chapter-title "Piranesi")
  assert equal ('Chapter 5: "The End" / Closing Credits' | parse_chapter_title) (chapter_title "Chapter 5 / Closing Credits" --chapter-title "The End")
  assert equal ("Chapter 5, Part 2 / Closing Credits" | parse_chapter_title) (chapter_title "Chapter 5 / Closing Credits" --chapter-part "Part 2")
  assert equal ("Chapter 1: One / Chapter 2: Two" | parse_chapter_title) (chapter_title "Chapter 1 / Chapter 2" --chapter-title "One / Two")
}

def test_parse_chapter_title_chapter_word_part [] {
  # Chapters may themselves be named "Part".
  assert equal ("Part 3" | parse_chapter_title) (chapter_title "Part 3")
  assert equal ("Part 3: The Return" | parse_chapter_title) (chapter_title "Part 3" --chapter-title "The Return")
  assert equal ("Part 1, Part 2" | parse_chapter_title) (chapter_title "Part 1" --chapter-part "Part 2")
}

def test_parse_chapter_title [] {
  test_parse_chapter_title_unquoted_title
  test_parse_chapter_title_punctuation
  test_parse_chapter_title_chapter_part_with_title
  test_parse_chapter_title_unquoted_part_title
  test_parse_chapter_title_quoted_commas_and_slashes
  test_parse_chapter_title_combined_tracks
  test_parse_chapter_title_chapter_word_part
  test_parse_chapter_title_all_parts
  test_parse_chapter_title_chapter_only
  test_parse_chapter_title_chapter_with_name
  test_parse_chapter_title_chapter_part
  test_parse_chapter_title_part_chapter
  test_parse_chapter_title_opening_credits
  test_parse_chapter_title_opening_credits_chapter_one
}

# Run the tests in this module
export def run_tests [] {
  test_lengths_to_start_offsets
  test_format_chapter_duration
  test_chapters_from_musicbrainz_release_media
  test_round_to_second_using_cumulative_offset
  test_round_to_second_using_cumulative_offset_edge_cases
  test_round_to_second_using_cumulative_offset_does_not_accumulate_error
  test_has_default_chapters
  test_rename_chapters
  test_unquote
  test_parse_chapter_title
  test_combine_chapter_parts
  test_parse_chapters_from_tone
  test_chapters_into_tone_format
  test_parse_chapters_from_musicbrainz_release
}
