#!/usr/bin/env nu

# Run the tests for media-juggler-lib
#
# Tests are discovered automatically.
# Each module under media-juggler-lib-tests defines its tests as exported commands whose names start with "test_".
# A test command that is defined but not exported is reported as skipped.
# To disable a test, remove "export" and add a comment explaining why.
#
# The tests in each module run in a separate Nushell process, and the modules run in parallel.
# A failing test doesn't stop the remaining tests from running.

const tests_directory = path self media-juggler-lib-tests

# Each test result is printed on a line beginning with this marker so that it can be told apart from other output.
const result_marker = "MEDIA_JUGGLER_TEST_RESULT "

# Find the tests in a test module
def discover_tests []: path -> record<exported: list<string>, skipped: list<string>> {
  let source = open --raw $in
  {
    exported: ($source | parse --regex '(?m)^export def (?<name>test_[^\s\[]+) ' | get name)
    skipped: ($source | parse --regex '(?m)^def (?<name>test_[^\s\[]+) ' | get name)
  }
}

# Build a Nushell script that runs the given tests of a module and prints the result of each one
def build_test_script [
  file: path
  module: string
  tests: list<string>
]: nothing -> string {
  let cases = (
    $tests
    | each {|test| $"  [($test | to nuon) {|| ($module) ($test)}]" }
    | str join "\n"
  )
  r#'
use FILE
let marker = MARKER
let cases = [
CASES
]
for case in $cases {
  let start = date now
  let result = try {
    do $case.1
    {status: passed}
  } catch {|error|
    {status: failed, error: $error.rendered}
  }
  print ($marker + ($result | insert test $case.0 | insert duration ((date now) - $start | into int) | to json --raw))
}
'#
  | str replace "FILE" ($file | to nuon)
  | str replace "MARKER" ($result_marker | to nuon)
  | str replace "CASES" $cases
}

# Run the tests of a single test module
def run_test_module [
  filter: string
]: path -> record {
  let file = $in
  let module = $file | path parse | get stem
  let discovered = $file | discover_tests
  let matches_filter = {|test| $"($module) ($test)" =~ $filter }
  let tests = $discovered.exported | where $matches_filter
  let skipped = $discovered.skipped | where $matches_filter
  if ($tests | is-empty) {
    return {module: $module results: [] skipped: $skipped log: ""}
  }
  let output = (
    do {
      cd ($tests_directory | path dirname)
      # Pass empty input so that a test can't wait on the runner's stdin
      "" | ^$nu.current-exe --no-config-file --commands (build_test_script $file $module $tests) | complete
    }
  )
  let results = (
    $output.stdout
    | lines
    | where {|line| $line starts-with $result_marker }
    | each {|line| $line | str substring ($result_marker | str length).. | from json | update duration { into duration } }
  )
  # Tests that didn't report a result, such as when the module fails to parse or the process crashes
  let reported = $results | get --optional test | default []
  let unreported = (
    $tests
    | where {|test| $test not-in $reported }
    | each {|test|
      {
        test: $test
        status: failed
        error: $"The test process exited with code ($output.exit_code) before reporting a result.\n($output.stderr | lines | last 20 | str join "\n")"
        duration: 0sec
      }
    }
  )
  {
    module: $module
    results: ($results | append $unreported)
    skipped: $skipped
    log: $output.stderr
  }
}

# Round a duration down to milliseconds for display
def round_duration []: duration -> duration {
  $in - ($in mod 1ms)
}

# Run the tests for media-juggler-lib
def main [
  filter: string = "" # Only run the tests whose "<module> <test>" name matches this regular expression
  --verbose # Print the log output of each test module
] {
  let start = date now
  let modules = (
    glob ($tests_directory | path join "*.nu")
    | sort
    | par-each --keep-order {|file| $file | run_test_module $filter }
  )
  let results = (
    $modules
    | each {|module| $module.results | insert module $module.module }
    | flatten
  )
  let failed = $results | where status == failed
  let passed = $results | where status == passed
  let skipped = $modules | each {|module| $module.skipped | each {|test| $"($module.module) ($test)" } } | flatten

  if $verbose {
    for module in ($modules | where log != "") {
      print $"(ansi cyan)Log output for ($module.module):(ansi reset)"
      print $module.log
    }
  }
  for failure in $failed {
    print $"(ansi red)FAILED(ansi reset) ($failure.module) ($failure.test)"
    print $failure.error
  }
  if ($skipped | is-not-empty) {
    print $"(ansi yellow)Skipped(ansi reset) tests that aren't exported:"
    for test in $skipped {
      print $"  ($test)"
    }
  }
  let slowest = $results | sort-by duration --reverse | first 5
  if ($slowest | is-not-empty) {
    print "Slowest tests:"
    for result in $slowest {
      print $"  ($result.duration | round_duration) ($result.module) ($result.test)"
    }
  }

  let summary = $"($passed | length) passed, ($failed | length) failed, ($skipped | length) skipped in ((date now) - $start | round_duration)"
  if ($results | is-empty) {
    print $"(ansi red)No tests matched the filter '($filter)'(ansi reset)"
    exit 1
  }
  if ($failed | is-not-empty) {
    print $"(ansi red)($summary)(ansi reset)"
    exit 1
  }
  print $"(ansi green)($summary)(ansi reset)"
}
