# Functions for losslessly optimizing the size of images, archives, PDFs, and EPUBs

use std log

use constants.nu *
use images.nu *
use utils.nu *

# Optimize image using efficient-compression-tool
export def optimize_image_ect []: path -> path {
  let path = $in
  log debug $"Running command: (ansi yellow)^ect -9 -strip --mt-deflate ($path)(ansi reset)"
  let result = do {
    ^ect -9 -strip --mt-deflate $path
  } | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^ect -9 -strip --mt-deflate ($path)(ansi reset)\n($result.stderr)\n"
    return $path
  }
  $path
}

# Optimize images using efficient-compression-tool
export def optimize_images_ect []: list<path> -> record<bytes: filesize, difference: float> {
  let paths = $in
  # Ignore config paths to ensure that lossy compression is not enabled.
  log debug $"Running command: (ansi yellow)^ect -9 -recurse -strip --mt-deflate ($paths | str join ' ')(ansi reset)"
  let result = do {
    ^ect -9 -recurse -strip --mt-deflate ...$paths
  } | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^ect -9 -recurse -strip --mt-deflate ($paths | str join ' ')(ansi reset)\n($result.stderr)\n"
    return null
  }
  log debug $"image_optim stdout:\n($result.stdout)\n"
  (
    $result.stdout
    | lines --skip-empty
    | last
    | (
      let line = $in;
      log debug $"ect line: ($line)";
      $line
      | parse --regex 'Saved (?P<saved>.+) out of (?P<total>.+) \((?P<difference>.+)%\)'
      | first
      | (
        let i = $in;
        {
          difference: ($i.difference | into float),
          bytes: ($i.saved | into filesize),
          total: ($i.total | into filesize),
        }
      )
    )
  )
}

# Visually losslessly optimize jpegs with jpegli
#
# Not truly lossless.
export def optimize_jpeg []: path -> path {
  let jpeg = $in
  let original_size = du $jpeg | get physical | first
  let temporary_png = mktemp --suffix .png --tmpdir
  let result = do {^djpegli $jpeg $temporary_png} | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^djpegli ($jpeg) ($temporary_png)(ansi reset)\n($result.stderr)\n"
    return $jpeg
  }
  let temporary_jpeg = mktemp --suffix .jpeg --tmpdir
  let result = do {^cjpegli --quality 100 $temporary_png $temporary_jpeg} | complete
  rm --force $temporary_png
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^djpegli --quality 100 ($temporary_png) ($temporary_jpeg)(ansi reset)\n($result.stderr)\n"
    return $jpeg
  }
  let current_size = du $temporary_jpeg | get physical | first
  if $current_size < $original_size {
    let average = (($original_size + $current_size) / 2)
    let percent_difference = ((($original_size - $current_size) / $average) * 100)
    log debug $"JPEG (ansi yellow)($jpeg)(ansi reset) optimized down from a size of (ansi purple)($original_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size."
    mv --force $temporary_jpeg $jpeg
  } else {
    log debug $"No space saving achieved attempting to optimize the jpeg with jpegli (ansi yellow)($jpeg)(ansi reset)"
    rm --force $temporary_jpeg
  }
  $jpeg
}

# Losslessly optimize images with image_optim
#
# You may want to avoid using all threads on a multithreaded system when optimizing PNGs.
# ((^nproc | into int) / 2)
export def image_optim [
  --threads: int = 0
]: list<path> -> list<path> {
  let paths = $in
  log debug $"Running command: (ansi yellow)image_optim --config-paths \"\" ($paths | first)...(ansi reset)"
  let result = do {
    if $threads > 0 {
      ^image_optim --config-paths "" --threads $threads ...$paths
    } else {
      ^image_optim --config-paths "" ...$paths
    }
  } | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)image_optim --config-paths \"\" ($paths | str join ' ')(ansi reset)\nstdout:\n($result.stdout)\nstderr:\n($result.stderr)\n"
    return null
  }
  $paths
}

# Optimize a PNG image
#
# Uses the media-juggler-png-optimizer.nu script which just runs oxipng followed by ect.
# This is much faster than just running image_optim followed by ect, since image_optim includes a bunch of optimizers besides oxipng.
# In a simple test, compression using oxipng followed by ect and image_optim followed by ect resulted in a file of the same size.
export def optimize_png []: path -> path {
  let png = $in
  log debug $"Running command: (ansi yellow)^media-juggler-png-optimizer.nu '($png)'(ansi reset)"
  let result = do {
    ^media-juggler-png-optimizer.nu $png
  } | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^media-juggler-png-optimizer.nu '($png)'(ansi reset)\n($result.stderr)\n"
    return $png
  }
  $png
}

# Optimize an image
#
# Lossless by default.
# When lossy compression is allowed, use jpegli for jpegs and image_optim for everything else.
export def optimize_image [
  allow_lossy = false
]: path -> path {
  let path = $in
  if $allow_lossy and ($path | path parse | get extension) in ["jpg" "jpeg"] {
    $path | optimize_jpeg
  } else {
    let extension = $path | path parse | get extension | str downcase
    if $extension in ["jpg" "jpeg"] {
      # I haven't seen ECT achieve better optimization than image_optim for JPEG's.
      [$path] | image_optim
    } else if $extension == "png" {
      $path | optimize_png
    } else {
      [$path] | image_optim | first | optimize_image_ect
    }
  }
  $path
}

# Losslessly optimize images
export def optimize_images [
  --log-optimization-performance = false
]: list<path> -> list<path> {
  let paths = $in

  let image_files = $paths | each {|path|
    if ($path | path type) == "dir" {
      let glob_expression = [($path | escape_special_glob_characters) "**" $"*[.]{($image_extensions | str join ',')}"] | path join
      glob --no-dir --no-symlink $glob_expression
    } else {
      $path
    }
  } | flatten

  # Filter out thumbnail images that have stems that end with '-thumb'
  let image_files = $image_files | where {|image| not ($image | path parse | get stem | str ends-with '-thumb') }

  let original_size = $image_files | reduce --fold 0b {|it acc|
    $acc + (du $it | get physical | first)
  }
  # Optimize all JPEG files at once to take advantage of image_optim's parallelization.
  let jpeg_files = $image_files | where {|image| ($image | path parse | get extension | str downcase) in ["jpg" "jpeg"] }
  let start = date now
  $jpeg_files | image_optim
  $image_files | where {|image| ($image | path parse | get extension | str downcase) not-in ["jpg" "jpeg"] } | each {|image|
    $image | optimize_image
  }
  let duration = (date now) - $start

  if $log_optimization_performance {
    let current_size = $image_files | reduce --fold 0b {|it acc|
      $acc + (du $it | get physical | first)
    }
    if $current_size < $original_size {
      let average = (($original_size + $current_size) / 2)
      let percent_difference = ((($original_size - $current_size) / $average) * 100)
      log debug $"Images optimized down from a size of (ansi purple)($original_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
    } else {
      log debug $"No space saving achieved attempting to optimize the images"
    }
  }

  $image_files
}

# Losslessly optimize the images in a ZIP archive such as an EPUB or CBZ
export def optimize_images_in_zip [
  --log-optimization-performance = false
]: path -> path {
  let archive = ($in | path expand)
  log debug $"Optimizing images in (ansi yellow)($archive)(ansi reset)"
  let temporary_directory = (mktemp --directory)
  let extraction_path = ($temporary_directory | path join "extracted")
  log debug $"Extracting zip archive to (ansi yellow)($extraction_path)(ansi reset)"
  ^unzip -q $archive -d $extraction_path
  ^chmod --recursive +rw $extraction_path
  [$extraction_path] | optimize_images --log-optimization-performance $log_optimization_performance
  log debug "Image optimization complete"
  log debug $"Compressing directory (ansi yellow)($extraction_path)(ansi reset) as (ansi yellow)($archive)(ansi reset)"
  let temporary_archive = $archive | path parse | update parent $temporary_directory | path join
  rm --force $temporary_archive
  cd $extraction_path
  # Add the mimetype file to the archive first so that epubcheck is happy.
  if ("mimetype" | path exists) {
    log debug $"Running (ansi yellow)^zip --quiet --recurse-paths ($temporary_archive) mimetype(ansi reset)"
    ^zip --quiet --recurse-paths $temporary_archive mimetype
  }
  log debug $"Running (ansi yellow)^zip --quiet --recurse-paths ($temporary_archive) .(ansi reset)"
  ^zip --quiet --recurse-paths $temporary_archive .
  cd -
  mv --force $temporary_archive $archive
  rm --force --recursive $temporary_directory
  log debug $"Finished compressing (ansi yellow)($archive)(ansi reset)"
  $archive
}

# Optimize the compression used by a zip archive.
#
# Utilizes advzip from the advancecomp project.
export def advzip_recompress [
  optimization_level: int = 4 # The degree to which to optimize the zip archive from 0 to 4, with 4 being the best compression possible
  ...args: string # Extra arguments to pass to advzip
]: path -> path {
  let archive = $in
  log debug $"Running (ansi yellow)^advzip --recompress -($optimization_level) ($args | str join ' ') ($archive)(ansi reset)"
  let result = do {^advzip --recompress $"-($optimization_level)" ...$args $archive} | complete
  if $result.exit_code != 0 {
    log error $"Error running (ansi yellow)^advzip --recompress -($optimization_level) ($args | str join ' ') ($archive)(ansi reset)\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  $archive
}

export def measure_optimization_performance [
  optimization_function: closure # Takes a path and returns a path
  # todo I feel like passing args to a closure like this won't work
  # ...args: string # Extra arguments to pass to optimization_function
]: [
  path
  ->
  record<original_file: path, optimized_file: path, original_size: filesize, optimized_size: filesize, percent_difference: float, duration: duration>
] {
  let original_file = $in
  let original_size = du $original_file | get physical | first
  let start = date now
  # let optimized = do $optimization_function $input ...$args
  let optimized_file = do $optimization_function $original_file
  if ($optimized_file | is-empty) {
    log error $"Optimization function ($optimization_function) errored attempting to optimize the file (ansi yellow)($original_file)(ansi reset)"
    {
      original_file: $original_file
      optimized_file: ""
      original_size: -1MiB
      optimized_size: -1MiB
      percent_difference: 0.0
      duration: 0sec
    }
  }
  let duration = (date now) - $start
  let current_size = du $optimized_file | get physical | first
  let average = (($original_size + $current_size) / 2)
  let percent_difference = ((($original_size - $current_size) / $average) * 100)
  {
    original_file: $original_file
    optimized_file: $optimized_file
    original_size: $original_size
    optimized_size: $current_size
    percent_difference: $percent_difference
    duration: $duration
  }
}

# Prints out optimization performance of for the given file with the given optimization function.
export def log_optimization_performance [
  --silence = false # Skip logging output
]: [
  record<original_file: path, optimized_file: path, original_size: filesize, optimized_size: filesize, percent_difference: float, duration: duration>
  ->
  record<original_file: path, optimized_file: path, original_size: filesize, optimized_size: filesize, percent_difference: float, duration: duration>
] {
  let input = $in
  if not $silence {
    if ($input.optimized_file | is-empty) {
      log error $"Optimization function errored attempting to optimize the file (ansi yellow)($input.original_file)(ansi reset)"
      return $input
    }
    if $input.optimized_size < $input.original_size {
      log debug $"Optimized down from a size of (ansi purple)($input.original_size)(ansi reset) to (ansi purple)($input.optimized_size)(ansi reset), a (ansi green)($input.percent_difference)%(ansi reset) decrease in size in (ansi green)($input.duration)(ansi reset)."
    } else {
      log debug $"No space saving achieved attempting to optimize the file"
    }
  }
  $input
}

export def get_smallest_from_optimization_result []: [
  record<original_file: path, optimized_file: path, original_size: filesize, optimized_size: filesize, percent_difference: float, duration: duration>
  ->
  path
] {
  let input = $in
  if ($input.optimized_file | is-empty) {
    log error $"Optimization function errored attempting to optimize the file (ansi yellow)($input.original_file)(ansi reset)"
    return null
  }
  if $input.optimized_size < $input.original_size {
    $input.optimized_file
  } else {
    $input.original_file
  }
}

# Optimize a ZIP archive using efficient-compression-tool
# todo Use a temporary file to avoid corruption
# todo I should just create a function that logs optimization performance given a closure.
export def optimize_zip_ect [
  optimization_level: int = 9 # The degree to which to optimize the zip archive from 1 to 9, with 9 being the best compression possible
  ...args: string # Extra arguments to pass to advzip
]: path -> path {
  let archive = $in
  log debug $"Running (ansi yellow)^ect -($optimization_level) -strip -zip --mt-deflate ($args | str join ' ') ($archive)(ansi reset)"
  let result = do {^ect $"-($optimization_level)" -strip -zip --mt-deflate ...$args $archive} | complete
  if $result.exit_code != 0 {
    log error $"Error running (ansi yellow)^ect -($optimization_level) -strip -zip --mt-deflate ($args | str join ' ') ($archive)(ansi reset)\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  $archive
}

# Losslessly optimize the compression of a zip archive as well as image files in it.
#
# Uses image_optim to optimize image files.
export def optimize_zip [
  optimization_level: int = 9 # The degree to which to optimize the zip archive from 1 to 9, with 9 being the best compression possible
  --log-optimization-performance = false
]: path -> path {
  let $archive = $in
  let output = $archive | optimize_images_in_zip --log-optimization-performance $log_optimization_performance
  if ($output | is-empty) {
    return null
  }
  let archive = $output | optimize_zip_ect $optimization_level
  $archive
}

# Compare two PDFs for differences with diff-pdf
export def compare_pdf [
  pdf2: path # PDF to compare
]: [
  path -> bool
] {
  let pdf1 = $in
  log debug $"Running command: '^diff-pdf (ansi yellow)($pdf1)(ansi reset) (ansi yellow)($pdf2)(ansi reset)'"
  let result = do {
    ^diff-pdf $pdf1 $pdf2
  } | complete
  if $result.exit_code not-in [0, 1] {
    log error $"Error running: '^diff-pdf (ansi yellow)($pdf1)(ansi reset) (ansi yellow)($pdf2)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  $result.exit_code == 0
}

# Compare two PDFs, returning the page numbers of pages that differ
#
# The PDFs should have the same number of pages.
# The page number indices are 0-based.
export def compare_pdf_pages [
  pdf2: path # PDF to compare
  working_directory: path
]: [
  path -> list<int>
] {
  let pdf1 = $in
  # todo Compare PDFs using raw image data from pdftoppm
  # Use -freetype yes?
  # -aa yes? # Enables font aliasing.

  mkdir $working_directory
  let working_directory = $working_directory | path expand
  cd $working_directory

  let result = do {
    ^pdftoppm -png -q $pdf1 root1
  } | complete
  if $result.exit_code != 0 {
    log error $"Error running: '^pdftoppm (ansi yellow)($pdf1)(ansi reset) root1'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    cd -
    return null
  }

  let result = do {
    ^pdftoppm -png -q $pdf2 root2
  } | complete
  if $result.exit_code != 0 {
    log error $"Error running: '^pdftoppm (ansi yellow)($pdf2)(ansi reset) root2'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    cd -
    return null
  }

  let pdf1_files = glob ./root1-*.png | sort --natural
  let pdf2_files = glob ./root2-*.png | sort --natural

  if ($pdf1_files | length) != ($pdf2_files | length) {
    log error $"PDF files have a different number of pages: (ansi yellow)($pdf1)(ansi reset) has (ansi purple)($pdf1_files | length)(ansi reset) pages and (ansi yellow)($pdf2)(ansi reset) has (ansi purple)($pdf2_files | length) pages(ansi reset)"
    return null
  }

  let different_images = $pdf1_files | zip $pdf2_files | enumerate | reduce --fold [] {|it acc|
    let equivalent = $it.item.0 | odiff_same_image $it.item.1
    if ($equivalent | is-empty) {
      log error $"Error comparing images (ansi yellow)($it.item.0)(ansi reset) and (ansi yellow)($it.item.1)(ansi reset) with odiff"
      $acc | append $it.index
    } else {
      if $equivalent {
        rm --force $it.item.1 $it.item.0
        $acc
      } else {
        $acc | append $it.index
      }
    }
  }

  cd -
  $different_images
}

# Optimize a PDF with pdfsizeopt
#
# To accommodate failures for what can be a long-running process, pdfsizeopt is run multiple times.
# First, it optimizes streams, then fonts, and finally images.
# The PDF is linearized with qpdf as the last step.
export def optimize_pdf_pdfsizeopt [
  working_directory: path # Working directory
  # todo Add option to control image optimizers?
  # ...args: string # Command-line options
]: [
  path -> path
] {
  let original_pdf = $in
  mkdir $working_directory
  let working_directory = $working_directory | path expand
  cd $working_directory

  # I'm going to assume that I should use the disk for the temp files instead of a temp directory given how large PDFs can be.
  let tmp_dir = mktemp --directory --tmpdir-path $working_directory "pdfsizeopt_tmp_dir.XXXXXXXXXX"

  let input_pdf = $original_pdf
  let input_size = du $input_pdf | get physical | first
  let output_pdf = mktemp --suffix ".pso-streams.pdf" --tmpdir-path $working_directory

  # Optimize streams
  log debug $"Optimizing streams with pdfsizeopt: '^pdfsizeopt --do-optimize-fonts=no --do-optimize-images=no --do-optimize-streams=yes --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'"
  let start = date now
  let result = do {
    ^systemd-inhibit --what=sleep:shutdown --who="Media Juggler" --why="Running expensive file optimizations" pdfsizeopt --do-optimize-fonts=no --do-optimize-images=no --do-optimize-streams=yes $"--tmp-dir=($tmp_dir)" $input_pdf $output_pdf
  } | complete
  let duration = (date now) - $start
  if $result.exit_code != 0 {
    log error $"Error running: '^pdfsizeopt --do-optimize-fonts=no --do-optimize-images=no --do-optimize-streams=yes --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    rm --force $output_pdf
    rm --force --recursive $tmp_dir
    cd -
    return null
  }
  let input_pdf = (
    if ($original_pdf | compare_pdf $output_pdf) {
      let current_size = du $output_pdf | get physical | first
      let average = (($input_size + $current_size) / 2)
      let percent_difference = ((($input_size - $current_size) / $average) * 100)
      if $current_size < $input_size {
        log info $"PDF stream optimizations with pdfsizeopt resulted in a size reduction from a size of (ansi purple)($input_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
        $output_pdf
      } else {
        log info $"No space saving achieved optimizing the PDF streams of (ansi yellow)($input_pdf)(ansi reset) with pdfsizeopt. Optimization lasted (ansi green)($duration)(ansi reset)"
        rm --force $output_pdf
        $input_pdf
      }
    } else {
      log error $"PDF image data changed when optimizing streams with pdfsizeopt using the command: '^pdfsizeopt --do-optimize-fonts=no --do-optimize-images=no --do-optimize-streams=yes --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      log debug "Determining which pages changed in the PDF"
      let pages_directory = mktemp --directory --tmpdir-path $working_directory "pdfsizeopt_streams_pages.XXXXXXXXXX"
      let differing_pages = $input_pdf | compare_pdf_pages $output_pdf $pages_directory
      if ($differing_pages == null) {
        log error "Failed to determine differing pages!"
      } else {
        log error $"Differing pages are: (ansi purple)($differing_pages)(ansi reset)"
      }
      $input_pdf
    }
  )
  let input_size = du $input_pdf | get physical | first

  # Optimize fonts
  let output_pdf = mktemp --suffix ".pso-fonts.pdf" --tmpdir-path $working_directory
  log debug $"Optimizing fonts with pdfsizeopt: '^pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'"
  let start = date now
  let result = do {
    ^systemd-inhibit --what=sleep:shutdown --who="Media Juggler" --why="Running expensive file optimizations" pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no $"--tmp-dir=($tmp_dir)" $input_pdf $output_pdf
  } | complete
  let duration = (date now) - $start
  if $result.exit_code != 0 {
    log error $"Error running: '^pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    rm --force $output_pdf
    rm --force --recursive $tmp_dir
    cd -
    return null
  }
  let input_pdf = (
    if ($original_pdf | compare_pdf $output_pdf) {
      let current_size = du $output_pdf | get physical | first
      let average = (($input_size + $current_size) / 2)
      let percent_difference = ((($input_size - $current_size) / $average) * 100)
      if $current_size < $input_size {
        log info $"PDF font optimizations with pdfsizeopt resulted in a size reduction from a size of (ansi purple)($input_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
        if ($input_pdf not-in [$original_pdf $output_pdf]) {
          rm --force $input_pdf
        }
        $output_pdf
      } else {
        log info $"No space saving achieved from optimizing PDF fonts in (ansi yellow)($input_pdf)(ansi reset) with pdfsizeopt. Optimization lasted (ansi green)($duration)(ansi reset)"
        rm --force $output_pdf
        $input_pdf
      }
    } else {
      log error $"PDF image data changed when optimizing fonts with pdfsizeopt using the command: '^pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      log error $"PDF image data changed when optimizing fonts with pdfsizeopt using the command: '^pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no --do-regenerate-all-fonts=no --do-unify-fonts=no --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      log debug "Determining which pages changed in the PDF"
      let pages_directory = mktemp --directory --tmpdir-path $working_directory "pdfsizeopt_fonts_pages.XXXXXXXXXX"
      let differing_pages = $input_pdf | compare_pdf_pages $output_pdf $pages_directory
      if ($differing_pages == null) {
        log error "Failed to determine differing pages!"
      } else {
        log error $"Differing pages are: (ansi purple)($differing_pages)(ansi reset)"
      }

      log debug $"Running command: '^pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no --do-regenerate-all-fonts=no --do-unify-fonts=no --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'"
      let start = date now
      let result = do {
        ^systemd-inhibit --what=sleep:shutdown --who="Media Juggler" --why="Running expensive file optimizations" pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no --do-regenerate-all-fonts=no --do-unify-fonts=no $"--tmp-dir=($tmp_dir)" $input_pdf $output_pdf
      } | complete
      let duration = (date now) - $start
      if $result.exit_code != 0 {
        log error $"Error running: '^pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no --do-regenerate-all-fonts=no --do-unify-fonts=no --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
        rm --force $output_pdf
        rm --force --recursive $tmp_dir
        cd -
        return null
      }
      if ($original_pdf | compare_pdf $output_pdf) {
        let current_size = du $output_pdf | get physical | first
        let average = (($input_size + $current_size) / 2)
        let percent_difference = ((($input_size - $current_size) / $average) * 100)
        if $current_size < $input_size {
          log info $"PDF font optimizations without font regeneration and unification with pdfsizeopt resulted in a size reduction from a size of (ansi purple)($input_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
          if ($input_pdf not-in [$original_pdf $output_pdf]) {
            rm --force $input_pdf
          }
          $output_pdf
        } else {
          log info $"No space saving achieved from optimizing PDF fonts without font regeneration and unification in (ansi yellow)($input_pdf)(ansi reset) with pdfsizeopt. Optimization lasted (ansi green)($duration)(ansi reset)"
          rm --force $output_pdf
          $input_pdf
        }
      } else {
        log error $"PDF image data changed when optimizing fonts with pdfsizeopt using the command: '^pdfsizeopt --do-optimize-fonts=yes --do-optimize-images=no --do-optimize-streams=no --do-regenerate-all-fonts=no --do-unify-fonts=no --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
        log debug "Determining which pages changed in the PDF"
        let pages_directory = mktemp --directory --tmpdir-path $working_directory "pdfsizeopt_fonts_no_unify_no_regenerate_pages.XXXXXXXXXX"
        let differing_pages = $input_pdf | compare_pdf_pages $output_pdf $pages_directory
        if ($differing_pages == null) {
          log error "Failed to determine differing pages!"
        } else {
          log error $"Differing pages are: (ansi purple)($differing_pages)(ansi reset)"
        }
        $input_pdf
      }
    }
  )
  let input_size = du $input_pdf | get physical | first

  # Optimize images
  let output_pdf = mktemp --suffix ".pso-images.pdf" --tmpdir-path $working_directory
  log debug $"Optimizing images with pdfsizeopt: '^pdfsizeopt --do-optimize-fonts=no --do-optimize-images=yes --do-optimize-streams=no --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) --use-image-optimizer=media_juggler_png_optimizer,imgdataopt,jbig2 (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'"
  let start = date now
  let result = do {
    ^systemd-inhibit --what=sleep:shutdown --who="Media Juggler" --why="Running expensive file optimizations" pdfsizeopt --do-optimize-fonts=no --do-optimize-images=yes --do-optimize-streams=no $"--tmp-dir=($tmp_dir)" --use-image-optimizer=media_juggler_png_optimizer,imgdataopt,jbig2 $input_pdf $output_pdf
  } | complete
  let duration = (date now) - $start
  if $result.exit_code != 0 {
    log error $"Error running: '^pdfsizeopt --do-optimize-fonts=no --do-optimize-images=no --do-optimize-streams=yes --use-image-optimizer=media_juggler_png_optimizer,imgdataopt,jbig2 --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    rm --force $output_pdf
    rm --force --recursive $tmp_dir
    cd -
    return null
  }
  let input_pdf = (
    if ($original_pdf | compare_pdf $output_pdf) {
      let current_size = du $output_pdf | get physical | first
      let average = (($input_size + $current_size) / 2)
      let percent_difference = ((($input_size - $current_size) / $average) * 100)
      if $current_size < $input_size {
        log info $"PDF image optimizations with pdfsizeopt resulted in a size reduction from a size of (ansi purple)($input_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
        if ($input_pdf not-in [$original_pdf $output_pdf]) {
          rm --force $input_pdf
        }
        $output_pdf
      } else {
        log info $"No space saving achieved from optimizing PDF images in (ansi yellow)($input_pdf)(ansi reset) with pdfsizeopt. Optimization lasted (ansi green)($duration)(ansi reset)"
        rm --force $output_pdf
        $input_pdf
      }
    } else {
      # todo Should I retry without jbig2 like minuimus.pl does?
      log error $"PDF image data changed when optimizing images with pdfsizeopt using the command: '^pdfsizeopt --do-optimize-fonts=no --do-optimize-images=yes --do-optimize-streams=no --use-image-optimizer=media_juggler_png_optimizer,imgdataopt,jbig2 --tmp-dir (ansi yellow)($tmp_dir)(ansi reset) (ansi yellow)($input_pdf)(ansi reset) (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      log debug "Determining which pages changed in the PDF"
      let pages_directory = mktemp --directory --tmpdir-path $working_directory "pdfsizeopt_images.XXXXXXXXXX"
      let differing_pages = $input_pdf | compare_pdf_pages $output_pdf $pages_directory
      if ($differing_pages == null) {
        log error "Failed to determine differing pages!"
      } else {
        log error $"Differing pages are: (ansi purple)($differing_pages)(ansi reset)"
      }
      $input_pdf
    }
  )
  let input_size = du $input_pdf | get physical | first

  # Linearize with QPDF
  let output_pdf = (
    if ($input_size > 1MiB) {
      let output_pdf = mktemp --suffix ".linearized.pdf" --tmpdir-path $working_directory
      log debug $"Linearizing PDF with qpdf: '^qpdf (ansi yellow)($input_pdf)(ansi reset) --linearize --stream-data=preserve (ansi yellow)($output_pdf)(ansi reset)'"
      let start = date now
      let result = do {
        ^systemd-inhibit --what=sleep:shutdown --who="Media Juggler" --why="Running expensive file optimizations" qpdf $input_pdf --linearize --stream-data=preserve $output_pdf
      } | complete
      let duration = (date now) - $start
      if $result.exit_code != 0 {
        log error $"Error running: '^qpdf (ansi yellow)($input_pdf)(ansi reset) --linearize --stream-data=preserve (ansi yellow)($output_pdf)(ansi reset)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
        rm --force $output_pdf
        rm --force --recursive $tmp_dir
        cd -
        return null
      }
      let current_size = du $output_pdf | get physical | first
      let average = (($input_size + $current_size) / 2)
      let percent_difference = ((($input_size - $current_size) / $average) * 100)
      # It's okay if the linearized PDF is larger.
      if $current_size < $input_size {
        log info $"PDF linearization with qpdf resulted in a size reduction from a size of (ansi purple)($input_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
      } else {
        log info $"No space saving achieved from linearizing the PDF (ansi yellow)($input_pdf)(ansi reset) with pdfsizeopt. Optimization lasted (ansi green)($duration)(ansi reset)"
      }
      if ($input_pdf not-in [$original_pdf $output_pdf]) {
        rm --force $input_pdf
      }
      $output_pdf
    } else {
      $input_pdf
    }
  )

  rm --force --recursive $tmp_dir
  cd -

  $output_pdf
}

# Losslessly optimize a PDF using minuimus and pdfsizeopt.
#
# This can take a long time, so systemd-inhibit is used to ensure the system doesn't sleep.
export def optimize_pdf [
  working_directory: path # Working directory
  ...args: string # Arguments to pass to minuimus.pl
]: path -> path {
  let $original_pdf = $in
  let $input_pdf = $original_pdf
  let original_size = du $original_pdf | get physical | first

  mkdir $working_directory
  let working_directory = $working_directory | path expand
  cd $working_directory

  let input_size = du $input_pdf | get physical | first
  let output_pdf = mktemp --suffix ".minuimus.pdf" --tmpdir-path $working_directory

  # First, we run minuimus.
  cp --force $input_pdf $output_pdf
  log info $"Running the command '^systemd-inhibit --what=sleep:shutdown --who='Media Juggler' minuimus.pl ($args | str join ' ') ($output_pdf)'"
  let start = date now
  let original_start = $start
  let result = with-env {
    QPDF_ZOPFLI: "force"
  } {
    do {
      ^systemd-inhibit --what=sleep:shutdown --who="Media Juggler" --why="Running expensive file optimizations" minuimus.pl ...$args $output_pdf
    } | complete
  }
  let duration = (date now) - $start
  if $result.exit_code != 0 {
    log info $"Error running '^systemd-inhibit --what=sleep:shutdown --who='Media Juggler' minuimus.pl ($args | str join ' ') ($output_pdf)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  # todo Check if one or both of these should be output.
  log debug $"minuimus.pl stderr: ($result.stderr)"
  log debug $"minuimus.pl stdout: ($result.stdout)"

  let current_size = du $output_pdf | get physical | first
  let average = (($input_size + $current_size) / 2)
  let percent_difference = ((($input_size - $current_size) / $average) * 100)
  if $current_size < $input_size {
    log info $"minuimus optimized the PDF (ansi yellow)($input_pdf)(ansi reset) down from a size of (ansi purple)($input_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
  } else {
    log debug $"No space saving achieved using minuimus to optimize the PDF (ansi yellow)($input_pdf)(ansi reset). Optimization lasted (ansi green)($duration)(ansi reset)"
  }

  # Recompress streams with qpdf and zopfli.
  # This is able to achieve better optimization than just using minuimus alone.
  # minuimus appears to have trouble with particularly large streams.
  # todo Do we need minuimus if we're running qpdf with zopfli?

  # QPDF_ZOPFLI=force ^qpdf input.pdf --compress-streams=y --compression-level=9 --stream-data=compress --decode-level=generalized --object-streams=generate --recompress-flat --linearize output.pdf
  let input_pdf = $output_pdf
  let input_size = du $input_pdf | get physical | first
  let output_pdf = mktemp --suffix ".qpdf-zopfli.pdf" --tmpdir-path $working_directory
  log info $"Running the command '^systemd-inhibit --what=sleep:shutdown --who='Media Juggler' qpdf ($input_pdf) --compress-streams=y --compression-level=9 --stream-data=compress --decode-level=generalized --object-streams=generate --recompress-flate --linearize ($output_pdf)'"
  let start = date now
  let result = with-env {
    QPDF_ZOPFLI: "force"
  } {
    do {
      ^systemd-inhibit --what=sleep:shutdown --who="Media Juggler" --why="Running expensive file optimizations" qpdf $input_pdf --compress-streams=y --compression-level=9 --stream-data=compress --decode-level=generalized --object-streams=generate --recompress-flate --linearize $output_pdf
    } | complete
  }
  let duration = (date now) - $start
  if $result.exit_code != 0 {
    log info $"Error running '^systemd-inhibit --what=sleep:shutdown --who='Media Juggler' qpdf ($input_pdf) --compress-streams=y --compression-level=9 --stream-data=compress --decode-level=generalized --object-streams=generate --recompress-flate --linearize ($output_pdf)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  let input_pdf = (
    if ($original_pdf | compare_pdf $output_pdf) {
      let current_size = du $output_pdf | get physical | first
      let average = (($input_size + $current_size) / 2)
      let percent_difference = ((($input_size - $current_size) / $average) * 100)
      if $current_size < $input_size {
        log info $"PDF stream optimizations with qpdf and zopfli resulted in a size reduction from a size of (ansi purple)($input_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
        if ($input_pdf not-in [$original_pdf $output_pdf]) {
          rm --force $input_pdf
        }
        $output_pdf
      } else {
        log info $"No space saving achieved from optimizing PDF streams in (ansi yellow)($input_pdf)(ansi reset) with qpdf and zopfli. Optimization lasted (ansi green)($duration)(ansi reset)"
        rm --force $output_pdf
        $input_pdf
      }
    } else {
      # todo Should I retry without jbig2 like minuimus.pl does?
      log error $"PDF image data changed when optimizing streams with qpdf and zopfli using the command: '^qpdf ($input_pdf) --compress-streams=y --compression-level=9 --stream-data=compress --decode-level=generalized --object-streams=generate --recompress-flat --linearize ($output_pdf)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      log debug "Determining which pages changed in the PDF"
      let pages_directory = mktemp --directory --tmpdir-path $working_directory "qpdf_zopfli.XXXXXXXXXX"
      let differing_pages = $input_pdf | compare_pdf_pages $output_pdf $pages_directory
      if ($differing_pages == null) {
        log error "Failed to determine differing pages!"
      } else {
        log error $"Differing pages are: (ansi purple)($differing_pages)(ansi reset)"
      }
      $input_pdf
    }
  )
  let input_size = du $input_pdf | get physical | first

  let start = date now
  let output_pdf = $input_pdf | optimize_pdf_pdfsizeopt $working_directory
  let duration = (date now) - $start
  let full_duration = (date now) - $original_start
  let output_pdf = (
    if ($output_pdf == null) {
      log error "Failed to optimize the PDF with pdfsizeopt"
      $input_pdf
    } else {
      let current_size = du $output_pdf | get physical | first
      let average = (($input_size + $current_size) / 2)
      let percent_difference = ((($input_size - $current_size) / $average) * 100)
      if $current_size < $input_size {
        log info $"pdfsizeopt successfully optimized the PDF (ansi yellow)($input_pdf)(ansi reset) down from a size of (ansi purple)($input_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
      } else {
        log debug $"No space saving achieved using pdfsizeopt to optimize the PDF (ansi yellow)($input_pdf)(ansi reset). Optimization lasted (ansi green)($duration)(ansi reset)"
      }
      rm --force $input_pdf
      $output_pdf
    }
  )

  let final_size = du $output_pdf | get physical | first
  let average = (($original_size + $final_size) / 2)
  let percent_difference = ((($original_size - $final_size) / $average) * 100)
  if $final_size < $original_size {
    log info $"Successfully optimized the PDF (ansi yellow)($original_pdf)(ansi reset) down from a size of (ansi purple)($original_size)(ansi reset) to (ansi purple)($final_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($full_duration)(ansi reset)."
  } else {
    log info $"No space saving achieved attempting to optimize the PDF (ansi yellow)($original_pdf)(ansi reset). Optimization lasted (ansi green)($full_duration)(ansi reset)"
  }
  $output_pdf
}

# Optimize and clean up an EPUB with Calibre
export def polish_epub []: [path -> path] {
  let epub = $in;
  # ebook-polish f***s up the cover art.
  # It's forcibly downsizing the artwork from 1600x2278 to 1545x2200.
  # If I'd wanted that, I would have asked... Geez.

  # Save the cover
  # let cover_file = mktemp
  # log debug $"Running (ansi yellow)^ebook-meta --get-cover '($cover_file)' ($epub)(ansi reset)"
  # ^ebook-meta --get-cover $cover_file $epub
  # let cover_file = $cover_file | rename_image_with_extension
  # log debug $"cover_file: ($cover_file) ($cover_file | get_image_dimensions)"

  log debug $"Running (ansi yellow)^ebook-polish --download-external-resources --remove-unused-css --subset-fonts --upgrade-book --verbose '($epub)' '($epub)'(ansi reset)"
  (
    ^ebook-polish
      --download-external-resources
      --remove-unused-css
      --subset-fonts
      # --cover $cover_file
      --upgrade-book
      --verbose
      $epub
      $epub
      # err> /dev/null
  )

  # let new_cover_file = mktemp
  # ^ebook-meta --get-cover $new_cover_file $epub
  # let new_cover_file = $new_cover_file | rename_image_with_extension
  # log debug $"new_cover_file: ($new_cover_file) ($new_cover_file | get_image_dimensions)"

  # Add back the original cover
  # log debug $"Running (ansi yellow)^ebook-meta --cover '($cover_file)' ($epub)(ansi reset)"
  # ^ebook-meta --cover $cover_file $epub
  # rm $cover_file

  $epub
}
