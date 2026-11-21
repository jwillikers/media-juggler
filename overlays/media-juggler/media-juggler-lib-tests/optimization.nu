# Tests for the optimization functions in media-juggler-lib

use std assert

use ../media-juggler-lib *

def optimization_result [original_size: filesize optimized_size: filesize]: nothing -> record {
  {
    original_file: "original.png"
    optimized_file: "optimized.png"
    original_size: $original_size
    optimized_size: $optimized_size
    percent_difference: 0.0
    duration: 1sec
  }
}

export def test_get_smallest_from_optimization_result_smaller [] {
  assert equal (optimization_result 10KiB 8KiB | get_smallest_from_optimization_result) "optimized.png"
}

export def test_get_smallest_from_optimization_result_larger [] {
  assert equal (optimization_result 10KiB 12KiB | get_smallest_from_optimization_result) "original.png"
}

export def test_get_smallest_from_optimization_result_same_size [] {
  assert equal (optimization_result 10KiB 10KiB | get_smallest_from_optimization_result) "original.png"
}

export def test_get_smallest_from_optimization_result_failed [] {
  assert equal (optimization_result 10KiB 10KiB | update optimized_file "" | get_smallest_from_optimization_result) null
}

export def test_measure_optimization_performance [] {
  let directory = mktemp --directory --tmpdir
  let original = $directory | path join "original.txt"
  1..100000 | each { "a" } | str join | save $original
  let result = $original | measure_optimization_performance {|file|
    let optimized = $directory | path join "optimized.txt"
    1..10000 | each { "a" } | str join | save $optimized
    $optimized
  }
  assert equal $result.original_file $original
  assert equal $result.optimized_file ($directory | path join "optimized.txt")
  assert ($result.optimized_size < $result.original_size)
  assert ($result.percent_difference > 0)
  rm --recursive $directory
}

export def test_measure_optimization_performance_failed [] {
  let directory = mktemp --directory --tmpdir
  let original = $directory | path join "original.txt"
  "original" | save $original
  let result = $original | measure_optimization_performance {|file| null }
  assert equal $result.optimized_file ""
  assert equal ($result | get_smallest_from_optimization_result) null
  rm --recursive $directory
}
