# Assertions for the tests of media-juggler-lib

# The base type of a value, such as record, table, list, or string
def base_type []: any -> string {
  $in | describe | str replace --regex '<.*' ''
}

# Append a key or index to a cell path for display
def append_to_path [member: any]: string -> string {
  let path = $in
  let member = (
    if ($member | describe) == "int" or ($member =~ '^[A-Za-z0-9_-]+$') {
      $member | into string
    } else {
      $member | to nuon
    }
  )
  if ($path | is-empty) {
    $member
  } else {
    $"($path).($member)"
  }
}

# Find the differences between two values
#
# Records are compared key by key and lists are compared item by item, so that each difference is reported with the path to it.
export def find_differences [
  actual: any
  expected: any
  path: string = "" # The path of the values being compared
]: nothing -> table<path: string, reason: string, actual: any, expected: any> {
  if $actual == $expected {
    return []
  }
  let actual_type = $actual | base_type
  let expected_type = $expected | base_type
  let differences = (
    if $actual_type == "record" and $expected_type == "record" {
      let actual_keys = $actual | columns
      let expected_keys = $expected | columns
      $expected_keys | append ($actual_keys | where {|key| $key not-in $expected_keys }) | each {|key|
        let key_path = $path | append_to_path $key
        if $key not-in $actual_keys {
          [{path: $key_path reason: "missing" actual: null expected: ($expected | get $key)}]
        } else if $key not-in $expected_keys {
          [{path: $key_path reason: "unexpected" actual: ($actual | get $key) expected: null}]
        } else {
          find_differences ($actual | get $key) ($expected | get $key) $key_path
        }
      } | flatten
    } else if $actual_type in [list table] and $expected_type in [list table] {
      let actual_length = $actual | length
      let expected_length = $expected | length
      let length_difference = (
        if $actual_length != $expected_length {
          [{path: $path reason: $"length ($actual_length) instead of ($expected_length)" actual: $actual_length expected: $expected_length}]
        } else {
          []
        }
      )
      let item_differences = (
        0..<([$actual_length $expected_length] | math max) | each {|index|
          let index_path = $path | append_to_path $index
          if $index >= $actual_length {
            [{path: $index_path reason: "missing" actual: null expected: ($expected | get $index)}]
          } else if $index >= $expected_length {
            [{path: $index_path reason: "unexpected" actual: ($actual | get $index) expected: null}]
          } else {
            find_differences ($actual | get $index) ($expected | get $index) $index_path
          }
        } | flatten
      )
      $length_difference | append $item_differences
    } else {
      []
    }
  )
  if ($differences | is-empty) {
    # The values differ in some other way, such as by type
    [{path: $path reason: "different" actual: $actual expected: $expected}]
  } else {
    $differences
  }
}

# Shorten a value's representation for display
def summarize_value [max_length: int]: any -> string {
  let text = $in | to nuon
  if ($text | str length) > $max_length {
    ($text | str substring 0..<$max_length) + "…"
  } else {
    $text
  }
}

# Assert that two values are equal, reporting each difference between them with its path
#
# This is useful for large records and tables, where assert equal prints both values in full.
export def assert_equal_deep [
  actual: any
  expected: any
  --max-differences: int = 20 # The maximum number of differences to report
  --max-value-length: int = 200 # The maximum length of each value in the report
] {
  if $actual == $expected {
    return
  }
  let differences = find_differences $actual $expected
  let report = (
    $differences
    | first $max_differences
    | each {|difference|
      let path = if ($difference.path | is-empty) { "(root)" } else { $difference.path }
      match $difference.reason {
        "missing" => $"  ($path): missing, expected ($difference.expected | summarize_value $max_value_length)"
        "unexpected" => $"  ($path): unexpected ($difference.actual | summarize_value $max_value_length)"
        "different" => $"  ($path): expected ($difference.expected | summarize_value $max_value_length)\n  ($path | str replace --all --regex '.' ' ')    actual ($difference.actual | summarize_value $max_value_length)"
        _ => $"  ($path): ($difference.reason)"
      }
    }
  )
  let omitted = ($differences | length) - $max_differences
  let report = (
    if $omitted > 0 {
      $report | append $"  … and ($omitted) more"
    } else {
      $report
    }
  )
  error make {
    msg: $"The values are not equal. Found ($differences | length) (if ($differences | length) == 1 { "difference" } else { "differences" }):\n($report | str join "\n")"
    label: {
      text: "actual value"
      span: (metadata $actual).span
    }
  }
}
