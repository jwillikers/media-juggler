# Functions for inspecting and comparing images

use std log

use archives.nu *
use constants.nu *

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

# Compare the perceptive difference of two images with ImageMagick's phash metric
#
# ImageMagick's phash metric works regardless of differences in image resolution.
export def compare_image_phash [
  image2: path
]: [
  path -> record<pixels_different: float, difference: float>
] {
  # ImagickMagick is normalizing the PHASH, causing images to appear the similar when they are actually quite different.
  # https://github.com/ImageMagick/ImageMagick/issues/8759
  # todo Switch to perceptualdiff CLI?
  let image1 = $in
  let result = do {^magick compare -metric PHASH $image1 $image2 "null:"} | complete
  # magick compare uses an exit code of 1 to indicate two images aren't the same.
  if $result.exit_code not-in [0, 1] {
    log error $"Error running '^magick compare -metric PHASH ($image1) ($image2) \"null:\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  # log debug $"Finished running '^magick compare -metric PHASH ($image1) ($image2) \"null:\"'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
  # log debug $"stderr: '($result.stderr)'"
  let diff = $result.stderr | str trim | parse --regex '^(?P<pixels_different>[0-9.]+) \((?P<difference>[0-9.]+)\).*$' | first
  # log debug $"diff: ($diff)"
  {
    pixels_different: ($diff.pixels_different | into float)
    difference: ($diff.difference | into float)
  }
}

# Compare two images with odiff
export def odiff_same_image [
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

# Determines whether two image files are the same image.
export def same_image [
  image2: path
]: [
  path -> bool
] {
  let image1 = $in
  if not (($image1 | path exists) and ($image2 | path exists)) {
    return null
  }
  if $image1 == $image2 {
    return true
  }
  let checksum1 = open --raw $image1 | hash sha256
  let checksum2 = open --raw $image2 | hash sha256
  if $checksum1 == $checksum2 {
    return true
  }
  # Compare raw image data.
  # This works regardless of the amount of lossless optimization of the image.
  if ($image1 | odiff_same_image $image2) {
    return true
  }
  # This will probably need dialed in over time.
  let phash_difference = $image1 | compare_image_phash $image2
  if $phash_difference == null {
    log error $"Error calculating phash difference for images (ansi yellow)($image1)(ansi reset) and (ansi yellow)($image2)(ansi reset)"
    return null
  }

  # ImagickMagick is normalizing the PHASH, causing images to appear the similar when they are actually quite different.
  # https://github.com/ImageMagick/ImageMagick/issues/8759
  # Note: The phash difference increased dramatically and may no longer have this issue.
  # todo Switch to perceptualdiff CLI?
  # todo Or if they are the same dimensions use NCC?
  # When things were working, 1.0 worked well here.

  # log warning "Skipping phash comparison due to normalization causing false positives."

  ## In case of a false positive duplicate cover detection, temporarily comment the section below
  ## Comment below
  if $phash_difference.difference < 1.0 {
    log debug $"Considering images (ansi yellow)($image1)(ansi reset) and (ansi yellow)($image2)(ansi reset) as the same since their phash difference (ansi purple)($phash_difference.difference)(ansi reset) is less than (ansi purple)1.0(ansi reset)"
    # todo This bug might be fixed now. Verify.
    log error "Aborting due to bug in phash. Remove similar cover manually or disable this check to avoid deleting incorrectly deleting a page."
    exit
    return true
  }
  if $phash_difference.difference < 5.0 {
    log debug $"Images (ansi yellow)($image1)(ansi reset) and (ansi yellow)($image2)(ansi reset) are very similar since their phash difference (ansi purple)($phash_difference.difference)(ansi reset) is between (ansi purple)1.0(ansi reset) and (ansi purple)5.0(ansi reset). Assuming they are not similar. Please review them to be sure, and consider adjusting the threshold accordingly."
    return false
  }
  log debug $"Images (ansi yellow)($image1)(ansi reset) and (ansi yellow)($image2)(ansi reset) are dissimilar since their phash difference (ansi purple)($phash_difference.difference)(ansi reset) is greater than (ansi purple)5.0(ansi reset)"
  ## Comment above
  false
}

# Remove duplicate image files at the front of a list image files.
#
# This function prefers covers that in the PNG format over JPEG/WEBP
#
# Comparing the cover and cover without text bundled in a CBZ yielded a phash difference (the value in parentheses) of 34.9865.
# Comparing a cover with slightly different text, i.e. "Vol. 1-2" instead of "Vol. 1" yielded a difference of 3.32233.
# Comparing a high resolution cover to a standard resolution cover from Apple Books yielded a difference of 0.457609.
export def remove_duplicate_covers []: [
  list<path> -> list<path>
] {
  let images = $in
  if ($images | length) <= 1 {
    return $images
  }
  if not ($images.0 | same_image $images.1) {
    return $images
  }
  # todo Prefer PNG over JPEG?
  # Prefer PNG over JPEG/WEBP and then prefer whichever image has the larger file size.
  let lossy = ["avif" "jpeg" "webp"]
  # todo Detect if the jxl encoding is lossless or lossy
  let lossless = ["jpeg" "jxl" "svg"]
  let image = (
    if ($images.0 | path parse | get extension | str downcase) in $lossless and ($images.1 | path parse | get extension | str downcase) in $lossy {
      $images.0
    } else if ($images.0 | path parse | get extension | str downcase) in $lossy and ($images.1 | path parse | get extension | str downcase) in $lossless {
      $images.1
    } else {
      if (du $images.0 | get physical | first) >= (du $images.1 | get physical | first) {
        $images.0
      } else {
        $images.1
      }
    }
  )
  $images | slice 2.. | prepend $image | remove_duplicate_covers
}

# Get the image extension used in a comic book archive
export def get_image_extension []: path -> string {
  let cbz = $in
  let file_extensions = (
    $cbz
    | list_files_in_archive_with_extensions $image_extensions
    | path parse
    | get extension
    | where {|extension| not ($extension | is-empty) }
    | uniq
  )
  let file_extensions = (
    if (($file_extensions | length) == 2 and "jpg" in $file_extensions and "jpeg" in $file_extensions) {
      ["jpeg"]
    } else {
      $file_extensions
    }
  )
  if ($file_extensions | is-empty) {
    log error "No file extensions found"
    null
  } else if (($file_extensions | length) > 1 or ($file_extensions | length) == 0) {
    log error $"Multiple file extensions found: ($file_extensions)"
    null
  } else {
    $file_extensions | first
  }
}

# Get an image's dimensions with ImageMagick
export def get_image_dimensions []: path -> record<width: int, height: int> {
  let image_file = $in
  let result = do { ^magick identify -format "%wx%h" $image_file } | complete
  if $result.exit_code != 0 {
    log error $"The command (ansi yellow)^magick identify -format '%wx%h' '($image_file)'(ansi reset) failed with the exit code (ansi red)($result.exit_code)(ansi reset): ($result.stderr)"
    return null
  }
  $result.stdout | parse '{width}x{height}' | first
}

# Get the dimensions of multiple images with ImageMagick
export def get_images_dimensions []: list<path> -> table<width: int, height: int> {
  let image_files = $in
  let result = do { ^magick identify -format '%wx%h\n' $image_files } | complete
  if $result.exit_code != 0 {
    log error $"The command (ansi yellow)^magick identify -format '%wx%h\\n' ($image_files | str join ' ')(ansi reset) failed with the exit code (ansi red)($result.exit_code)(ansi reset): ($result.stderr)"
    return null
  }
  $result.stdout | parse '{width}x{height}'
}

# Get the image dimensions used by the majority of the images in a ZIP archive
export def get_zip_image_dimensions []: path -> string {
  let archive = $in
  (
    $archive
    | list_files_in_archive_with_extensions $image_extensions
    | get_images_dimensions
    | uniq --count
    | sort-by --reverse count
    | first
  )
}

# Rename an image with the proper extension for its file type
export def rename_image_with_extension [] : path -> path {
  let old = $in
  if not ($old | path exists) {
    return null
  }
  let components = $old | path parse
  let file_type = ^file --brief $old | split words | first | str downcase
  let new = $old | path parse | update extension $file_type | path join
  try {
    mv $old $new
  } catch {|error|
    log info $"Ignoring error moving file from ($old) to ($new): ($error)"
    return null
  }
  $new
}
