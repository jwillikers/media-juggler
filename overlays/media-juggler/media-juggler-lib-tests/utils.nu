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

export def test_sanitize_file_name_plain [] {
  assert equal ("My Book" | sanitize_file_name) "My Book"
}

export def test_sanitize_file_name_slash [] {
  assert equal ("Fate/Zero" | sanitize_file_name) "Fate⧸Zero"
}

export def test_sanitize_file_name_dot [] {
  assert equal ("." | sanitize_file_name) "․"
}

export def test_sanitize_file_name_dot_dot [] {
  assert equal (".." | sanitize_file_name) "‥"
}

export def test_use_unicode_in_title_apostrophe_hyphen_ellipsis [] {
  assert equal ("Don't Re-read This..." | use_unicode_in_title) "Don’t Re‐read This…"
}

export def test_use_unicode_in_title_half [] {
  assert equal ("Ranma 1/2" | use_unicode_in_title) "Ranma ½"
  assert equal ("Ranma 1⧸2" | use_unicode_in_title) "Ranma ½"
}

export def test_use_unicode_in_title_quotes [] {
  assert equal ('The "Best" and "Worst"' | use_unicode_in_title) "The “Best” and “Worst”"
}

export def test_use_unicode_in_title_keeps_hyphen_before_volume [] {
  assert equal ("Spice-and-Wolf - Volume 1" | use_unicode_in_title) "Spice‐and‐Wolf - Volume 1"
}

export def test_standardize_title_no_volume [] {
  assert equal ("Spice and Wolf" | standardize_title) "Spice and Wolf"
}

export def test_standardize_title_volume [] {
  assert equal ("Spice and Wolf - Volume 1" | standardize_title) "Spice and Wolf, Volume 1"
}

export def test_standardize_title_volume_after_punctuation [] {
  assert equal ("Kaguya-sama: Love Is War! - Volume 2" | standardize_title) "Kaguya-sama: Love Is War! Volume 2"
}

export def test_merge_or_input_both [] {
  assert equal ({a: 1 b: 2} | merge_or_input {b: 3 c: 4}) {a: 1 b: 3 c: 4}
}

export def test_merge_or_input_empty_input [] {
  assert equal ({} | merge_or_input {b: 3}) {b: 3}
}

export def test_merge_or_input_empty_argument [] {
  assert equal ({a: 1} | merge_or_input null) {a: 1}
}

export def test_merge_or_input_both_empty [] {
  assert equal (null | merge_or_input {}) null
}

export def test_parse_multi_value_tag_empty [] {
  assert equal ("" | parse_multi_value_tag) null
}

export def test_parse_multi_value_tag_values [] {
  assert equal ("a; b ;c" | parse_multi_value_tag) [a b c]
}

export def test_parse_multi_value_tag_separator [] {
  assert equal ("a, b;c" | parse_multi_value_tag ",") [a "b;c"]
}

export def test_join_multi_value_empty [] {
  assert equal ([] | join_multi_value) null
}

export def test_join_multi_value_values [] {
  assert equal ([a b c] | join_multi_value) "a;b;c"
}

export def test_retry_succeeds_first_attempt [] {
  let calls = mktemp --tmpdir
  let result = retry {|| "x" | save --append $calls; "done" } {|response| false } 3 0sec false
  assert equal $result "done"
  assert equal (open --raw $calls | str length) 1
  rm $calls
}

export def test_retry_until_success [] {
  let calls = mktemp --tmpdir
  let result = retry {||
    "x" | save --append $calls
    open --raw $calls | str length
  } {|response| $response < 2 } 3 0sec false
  assert equal $result 2
  rm $calls
}

export def test_retry_makes_at_most_retries_attempts [] {
  let calls = mktemp --tmpdir
  let result = retry {|| "x" | save --append $calls; "failure" } {|response| true } 3 0sec false
  # The result of the final attempt is returned even when it should be retried
  assert equal $result "failure"
  assert equal (open --raw $calls | str length) 3
  rm $calls
}

export def test_retry_ignores_exceptions [] {
  let calls = mktemp --tmpdir
  let result = retry {||
    "x" | save --append $calls
    if (open --raw $calls | str length) < 2 {
      error make {msg: "transient failure"}
    }
    "done"
  } {|response| false } 3 0sec true
  assert equal $result "done"
  assert equal (open --raw $calls | str length) 2
  rm $calls
}

export def test_retry_rethrows_exceptions [] {
  assert error {|| retry {|| error make {msg: "failure"} } {|response| false } 3 0sec false }
}

export def test_hash_sha3_512 [] {
  let file = mktemp --tmpdir
  "abc" | save --force $file
  let expected = "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0"
  assert equal ($file | hash_sha3_512) $expected
  rm $file
}

export def test_hash_blake3 [] {
  let file = mktemp --tmpdir
  "abc" | save --force $file
  let expected = "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85"
  assert equal ($file | hash_blake3) $expected
  rm $file
}

export def test_hash_sha3_512_missing_file [] {
  assert error {|| "missing-file" | hash_sha3_512 }
}
