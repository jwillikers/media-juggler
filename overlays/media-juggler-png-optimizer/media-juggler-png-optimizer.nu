#!/usr/bin/env nu

use std log

# Get a hash of an image file's image data with ImageMagick
export def image_data_hash []: [
  path -> string
] {
  let image = $in
  let result = do {^magick identify -quiet -format "%#" $image} | complete
  if $result.exit_code != 0 {
    log info $"Error running '^magick identify -quiet -format '%#' ($image)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  $result.stdout | str trim
}

# Compare two images with odiff
export def same_image [
  image2: path
]: path -> bool {
  let image1 = $in
  let result = do {^odiff --threshold 0.0 $image1 $image2} | complete
  if $result.exit_code not-in [0, 21, 22] {
    log info $"Error running '^odiff --threshold 0.0 \"($image1)\" \"($image2)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  $result.exit_code == 0
}

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

  let extension = $source | path parse | get extension
  let original_source = mktemp --suffix ("." + $extension) --tmpdir-path .
  cp $source $original_source

  # let original_image_checksum = (
  #   if not ($force_gray_scale) {
  #     $source | image_data_hash
  #   }
  # )

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
    # todo --zopfli?
    # --zopfli takes way longer but does optimize slightly more
    ^oxipng --opt max --out $destination --quiet --strip safe -- $source
  } | complete
  if $result.exit_code != 0 {
    log error $"Error running '^oxipng --opt max --out \"($destination)\" --quiet --strip safe -- \"($source)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    rm --force $original_source
    exit 1
  }
  if not ($force_gray_scale) and ($destination | path exists) and not ($original_source | same_image $destination) {
    log warning "oxipng produced an image with different image data. Rerunning without modifying colortype."
    # Changes to the colortype may cause it to render differently, so redo without the colortype change.
    let result = do {
      ^oxipng --nc --opt max --out $destination --quiet --strip safe -- $source
    } | complete
    if $result.exit_code != 0 {
      log error $"Error running '^oxipng --nc --opt max --out \"($destination)\" --quiet --strip safe -- \"($source)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      rm --force $original_source
      exit 1
    }
    if ($destination | path exists) and not ($original_source | same_image $destination) {
      log error "oxipng produced an image with different image data even without modifying colortype! Skipping oxipng optimizations."
      cp $source $destination
    }
  }

  # oxipng doesn't write out the output file when the output image is larger than the source.
  if not ($destination | path exists) {
    cp $source $destination
  }

  let extension = $source | path parse | get extension
  let temp_destination = mktemp --suffix ("." + $extension) --tmpdir-path .
  cp $destination $temp_destination

  let result = do {
    ^ect -9 -strip --mt-deflate $temp_destination
  } | complete
  if $result.exit_code != 0 {
    log error $"Error running '^ect -9 -strip --mt-deflate \"($temp_destination)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    rm --force $original_source $temp_destination
    exit 1
  }
  if not ($force_gray_scale) and not ($original_source | same_image $destination) {
    log warning "ect produced an image with different image data. Rerunning with the --reuse flag."
    # Changes to the colortype cause it to render differently, so redo without the colortype change.
    cp --force $destination $temp_destination
    let result = do {
      ^ect -9 -strip --mt-deflate --reuse $temp_destination
    } | complete
    if $result.exit_code != 0 {
      log error $"Error running '^ect -9 -strip --mt-deflate --reuse \"($temp_destination)\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      rm --force $original_source $temp_destination
      exit 1
    }
    if not ($original_source | same_image $destination) {
      log error "ect produced an image with different image data even with the --reuse flag. Ignoring"
      cp --force $destination $temp_destination
    }
  }
  rm --force $original_source
  mv --force $temp_destination $destination
}
