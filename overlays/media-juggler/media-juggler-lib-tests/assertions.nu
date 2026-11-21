# Tests for the assertions used by the tests of media-juggler-lib

use std assert

use helpers/assertions.nu *

export def test_find_differences_equal [] {
  assert equal (find_differences {a: [1 2] b: "x"} {a: [1 2] b: "x"}) []
}

export def test_find_differences_scalar [] {
  let expected = [[path reason actual expected]; ["" different 1 2]]
  assert equal (find_differences 1 2) $expected
}

export def test_find_differences_different_types [] {
  let expected = [[path reason actual expected]; ["" different "1" 1]]
  assert equal (find_differences "1" 1) $expected
}

export def test_find_differences_record_value [] {
  let expected = [[path reason actual expected]; [b different 3 2]]
  assert equal (find_differences {a: 1 b: 3} {a: 1 b: 2}) $expected
}

export def test_find_differences_record_missing_and_unexpected_keys [] {
  let expected = [
    [path reason actual expected];
    [b missing null 2]
    [c unexpected 3 null]
  ]
  assert equal (find_differences {a: 1 c: 3} {a: 1 b: 2}) $expected
}

export def test_find_differences_key_with_spaces [] {
  let expected = [[path reason actual expected]; ['"MusicBrainz Work Id"' different "a" "b"]]
  assert equal (find_differences {"MusicBrainz Work Id": "a"} {"MusicBrainz Work Id": "b"}) $expected
}

export def test_find_differences_nested [] {
  let actual = {book: {series: [{name: "A" index: "1"} {name: "B" index: "3"}]}}
  let expected = {book: {series: [{name: "A" index: "1"} {name: "B" index: "2"}]}}
  let expected_differences = [[path reason actual expected]; ["book.series.1.index" different "3" "2"]]
  assert equal (find_differences $actual $expected) $expected_differences
}

export def test_find_differences_list_length [] {
  let expected = [
    [path reason actual expected];
    ["" "length 3 instead of 2" 3 2]
    ["2" unexpected "c" null]
  ]
  assert equal (find_differences [a b c] [a b]) $expected
}

export def test_find_differences_table [] {
  let actual = [[name count]; [fantasy 1] [romance 2]]
  let expected = [[name count]; [fantasy 1] [romance 1]]
  let expected_differences = [[path reason actual expected]; ["1.count" different 2 1]]
  assert equal (find_differences $actual $expected) $expected_differences
}

export def test_assert_equal_deep_equal [] {
  assert_equal_deep {a: [1 {b: 2}]} {a: [1 {b: 2}]}
}

export def test_assert_equal_deep_reports_paths [] {
  let error = try {
    assert_equal_deep {a: 1 b: {c: [1 2]}} {a: 1 b: {c: [1 3]} d: 4}
    null
  } catch {|error|
    $error.msg
  }
  assert ($error | is-not-empty) "assert_equal_deep should fail for different values"
  assert str contains $error "Found 2 differences"
  assert str contains $error "b.c.1: expected 3"
  assert str contains $error "actual 2"
  assert str contains $error "d: missing, expected 4"
}

export def test_assert_equal_deep_one_difference [] {
  let error = try {
    assert_equal_deep {a: 1} {a: 2}
    null
  } catch {|error|
    $error.msg
  }
  assert str contains $error "Found 1 difference:"
}

export def test_assert_equal_deep_limits_differences [] {
  let error = try {
    assert_equal_deep [1 2 3 4] [5 6 7 8] --max-differences 2
    null
  } catch {|error|
    $error.msg
  }
  assert str contains $error "Found 4 differences"
  assert str contains $error "… and 2 more"
}
