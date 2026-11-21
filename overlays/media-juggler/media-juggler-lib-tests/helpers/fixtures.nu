# Create files for the tests of media-juggler-lib
#
# Files are generated when the tests run instead of being stored in the repository.

# Create a PDF with one page for each line of text
#
# The PDF uses a font built into PDF readers, so no fonts need to be installed.
export def create_pdf [
  pages: list<string> # The text on each page
]: path -> path {
  let pdf = $in
  let directory = mktemp --directory --tmpdir
  let page_files = $pages | enumerate | each {|page|
    let page_file = $directory | path join $"page-($page.index).txt"
    let text = $page.item | str replace --all '\' '\\' | str replace --all '(' '\(' | str replace --all ')' '\)'
    [
      "%%MediaBox 0 0 612 200"
      "%%Font Helv Helvetica"
      $"BT /Helv 28 Tf 36 90 Td \(($text)\) Tj ET"
    ] | str join "\n" | save $page_file
    $page_file
  }
  ^mutool create -o $pdf ...$page_files
  rm --recursive $directory
  $pdf
}

# Render the first page of a PDF to a PNG image
export def render_pdf_page []: path -> path {
  let pdf = $in
  let image = $pdf | path parse | update extension png | path join
  ^mutool draw -q -r 150 -o $image $pdf 1
  $image
}

# Create a solid color PNG image
export def create_image [
  width: int
  height: int
  color: string = "white"
]: path -> path {
  let image = $in
  ^magick -size $"($width)x($height)" $"xc:($color)" $image
  $image
}

# Create a ZIP archive containing the given files
#
# The paths of the files in the archive are relative to the directory containing the archive.
export def create_zip [
  files: list<path> # The files to add, relative to the directory of the archive
]: path -> path {
  let archive = $in
  do {
    cd ($archive | path dirname)
    ^zip --quiet ($archive | path basename) ...$files
  }
  $archive
}
