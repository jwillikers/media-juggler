# Functions for working with files on remote hosts over SSH

use std log

# Get the type of a path via SSH
export def "ssh_path_type" []: path -> string {
  let input = $in
  let ssh_path = $in | split_ssh_path
  ^ssh $ssh_path.server nu --commands $"\'\"($ssh_path.path)\" | path type | to json\'" | from json
}

# Delete a file over SSH
export def "ssh rm" []: path -> nothing {
  let target = $in | split_ssh_path
  ^ssh $target.server nu --commands $"\'rm \"($target.path)\"\'"
  # Prune empty directories
  let parent_directory = $target.path | path dirname
  ^ssh $target.server nu --commands $"\'^rmdir --ignore-fail-on-non-empty --parents \"($parent_directory)\"\'"
}

# Determine if a path is meant for SSH, i.e. it starts with "server:"
export def is_ssh_path []: path -> bool {
  let input = $in
  if ($input | is-empty) {
    return false
  }
  let components = $input | path split
  let first_component = (
    $components | first | str trim --left --char ":"
  )
  (
    ($first_component | str contains ":")
    and ($components | split row ":" | where {|component| $component | is-not-empty} | append ($components | skip 1) | length) > 1
  )
}

# Split an SSH path into the server and path elements
export def split_ssh_path []: path -> record<server: string, path: path> {
  let input = $in
  if ($input | is-empty) {
    return null
  }
  if not ($input | is_ssh_path) {
    return {
      server: null
      path: $input
    }
  }
  let split = $input | path split
  let server = (
    $split | first | split row ':' | first
  )
  if ($server | is-empty) {
    return null
  }
  let path = $input | str replace ($server + ":") ""
  if ($path | is-empty) {
    return null
  }
  {
    server: $server
    path: $path
  }
}

# Copy files over SSH using the scp program
export def "scp" [
  destination: path # The destination on the server to which to copy the file
  ...args: string # Arguments to pass to the scp program
  --mkdir # Create the destination directory and any parent directories on the server
  # --mkdir-permissions # Set the permissions
  # --mkdir-group
  # --file-group
  # --file-permissions
]: path -> path {
  let source = $in
  let source_path_type = (
    if ($source | is_ssh_path) {
      $source | ssh_path_type
    } else {
      $source | path type
    }
  )
  if $mkdir {
    let ssh_path = $destination | path dirname | split_ssh_path
    ^ssh $ssh_path.server nu --commands $"\'mkdir \"($ssh_path.path)\"\'"
  }
  if $source_path_type == "dir" {
    ^scp --recursive ...$args $source $destination
  } else {
    ^scp ...$args $source $destination
  }
  [$destination ($source | path basename)] | path join
}

# Copy files via rsync
#
# The server must have rsync installed for this to work.
export def "rsync" [
  destination: path
  ...args: string
]: path -> path {
  let source = $in
  let source_path_type = (
    if ($source | is_ssh_path) {
      $source | ssh_path_type
    } else {
      $source | path type
    }
  )
  # let ssh_path = $destination | path dirname | split_ssh_path
  # ^ssh $ssh_path.server nu --commands $"\'mkdir \"($ssh_path.path)\"\'"
  # ^ssh $ssh_path.server nu --commands $"\'chmod 2770 \"($ssh_path.path)\"\'"
  let result = do {
    if $source_path_type == "dir" {
      ^rsync --no-perms --no-owner --no-group --omit-dir-times --recursive ...$args $source $destination
    } else {
      ^rsync --no-perms --no-owner --no-group --omit-dir-times ...$args $source $destination
    }
  } | complete
  if $result.exit_code == 23 {
    log warning $"rsync exited with code (ansi purple)23(ansi reset) which usually indicates that some file attributes may not have been transferred. Assuming the file was transferred successfully.\nstdout: ($result.stdout)\nstderr: ($result.stderr)"
  } else if $result.exit_code != 0 {
    log error $"rsync failed with exit code (ansi purple)($result.exit_code)(ansi reset).\nstdout: ($result.stdout)\nstderr: ($result.stderr)"
    return null
  }
  [$destination ($source | path basename)] | path join
}

# Glob files over SSH
export def "ssh glob" [
  ...glob_args: string
]: path -> table {
  let input = $in
  let ssh_path = $input | split_ssh_path
  let result = ^ssh $ssh_path.server nu --commands $"\'glob ($glob_args | str join ' ') \"($ssh_path.path | str replace --all '\' '\\\\')\" | to json\'" | from json
  # log debug $"ssh glob result: ($result)"
  $result
}

# List files over SSH
export def "ssh ls" [
  ...args: string
  --expand-path
]: path -> table {
  let input = $in
  let ssh_path = $input | split_ssh_path
  let path = $ssh_path.path
  if $expand_path {
    ^ssh $ssh_path.server nu --commands $"\'ls ($args | str join ' ') \"($path | path expand)\" | to json\'" | from json
  } else {
    ^ssh $ssh_path.server nu --commands $"\'ls ($args | str join ' ') \"($path)\" | to json\'" | from json
  }
}

# Check if a path exists over SSH
export def "ssh_path_exists" []: path -> bool {
  let input = $in
  let ssh_path = $input | split_ssh_path
  # log debug $"ssh_path: (ansi yellow)($ssh_path)(ansi reset)"
  let path = $ssh_path.path
  let exit_code = do {^ssh $ssh_path.server nu --commands $"\'stat \"($path)\"\'"} | complete | get exit_code
  ($exit_code == 0)
}
