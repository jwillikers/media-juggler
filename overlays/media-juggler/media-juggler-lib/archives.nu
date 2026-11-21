# Functions for working with zip archives

use std log

use constants.nu *

# Escape special characters like the opening bracket for the unzip command.
#
# The special characters are the opening bracket, question mark, and asterisk.
export def escape_unzip_path []: path -> path {
  $in | str replace --all '[' '[[]' | str replace --all '?' '[?]' | str replace --all '*' '[*]'
}

# Extract files from a zip archive
export def unzip [
  destination: directory
]: path -> list<path> {
  let archive = $in
  let files = $archive | list_files_in_archive
  ^unzip -q $archive -d $destination
  $files | par-each {|file|
    [($destination | path expand) $file] | path join
  }
}

# Extract a file from a zip archive
export def extract_file_from_archive [
  file: path
  working_directory: directory # The scratch-space directory to use
]: path -> path {
  let archive = $in
  log debug $"Running ^unzip -o ($archive) ($file | escape_unzip_path) -d ($working_directory)"
  let result = do {^unzip -o $archive ($file | escape_unzip_path) -d $working_directory} | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^unzip -o \"($archive)\" \"($file | escape_unzip_path)\" -d \"($working_directory)\"(ansi reset)\n($result.stderr)\n"
    return null
  }
  [$working_directory $file] | path join
}

# Add or update a file in a zip archive
export def add_file_to_archive [
  file: path # The file to add or update in the archive.
]: path -> path {
  let archive = $in
  log debug $"Running ^zip ($archive) ($file)"
  let result = do {^zip $archive $file} | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^zip \"($archive)\" \"($file)\"(ansi reset)\n($result.stderr)\n"
    return null
  }
  $archive
}

# List the files in a zip archive
export def list_files_in_archive []: path -> list<path> {
  let archive = $in
  # List only the file names, one per line, to avoid parsing the header and footer of the full listing
  (
    ^unzip -Z1 $archive
    | lines
    | uniq
    | sort
  )
}

# List the image files in a zip archive
export def list_files_in_archive_with_extensions [
  extensions: list<string>
]: path -> list<path> {
  let archive = $in
  (
    $archive
    | list_files_in_archive
    | path parse
    | where extension in $extensions
    | path join
  )
}

# Count the number of image files in a ZIP archive
export def number_of_images_in_archive []: [path -> int] {
  let archive = $in
  $archive | list_files_in_archive_with_extensions $image_extensions | length
}
