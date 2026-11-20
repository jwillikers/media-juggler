# Tests for the chapters functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

const test_data_dir = path self ../test-data

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

def test_combine_chapter_parts [] {
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

# Run the tests in this module
export def run_tests [] {
  test_round_to_second_using_cumulative_offset
  test_combine_chapter_parts
  test_parse_chapters_from_tone
  test_chapters_into_tone_format
  test_parse_chapters_from_musicbrainz_release
}
