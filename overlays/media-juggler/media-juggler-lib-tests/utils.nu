# Tests for the utils functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

export def test_upsert_if_present_same_column [] {
  let expected = {key: "value"}
  assert equal ({} | upsert_if_present key {key: "value"}) $expected
}

export def test_upsert_if_present_different_column [] {
  let expected = {different: "value"}
  assert equal ({} | upsert_if_present different {key: "value"} key) $expected
}

export def test_upsert_if_present_null_value [] {
  assert equal ({} | upsert_if_present different {key: null} key) {}
}

export def test_upsert_if_present_missing_column [] {
  assert equal ({} | upsert_if_present different {} key) {}
}

export def test_upsert_if_value_null [] {
  assert equal ({} | upsert_if_value key null) {}
}

export def test_upsert_if_value_empty [] {
  assert equal ({} | upsert_if_value key []) {}
}

export def test_upsert_if_value_something [] {
  assert equal ({} | upsert_if_value key "something") {key: "something"}
}

export def test_escape_special_glob_characters_empty_input [] {
  let input = ""
  let expected = ""
  assert equal ($input | escape_special_glob_characters) $expected
}

export def test_escape_special_glob_characters_escape_square_brackets [] {
  let input = '/var/[Special Directory]'
  let expected = '/var/\[Special Directory\]'
  assert equal ($input | escape_special_glob_characters) $expected
}

export def test_escape_special_glob_characters_escape_parentheses [] {
  let input = '/var/something (Special Directory)'
  let expected = '/var/something [(]Special Directory[)]'
  assert equal ($input | escape_special_glob_characters) $expected
}

export def test_escape_special_glob_characters_escape_curly_braces [] {
  let input = '/var/something {Special Directory}/test'
  let expected = '/var/something [{]Special Directory[}]/test'
  assert equal ($input | escape_special_glob_characters) $expected
}

export def test_escape_special_glob_characters_escape_nothing [] {
  let input = '/var/nothing special here!/...'
  assert equal ($input | escape_special_glob_characters) $input
}

export def test_escape_special_glob_characters_escape_all_special_characters [] {
  let input = '/var/][nothing }{special here!/...($money: 20.*,)'
  let expected = '/var/\]\[nothing [}][{]special here!/...[(][$]money[:] 20.[*][,][)]'
  assert equal ($input | escape_special_glob_characters) $expected
}

# Run the tests in this module
export def test_join_parallel_multi_value_null [] {
  assert equal (null | join_parallel_multi_value) null
}

export def test_join_parallel_multi_value_empty_list [] {
  assert equal ([] | join_parallel_multi_value) null
}

export def test_join_parallel_multi_value_all_missing [] {
  assert equal ([null "" []] | join_parallel_multi_value) null
}

export def test_join_parallel_multi_value_one [] {
  assert equal (["a"] | join_parallel_multi_value) "a"
}

export def test_join_parallel_multi_value_all_present [] {
  assert equal (["a" "b" "c"] | join_parallel_multi_value) "a;b;c"
}

export def test_join_parallel_multi_value_some_missing [] {
  assert equal ([null "b" "" []] | join_parallel_multi_value) ";b;;"
}

export def test_parse_parallel_multi_value_tag_null [] {
  assert equal (null | parse_parallel_multi_value_tag) null
}

export def test_parse_parallel_multi_value_tag_empty_string [] {
  assert equal ("" | parse_parallel_multi_value_tag) null
}

export def test_parse_parallel_multi_value_tag_one [] {
  assert equal ("a" | parse_parallel_multi_value_tag) ["a"]
}

export def test_parse_parallel_multi_value_tag_all_present [] {
  assert equal ("a; b ;c" | parse_parallel_multi_value_tag) ["a" "b" "c"]
}

export def test_parse_parallel_multi_value_tag_some_missing [] {
  assert equal (";b;;" | parse_parallel_multi_value_tag) [null "b" null null]
}

export def test_parse_parallel_multi_value_tag_empty_list_literal [] {
  assert equal ("[];b;[]" | parse_parallel_multi_value_tag) [null "b" null]
}

export def test_parse_parallel_multi_value_tag_round_trip [] {
  let input = [null "b" null "d"]
  assert equal ($input | join_parallel_multi_value | parse_parallel_multi_value_tag) $input
}
