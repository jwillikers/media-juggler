# Tests for the ssh functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

export def test_is_ssh_path_simple_ssh_path [] {
  let input = "meerkat:/var/home/media"
  assert ($input | is_ssh_path)
}

export def test_is_ssh_path_simple_local_path [] {
  let input = "/var/home/media"
  assert not ($input | is_ssh_path)
}

export def test_is_ssh_path_server_no_path [] {
  let input = "meerkat:"
  assert not ($input | is_ssh_path)
}

export def test_is_ssh_path_server_root_path_depth_one [] {
  let input = "meerkat:/var"
  assert ($input | is_ssh_path)
}

export def test_is_ssh_path_server_relative_path_depth_one [] {
  let input = "meerkat:dir"
  assert ($input | is_ssh_path)
}

export def test_is_ssh_path_server_relative_path_depth_two [] {
  let input = "meerkat:one/two"
  assert ($input | is_ssh_path)
}

export def test_is_ssh_path_local_absolute_path_with_colon [] {
  let input = "/var/o:ne/two"
  assert not ($input | is_ssh_path)
}

export def test_is_ssh_path_local_relative_path_with_colon [] {
  let input = "one/t:wo"
  assert not ($input | is_ssh_path)
}

export def test_is_ssh_path_relative_path_starts_with_colon [] {
  let input = ":one/two"
  assert not ($input | is_ssh_path)
}

export def test_is_ssh_path_absolute_path_starts_with_colon [] {
  let input = ":/one/two"
  assert not ($input | is_ssh_path)
}

export def test_split_ssh_path_simple_ssh_path [] {
  let input = "meerkat:/var/home/media"
  let expected = {
    server: "meerkat"
    path: "/var/home/media"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_simple_local_path [] {
  let input = "/var/home/media"
  let expected = {
    server: null
    path: "/var/home/media"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_server_no_path [] {
  let input = "meerkat:"
  let expected = {
    server: null
    path: "meerkat:"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_server_root_path_depth_one [] {
  let input = "meerkat:/var"
  let expected = {
    server: "meerkat"
    path: "/var"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_server_relative_path_depth_one [] {
  let input = "meerkat:dir"
  let expected = {
    server: "meerkat"
    path: "dir"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_server_relative_path_depth_two [] {
  let input = "meerkat:one/two"
  let expected = {
    server: "meerkat"
    path: "one/two"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_local_absolute_path_with_colon [] {
  let input = "/var/o:ne/two"
  let expected = {
    server: null
    path: "/var/o:ne/two"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_local_relative_path_with_colon [] {
  let input = "one/t:wo"
  let expected = {
    server: null
    path: "one/t:wo"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_relative_path_starts_with_colon [] {
  let input = ":one/two"
  let expected = {
    server: null
    path: ":one/two"
  }
  assert equal ($input | split_ssh_path) $expected
}

export def test_split_ssh_path_absolute_path_starts_with_colon [] {
  let input = ":/one/two"
  let expected = {
    server: null
    path: ":/one/two"
  }
  assert equal ($input | split_ssh_path) $expected
}
