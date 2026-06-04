#!/usr/bin/env nu

use std log

# This is a wrapper program meant to be called by pdfsizeopt for optimizing images, specifically PNGs.
#
# It wraps a couple of other utilities, namely oxipng, ect, and pngcrush, and allows forcing images to gray scale.
# Since pdfsizeopt can take a really long time to run due to optimizing PNGs, only oxipng and ect are used for compression.
# The pngcrush utility is only used to force images to gray scale.
def main [
  source: path # The input image.
  --destination: path # The destination of the optimized image file.
  --force-gray-scale # Force the image to be gray scale.
] {
  if ($source | is-empty) {
    log error "No source file provided"
    exit 1
  }

  let destination = (
    if ($destination | is-empty) {
      $source
    } else {
      $destination
    }
  )

  # Use pngcrush to force images to gray scale.
  let source = (
    if ($force_gray_scale) {
      let result = do {
        if $source == $destination {
          ^pngcrush -c 0 -force -l 0 -m 1 -noreduce -ow -q -speed $source
        } else {
          ^pngcrush -c 0 -force -l 0 -m 1 -noreduce -q -speed $source $destination
        }
      } | complete
      if $result.exit_code != 0 {
        if $source == $destination {
          log error $"Error running '^pngcrush -c 0 -force -l 0 -m 1 -noreduce -ow -q -speed \"($source)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
        } else {
          log error $"Error running '^pngcrush -c 0 -force -l 0 -m 1 -noreduce -q -speed \"($source)\" \"($destination)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
        }
        exit 1
      }
      if $source == $destination {
        $source
      } else {
        $destination
      }
    } else {
      $source
    }
  )

  let result = do {
    ^oxipng --interlace 0 --quiet --strip all -o max --out $destination -- $source
  } | complete
  if $result.exit_code != 0 {
    log error $"Error running '^oxipng --interlace 0 --quiet --strip all -o max --out \"($destination)\" -- \"($source)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    exit 1
  }

  let result = do {
    ^ect -9 -strip --mt-deflate $destination
  } | complete
  if $result.exit_code != 0 {
    log error $"Error running '^ect -9 -strip --mt-deflate \"($destination)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    exit 1
  }
}
