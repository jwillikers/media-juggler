# General-purpose utility functions for strings, records, file names, hashing, and retrying requests

use std log

use constants.nu *

# Surround special characters in a string with square brackets
#
# Use this on strings before adding glob characters.
# Note that I can't actually escape backslashes, so those will cause the glob expression to fail outright.
# Maybe this will be fixed in Nushell at some point?
# Seems like double backslash works.
export def escape_special_glob_characters []: string -> string {
  let input = $in
  if ($input | describe) not-in ["glob" "string"] {
    return $input
  }
  const special_glob_characters = ['[' ']' '(' ')' '{' '}' '*' '?' ':' '$' ',']
  $special_glob_characters | reduce --fold $input {|character, acc|
    if $character in ["[" "]"] {
      $acc | str replace --all $character ('\' + $character)
    } else {
      $acc | str replace --all $character ('[' + $character + ']')
    }
  }
}

# Replace forward slashes and reserved file names with Unicode characters for use as file names
#
# Thank you Unicode.
export def sanitize_file_name []: string -> string {
  let name = $in
  if $name == "." {
    '․'
  } else if $name == ".." {
    "‥"
  } else {
    # Replace forward slash, a.k.a. solidus, with big solidus
    $name | str replace --all '/' '⧸'
  }
}

export def use_unicode_in_title []: string -> string {
  let title = $in
  # We don't want to replace the "-" before the volume part with an emdash or endash.
  let components = $title | split row --number 2 " - Volume "
  let title = (
    if ($components | length) > 1 {
      $components | update 0 (
        $components
        | first
        | str replace --all "'" "’"
        | str replace --all "-" "‐"
        | str replace --all "..." "…"
        | str replace --all "1/2" "½"
        | str replace --all "1⧸2" "½"
      ) | str join " - Volume "
    } else {
      (
        $title
        | str replace --all "'" "’"
        | str replace --all "-" "‐"
        | str replace --all "..." "…"
        | str replace --all "1/2" "½"
        | str replace --all "1⧸2" "½"
      )
    }
  )
  mut new_title = $title
  while '"' in $new_title {
    $new_title = $new_title | str replace '"' '“' | str replace '"' '”'
  }
  $new_title
}

# Make the title look nice when named for a volume, i.e. use a comma before the volume word when there isn't any other punctuation.
#
# This basically ends up following the MusicBrainz style guidelines.
export def standardize_title []: string -> string {
  let title = $in
  # We don't want to replace the "-" before the volume part with an emdash or endash.
  let components = $title | split row --number 2 " - Volume "
  if ($components | length) > 1 {
    # If the title of the series ends with punctuation, don't add a comma.
    if ($components | first | split chars | last) in ["!", "?", ".", ","] {
      $components | str join " Volume "
    } else {
      $components | str join ", Volume "
    }
  } else {
    $title
  }
}

# Calculate the SHA3-512 checksum for a file using rhash.
export def hash_sha3_512 []: [string -> string] {
  # File for which to generate the checksum.
  let file = $in
  if ($file | is-empty) {
    error make {
      msg: "no file provided"
      labels: [
        {text: "in" span: (metadata $in).span}
      ]
      help: "pipe in the path of the file to hash"
    }
  }
  log debug $"Running command: (ansi yellow)^rhash --printf '%x{sha3-512}' '($file)'(ansi reset)"
  let result = do { ^rhash --printf '%x{sha3-512}' $file } | complete
  if ($result.exit_code != 0) {
    error make {
      msg: "non-zero exit code from rhash while calculating SHA3-512 checksum"
      labels: [
        {text: "result.exit_code" span: (metadata $result.exit_code).span}
      ]
      help: $"error calculating the SHA3-512 checksum for the file (ansi yellow)($file)(ansi reset): ($result.stderr)"
    }
  }
  if ($result.stdout | is-empty) {
    error make {
      msg: "missing SHA3-512 checksum in stdout"
      labels: [
        {text: "result.stdout" span: (metadata $result.stdout).span}
      ]
      help: $"no SHA3-512 checksum output by rhash for the file (ansi yellow)($file)(ansi reset): ($result.stderr)"
    }
  }
  $result.stdout | str trim
}

# Calculate the BLAKE3 checksum for a file using the b3sum utility.
export def hash_blake3 []: [string -> string] {
  # File for which to generate the checksum.
  let file = $in
  if ($file | is-empty) {
    error make {
      msg: "no file provided"
      labels: [
        {text: "in" span: (metadata $in).span}
      ]
      help: "pipe in the path of the file to hash"
    }
  }
  log debug $"Running command: (ansi yellow)^b3sum --no-names '($file)'(ansi reset)"
  let result = do { ^b3sum --no-names $file } | complete
  if ($result.exit_code != 0) {
    error make {
      msg: "non-zero exit code from b3sum while calculating the BLAKE3 checksum"
      labels: [
        {text: "result.exit_code" span: (metadata $result.exit_code).span}
      ]
      help: $"error calculating the BLAKE3 checksum for the file (ansi yellow)($file)(ansi reset): ($result.stderr)"
    }
  }
  if ($result.stdout | is-empty) {
    error make {
      msg: "missing BLAKE3 checksum in stdout"
      labels: [
        {text: "result.stdout" span: (metadata $result.stdout).span}
      ]
      help: $"no BLAKE3 checksum output by b3sum for the file (ansi yellow)($file)(ansi reset): ($result.stderr)"
    }
  }
  $result.stdout | str trim
}

# Apparently no sanitization needs to be done?
export def sanitize_minio_filename []: string -> string {
    # $in | str replace --all "!" ""
    $in
}

# Upsert a value in the input record if a value is present for the given column in the source record
#
# The source column may be omitted when it has the same name as the destination column.
export def upsert_if_present [
  destination_column: string
  source: record
  source_column: string = ""
]: record -> record {
  let source_column = (
    if $source_column == null or ($source_column | is-empty) {
      $destination_column
    } else {
      $source_column
    }
  )
  $in | (
    let input = $in;
    if $source_column in $source and (($source | get $source_column) != null) {
      $input | upsert $destination_column ($source | get $source_column)
    } else {
      $input
    }
  )
}

# Upsert a value in the input record if the value is not null or empty
export def upsert_if_value [
  destination_column: string
  value: any
]: record -> record {
  $in | (
    let input = $in;
    if ($value | is-empty) {
      $input
    } else {
      $input | upsert $destination_column $value
    }
  )
}

# A Nushell merge that accepts empty inputs.
#
# If an input is empty, the remaining input is returned.
# If both inputs are empty, null is returned.
export def merge_or_input [
  b: any
]: any -> any {
  let a = $in
  if ($a | is-not-empty) and ($b | is-not-empty) {
    $a | merge $b
  } else if ($a | is-not-empty) {
    $a
  } else if ($b | is-not-empty) {
    $b
  }
}

# Parse multi-value tags
export def parse_multi_value_tag [
  separator: string = ";"
]: any -> list {
  let input = $in
  if ($input | is-empty) {
    return null
  }
  $in | split row ";" | str trim
}

export def join_multi_value []: any -> string {
  let input = $in
  if ($input | is-empty) {
    return null
  }
  $input | str join ";"
}

# Attempt to download a file, retrying up to the given number of retries
#
# Sometimes, there is a "Connection reset" exception when attempting to download a file.
# This function just retries when this happens.
# See the Nushell bug here: https://github.com/nushell/nushell/issues/17231
export def retry_download [
  download_request: closure # The function to call
  destination: path # The path to save the downloaded file to
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
]: [
  nothing -> path
] {
  for attempt in 1..($retries - 1) {
    try {
      do $download_request | save --force $destination
    } catch {|error|
      log warning $"Error downloading file to ($destination): ($error.debug)"
      sleep $delay
      continue
    }
    return $destination
  }
  try {
    do $download_request | save --force $destination
  } catch {|error|
    log warning $"Error downloading file to ($destination): ($error.debug)"
    return null
  }
  $destination
}

# Download a file given a URL
export def download_file [
  download_directory: directory
  --retries: int = 3
  --retry-delay: duration = 3sec
]: string -> path {
  let url = $in
  let request = {
    http get --full --headers [User-Agent $user_agent] $"($url)"
  }
  let response = retry_http $request $retries $retry_delay
  let filename = $url | url parse | get path | path basename
  let destination = $download_directory | path join $filename
  # If the path exists, skip the download.
  if ($destination | path exists) {
    return $destination
  }
  let download_request = {
    http get --headers [User-Agent $user_agent] $url
  }
  let destination = retry_download $download_request $destination $retries $retry_delay
  if ($destination | is-empty) {
    log error $"Error downloading file from ($url) to ($destination)"
    return null
  }
  $destination
}

# Call a function, retrying up to the given number of retries
export def retry [
  request: closure # The function to call
  should_retry: closure # A closure which determines whether to retry or not based on the result of the request closure. True means retry, false means stop.
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
  ignore_exceptions: bool # Whether to ignore exceptions thrown by the request closure and retry
]: nothing -> any {
  # Note that ranges in Nushell count downwards when the end is less than the start, i.e. 1..0 is [1, 0].
  mut attempt = 1
  while $attempt < $retries {
    let current_attempt = $attempt
    let result = (
      try {
        {response: (do $request)}
      } catch {|error|
        if $ignore_exceptions {
          log warning $"Error during request attempt ($current_attempt): ($error.debug)"
          null
        } else {
          throw $error
        }
      }
    )
    if ($result != null) and not (do $should_retry $result.response) {
      return $result.response
    }
    # Always wait before retrying, including after an exception, to avoid hammering rate-limited servers
    sleep $delay
    $attempt += 1
  }
  do $request
}

# Make an http call, retrying up to the given number of retries
export def retry_http [
  request: closure # The function to call
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
  http_status_codes_to_retry: list<int> = [408 429 500 502 503 504] # HTTP status codes where the request will be retries
  ignore_exceptions: bool = true # Whether to ignore exceptions thrown by the request closure and retry
]: nothing -> any {
  let should_retry = {|result|
    $result.status in $http_status_codes_to_retry
  }
  retry $request $should_retry $retries $delay $ignore_exceptions
}
