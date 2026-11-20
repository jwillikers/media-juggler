#!/usr/bin/env nu

# Run the tests for media-juggler-lib
#
# The tests are split into modules under media-juggler-lib-tests, matching the modules of media-juggler-lib.

use media-juggler-lib-tests/utils.nu
use media-juggler-lib-tests/ssh.nu
use media-juggler-lib-tests/audio.nu
use media-juggler-lib-tests/identifiers.nu
use media-juggler-lib-tests/metadata.nu
use media-juggler-lib-tests/comics.nu
use media-juggler-lib-tests/ebooks.nu
use media-juggler-lib-tests/hardcover.nu
use media-juggler-lib-tests/wikidata.nu
use media-juggler-lib-tests/chapters.nu
use media-juggler-lib-tests/tone.nu
use media-juggler-lib-tests/musicbrainz.nu
use media-juggler-lib-tests/acoustid.nu
use media-juggler-lib-tests/audiobooks.nu

def main [] {
  utils run_tests
  ssh run_tests
  audio run_tests
  identifiers run_tests
  metadata run_tests
  comics run_tests
  ebooks run_tests
  hardcover run_tests
  wikidata run_tests
  chapters run_tests
  tone run_tests
  musicbrainz run_tests
  acoustid run_tests
  audiobooks run_tests
  echo $"(ansi green)All tests passed!(ansi reset)"
}
