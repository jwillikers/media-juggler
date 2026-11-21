# Tests for the utils functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

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

def test_escape_special_glob_characters_empty_input [] {
  let input = ""
  let expected = ""
  assert equal ($input | escape_special_glob_characters) $expected
}

def test_escape_special_glob_characters_escape_square_brackets [] {
  let input = '/var/[Special Directory]'
  let expected = '/var/\[Special Directory\]'
  assert equal ($input | escape_special_glob_characters) $expected
}

def test_escape_special_glob_characters_escape_parentheses [] {
  let input = '/var/something (Special Directory)'
  let expected = '/var/something [(]Special Directory[)]'
  assert equal ($input | escape_special_glob_characters) $expected
}

def test_escape_special_glob_characters_escape_curly_braces [] {
  let input = '/var/something {Special Directory}/test'
  let expected = '/var/something [{]Special Directory[}]/test'
  assert equal ($input | escape_special_glob_characters) $expected
}

def test_escape_special_glob_characters_escape_nothing [] {
  let input = '/var/nothing special here!/...'
  assert equal ($input | escape_special_glob_characters) $input
}

def test_escape_special_glob_characters_escape_all_special_characters [] {
  let input = '/var/][nothing }{special here!/...($money: 20.*,)'
  let expected = '/var/\]\[nothing [}][{]special here!/...[(][$]money[:] 20.[*][,][)]'
  assert equal ($input | escape_special_glob_characters) $expected
}

def test_escape_special_glob_characters [] {
  test_escape_special_glob_characters_empty_input
  test_escape_special_glob_characters_escape_square_brackets
  test_escape_special_glob_characters_escape_parentheses
  test_escape_special_glob_characters_escape_curly_braces
  test_escape_special_glob_characters_escape_nothing
  test_escape_special_glob_characters_escape_all_special_characters
}

# Run the tests in this module
def test_join_parallel_multi_value_null [] {
  assert equal (null | join_parallel_multi_value) null
}

def test_join_parallel_multi_value_empty_list [] {
  assert equal ([] | join_parallel_multi_value) null
}

def test_join_parallel_multi_value_all_missing [] {
  assert equal ([null "" []] | join_parallel_multi_value) null
}

def test_join_parallel_multi_value_one [] {
  assert equal (["a"] | join_parallel_multi_value) "a"
}

def test_join_parallel_multi_value_all_present [] {
  assert equal (["a" "b" "c"] | join_parallel_multi_value) "a;b;c"
}

def test_join_parallel_multi_value_some_missing [] {
  assert equal ([null "b" "" []] | join_parallel_multi_value) ";b;;"
}

def test_join_parallel_multi_value [] {
  test_join_parallel_multi_value_null
  test_join_parallel_multi_value_empty_list
  test_join_parallel_multi_value_all_missing
  test_join_parallel_multi_value_one
  test_join_parallel_multi_value_all_present
  test_join_parallel_multi_value_some_missing
}

def test_parse_parallel_multi_value_tag_null [] {
  assert equal (null | parse_parallel_multi_value_tag) null
}

def test_parse_parallel_multi_value_tag_empty_string [] {
  assert equal ("" | parse_parallel_multi_value_tag) null
}

def test_parse_parallel_multi_value_tag_one [] {
  assert equal ("a" | parse_parallel_multi_value_tag) ["a"]
}

def test_parse_parallel_multi_value_tag_all_present [] {
  assert equal ("a; b ;c" | parse_parallel_multi_value_tag) ["a" "b" "c"]
}

def test_parse_parallel_multi_value_tag_some_missing [] {
  assert equal (";b;;" | parse_parallel_multi_value_tag) [null "b" null null]
}

def test_parse_parallel_multi_value_tag_empty_list_literal [] {
  assert equal ("[];b;[]" | parse_parallel_multi_value_tag) [null "b" null]
}

def test_parse_parallel_multi_value_tag_round_trip [] {
  let input = [null "b" null "d"]
  assert equal ($input | join_parallel_multi_value | parse_parallel_multi_value_tag) $input
}

def test_parse_parallel_multi_value_tag [] {
  test_parse_parallel_multi_value_tag_null
  test_parse_parallel_multi_value_tag_empty_string
  test_parse_parallel_multi_value_tag_one
  test_parse_parallel_multi_value_tag_all_present
  test_parse_parallel_multi_value_tag_some_missing
  test_parse_parallel_multi_value_tag_empty_list_literal
  test_parse_parallel_multi_value_tag_round_trip
}

export def run_tests [] {
  test_upsert_if_present
  test_upsert_if_value
  test_escape_special_glob_characters
  test_join_parallel_multi_value
  test_parse_parallel_multi_value_tag
}
