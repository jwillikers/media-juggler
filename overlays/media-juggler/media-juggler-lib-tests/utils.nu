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
export def run_tests [] {
  test_upsert_if_present
  test_upsert_if_value
  test_escape_special_glob_characters
}
