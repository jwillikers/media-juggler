# A collection of helpful utility functions

use std log
use std assert

export const media_juggler_version = "0.0.1"

export const user_agent = $"MediaJuggler/($media_juggler_version) \( https://github.com/jwillikers/media-juggler \)"

export const ereader_profiles = [
    [model height width disk_label];
    ["Kobo Elipsa 2E" 1872 1404 "KOBOeReader"]
]

export const image_extensions = [
  avif
  bmp
  gif
  jpeg
  jpg
  jxl
  png
  svg
  tiff
  webp
]

export const audiobook_accompanying_document_file_extensions = [
  cbz
  epub
  pdf
]

export const musicbrainz_non_genre_tags = [
  "abridged"
  "accompanying document"
  "audiobook"
  "chapters"
  "explicit"
  "novel"
  "unabridged"
]

# Surround special characters in a string with square brackets
#
# Use this on strings before adding glob characters.
# Not that I can't actually escape backslashes, so those will cause the glob expression to fail outright.
# Maybe this will be fixed in Nushell at some point?
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

# Determine of the embedded cover in a video stream is set incorrectly
export def has_bad_video_stream []: record<streams: table, format: record> -> bool {
  let ffprobe_output = $in
  if ($ffprobe_output | is-empty) {
    return false
  }
  let streams = $ffprobe_output | get --ignore-errors streams
  if ($streams | is-empty) {
    return false
  }
  let video_streams = $streams | where codec_type == "video"
  if ($video_streams | is-empty) {
    return false
  }
  # The problematic video streams have default disposition set to 1 instead of attached_pic
  $video_streams | where disposition.attached_pic == 0 | is-not-empty
}

export def remove_video_stream [
  output_file: path = ""
]: path -> path {
  let input_file = $in
  let the_output_file = (
    if ($output_file | is-empty) {
      mktemp --suffix ("." + ($input_file | path parse | get extension)) --tmpdir
    } else {
      $output_file
    }
  )
  # log info $"the_output_file: ($the_output_file)"
  ^ffmpeg -y -i $input_file -codec:a copy -vn $the_output_file
  if ($output_file | is-empty) {
    mv $the_output_file $input_file
    $input_file
  } else {
    $the_output_file
  }
}

# Parse the container and audio codec from ffprobe's output
export def parse_container_and_audio_codec_from_ffprobe_output []: record<streams: table, format: record> -> record<audio_codec: string, container: string, audio_channel_layout: string> {
  let ffprobe_output = $in
  if ($ffprobe_output | is-empty) {
    log error "No ffprobe output"
    return null
  }
  let streams = $ffprobe_output | get --ignore-errors streams
  if ($streams | is-empty) {
    log error "Missing streams in ffprobe output"
    return null
  }
  let audio_streams = $streams | where codec_type == "audio"
  if ($audio_streams | is-empty) {
    log error "No audio stream in ffprobe output"
    return null
  }
  if ($audio_streams | length) > 1 {
    log error $"The ffprobe output contains ($audio_streams | length) audio streams. Unsure what to do when there is more than one audio stream."
    return null
  }
  let audio_stream = $audio_streams | first
  if "codec_name" not-in $audio_stream {
    log error "The ffprobe audio stream is missing the codec_name"
    return null
  }
  let format = $ffprobe_output | get --ignore-errors format;
  if ($format | is-empty) {
    log error "The ffprobe output is missing the format field"
    return null
  }
  {
    container: $format.format_name
    audio_codec: $audio_stream.codec_name
    audio_channel_layout: ($audio_stream | get --ignore-errors channel_layout)
  }
}

# Parse the output from the ffprobe command
export def parse_ffprobe_output []: record<streams: table, format: record> -> record<audio_streams: table, video_streams: table, format: record<format_name: string, format_long_name: string>> {
  let ffprobe_output = $in
  let streams = $ffprobe_output | get --ignore-errors streams
  if ($streams | is-empty) {
    log error "Missing streams in ffprobe output"
    return null
  }
  let audio_streams = (
    let audio_streams = $streams | where codec_type == "audio";
    if ($audio_streams | is-empty) {
      []
    } else {
      $audio_streams
      | select codec_name codec_long_name profile codec_tag_string sample_fmt sample_rate channels channel_layout time_base duration bit_rate nb_frames
      | update duration {|audio_stream| $audio_stream.duration | into duration --unit sec}
    }
  )
  let video_streams = (
    let video_streams = $streams | where codec_type == "video";
    if ($video_streams | is-empty) {
      []
    } else {
      $video_streams
      | select codec_name codec_long_name codec_type codec_tag_string width height coded_width coded_height pix_fmt color_range color_space
    }
  )
  let format = (
    let format = $ffprobe_output | get --ignore-errors format;
    if ($format | is-empty) {
      {}
    } else {
      $format | select format_name format_long_name
    }
  )
  {
    audio_streams: $audio_streams
    video_streams: $video_streams
    format: $format
  }
}

# Get the audio data for a file using the ffprobe command
export def ffprobe [
  ...args: string # Arguments to pass to the ffprobe command
]: path -> record {
  ^ffprobe ...$args -v quiet -print_format json -show_format -show_streams $in | from json
}

# todo
export def convert_to_opus [
  extension: string # file extension of the output container, i.e. ogg, m4b
  ...args: string # ffmpeg args
]: path -> path {
  let input = $in
  let output = $input | path parse | update extension $extension
  ^ffmpeg -i $input -c:a libopus ...$args $output
  # todo Use opusenc to keep embedded cover art
  # ^opusenc
  #  -b:a 128k
  #  -map_metadata 0
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
    $name | str replace --all '/' '⁄'
  }
}

# Get the type of a path via SSH
export def "ssh_path_type" []: path -> string {
  let input = $in
  let ssh_path = $in | split_ssh_path
  ^ssh $ssh_path.server nu --commands $"\'\"($ssh_path.path)\" | path type | to json\'" | from json
}

# Delete a file over SSH
export def "ssh rm" []: path -> nothing {
  let target = $in | split_ssh_path
  ^ssh $target.server nu --commands $"\'rm ($target)\'"
  # Prune empty directories
  let parent_directory = $target.path | path dirname
  ^ssh $target.server nu --commands $"\'^rmdir --ignore-fail-on-non-empty --parents ($parent_directory)\'"
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
    and ($components | split row ":" | filter {|component| $component | is-not-empty} | append ($components | skip 1) | length) > 1
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
  if $source_path_type == "dir" {
    ^rsync --recursive ...$args $source $destination
  } else {
    ^rsync ...$args $source $destination
  }
  [$destination ($source | path basename)] | path join
}

# Glob files over SSH
export def "ssh glob" [
  ...glob_args: string
]: path -> table {
  let input = $in
  let ssh_path = $input | split_ssh_path
  ^ssh $ssh_path.server nu --commands $"\'glob (...$glob_args) ($ssh_path.path) | to json\'" | from json
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
    ^ssh $ssh_path.server nu --commands $"\'ls (...$args) ($path | path expand) | to json\'" | from json
  } else {
    ^ssh $ssh_path.server nu --commands $"\'ls (...$args) ($path) | to json\'" | from json
  }
}

# Check if a path exists over SSH
export def "ssh_path_exists" []: path -> bool {
  let input = $in
  let ssh_path = $input | split_ssh_path
  let path = $ssh_path.path
  let exit_code = do {^ssh $ssh_path.server nu --commands $"\'stat ($path)\'"} | complete | get exit_code
  ($exit_code == 0)
}

# List files over SSH
# export def "ssh_list_files_in_archive_with_extensions" [
#   ...args: string
# ]: path -> nothing {
#   let input = $in
#   let ssh_path = $input | split_ssh_path
#   (
#     ^unzip -l $archive
#     | lines
#     | drop nth 0 1
#     | drop 2
#     | str trim
#     | parse "{length}  {date} {time}   {name}"
#     | get name
#     | uniq
#     | sort
#   )
#   ^ssh $ssh_path.server nu --commands $"\'ls (...$args) ($ssh_path.path) | to json\'" | from json
# }

# Get the number of pages in a PDF
export def pdf_page_count []: path -> int {
  let pdf = $in
  # ^pdfinfo $pdf | lines --skip-empty | parse --regex '(?P<key>\w+):\W+(?P<value>\w+.*)' | where key == "Pages" | get value
  ^mutool show $pdf trailer/Root/Pages/Count | into int
}

# Get text from a PDF
# export def pdftotext [
#   --first: int # First page to convert
#   --last: int # Last page to convert
# ]: path -> string {
#   let pdf = $in
#   ^pdftotext  -
# }

# RE_NORMAL = re.compile(
#     r'97[89]{1}-?[0-9]{10}|'
#     r'97[89]{1}-[-0-9]{13}|'
#     r'\d{9}[0-9X]{1}|'
#     r'[-0-9X]{10,16}',
#     re.I | re.M | re.S,
# )

# r'^(?:ISBN(?:-1[03])?:? )?(?=[0-9X]{10}$|'
# r'(?=(?:[0-9]+[- ]){3})'
# r'[- 0-9X]{13}$|97[89][0-9]{10}$|'
# r'(?=(?:[0-9]+[- ]){4})'
# r'[- 0-9]{17}$)(?:97[89][- ]?)?[0-9]{1,5}'
# r'[- ]?[0-9]+[- ]?[0-9]+[- ]?[0-9X]$',

# todo Use a confidence rating for all ISBN results and use that to determine the most likely candidates?
# Parse ISBN from text
export def parse_isbn [
]: list<string> -> list<string> {
  let text = $in

  # todo Fix this so that ISBN's occurring after the first one on this line are still eligible?
  # Avoid the ISBN preview in Tor books like this:
  # A Tor Hardcover ISBN    978-0-3128-51408
  let text = (
    $text | filter {
      |l| not ($l | str contains "A Tor Hardcover ISBN")
    }
  )

  # ISBN 978-1-250-16947-1 (ebook)
  # 978-1-250-16947-1 (ebook)
  # eISBN 978-1-6374-1067-7
  # eISBN
  # ISBN: 978-1-250-16947-1

  # ISBN-13: 978-1-7185-0186-7 (ebook)
  let obvious_isbn = (
    $text
    | parse --regex 'ISBN-13:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # ebook ISBN: xxx
  let obvious_isbn = (
    $text
    | parse --regex 'ebook ISBN:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # ISBN xxx (ebook)
  let obvious_isbn = (
    $text
    | parse --regex 'ISBN\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let obvious_isbn = (
    $text
    | parse --regex '(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))\s*\(ebook\)'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  # eISBN 978-1-6374-1067-7
  let obvious_isbn = (
    $text
    | parse --regex 'eISBN\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let obvious_isbn = (
    $text
    | parse --regex 'ISBN:\s*(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($obvious_isbn | is-not-empty) {
    return ($obvious_isbn | get isbn | str replace --all "-" "" | uniq)
  }

  let isbn_numbers = (
    $text
    | parse --regex '(?P<isbn>(?:97[89]{1}-?[0-9]{10})|(?:97[89]{1}-[-0-9]{13}))'
  )
  if ($isbn_numbers | is-empty) {
    []
  } else {
    $isbn_numbers | get isbn | str replace --all "-" "" | uniq
  }
}

# Convert the first 10 and last 10 pages of a PDF file to text
export def pdf_to_text []: path -> string {
  let pdf = $in
  let pages = $pdf | pdf_page_count
  let text_file = mktemp
  if $pages <= 20 {
    # ^pdftotext $pdf -
    # todo https://bugs.ghostscript.com/show_bug.cgi?id=707651
    ^mutool convert -F text -o $text_file -O mediabox-clip=no $pdf
  } else {
    ^mutool convert -F text -o $text_file -O mediabox-clip=no $pdf $"1-10,($pages - 10)-N"
    # [(^pdftotext -l 10 $pdf -) (^pdftotext -f ($pages - 10) $pdf -)] | str join "\n"
  }
  let text = open $text_file
  rm $text_file
  $text
}

# Convert the first 10 and last 10 pages of an EPUB file to text
export def epub_to_text []: path -> string {
  let epub = $in
  let text_file = mktemp --suffix .txt --tmpdir
  # todo Get a smaller portion of the EPUB's pages?
  ^ebook-convert $epub $text_file
  let text = open $text_file
  rm $text_file
  $text
}

# Convert a PDF or EPUB to text
export def book_to_text []: path -> string {
  let book = $in
  let input_format = $book | path parse | get extension
  if $input_format == "epub" {
    $book | epub_to_text
  } else if $input_format == "pdf" {
    $book | pdf_to_text
  } else {
    null
  }
}

export def isbn_from_images_in_archive [
  working_directory: path
]: path -> list<string> {
  let archive = $in
  let images = $archive | list_files_in_archive_with_extensions $image_extensions
  # We start at the back first
  let pages = (
    $images
    | last 10
    | reverse
    | append ($images | first 10)
    | uniq
  )
  # $pages | each {|page|
  #   $page | image_to_text | parse_isbn
  # }
  for page in $pages {
    let image = $archive | extract_file_from_archive $page $working_directory
    if $image == null {
      return []
    }
    let image_text = $image | image_to_text
    if $image_text == null {
      return []
    }
    let isbn = $image_text | lines --skip-empty | reverse | parse_isbn
    rm $image
    if ($isbn | is-not-empty) {
      return $isbn
    }
  }
  []
}

# Extract text from an image using OCR
export def image_to_text []: path -> string {
  let image = $in
  let result = do {^tesseract $image stdout} | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^tesseract \"($image)\" stdout(ansi reset)\n($result.stderr)\n"
    return null
  }
  $result.stdout
}

# todo
# export def isbn_10_to_isbn_13 []: string -> string {
#   str substring 0 11
# }

# export def extract_isbn_from_image []: path -> list<string> {
#   let image = $in
#   $image | image_to_text | lines --skip-empty | parse_isbn
# }

# Extract an ISBN from the pages of CBZ, PDF, or EPUB file
export def isbn_from_pages [
    working_directory: directory # The scratch-space directory to use
]: path -> list<string> {
  let $file = $in
  let input_format = $file | path parse | get extension
  let isbn = (
    if $input_format in ["epub" "pdf"] {
      log debug "Attempting to parse the ISBN from the book's text"
      $file | book_to_text | lines --skip-empty | reverse | parse_isbn
    } else {
      []
    }
  )
  if ($isbn | is-not-empty) {
    return $isbn
  }
  if $input_format in ["cbz" "epub" "zip"] {
    log debug "Attempting to parse the ISBN from the book's images"
    $file | isbn_from_images_in_archive $working_directory
  } else {
    []
  }
}

# Parse fetched metadata from Comic Vine for an issue
# todo
export def parse_comic_vine_issue_metadata []: record -> table {
  let metadata = $in | get md
}

# Extract the issue from ComicInfo.xml metadata
#
# todo Add tests
export def issue_from_comic_info []: record -> string {
  let comic_info = $in
  let number = $comic_info | get content | where tag == "Number" | get content
  if ($number | is-empty) {
    return null
  }
  if ($number | length) > 1 {
    log warning $"Somehow found multiple Number fields in the ComicInfo.xml metadata: ($number). Ignoring Number fields."
    return null
  }
  let values = $number | first | get content
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple values in the Number field of the ComicInfo.xml metadata: ($values). Ignoring Number field."
    return null
  }
  $values | first
}

# Extract the issue year from ComicInfo.xml metadata
#
# todo Add tests
export def issue_year_from_comic_info []: record -> string {
  let comic_info = $in
  let year = $comic_info | get content | where tag == "Year" | get content
  if ($year | is-empty) {
    return null
  }
  if ($year | length) > 1 {
    log warning $"Somehow found multiple Year fields in the ComicInfo.xml metadata: ($year). Ignoring Year fields."
    return null
  }
  let values = $year | first | get content
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple years in the Year field of the ComicInfo.xml metadata: ($values). Ignoring Year field."
    return null
  }
  $values | first
}

# Extract the series year from ComicInfo.xml metadata
#
# todo Add tests
export def series_year_from_comic_info []: record -> string {
  let comic_info = $in
  let volume = $comic_info | get content | where tag == "Volume" | get content
  if ($volume | is-empty) {
    return null
  }
  if ($volume | length) > 1 {
    log warning $"Somehow found multiple Volume fields in the ComicInfo.xml metadata: ($volume). Ignoring Volume fields."
    return null
  }
  let values = $volume | first | get content
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple volumes in the Volume field of the ComicInfo.xml metadata: ($values). Ignoring Volume field."
    return null
  }
  $values | first
}

# Extract the series from ComicInfo.xml metadata
#
# todo Add tests
export def series_from_comic_info []: record -> string {
  let comic_info = $in
  let series = $comic_info | get content | where tag == "Series" | get content
  if ($series | is-empty) {
    return null
  }
  if ($series | length) > 1 {
    log warning $"Somehow found multiple Series fields in the ComicInfo.xml metadata: ($series). Ignoring Series fields."
    return null
  }
  let values = $series | first | get content
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple series in the Series field of the ComicInfo.xml metadata: ($values). Ignoring Series field."
    return null
  }
  $values | first
}

# Extract the ISBN from ComicInfo.xml metadata
#
# The GTIN field stores a value that can be an ISBN.
# todo Add tests
export def isbn_from_comic_info []: record -> string {
  let comic_info = $in
  let gtin = $comic_info | get content | where tag == GTIN
  if ($gtin | is-empty) {
    return null
  }
  let isbn_numbers = ($gtin | first | get content | first | get content) | lines --skip-empty | reverse | parse_isbn
  if ($isbn_numbers | is-empty) {
    return null
  }
  if ($isbn_numbers | length) > 1 {
    log warning $"Somehow found multiple ISBN numbers in the GTIN field of the ComicInfo.xml metadata: ($isbn_numbers). Ignoring GTIN field."
    return null
  }
  $isbn_numbers | first
}

# Inject the ISBN in ComicInfo.xml metadata
#
# The GTIN field stores a value that can be an ISBN.
# todo Add tests
export def add_isbn_to_comic_info [
  isbn: string
]: record -> record {
  let comic_info = $in
  # let gtin = $comic_info | get content | where tag == GTIN
  # if ($gtin | is-empty) {
  #   (
  #     $comic_info
  #     | (
  #       let i = $in;
  #       $i
  #       | update content (
  #         $i
  #         | get content
  #         | append {
  #           tag: GTIN
  #           attributes: {}
  #           content: [
  #             [tag attributes content];
  #             [null null $isbn]
  #           ]
  #         }
  #       )
  #     )
  #   )
  # } else {
    (
      $comic_info
      | (
        let i = $in;
        $i
        | update content (
          $i
          | get content
          | where tag != "GTIN"
          | append {
            tag: "GTIN"
            attributes: {}
            content: [
              [tag attributes content];
              [null null $isbn]
            ]
          }
        )
      )
    )
  # }
}

export def upsert_comic_info [
  field: record<tag: string, value: string>
]: record -> record {
  let comic_info = $in
  (
    $comic_info
    | (
      let i = $in;
      $i
      | update content (
        $i
        | get content
        | where tag != $field.tag
        | append {
          tag: $field.tag
          attributes: {}
          content: [
            [tag attributes content];
            [null null $field.value]
          ]
        }
      )
    )
  )
}

# Extract the title from ComicInfo.xml metadata
#
# todo Add tests
export def title_from_comic_info []: record -> string {
  let comic_info = $in
  let tags = $comic_info | get content | where tag == "Title"
  if ($tags | is-empty) {
    return null
  }
  let titles = $tags | first | get content | get content
  if ($titles | is-empty) {
    return null
  }
  if ($titles | length) > 1 {
    log warning $"Somehow found multiple titles in the Title field of the ComicInfo.xml metadata: ($titles). Ignoring Title field."
    return null
  }
  $titles | first
}

# Extract the metadata from an EPUB file in the OPF format
export def opf_from_epub [
  working_directory: directory
]: path -> record {
  let epub = $in
  let opf_file = mktemp # ($epub | path parse | update  | update extension "opf" | path join)
  ^ebook-meta --to-opf $opf_file $epub
  let opf = open $opf_file | from xml
  rm $opf_file
  $opf
}

# Extract the metadata from an EPUB, CBZ, or sidecar OPF or ComicInfo.xml file
#
# The ISBN from a side-car ComicInfo.xml has the highest precedence, followed by a sidecar metadata.opf file.
# Metadata embedded in an EPUB file or a ComicInfo.xml embedded in a CBZ or ZIP archive have the lowest precedence.
# The sidecar metadata.opf and ComicInfo.xml files are assumed to reside in the same directory as the target file.
#
export def get_metadata [
  working_directory: directory # The scratch-space directory to use
]: path -> record {
  let file = $in
  let metadata = {}
  let metadata = (
    let comic_info_file = [($file | path dirname) "ComicInfo.xml"] | path join;
    if ($comic_info_file | path exists) {
      let comic_info = open $comic_info_file
      if $comic_info == null {
        $metadata
      } else {
        $metadata | insert comic_info $comic_info
      }
    } else {
      $metadata
    }
  )

  let metadata = (
    let metadata_opf_file = [($file | path dirname) "metadata.opf"] | path join;
    if ($metadata_opf_file | path exists) {
      let opf = open $metadata_opf_file | from xml
      if $opf == null {
        $metadata
      } else {
        $metadata | insert opf $opf
      }
    } else {
      $metadata
    }
  )

  let input_format = $file | path parse | get extension
  let metadata = (
    if $input_format == "epub" {
      let opf = $file | opf_from_epub $working_directory
      if $opf == null {
        $metadata
      } else {
        $metadata | upsert opf (
          if "opf" in $metadata {
            $metadata | get opf | merge $opf
          } else {
            $opf
          }
        )
      }
    } else if $input_format in ["cbz" "zip"] {
      let comic_info = $file | extract_comic_info_xml $working_directory
      if $comic_info == null {
        $metadata
      } else {
        $metadata | upsert comic_info (
          if "comic_info" in $metadata {
            $metadata | get comic_info | merge $comic_info
          } else {
            $comic_info
          }
        )
      }
    } else {
      $metadata
    }
  )

  $metadata
}

# Extract the ISBN from OPF metadata
#
# todo Add tests
export def isbn_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata" | get content
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring metadata."
    return null
  }
  let isbn = $metadata | first | where tag == "identifier" | where attributes.scheme == "ISBN"
  if ($isbn | is-empty) {
    return null
  }
  if ($isbn | length) > 1 {
    log warning $"Somehow found multiple ISBN numbers in the OPF metadata: ($metadata). Ignoring ISBN numbers."
    return null
  }
  let isbn_values = $isbn | first | get content | get content
  if ($isbn_values | is-empty) {
    return null
  }
  if ($isbn_values | length) > 1 {
    log warning $"Somehow found multiple ISBN values in the OPF metadata: ($metadata). Ignoring ISBN numbers."
    return null
  }
  let isbn_numbers = ($isbn_values | first) | lines --skip-empty | reverse | parse_isbn
  if ($isbn_numbers | is-empty) {
    return null
  }
  if ($isbn_numbers | length) > 1 {
    log warning $"Somehow parsed multiple ISBN numbers from the ISBN field of the OPF metadata: ($isbn_numbers). Ignoring ISBN numbers."
    return null
  }
  $isbn_numbers | first
}

# Extract the issue from OPF metadata
#
# todo Add tests
export def issue_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring."
    return null
  }
  let series_index = $metadata | first | get content | where tag == "meta" | where attributes.name == "calibre:series_index" | get attributes | get content
  if ($series_index | is-empty) {
    return null
  }
  if ($series_index | length) > 1 {
    log warning $"Somehow found multiple calibre:series_index field of the OPF metadata: ($series_index). Ignoring."
    return null
  }
  $series_index | first
}

# Extract the issue year from OPF metadata
#
# todo Add tests
export def issue_year_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring metadata."
    return null
  }
  let date = $metadata | first | get content | where tag == "date"
  if ($date | is-empty) {
    return null
  }
  if ($date | length) > 1 {
    log warning $"Somehow found multiple date fields in the OPF metadata: ($date). Ignoring."
    return null
  }
  let values = $date | first | get content | get content
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple values for the date field of the OPF metadata: ($values). Ignoring title field."
    return null
  }
  $values | first | into datetime | format date "%Y"
}

# Extract the issue datetime from OPF metadata
#
# todo Add tests
export def issue_datetime_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring metadata."
    return null
  }
  let date = $metadata | first | get content | where tag == "date"
  if ($date | is-empty) {
    return null
  }
  if ($date | length) > 1 {
    log warning $"Somehow found multiple date fields in the OPF metadata: ($date). Ignoring."
    return null
  }
  let values = $date | first | get content | get content
  if ($values | is-empty) {
    return null
  }
  if ($values | length) > 1 {
    log warning $"Somehow found multiple values for the date field of the OPF metadata: ($values). Ignoring title field."
    return null
  }
  $values | first | into datetime
}

# Extract the series from OPF metadata
#
# todo Add tests
export def series_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring."
    return null
  }
  let series = $metadata | first | get content | where tag == "meta" | where attributes.name == "calibre:series" | get attributes | get content
  if ($series | is-empty) {
    return null
  }
  if ($series | length) > 1 {
    log warning $"Somehow found multiple calibre:series fields of the OPF metadata: ($series). Ignoring."
    return null
  }
  $series | first
}

# Extract the series year from OPF metadata
#
# I don't know how this is actually stored in OPF metadata if it is at all.
# todo Add tests
#
# export def series_year_from_opf []: record -> string {
#   ""
# }

# Extract the title from OPF metadata
#
# todo Add tests
export def title_from_opf []: record -> string {
  let opf = $in
  let metadata = $opf | get content | where tag == "metadata"
  if ($metadata | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple metadata fields of the OPF metadata: ($metadata). Ignoring metadata."
    return null
  }
  let title = $metadata | first | get content | where tag == "title"
  if ($title | is-empty) {
    return null
  }
  if ($metadata | length) > 1 {
    log warning $"Somehow found multiple title fields of the OPF metadata: ($title). Ignoring metadata."
    return null
  }
  let titles = $title | first | get content | get content
  if ($titles | is-empty) {
    return null
  }
  if ($titles | length) > 1 {
    log warning $"Somehow found multiple Titles field of the OPF metadata: ($titles). Ignoring title field."
    return null
  }
  $titles | first
}

# Extract the ISBN from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def isbn_from_metadata [
]: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let isbn = (
    if "comic_info" in $metadata {
      $metadata.comic_info | isbn_from_comic_info
    } else {
      null
    }
  )

  if $isbn == null {
    if "opf" in $metadata {
      $metadata.opf | isbn_from_opf
    } else {
      null
    }
  } else {
    $isbn
  }
}

# Extract the issue from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def issue_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let issue = (
    if "comic_info" in $metadata {
      $metadata.comic_info | issue_from_comic_info
    } else {
      null
    }
  )

  if $issue == null {
    if "opf" in $metadata {
      $metadata.opf | issue_from_opf
    } else {
      null
    }
  } else {
    $issue
  }
}

# Extract the issue year from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def issue_year_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let issue_year = (
    if "comic_info" in $metadata {
      $metadata.comic_info | issue_year_from_comic_info
    } else {
      null
    }
  )

  if $issue_year == null {
    if "opf" in $metadata {
      let exact = $metadata.opf | issue_datetime_from_opf
      # For some reason, this appears to be a placeholder and should be ignored
      if $exact == ("2013-03-04T11:00:00+00:00" | into datetime) {
        null
      } else {
        $exact | format date "%Y"
      }
    } else {
      null
    }
  } else {
    $issue_year
  }
}

# Extract the series from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def series_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let series = (
    if "comic_info" in $metadata {
      $metadata.comic_info | series_from_comic_info
    } else {
      null
    }
  )

  if $series == null {
    if "opf" in $metadata {
      $metadata.opf | series_from_opf
    } else {
      null
    }
  } else {
    $series
  }
}

# Extract the series year from Comic Info and/or OPF metadata
#
# Don't know how to get the series year from OPF metadata, so the year can only be retrieved from Comic Info.
#
# todo Add tests.
#
export def series_year_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }
  let series_year = (
    if "comic_info" in $metadata {
      $metadata.comic_info | series_year_from_comic_info
    } else {
      null
    }
  )
}

# Extract the title from Comic Info and/or OPF metadata
#
# todo Add tests.
#
export def title_from_metadata []: record -> string {
  let metadata = $in
  if $metadata == null or ($metadata | is-empty) {
    return null
  }

  # Prefer the Comic Info metadata
  let title = (
    if "comic_info" in $metadata {
      $metadata.comic_info | title_from_comic_info
    } else {
      null
    }
  )

  if $title == null {
    if "opf" in $metadata {
      $metadata.opf | title_from_opf
    } else {
      null
    }
  } else {
    $title
  }
}

# Extract files from a zip archive
export def unzip [
  destination: directory
]: path -> path {
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
  let result = do {^unzip $archive $file -d $working_directory} | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)^unzip \"($archive)\" \"($file)\" -d \"($working_directory)\"(ansi reset)\n($result.stderr)\n"
    return null
  }
  [$working_directory $file] | path join
}

# Combine a list of audio files into a single M4B file with m4b-tool
export def merge_into_m4b [
  output_directory: directory
  ...args: string
  --audio-format: string = "m4b" # Use "opus" for opus-encoded audio and "oga" for lossless encoded audio, i.e. wav / flac.
  --audio-extension: string = "m4b"
  # --audio-bitrate: string = "128k" # Use "opus" for opus-encoded audio and "oga" for lossless encoded audio, i.e. wav / flac.
  # --audio-codec: string = "opus" # Use "opus" for opus-encoded audio and "flac" for lossless encoded audio
]: list<path> -> path {
  let files = $in
  let output_file = (
    {
      parent: $output_directory
      stem: ($output_directory | path basename)
      extension: $audio_extension
    }
    | path join
  )
  # todo do complete and error checking
  (
    ^m4b-tool merge
    --audio-format $audio_format
    --audio-extension $audio_extension
    --jobs ((^nproc | into int) / 2)
    --no-interaction
    --output-file $output_file
    ...$args
    "--"
    ...$files
  )
  $output_file
}

# Decrypt and convert an AAX file from Audible to an M4B file.
export def decrypt_audible_aax [
  activation_bytes: string # Audible activation bytes
  --working-directory: directory
]: path -> path {
  let aax = $in
  let stem = $aax | path parse | get stem
  let m4b = ({ parent: $working_directory, stem: $stem, extension: "m4b" } | path join)
  # todo do complete and error checking
  # ^ffmpeg -activation_bytes $activation_bytes -i $aax -c copy $m4b
  ^ffmpeg -activation_bytes $activation_bytes -i $aax -c:a copy -vn $m4b
  $m4b
}

# Extract the ComicInfo.xml file from an archive
export def extract_comic_info_xml [
    working_directory: directory # The scratch-space directory to use
]: path -> record {
    let archive = $in
    if not ($archive | has_comic_info) {
      return null
    }
    let comic_info_file = $archive | extract_file_from_archive "ComicInfo.xml" $working_directory
    if $comic_info_file == null {
      return null
    }
    let comic_info = $comic_info_file | open
    rm $comic_info_file
    $comic_info
}

# Extract the ComicInfo.xml file from an archive
export def extract_comic_info [
    working_directory: directory # The scratch-space directory to use
]: path -> path {
    let archive = $in
    ^unzip $archive "ComicInfo.xml" -d $working_directory
    [$working_directory "ComicInfo.xml"] | path join
}

export def has_comic_info []: [
    path -> bool
] {
  let archive = $in
  (
    $archive
    | list_files_in_archive
    | path basename
    | any {|name| $name == "ComicInfo.xml"}
  )
}

# Inject ComicInfo data into a zip archive
#
# Takes a record containing the archive and ComicInfo.xml file
export def inject_comic_info []: [
  record<archive: path, comic_info: record> -> path
] {
    let input = $in
    if ($input.archive | has_comic_info) {
        ^zip --delete $input.archive "ComicInfo.xml"
    }
    let temporary_directory = mktemp --directory
    let target = [$temporary_directory "ComicInfo.xml"] | path join
    $input.comic_info | to xml | save $target
    ^zip --junk-paths $input.archive $target
    rm $target
    rm $temporary_directory
    $input.archive
}

# Convert an Adobe Digital Editions ACSM file to an EPUB
export def acsm_to_epub [
  working_directory: directory # The scratch-space directory to use
]: [path -> path] {
  let acsm_file = $in
  log info "Closing running instance of Calibre"
  ^calibre --shutdown-running-calibre

  log info $"Importing the ACSM file (ansi yellow)($acsm_file)(ansi reset) into Calibre. This may take a bit..."
  let book_id = (
    ^calibredb add --automerge overwrite -- $acsm_file
      # todo Keep output and print in case of error?
      # err> /dev/null
    | lines --skip-empty
    | last
    | parse --regex '.* book ids: (?P<book_id>\w+)'
    | get book_id
    | first
  )
  log info $"Successfully imported into Calibre as id (ansi purple_bold)($book_id)(ansi reset)"

  log debug $"Exporting the EPUB from Calibre to (ansi yellow)($working_directory)/($book_id).epub(ansi reset)"
  (
    ^calibredb export
      --dont-asciiize
      --dont-save-cover
      --dont-save-extra-files
      --dont-write-opf
      --progress
      --template '{id}'
      --single-dir
      --to-dir $working_directory
      -- $book_id
      # err> /dev/null
  )

  log debug $"Removing EPUB format for book '($book_id)' in Calibre"
  ^calibredb remove_format $book_id EPUB
  let available_formats = (
    ^calibredb list
      --fields "formats"
      --for-machine
      --search $"id:($book_id)"
  )
  if ($available_formats | is-empty) {
    log debug $"Removing book '($book_id)' in Calibre"
    ^calibredb remove $book_id
  }

  ({ parent: $working_directory, stem: $book_id, extension: "epub" } | path join)
}

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
  let original_size = ls $jpeg | get size | first
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
  let current_size = ls $temporary_jpeg | get size | first
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

# Losslessly optimize an image with image_optim
export def image_optim []: path -> path {
  let path = $in
  log debug $"Running command: (ansi yellow)image_optim --config-paths \"\" ($path)(ansi reset)"
  let result = do {
    ^image_optim --config-paths "" --threads ((^nproc | into int) / 2) $path
  } | complete
  if ($result.exit_code != 0) {
    log error $"Exit code ($result.exit_code) from command: (ansi yellow)image_optim --config-paths \"\" ($path)(ansi reset)\nstdout:\n($result.stdout)\nstderr:\n($result.stderr)\n"
    return null
  }
  $path
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
    $path | image_optim | optimize_image_ect
  }
  $path
}

# Losslessly optimize images
export def optimize_images []: list<path> -> list<path> {
  let paths = $in

  let image_files = $paths | each {|path|
    if ($path | path type) == "dir" {
      let glob_expression = [($path | escape_special_glob_characters) "**" $"*[.]{($image_extensions | str join ',')}"] | path join
      glob --no-dir --no-symlink $glob_expression
    } else {
      $path
    }
  } | flatten

  let original_size = $image_files | reduce --fold 0b {|it acc|
    $acc + (ls $it | get size | first)
  }
  $image_files | each {|image|
    $image | optimize_image
  }
  let current_size = $image_files | reduce --fold 0b {|it acc|
    $acc + (ls $it | get size | first)
  }

  if $current_size < $original_size {
    let average = (($original_size + $current_size) / 2)
    let percent_difference = ((($original_size - $current_size) / $average) * 100)
    log info $"Images optimized down from a size of (ansi purple)($original_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size."
  } else {
    log debug $"No space saving achieved attempting to optimize the images"
  }

  $image_files
}

# Losslessly optimize the images in a ZIP archive such as an EPUB or CBZ
export def optimize_images_in_zip []: path -> path {
  let archive = ($in | path expand)
  let original_size = ls $archive | get size | first
  log debug $"Optimizing images in (ansi yellow)($archive)(ansi reset)"
  let temporary_directory = (mktemp --directory)
  let extraction_path = ($temporary_directory | path join "extracted")
  log debug $"Extracting zip archive to (ansi yellow)($extraction_path)(ansi reset)"
  ^unzip -q $archive -d $extraction_path
  ^chmod --recursive +rw $extraction_path
  [$extraction_path] | optimize_images
  log debug "Image optimization complete"
  log debug $"Compressing directory (ansi yellow)($extraction_path)(ansi reset) as (ansi yellow)($archive)(ansi reset)"
  let temporary_archive = $archive | path parse | update parent $temporary_directory | path join
  rm --force $temporary_archive
  cd $extraction_path
  log debug $"Running (ansi yellow)^zip --quiet --recurse-paths ($temporary_archive) .(ansi reset)"
  ^zip --quiet --recurse-paths $temporary_archive .
  cd -
  mv --force $temporary_archive $archive
  rm --force --recursive $temporary_directory
  log debug $"Finished compressing (ansi yellow)($archive)(ansi reset)"
  let current_size = ls $archive | get size | first
  if $current_size < $original_size {
    let average = (($original_size + $current_size) / 2)
    let percent_difference = ((($original_size - $current_size) / $average) * 100)
    log debug $"Images in ZIP archive (ansi yellow)($archive)(ansi reset) optimized down from a size of (ansi purple)($original_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size."
  } else {
    log debug $"No space saving achieved attempting to optimize the images in the ZIP archive (ansi yellow)($archive)(ansi reset)"
  }
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

# Optimize a ZIP archive using efficient-compression-tool
# todo Use a temporary file to avoid corruption
export def optimize_zip_ect [
  optimization_level: int = 9 # The degree to which to optimize the zip archive from 1 to 9, with 9 being the best compression possible
  ...args: string # Extra arguments to pass to advzip
]: path -> path {
  let archive = $in
  let original_size = ls $archive | get size | first
  log debug $"Running (ansi yellow)^ect -($optimization_level) -strip -zip --mt-deflate ($args | str join ' ') ($archive)(ansi reset)"
  let result = do {^ect $"-($optimization_level)" -strip -zip --mt-deflate ...$args $archive} | complete
  if $result.exit_code != 0 {
    log error $"Error running (ansi yellow)^ect -($optimization_level) -strip -zip --mt-deflate ($args | str join ' ') ($archive)(ansi reset)\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  let current_size = ls $archive | get size | first
  if $current_size < $original_size {
    let average = (($original_size + $current_size) / 2)
    let percent_difference = ((($original_size - $current_size) / $average) * 100)
    log info $"ZIP archive (ansi yellow)($archive)(ansi reset) optimized down from a size of (ansi purple)($original_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size."
  } else {
    log debug $"No space saving achieved attempting to optimize the zip archive (ansi yellow)($archive)(ansi reset)"
  }
  $archive
}

# Losslessly optimize the compression of a zip archive as well as image files in it.
#
# Uses image_optim to optimize image files.
export def optimize_zip [
  optimization_level: int = 9 # The degree to which to optimize the zip archive from 1 to 9, with 9 being the best compression possible
]: path -> path {
  let $archive = $in
  log debug $"Optimizing ZIP archive (ansi yellow)($archive)(ansi reset)"
  let original_size = ls $archive | get size | first
  let output = $archive | optimize_images_in_zip
  if ($output | is-empty) {
    return null
  }
  let archive = $output | optimize_zip_ect $optimization_level
  let current_size = ls $archive | get size | first
  if $current_size < $original_size {
    let average = (($original_size + $current_size) / 2)
    let percent_difference = ((($original_size - $current_size) / $average) * 100)
    log info $"ZIP archive (ansi yellow)($archive)(ansi reset) optimized down from a size of (ansi purple)($original_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size."
  } else {
    log debug $"No space saving achieved attempting to optimize the zip archive (ansi yellow)($archive)(ansi reset)"
  }
  log debug $"Finished Optimizing ZIP archive (ansi yellow)($archive)(ansi reset)"
  $archive
}

# Losslessly optimize a PDF using minuimus and pdfsizeopt.
#
# This can take a long time, so systemd-inhibit is used to ensure the system doesn't sleep.
# todo Use minuimus / pdfsizeopt to optimize PDFs
export def optimize_pdf [
  ...args: string # Arguments to pass to minuimus.pl
]: path -> path {
  let $pdf = $in
  let original_size = ls $pdf | get size | first
  let start = date now
  let result = do {^systemd-inhibit --what=sleep:shutdown --who="Media Juggler" --why="Running expensive file optimizations" minuimus.pl ...$args $pdf} | complete
  let duration = (date now) - $start
  if $result.exit_code != 0 {
    log info $"Error running '^systemd-inhibit minuimus.pl (...$args) ($pdf)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  let current_size = ls $pdf | get size | first
  let average = (($original_size + $current_size) / 2)
  let percent_difference = ((($original_size - $current_size) / $average) * 100)
  if $current_size < $original_size {
    log info $"PDF (ansi yellow)($pdf)(ansi reset) optimized down from a size of (ansi purple)($original_size)(ansi reset) to (ansi purple)($current_size)(ansi reset), a (ansi green)($percent_difference)%(ansi reset) decrease in size in (ansi green)($duration)(ansi reset)."
  } else {
    log debug $"No space saving achieved attempting to optimize the PDF (ansi yellow)($pdf)(ansi reset). Optimization lasted (ansi green)($duration)(ansi reset)"
  }
  $pdf
}

# Optimize and clean up an EPUB with Calibre
export def polish_epub []: [path -> path] {
    let epub = $in;
    (
        ^ebook-polish
            --download-external-resources
            --remove-unused-css
            --subset-fonts
            --upgrade-book
            $epub
            $epub
            # err> /dev/null
    )
    $epub
}

# Convert an EPUB to a CBZ
export def epub_to_cbz [
    --working-directory: directory # Directory to work in
]: path -> path {
    let epub = $in
    let cbz = ({ parent: $working_directory, stem: ($epub | path parse | get stem), extension: "cbz" } | path join)

    log debug $"Extracting contents of the EPUB (ansi yellow)($epub)(ansi reset) to (ansi yellow)($working_directory)/epub(ansi reset)"
    ^unzip -q $epub -d ($working_directory | path join "epub")

    let image_files = (glob --no-dir --no-symlink $"($working_directory)/epub/**/*.{($image_extensions | str join ',')}") | sort | path parse
    if ($image_files | is-empty) {
      log error $"No images found under the directory (ansi yellow)($working_directory)/epub/(ansi reset)"
      return null
    }

    let covers = $image_files | where stem =~ 'cover'
    let pages = $image_files | where stem !~ 'cover'
    let pages = $covers | append $pages

    let number_of_digits = (($pages | length) - 1) | into string | str length

    let image_subdirectory = (mktemp --directory)
    log debug $"Organizing images for the CBZ file in the directory (ansi yellow)($image_subdirectory)(ansi reset)"

    # Rename everything for consistency.
    let pages = (
      $pages | enumerate | each {|p|
        let old_page = $p.item | path join
        let new_page = {
          parent: $image_subdirectory
          stem: (
            "page_" + ($p.index | fill --alignment r --character '0' --width $number_of_digits)
          )
          extension: $p.item.extension
        } | path join
        mv --no-clobber $old_page $new_page
        $new_page
      }
    )
    log debug $"Pages (ansi yellow)($pages)(ansi reset)"
    log debug $"Compressing the contents of the directory (ansi yellow)($image_subdirectory)(ansi reset) into the CBZ file (ansi yellow)($cbz)(ansi reset)"
    log debug $"Running command: ^zip -jqr ($cbz) ($image_subdirectory)"
    ^zip -jqr $cbz $image_subdirectory
    rm --force --recursive ($working_directory | path join "epub")
    rm --force --recursive $image_subdirectory
    $cbz
}

# Convert an PDF to a CBZ
export def pdf_to_cbz [
    --working-directory: directory # Directory to work in
]: path -> path {
    let pdf = $in
    let cbz = ({ parent: $working_directory, stem: ($pdf | path parse | get stem), extension: "cbz" } | path join)

    # https://lonm.vivaldi.net/2022/11/16/converting-comics-from-pdf-into-cbz-format/
    # pdfimages -png -j -p $pdf $images_directory
    # mutool convert -F cbz ../../attackontitan_beforethefall_vol9.pdf
    # Convert to jxl

    log debug $"Extracting contents of the PDF (ansi yellow)($pdf)(ansi reset) to (ansi yellow)($working_directory)/epub(ansi reset)"
    ^unzip -q $pdf -d ($working_directory | path join "pdf")

    let image_files = (glob $"($working_directory)/epub/**/*.{avif,bmp,jpeg,jpg,jxl,png,tiff,webp}")
    let image_file_extension = ($image_files | first | path parse | get extension)
    let image_subdirectory = ($image_files | first | path parse | get parent)
    let image_format = (
        if $image_file_extension == "jpg" {
            "jpeg"
        } else {
            $image_file_extension
        }
    )

    # todo Verify the cover is indeed the first page in the archive.
    # Especially for the bonking sorting order used by ComicTagger.
    if ($"($image_subdirectory)/page_cover.($image_file_extension)" | path exists) {
        log debug $"Renaming ($image_subdirectory)/page_cover.($image_file_extension) to ($image_subdirectory)/cover.($image_file_extension) to avoid the cover not being detected as the first page"
        mv $"($image_subdirectory)/page_cover.($image_file_extension)" $"($image_subdirectory)/cover.($image_file_extension)"
    }
    log debug $"Compressing the contents of the directory (ansi yellow)($image_subdirectory)(ansi reset) into the CBZ file (ansi yellow)($cbz)(ansi reset)"
    ^zip -jqr $cbz $image_subdirectory
    rm --force --recursive $"($working_directory)/epub"
    $cbz
}

# Parse metadata from a comic file name
#
# <series> (<series_year>) #<issue> (<issue_year>)
export def metadata_from_comic_filename []: path -> record {
  let file = $in
  let stem = $file | path parse | get stem
  let metadata = (
    $stem
    | parse --regex '(?P<series>.+?)\s+(?:\((?P<series_year>[0-9]+)\)\s+){0,1}#(?P<issue>[0-9]+)(?:\s+\((?P<issue_year>[0-9]+)\)){0,1}'
  )
  if ($metadata | is-empty) {
    null
  } else {
    $metadata | first
  }
}

# Incorporate metadata for ComicTagger in the filename.
export def comic_file_name_from_metadata [
    working_directory: directory
    --issue: string
    --issue-year: string
    --series: string
    --series-year: string
]: path -> path {
    let file = $in
    let metadata = $file | get_metadata $working_directory
    let title = $metadata | title_from_metadata
    if $title != null {
      log debug $"Title from metadata: ($title)"
    }
    let series = (
      if $series == null {
        $metadata | series_from_metadata
      } else {
        $series
      }
    )
    let series_year = (
      if $series_year == null {
        $metadata | series_year_from_metadata
      } else {
        $series_year
      }
    )
    let issue = (
      if $issue == null {
        $metadata | issue_from_metadata
      } else {
        $issue
      }
    )
    let issue_year = (
      if $issue_year == null {
        $metadata | issue_year_from_metadata
      } else {
        $issue_year
      }
    )

    let filename_metadata = $file | metadata_from_comic_filename
    let series = (
      if $series == null {
        if $filename_metadata == null {
          null
        } else {
          $filename_metadata | get series
        }
      } else {
        $series
      }
    )
    let series_year = (
      if $series_year == null {
        if $filename_metadata == null {
          null
        } else {
          $filename_metadata | get series_year
        }
      } else {
        $series_year
      }
    )
    let issue = (
      if $issue == null {
        if $filename_metadata == null {
          null
        } else {
          $filename_metadata | get issue
        }
      } else {
        $issue
      }
    )
    let issue_year = (
      if $issue_year == null {
        if $filename_metadata == null {
          null
        } else {
          $filename_metadata | get issue_year
        }
      } else {
        $issue_year
      }
    )

    let parsed_title = (
      if $title == null {
        null
      } else {
        if ($title | str contains "Volume") {
            (
                $title
                | parse --regex '(?P<series>.+) Volume (?P<issue>[0-9]+)'
                | first
            )
        } else if ($title =~ '.*[\s,_]+[vV][oO][lL]\.*\s*[0-9]+') {
            (
                $title
                | parse --regex '(?P<series>.+?)[\s,_]+[vV][oO][lL]\.*\s*(?P<issue>[0-9]+)'
                | first
            )
        } else if $title =~ ".+ [0-9]+" {
          $title
          | parse --regex '(?P<series>.+) (?P<issue>[0-9]+)'
          | first
        } else {
          { series: $title, issue: 1 }
        }
      }
    )
    if $parsed_title != null {
      log debug $"Parsed the title as (ansi purple)($parsed_title)(ansi reset)"
    }

    let series = (
      if $series == null {
        if $parsed_title == null {
          null
        } else {
          log debug $"Parsed the series as (ansi purple)'($parsed_title.series)'(ansi reset) from the title"
          $parsed_title.series
        }
      } else {
        $series
      }
    )
    let issue = (
      if $issue == null {
        if $parsed_title == null {
          null
        } else {
          log debug $"Parsed the issue as (ansi purple)'($parsed_title.issue)'(ansi reset) from the title"
          $parsed_title.issue
        }
      } else {
        $issue
      }
    )

  if $series == null and $issue == null {
    log error $"Unable to determine the series and issue from the metadata title '($title)'. Pass the Comic Vine issue id with the (ansi green)--comic-vine-issue-id(ansi reset) flag."
    $file
  } else {
    $file | path parse | update stem $"($series) \(($series_year)\) #($issue) \(($issue_year)\)" | path join
  }
}

# Convert a FLAC to an OGA
#
# ffmpeg drops embedded cover art.
export def flac_to_oga [
  output_directory: directory
  ...args: string # Arguments to pass to opusenc
]: path -> path {
  let flac = $in
  let output_file = $flac | path parse | update parent $output_directory | update extension "oga" | path join
  # ^opusenc $flac $output_file
  ^ffmpeg -i $flac -c:a copy ...$args $output_file
  $output_file
}

# Transcode a lossy audio format to OPUS
#
# Converting between lossy formats further degrades quality and can introduce artifacts.
# ffmpeg drops embedded cover art.
# For lossless formats, prefer using opusenc instead of ffmpeg.
export def ffmpeg_transcode_to_opus [
  output_directory: directory
  # bitrate: string = "128k" # Audio bitrate with which to encode
  ...args: string # Arguments to pass to opusenc
]: path -> path {
  let file = $in
  let output_file = $file | path parse | update parent $output_directory | update extension "opus" | path join
  # -b:a $bitrate
  ^ffmpeg -i $file -vn -c:a libopus ...$args $output_file
  $output_file
}

# List the files in a zip archive
export def list_files_in_archive []: path -> list<path> {
  let archive = $in
  (
    ^unzip -l $archive
    | lines
    | drop nth 0 1
    | drop 2
    | str trim
    | parse "{length}  {date} {time}   {name}"
    | get name
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

# Get the image extension used in a comic book archive
export def get_image_extension []: path -> string {
  let cbz = $in
    let file_extensions = (
        $cbz
        | list_files_in_archive_with_extensions $image_extensions
        | path parse
        | get extension
        | filter {|extension| not ($extension | is-empty) }
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

# Fetch metadata for the EPUB using Comic Vine and embed it
#
# The metadata for Authors and Title from the Comic Vine Calibre plugin are corrected here.
# The title includes the issue number twice in the name, which is kind of ugly, so that is fixed.
# All creators are tagged as authors which is incorrect.
# To accommodate this, authors must be passed directly.
#
export def tag_epub_comic_vine [
    comic_vine_issue_id: string # The unique Comic Vine id for the issue
    authors: list<string> # A list of authors to use
    title: string # The title to use
    --working-directory: directory
]: path -> path {
    let epub = $in
    let opf_file = ({ parent: $working_directory, stem: $comic_vine_issue_id, extension: "opf" } | path join)
    let opf = (
      ^fetch-ebook-metadata
        --allowed-plugin "Comicvine"
        --identifier $"comicvine:($comic_vine_issue_id)"
        --opf
      | from xml
    )
    log debug $"The opf metadata for Comic Vine issue id (ansi purple_bold)($comic_vine_issue_id)(ansi reset) is:\n($opf)\n"
    # todo edit XML directly?
    (
      $opf
      | to xml
      | save --force $opf_file
    )
    (
      ^ebook-meta
        $epub
        --authors ($authors | str join "&")
        --from-opf $"($working_directory)/($comic_vine_issue_id).opf"
        --title $title
    )
    rm $opf_file
    $epub
}

# Fetch metadata for an ebook
export def fetch-ebook-metadata [
    ...args: string
    # Remove Comicvine because it can cause trouble, although it does have entries for some Light Novels apparently.
    --allowed-plugins: list<string> = ["Kobo Metadata" Goodreads Google "Google Images" "Amazon.com" Edelweiss "Open Library" "Big Book Search"] # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
    # --allowed-plugins: list<string> = [Google "Amazon.com"] # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
    --authors: list<string> # A list of authors to use
    --cover: path # Path to which to download the cover
    --identifiers: list<string> # A list of identifiers
    --isbn: string # The ISBN of the book
    --title: string # The title to use
]: nothing -> record<opf: record, cover: path> {
  let allowed_plugins = (
    if $allowed_plugins == null {
      null
    } else {
      $allowed_plugins | par-each {|plugin| $"--allowed-plugin=($plugin)"}
    }
  )
  let authors = (
    if $authors == null {
      null
    } else {
      $authors | str join "&" | $"--authors=($in)"
    }
  )
  let identifiers = (
    if $identifiers == null {
      null
    } else {
      $identifiers | par-each {|identifier| $"--identifier=($identifier)"}
    }
  )
  let isbn = (
    if $isbn == null {
      null
      # log error "fetch-ebook-metadata currently requires that an ISBN be provided to avoid pulling in the wrong data."
      # exit 1
    } else {
      $"--isbn=($isbn)"
    }
  )
  let title = (
    if $title == null {
      null
    } else {
      $"--title=($title)"
    }
  )
  let cover_arg = (
    if $cover == null {
      null
    } else {
      $"--cover=($cover)"
    }
  )
  let args = (
    $args
    | append "--opf"
    | append $allowed_plugins
    | append $authors
    | append $cover_arg
    | append $identifiers
    | append $isbn
    | append $title
  )
  # let result = ^fetch-ebook-metadata ...$args | complete
  # let opf = $result.stdout | from xml
  log debug $"Running: fetch-ebook-metadata ($args | str join ' ')"
  let opf = (
    let result = (^fetch-ebook-metadata ...$args | complete);
    if $result.exit_code == 0 {
      $result.stdout | from xml
    } else if ($result.stderr | lines --skip-empty | last) == "No results found" {
      log debug $"(ansi red)No metadata found!(ansi reset)"
      null
    } else {
      log error $"fetch-ebook-metadata failed with the exit code (ansi red)($result.exit_code)(ansi reset): ($result.stderr)"
      null
    }
  )
  {
    opf: $opf,
    cover: (
      if $cover == null {
        null
      } else {
        $cover | rename_image_with_extension
      }
    )
  }
}

export def extract_book_metadata [
  working_directory: directory
]: path -> record<opf: record, cover: path> {
  let book = $in
  log debug $"book: ($book)"
  let opf_file = mktemp --suffix ".xml" --tmpdir
  # let opf_file = (
  #   {
  #     parent: $working_directory
  #     # stem: ($book | path parse | get stem)
  #     # stem: "metadata"
  #     extension: "opf"
  #   } | path join
  # )
  log debug $"opf: ($opf_file)"
  let cover_file = (
    {
      parent: $working_directory,
      stem: ([($book | path parse | get stem) "-cover"] | str join),
    } | path join
  )
  (
    ^ebook-meta
    --get-cover $cover_file
    --to-opf $opf_file
    $book
  )
  # todo Remove title == "Untitled" and creator == "Unknown"?
  let opf = $opf_file | open
  rm $opf_file
  {
    opf: $opf
    cover: ($cover_file | rename_image_with_extension)
  }
}

# # Use the metadata.opf and cover.ext files for metadata
# export def get_metadata_from_opf [
#   --working-directory: directory
# ]: path -> record<opf: record, cover: path> {
#   let book = $in;
#   let opf_file = ({ parent: $working_directory, stem: ($book | path parse | get stem), extension: "opf" } | path join)
#   let cover_file = ({ parent: $working_directory, stem: ($book | path parse | get stem | $"($in)-cover"), extension: "" } | path join)
#   (
#     ^ebook-meta
#     --get-cover $cover_file
#     --to-opf $opf_file
#     $book
#   )
#   # todo Remove title == "Untitled" and creator == "Unknown"?
#   { opf: ($opf_file | open | from xml), cover: ($cover_file | rename_image_with_extension) }
# }

# Rename an image with the proper extension for its file type
export def rename_image_with_extension [] : path -> path {
  let old = $in
  let components = $old | path parse
  let file_type = ^file --brief $old | split words | first | str downcase
  let new = $old | path parse | update extension $file_type | path join
  mv $old $new
  $new
}

# export def update_book_metadata [
export def fetch_book_metadata [
  working_directory: directory
  --allowed-plugins: list<string>
  --authors: list<string>
  --identifiers: list<string>
  --isbn: string
  --title: string
]: path -> record<book: path, cover: path, opf: record> {
  let book = $in
  # todo Check for metadata.opf and cover.ext files
  # todo Use ComicInfo.xml as well here?
  # Prefer metadata.opf and cover.ext over embedded metadata and cover
  let current = (
    $book
    | extract_book_metadata $working_directory
    | (
      let input = $in;
      let metadata_opf = $book | path dirname | path join "metadata.opf";
      if ($metadata_opf | path exists) {
        $input | update opf (
          $input | merge (open $metadata_opf | from xml)
        )
      } else {
        $input
      }
    )
    | (
      let input = $in;
      let covers = (
        ls ($book | path dirname)
        | get name
        | filter {|f|
          let components = $f | path parse
          $components.stem == "cover" and $components.extension in $image_extensions
        }
      );
      if ($covers | is-empty) {
        $input
      } else if ($covers | length) > 1 {
        log error $"Found multiple files looking for the cover image file:\n($covers)\n"
        exit 1
      } else {
        if ($covers | first | path exists) {
          $input | update cover ($covers | first)
        } else {
          $input
        }
      }
    )
  )
  let all_opf_identifiers = (
      $current.opf
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "identifier"
  )
  let isbn = (
    if $isbn == null and ($all_opf_identifiers != null) {
      let all_opf_isbn = (
        $all_opf_identifiers
        | where attributes.scheme == "ISBN"
      )
      if ($all_opf_isbn | is-empty) {
        null
      } else {
        $all_opf_isbn
        | first
        | get content
        | first
        | get content
      }
    } else {
      $isbn
    }
  )
  # if $isbn == null {
  #   log error "fetch_book_metadata currently requires an ISBN to avoid pulling in the wrong data."
  #   exit 1
  # }
  let identifiers = (
    # todo Merge identifiers?
    if $isbn == null and ($all_opf_identifiers != null) {
      let all_opf_non_isbn = (
        $all_opf_identifiers
        | where attributes.scheme != "ISBN"
      )
      if ($all_opf_non_isbn | is-empty) {
        null
      } else {
        $all_opf_non_isbn
        | par-each {|identifier|
          let scheme = $identifier.attributes.scheme;
          let id = $identifier.content | get first | get content;
          { $"($scheme):($id)" }
        }
      }
    } else {
      $identifiers
    }
  )
  let identifier_flags = (
    if $identifiers == null {
      null
    } else {
      $identifiers | par-each {|identifier| $"--identifier=($identifier)" }
    }
  )
  let isbn_flag = (
    if $isbn == null {
      null
    } else {
      $"--isbn=($isbn)"
    }
  )
  let title = (
    if $title == null {
      $current.opf
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "title"
      | first
      | get content
      | first
      | get content
    } else {
      $title
    }
  )
  let title_flag = (
    if $title == null {
      null
    } else {
      $"--title=($title)"
    }
  )
  let authors = (
    if $authors == null {
      $current.opf
      | get content
      | where tag == "metadata"
      | first
      | get content
      | where tag == "creator"
      | where attributes.role == "aut"
      | par-each {|creator| $creator | get content | first | get content }
      | sort
    } else {
      $authors
    }
  )
  let authors_flag = (
    if $authors == null {
      null
    } else {
      $"--authors=($authors | str join '&')"
    }
  )
  let args = (
    # [ --opf ]
    []
    | (
      let input = $in;
      $input
      | append $isbn_flag
      | append $authors_flag
      | append $title_flag
      | append $identifier_flags
      # | append (
      #   if $isbn == null {
      #     $authors_flag
      #   }
      # )
      # | append (
      #   if $isbn == null {
      #     $title_flag
      #   }
      # )
      # | append (
      #   if $isbn == null {
      #     $identifier_flags
      #   }
      # )
    )
  )
  let updated = (
    # Prefer using the current cover if there is one
    # todo I should probably prefer the highest resolution cover if it is similar to the current one.
    if $current.cover == null {
      (
        fetch-ebook-metadata
        --allowed-plugins $allowed_plugins
        --cover (
          {
            parent: $working_directory
            stem: ($book | path parse | get stem | $"($in)-fetched-cover")
            extension: ""
          } | path join
        )
        ...$args
      )
    } else {
      fetch-ebook-metadata --allowed-plugins $allowed_plugins ...$args
    }
  )
  # todo Check if cover is empty or not found?
  let cover_file = (
    if $current.cover == null {
      $updated.cover
    } else {
      $current.cover
    }
  )
  $cover_file | optimize_image
  {
    book: $book
    opf: $updated.opf
    cover: $cover_file
  }
}

# Export the book, OPF, and cover files to a directory named after the book
export def export_book_to_directory [
  working_directory: path
]: [
  record<book: path, cover: path, opf: record>
  ->
  record<book: path, cover: path, opf: path>
] {
  let input = $in
  let title = (
    $input.opf
    | get content
    | where tag == "metadata"
    | first
    | get content
    | where tag == "title"
    | first
    | get content
    | first
    | get content
  )
  # todo Handle missing title?
  let sanitized_title_for_filename = $title | str replace --all "/" "-"
  let target_directory = [$working_directory $sanitized_title_for_filename] | path join
  mkdir $target_directory
  let opf = (
    {
      parent: $target_directory
      stem: "metadata"
      extension: "opf"
    } | path join
  )
  (
    $input.opf
    | to xml
    | save --force $opf
  )
  let cover = (
    $input.cover
    | path parse
    | update parent $target_directory
    | update stem "cover"
    | path join
  )
  let book = (
    $input.book
    | path parse
    | update parent $target_directory
    | update stem $sanitized_title_for_filename
    | path join
  )
  mv $input.cover $cover
  log debug $"Renaming book from (ansi yellow)($input.book)(ansi reset) to (ansi yellow)($book)(ansi reset)"
  mv $input.book $book
  log debug $"Book contents in the directory (ansi purple)($target_directory)(ansi reset)";
  {
    book: $book
    opf: $opf
    cover: $cover
  }
}

# todo Pass around opf as metadata instead of a file path.
export def embed_book_metadata []: [
  record<book: path, cover: path, opf: path> -> record<book: path, cover: path, opf: path>
] {
  let input = $in
  let book_format = ($input.book | path parse | get extension)
  if $book_format in ["epub" "pdf"] {
    ^ebook-meta $input.book --cover $input.cover --from-opf $input.opf
  }
  $input
}

# export def tag_epub [
#     # --allowed-plugins: list<string> # Allowed metadata plugins, i.e. [Comicvine, Google, Google Images, Amazon.com, Edelweiss, Open Library, Big Book Search]
#     # --authors: list<string> # A list of authors to use
#     # --cover: path # Path to which to download the cover
#     # --identifiers: list<string> # A list of identifiers
#     # --isbn: string # The unique ComicVine id for the issue
#     # --title: string # The title to use
#     --working-directory: directory
# ]: record<epub: path, opf: record, cover: path> -> path {
#     let epub = $in
#     # let opf_file = ({ parent: $working_directory, stem: ($epub | path parse | get stem), extension: "opf" } | path join)
#     # let cover = ({ parent: $working_directory, stem: ($epub | path parse | get stem), extension: "opf" } | path join)
#     let result = fetch-ebook-metadata
#     log debug $"The fetched metadata for the book (ansi purple_bold)($epub)(ansi reset) is:\n($result.opf)\n"
#     (
#         $result.opf
#         | to xml
#         | save --force $opf_file
#     )
#     (
#         ^ebook-meta
#             $epub
#             # --authors ($authors | str join "&")
#             # --cover
#             --from-opf $"($working_directory)/($comic_vine_issue_id).opf"
#             # --title $title
#     )
#     rm $opf_file
#     # rm $cover
#     $epub
# }

# Convert images in a CBZ to lossless JXL.
# JXL should be a great archival format going forward and is a significant reduction in size over JPEG, even using lossless compression.
# AVIF is an alternative format which could be used for archival purposes.
# I decided to go with JXL, but haven't looked into both formats exhaustively.
#
# CBconvert uses lossless encoding when the quality is set to 100.
# The intent is for this to be archival quality.
# The EPUB is saved to ensure that the original source material remains intact, just in case I messed something up in the conversion process.
#
# Unfortunately, the JXL format isn't supported by KOReader yet.
#
# Okay, so, updating CBConvert to 1.1.0 results in proper JXL lossless compression I'm pretty sure.
# However, it results in significantly larger files than the source JPEGs.
# I'll probably only want to use JXL when the source files are PNGs.
export def convert_to_lossless_jxl []: path -> path {
    let input_file = $in
    let components = ($input_file | path parse)
    let original_size = (ls $input_file | first | get size)
    let file = (
        $input_file | cbconvert
            --format "jxl"
            --quality 100 # lossless

    )
    let current_size = (ls $file | first | get size)
    let average = (($original_size + $current_size) / 2)
    let percent_difference = ((($original_size - $current_size) / $average) * 100)
    let size_table = [[original current "% difference"]; [$original_size $current_size $percent_difference]]
    log info $"Converted (ansi yellow)($input_file)(ansi reset) to (ansi yellow)($file)(ansi reset) to JPEG-XL: ($size_table)"
    if $current_size > $original_size {
      log warning "JPEG-XL comic archive increased in size compared to the original input file!"
    }
    $file
}

# Convert a copy for my primary e-reader:
# Kobo Elipsa 2E: 1404x1872 (Gamma 1.8).
# todo I'm not sure this is even really necessary
# Using the correct resolution does seem to result in much faster page loads.
# Although, maybe that's due to using webp?
# I should verify.
export def cbconvert [
    suffix: string = "" # Suffix to add to the CBZ filename
    --format: string # The image format to convert to
    --height: string # The height of the converted images
    --quality: string # The quality setting to use for the encoder
    --width: string # The width of the converted images
]: path -> path {
    let file = $in
    let components = ($file | path parse)
    # todo Use some sort of wrapper to print out command-line of command being run?
    # todo This doesn't work right with jpegs.
    if $height == null and $width == null {
        log debug $"Running command: cbconvert --filter 7 --format ($format) --height ($height) --outdir ($components.parent) --quality ($quality) --suffix ($suffix) --width ($width) ($file)"
        (
            ^cbconvert convert
                --filter 7 # Use the highest quality resampling filter.
                --format $format
                --outdir $components.parent
                --quality $quality
                --suffix $suffix
                $file
        )
    } else {
        log debug $"Running command: cbconvert --filter 7 --format ($format) --height ($height) --outdir ($components.parent) --quality ($quality) --suffix ($suffix) --width ($width) ($file)"
        (
            ^cbconvert convert
                --filter 7 # Use the highest quality resampling filter.
                --fit
                --format $format
                --height $height
                --outdir $components.parent
                --quality $quality
                --suffix $suffix
                --width $width
                $file
        )
    }
    $components | { parent: $components.parent, stem: ($components.stem + $suffix), extension: "cbz" } | path join
}

# Convert a copy for my primary e-reader:
# Kobo Elipsa 2E: 1404x1872 (Gamma 1.8).
# todo I'm not sure this is even really necessary
# Using the correct resolution does seem to result in much faster page loads.
# Although, maybe that's due to using webp?
# I should verify.
export def convert_for_ereader [
    ereader: string
    working_directory: directory
]: path -> path {
    let file = $in
    let suffix = ("_" + ($ereader | str replace --all " " "_" | str downcase))
    let components = ($file | path parse)
    let input_format = $components.extension

    let image_format = (
        if $input_format in ["cbz" "epub" "zip"] {
            let image_extension = ($file | get_image_extension);
            if ($image_extension == null) {
                log error "Failed to determine the image file format"
                exit 1
            }
            $image_extension
        } else {
            null
        }
    )

    # todo Use KCC for PDFs too?

    # Use KCC because it won't look right when converting jpegs with cbconvert 1.1.0.
    if $image_format in ["jpeg" "jpg"] {
        (
            let components = ($file | path parse);
            let temp = (
                {
                    parent: $working_directory,
                    stem: $components.stem,
                    extension: $components.extension
                }
                | path join
            );
            cp $file $temp;
            let components = ($temp | path parse);
            let kcc_output = (
                {
                    parent: $components.parent,
                    stem: ($components.stem + "_kcc0"),
                    extension: $components.extension
                }
                | path join
            );
            let output = (
                {
                    parent: $components.parent,
                    stem: ($components.stem + $suffix),
                    extension: $components.extension
                }
                | path join
            );
            log debug $"Running command: flatpak run --command=kcc-c2e io.github.ciromattia.kcc --profile KoE --manga-style --forcecolor --format CBZ --output '($temp)' --targetsize 10000 --upscale '($temp)'";
            (^flatpak run --command=kcc-c2e io.github.ciromattia.kcc --profile KoE --manga-style --forcecolor --format CBZ --output $temp --targetsize 10000 --upscale $temp);
            mv $kcc_output $output;
            rm $temp;
            $output
        )
    } else {
        (
            $file
            | cbconvert $suffix
                # Alternatively, PNG could also be used for PDFs i.e. when image_format is null.
                --format (if $image_format in [ "avif" "jxl" "png", ] { "png" } else { "jpeg" })
                --height ($ereader_profiles | where model == $ereader | first | get height)
                --quality 100
                --width ($ereader_profiles | where model == $ereader | first | get width)
        )
    }
    # The output is always a CBZ file.
    $components | update stem ($components.stem + $suffix) | update extension "cbz" | path join
}

# Apparently no sanitization needs to be done?
export def sanitize_minio_filename []: string -> string {
    # $in | str replace --all "!" ""
    $in
}

# Parse series from the group metadata tag
#
# audiobookshelf stores series in a semicolon-separated list in the group field
# The index in the series is preceded by a hash sign.
export def parse_series_from_group []: string -> table<name: string, index: string> {
  $in | split row ";" | str trim | each {|series|
    if "#" in $series {
      $series | parse '{name} #{index}'
    } else {
      [[name index]; [$series null]]
    }
  } | flatten
}

# Parse series from the series / series-part and mvnm / mvin tags from the additionalFields metadata
#
# todo audiobookshelf now supports multiple series in these tags, so this function should too.
export def parse_series_from_series_tags []: record -> table<name: string, index: string> {
  let additionalFields = $in
  if "mvnm" in $additionalFields and $additionalFields.mvnm != null {
    [
      [name index];
      [
        ($additionalFields.mvnm | into string)
        (
          if "mvin" in $additionalFields and $additionalFields.mvin != null {
            $additionalFields.mvin | into string
          }
        )
      ]
    ]
  } | append (
    if "series" in $additionalFields and $additionalFields.series != null {
      [
        [name index];
        [
          ($additionalFields.series | into string)
          (
            if "series-part" in $additionalFields and $additionalFields.series-part != null {
              $additionalFields.series-part | into string
            }
          )
        ]
      ]
    }
  ) | (let i = $in; if ($i | is-empty) {null} else {$i})
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

export const release_only_contributor_roles = [distributor illustrator publisher]

# Parse audiobook metadata from tone for a single file into a standard format
#
# todo Parse using a generic schema?
export def parse_audiobook_metadata_from_tone []: record -> record {
  let all_metadata = $in
  # log info $"all_metadata: ($all_metadata)"
  let metadata = $all_metadata | get meta
  # log info $"metadata: ($metadata)"
  let series = (
    let group_series = (
      if "group" in $metadata {
        $metadata.group | parse_series_from_group
      }
    );
    let series = (
      if "additionalFields" in $metadata {
        $metadata.additionalFields | parse_series_from_series_tags
      }
    );
    # The first series should be considered the primary series
    let series = [] | append $series | append $group_series;
    if ($series | is-not-empty) {
      let duplicate_series = (
        $series | group-by --to-table name | each {|group|
          if ($group.items | length) > 1 {
            $group.items
          }
        } | flatten | filter {|item| $item != null}
      )
      if ($duplicate_series | is-not-empty) {
        log error $"Multiple series with the same name present: ($duplicate_series). Only the first series will be used and duplicate series will be ignored."
      }
      $series | uniq-by name
    }
  )
  let genres = (
    if "genre" in $metadata {
      $metadata.genre | parse_multi_value_tag
    }
  )
  let tags = (
    if "additionalFields" in $metadata and "tags" in $metadata.additionalFields {
      $metadata.additionalFields.tags | parse_multi_value_tag
    }
  )
  let publication_date = (
    if "publicationDate" in $metadata {
      $metadata.publicationDate | into datetime
    } else if "date" in $metadata {
      $metadata.date | into datetime
    } else if "releaseDate" in $metadata {
      $metadata.releaseDate | into datetime
    } else if "recordingDate" in $metadata {
      $metadata.recordingDate | into datetime
    } else if "originalDate" in $metadata {
      $metadata.originalDate | into datetime
    } else if "year" in $metadata {
      ($metadata.year + "-01-01") | into datetime
    } else if "releaseYear" in $metadata {
      ($metadata.year + "-01-01") | into datetime
    } else if "recordingYear" in $metadata {
      ($metadata.year + "-01-01") | into datetime
    } else if "originalYear" in $metadata {
      ($metadata.originalYear + "-01-01") | into datetime
    }
  )
  let artists = (
    let artist_names = (
      if "artist" in $metadata and ($metadata.artist | is-not-empty) {
        $metadata.artist | parse_multi_value_tag | wrap name
      }
    );
    let artist_ids = (
      if "additionalFields" in $metadata and "musicBrainz Artist Id" in $metadata.additionalFields {
        $metadata.additionalFields."musicBrainz Artist Id" | parse_multi_value_tag | wrap id
      }
    );
    let artist = $artist_names | merge_or_input $artist_ids;
    let artist = (
      if "id" not-in ($artist | columns) {
        $artist | insert id ""
      } else {
        $artist
      }
    );
    let artists = (
      if "additionalFields" in $metadata and "artists" in $metadata.additionalFields and ($metadata.additionalFields.artists | is-not-empty) {
        $metadata.additionalFields.artists | parse_multi_value_tag | wrap name | insert id ""
      }
    );
    let non_duplicate_artists = (
      if ($artists | is-not-empty) {
        $artists | where name not-in ($artist.name)
      }
    );
    $artist | append ($non_duplicate_artists)
  ) | insert role "writer" | insert entity "artist"
  let primary_authors = (
    let names = (
      if "albumArtist" in $metadata and ($metadata.albumArtist | is-not-empty) {
        $metadata.albumArtist | parse_multi_value_tag | wrap name
      }
    );
    let ids = (
      if "additionalFields" in $metadata and "musicBrainz Album Artist Id" in $metadata.additionalFields {
        $metadata.additionalFields."musicBrainz Album Artist Id" | parse_multi_value_tag | wrap id
      }
    );
    let primary_authors = $names | merge_or_input $ids;
    if ($primary_authors | is-not-empty) {
      let primary_authors = $primary_authors | insert role "primary author" | insert entity "artist";
      if "id" not-in ($primary_authors | columns) {
        $primary_authors | insert id ""
      } else {
        $primary_authors
      }
    }
  )

  let publishers = (
    let label_names = (
      if "label" in $metadata {
        $metadata.label | parse_multi_value_tag | wrap name
      }
    );
    let label_ids = (
      if "additionalFields" in $metadata and "musicBrainz Label Id" in $metadata.additionalFields {
        $metadata.additionalFields."musicBrainz Label Id" | parse_multi_value_tag | wrap id
      }
    );
    let labels = $label_names | merge_or_input $label_ids;
    if ($labels | is-not-empty) and "id" in ($labels | columns) {
      $labels
    } else {
      let publishers = (
        if "publisher" in $metadata {
          $metadata.publisher | parse_multi_value_tag | wrap name
        }
      );
      # audiobookshelf stores the publisher in the copyright field.
      # I don't think there can be multiple here.
      let copyright = (
        if "copyright" in $metadata {
          $metadata.copyright | wrap name
        }
      );
      [] | append $publishers | append $label_names | append $copyright | uniq
    }
  )

  let musicbrainz_album_types = (
    if "additionalFields" in $metadata and "musicBrainz Album Type" in $metadata.additionalFields {
      $metadata.additionalFields."musicBrainz Album Type" | parse_multi_value_tag | str downcase
    }
  )
  let lyrics = (
    if "lyrics" in $metadata {
      $metadata.lyrics | parse_multi_value_tag
    }
  )
  let rating = (
    if "rating" in $metadata {
      $metadata.rating | parse_multi_value_tag
    }
  )
  let musicbrainz_works = (
    if "additionalFields" in $metadata {
      let ids = (
        if "musicBrainz Work Id" in $metadata.additionalFields {
          $metadata.additionalFields."musicBrainz Work Id" | parse_multi_value_tag | wrap id
        }
      )
      let bookbrainz_work_id = (
        if "bookBrainz Work Id" in $metadata.additionalFields {
          $metadata.additionalFields."bookBrainz Work Id" | parse_multi_value_tag | wrap bookbrainz_work_id
        }
      )
      let names = (
        if "work" in $metadata.additionalFields {
          $metadata.additionalFields.work | parse_multi_value_tag | wrap name
        }
      )
      $ids | merge_or_input $names | merge_or_input $bookbrainz_work_id
    }
  )

  let duration = (
    $all_metadata | get audio.duration | into int | into duration --unit ms
  )

  let musicbrainz_release_country = (
    if "additionalFields" in $metadata and ($metadata.additionalFields | is-not-empty) and "musicBrainz Album Release Country" in $metadata.additionalFields {
      $metadata.additionalFields."musicBrainz Album Release Country" | str upcase
    }
  )
  let musicbrainz_release_status = (
    if "additionalFields" in $metadata and ($metadata.additionalFields | is-not-empty) and "musicBrainz Album Status" in $metadata.additionalFields {
      $metadata.additionalFields."musicBrainz Album Status" | str downcase
    }
  )

  let all_contributors = (
    [adapter arranger composer director editor engineer illustrator lyricist mixer narrator performer producer remixer translator writer] | par-each {|role|
      let names = (
        $metadata
        | (
          let input = $in;
          if $role in [adapter editor illustrator translator writer] {
            $input | get --ignore-errors additionalFields
          } else {
            $input
          }
        )
        | get --ignore-errors $role
        | parse_multi_value_tag
      )
      if ($names | is-not-empty) {
        $names | par-each {|name|
          {
            id: ""
            name: $name
            entity: "artist"
            role: $role
          }
        }
      }
    } | flatten | filter {|contributor|
      # Drop writers that are in the artists table, as the ones there might also have the id
      not ($contributor.entity == "artist" and $contributor.role == "writer" and $contributor.name in ($artists | get name))
    } | append $artists | append $primary_authors | uniq
  )
  let all_contributors = $all_contributors | append (
    [distributor] | par-each {|role|
      let names = (
        $metadata
        | (
          let input = $in;
          if $role in [distributor] {
            $input | get --ignore-errors additionalFields
          } else {
            $input
          }
        )
        | get --ignore-errors $role
        | parse_multi_value_tag
      )
      if ($names | is-not-empty) {
        $names | par-each {|name|
          {
            id: ""
            name: $name
            entity: "label"
            role: $role
          }
        }
      }
    } | uniq
  )
  # Attempt to parse the distributor from the comment
  let all_contributors = (
    if ($metadata | get --ignore-errors comment | is-not-empty) and ($all_contributors | where role == "distributor" | is-empty) {
      if "Libro.fm" in $metadata.comment {
        $all_contributors | append {
          id: "158b7958-b872-4944-88a5-fd9d75c5d2e8"
          name: "Libro.fm"
          entity: "label"
          role: "distributor"
        }
      } else {
        $all_contributors
      }
    } else {
      $all_contributors
    }
  )
  # Assume all contributors are track level, except for primary authors, illustrators, and distributors
  # Realistically, illustrators could be attributed to a single track, but that's probably more likely for music than it is for audibooks.
  const book_contributor_roles = []
  let book_contributors = $all_contributors | where role in (["primary author"] | append $release_only_contributor_roles)
  let track_contributors = $all_contributors | where role not-in $release_only_contributor_roles

  let amazon_asin = (
    if "additionalFields" in $metadata and ($metadata.additionalFields | is-not-empty) and "asin" in $metadata.additionalFields {
      $metadata.additionalFields.asin | str upcase
    }
  )
  let audible_asin = (
    if "additionalFields" in $metadata and ($metadata.additionalFields | is-not-empty) and "audible_asin" in $metadata.additionalFields {
      $metadata.additionalFields.audible_asin | str upcase
    }
  )

  let book = (
    {}
    | upsert_if_present title $metadata album
    | upsert_if_present title_sort $metadata sortAlbum
    | upsert_if_present subtitle $metadata
    | upsert_if_value contributors $book_contributors
    | upsert_if_present comment $metadata
    | upsert_if_present description $metadata
    | upsert_if_present long_description $metadata longDescription
    | upsert_if_present language $metadata lang
    | upsert_if_present language $metadata
    | upsert_if_value publishers $publishers
    | upsert_if_value publication_date $publication_date
    | upsert_if_value series $series
    | upsert_if_value genres $genres
    | upsert_if_present total_discs $metadata totalDiscs
    | upsert_if_present total_tracks $metadata totalTracks
    | (
      let input = $in;
      if additionalFields in $metadata {
        $input
        | upsert_if_present isbn $metadata.additionalFields barcode
        | upsert_if_present isbn $metadata.additionalFields
        | upsert_if_value amazon_asin $amazon_asin
        | upsert_if_value audible_asin $audible_asin
        | upsert_if_present script $metadata.additionalFields
        | upsert_if_present musicbrainz_release_group_id $metadata.additionalFields "musicBrainz Release Group Id"
        | upsert_if_present musicbrainz_release_id $metadata.additionalFields "musicBrainz Album Id"
        | upsert_if_value musicbrainz_release_country $musicbrainz_release_country
        | upsert_if_value musicbrainz_release_status $musicbrainz_release_status
        | upsert_if_value musicbrainz_release_types $musicbrainz_album_types
        | upsert_if_value tags $tags
        | upsert_if_present packaging $metadata.additionalFields
      } else {
        $input
      }
    )
    | (
      let input = $in;
      if "chapters" in $metadata and ($metadata.chapters | is-not-empty) {
        $input | upsert chapters ($metadata.chapters | parse_chapters_from_tone)
      } else {
        $input
      }
    )
  );
  let track = (
    {
      # The path of the track on the filesystem is used internally
      file: $all_metadata.file
      duration: $duration
    }
    | upsert_if_present title $metadata
    | upsert_if_present title_sort $metadata sortTitle
    | upsert_if_present index $metadata trackNumber
    | upsert_if_present embedded_pictures $metadata embeddedPictures
    | upsert_if_value musicbrainz_works $musicbrainz_works
    | upsert_if_value contributors $track_contributors
    | upsert_if_value lyrics $lyrics
    | upsert_if_value rating $rating
    | upsert_if_present disc_number $metadata discNumber
    | upsert_if_present disc_subtitle $metadata discSubtitle
    | upsert_if_present media $metadata
    | (
      let input = $in;
      if "additionalFields" in $metadata {
        $input
        | upsert_if_present acoustid_fingerprint $metadata.additionalFields "acoustid Fingerprint"
        | upsert_if_present acoustid_track_id $metadata.additionalFields "acoustid Id"
        | upsert_if_present musicbrainz_recording_id $metadata.additionalFields "musicBrainz Track Id"
        | upsert_if_present musicbrainz_track_id $metadata.additionalFields "musicBrainz Release Track Id"
      } else {
        $input
      }
    )
  );
  {
      book: $book
      track: $track
  }
}

# Get metadata from a file with tone
export def tone_dump []: path -> record {
  let file = $in | path expand
  let result = do {^tone dump --format json $file} | complete
  if $result.exit_code != 0 {
    log info $"Error running '^tone dump --format json ($file)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }
  $result.stdout | from json
}

# Parse audiobook metadata for a single file into a standard format
export def parse_audiobook_metadata_from_file []: path -> record {
  let file = $in | path expand
  let tone_output = $file | tone_dump
  if ($tone_output | is-empty) {
    return null
  }
  $tone_output | upsert file $file | parse_audiobook_metadata_from_tone
}

# Parse audiobook metadata from a list of individual tracks' metadata
export def parse_audiobook_metadata_from_tracks_metadata []: list<record> -> record {
  let metadata = $in | sort-by track.index
  # The book metadata should match across all tracks.
  let book = $metadata | get book | reduce {|it, acc|
    # todo Use metadata with the most occurrences when there is a conflict?
    $acc | items {|key, value|
      if $key not-in $it {
        log warning $"Missing ($key) in track"
      } else if $value != ($it | get $key) {
        log warning $"Inconsistent metadata among files: ($value) != ($it | get $key)"
      }
    }
    $it | items {|key, value|
      if $key not-in $acc {
        log warning $"Missing ($key) in track"
      }
    }
    $acc | merge $it
  }
  let book = (
    if ($book | get --ignore-errors total_tracks | is-empty) {
      $book | upsert total_tracks ($metadata.track | length)
    } else {
      $book
    }
  )
  let tracks = (
    if "index" in ($metadata.track | columns) {
      $metadata.track | sort-by index
    } else {
      $metadata.track
    }
  )
  {
      book: $book
      tracks: $tracks
  }
}

# Parse audiobook metadata from a list of audio files correlating to the tracks of the audiobook
export def parse_audiobook_metadata_from_files []: list<path> -> record {
  let files = $in
  let tracks = $files | enumerate | par-each {|file|
    let metadata = $file.item | parse_audiobook_metadata_from_file
    if "index" in $metadata.track and ($metadata.track.index | is-not-empty) {
      $metadata
    } else {
      $metadata | insert track.index ($file.index + 1)
    }
  }
  $tracks | parse_audiobook_metadata_from_tracks_metadata
}

# Convert the series table to a value suitable for the group tag
export def convert_series_for_group_tag []: table<name: string, index: string> -> string {
  let series = $in
  $series | each {|s|
    if index in $s and ($s.index | is-not-empty) {
      $s.name + " #" + $s.index
    } else {
      $s.name
    }
  } | str join ";"
}

export def join_multi_value []: any -> string {
  let input = $in
  if ($input | is-empty) {
    return null
  }
  $input | str join ";"
}

# Convert the internal audiobook metadata representation of a track into the format required for tone
#
# The input metadata should be for an individual track, with a book and track record at the top level.
# The returned record contains a file key for the path of the file on disk and a metadata key for the metadata for tone.
#
# audiobookshelf and Picard use a semicolon followed by a space to separate multiple values, I think.
# Technically, I think ID3v2.4 is supposed to use a null byte, but tone doesn't seem to support that.
export def into_tone_format []: record -> record {
  let metadata = $in
  # Prefer release group series
  let group = (
    let series = (
      if "series" in $metadata.book and $metadata.book.series != null {
        if "scope" in ($metadata.book.series | columns) {
          let release_group_series = $metadata.book.series | where scope == "release group"
          if ($release_group_series | is-empty) {
            # Fallback to the work series if there is no release group series
            let work_series = $metadata.book.series | where scope == "work"
            if ($work_series | is-empty) {
              # Use whatever series there are at this point
              $metadata.book.series
            } else {
              $work_series
            }
          } else {
            $release_group_series
          }
        } else {
          $metadata.book.series
        }
      }
    );
    if ($series | is-not-empty) {
      let duplicate_series = (
        $series | group-by --to-table name | each {|group|
          if ($group.items | length) > 1 {
            $group.items
          }
        } | flatten | filter {|item| $item != null}
      )
      if ($duplicate_series | is-not-empty) {
        log error $"Multiple series with the same name present: ($duplicate_series). Only the first series will be used and duplicate series will be ignored."
      }
      $series | uniq-by name | convert_series_for_group_tag
    }
  )
  let publication_date = (
    if "publication_date" in $metadata.book and ($metadata.book.publication_date | is-not-empty) {
      $metadata.book.publication_date | format date '%Y-%m-%dT%H:%M:%SZ'
    }
  )
  let chapters = (
    if "chapters" in $metadata.book and ($metadata.book.chapters | is-not-empty) {
      $metadata.book.chapters | chapters_into_tone_format
    }
  )
  let primary_authors = (
    if "contributors" in $metadata.book and ($metadata.book.contributors | is-not-empty) {
      $metadata.book.contributors | where entity == "artist" | where role == "primary author"
    }
  )

  # todo Should genres and tags only be kept at the track level?
  # Combine track and book genres
  let genres = (
    let track_genres = (
      if "genres" in $metadata.track and ($metadata.track.genres | is-not-empty) and "name" in ($metadata.track.genres | columns) {
        $metadata.track.genres.name
      } else {
        []
      }
    );
    let book_genres = (
      if "genres" in $metadata.book and ($metadata.book.genres | is-not-empty) and "name" in ($metadata.book.genres | columns) {
        $metadata.book.genres.name
      } else {
        []
      }
    );
    $track_genres | append $book_genres | uniq | join_multi_value
  )

  # Combine track and book tags
  let tags = (
    let track_tags = (
      if "tags" in $metadata.track and ($metadata.track.tags | is-not-empty) and "name" in ($metadata.track.tags | columns) {
        $metadata.track.tags.name
      } else {
        []
      }
    );
    let book_tags = (
      if "tags" in $metadata.book and ($metadata.book.tags | is-not-empty) and "name" in ($metadata.book.tags | columns) {
        $metadata.book.tags.name
      } else {
        []
      }
    );
    $track_tags | append $book_tags | uniq | filter {|tag| $tag not-in ["chapters"]} | join_multi_value
  )

  let additionalFields = (
    {}
    # book metadata
    | upsert_if_value tags $tags
    | upsert_if_value "MusicBrainz Album Type" ($metadata.book | get --ignore-errors musicbrainz_release_types | join_multi_value)
    | upsert_if_value "MusicBrainz Album Artist Id" ($primary_authors | get --ignore-errors id | join_multi_value)
    | upsert_if_present "MusicBrainz Release Group Id" $metadata.book musicbrainz_release_group_id
    | upsert_if_present "MusicBrainz Album Id" $metadata.book musicbrainz_release_id
    | upsert_if_present "MusicBrainz Album Release Country" $metadata.book musicbrainz_release_country
    | upsert_if_present "MusicBrainz Album Status" $metadata.book musicbrainz_release_status
    | upsert_if_present script $metadata.book
    # For audiobookshelf to be happy, publisher has to go in additionalFields for some reason.
    # todo I'm not sure audiobookshelf supports multiple values for the publisher
    | upsert_if_value publisher ($metadata.book | get --ignore-errors publishers | get --ignore-errors name | join_multi_value)
    | upsert_if_present ISBN $metadata.book isbn
    | upsert_if_present barcode $metadata.book isbn
    | upsert_if_present asin $metadata.book amazon_asin
    | upsert_if_present audible_asin $metadata.book
    # For audiobookshelf to be happy, language has to go in additionalFields for some reason.
    | upsert_if_present language $metadata.book
    | upsert_if_present packaging $metadata.book
    # track metadata
    | upsert_if_present "AcoustID Fingerprint" $metadata.track acoustid_fingerprint
    | upsert_if_present "AcoustID Id" $metadata.track acoustid_track_id
    | upsert_if_present "MusicBrainz Track Id" $metadata.track musicbrainz_recording_id
    | upsert_if_present "MusicBrainz Release Track Id" $metadata.track musicbrainz_track_id
    | upsert_if_value "MusicBrainz Artist Id" (
      if "contributors" in $metadata.track and ($metadata.track.contributors | is-not-empty) {
        $metadata.track.contributors | where role == "writer" | get --ignore-errors id | join_multi_value
      }
    )
    | upsert_if_value "MusicBrainz Work Id" ($metadata.track | get --ignore-errors musicbrainz_works | get --ignore-errors id | join_multi_value)
    | upsert_if_value "BookBrainz Work Id" ($metadata.track | get --ignore-errors musicbrainz_works | get --ignore-errors bookbrainz_work_id | join_multi_value)
    | upsert_if_value "MusicBrainz Label Id" ($metadata.track | get --ignore-errors publishers | get --ignore-errors id | join_multi_value)
    | upsert_if_value "work" ($metadata.track | get --ignore-errors musicbrainz_works | get --ignore-errors name | join_multi_value)
    | (
      let input = $in;
      if "contributors" in $metadata.track and ($metadata.track.contributors | is-not-empty) {
        let r = [adapter editor illustrator translator writer] | par-each {|role|
          let contributors_for_role = (
            $metadata.track.contributors
            | where role == $role
            | get name
            | uniq
            | join_multi_value
          )
          if ($contributors_for_role | is-not-empty) {
            {$role: $contributors_for_role}
          }
        } | reduce {|it, acc|
          $acc | merge_or_input $it
        };
        $input | merge_or_input $r
      } else {
        $input
      }
    )
  )

  let m = {
    # audio: {
    #   language:
    # }
    meta: (
      {}
      #
      # book metadata
      #
      | upsert_if_present album $metadata.book title
      | upsert_if_present sortAlbum $metadata.book title_sort
      | upsert_if_present subtitle $metadata.book
      | upsert_if_value albumArtist ($primary_authors | get --ignore-errors name | join_multi_value)
      | upsert_if_present description $metadata.book
      | upsert_if_present longDescription $metadata.book long_description
      | upsert_if_present comment $metadata.book
      | upsert_if_value group $group
      | upsert_if_value genre $genres
      | upsert_if_value publishingDate $publication_date
      # audiobookshelf uses recordingDate and not publishingDate for some reason
      | upsert_if_value recordingDate $publication_date
      # language has no effect here I guess?
      # | upsert_if_present language $metadata.book
      | upsert_if_value publisher ($metadata.book | get --ignore-errors publishers | get --ignore-errors name | join_multi_value)
      | upsert_if_value label ($metadata.book | get --ignore-errors publishers | get --ignore-errors name | join_multi_value)
      | upsert_if_present totalDiscs $metadata.book total_discs
      | upsert_if_present totalTracks $metadata.book total_tracks
      #
      # track metadata
      #
      | upsert_if_present title $metadata.track
      | upsert_if_present sortTitle $metadata.track title_sort
      | upsert_if_present trackNumber $metadata.track index
      | (
        let input = $in;
        if "contributors" in $metadata.track and ($metadata.track.contributors | is-not-empty) {
          let r = [arranger artist composer director engineer lyricist mixer narrator performer producer remixer] | par-each {|role|
            let contributors_for_role = (
              $metadata.track.contributors
              | (
                let i = $in;
                if $role == "artist" {
                  $i | where role == "writer"
                # Use the composer field for the narrators for audiobookshelf
                } else if $role == "composer" {
                  $i | where role == "narrator"
                } else {
                  $i | where role == $role
                }
              )
              | get name
              | uniq
              | join_multi_value
            )
            if ($contributors_for_role | is-not-empty) {
              {$role: $contributors_for_role}
            }
          } | reduce {|it, acc|
            $acc | merge_or_input $it
          };
          $input | merge_or_input $r
        } else {
          $input
        }
      )
      | upsert_if_present lyrics $metadata.track
      | upsert_if_present rating $metadata.track
      | upsert_if_value chapters $chapters
      | upsert_if_present embeddedPictures $metadata.track embedded_pictures
      | upsert_if_present discNumber $metadata.track disc_number
      | upsert_if_present discSubtitle $metadata.track disc_subtitle
      | upsert_if_present media $metadata.track
      #
      # additionalFields
      #
      | upsert_if_value additionalFields $additionalFields
    )
  }
  # log info $"($m | to nuon)"
  $m
}

# Convert the metadata for a set of tracks into a format suitable for tone
#
# The input data should be in the form of a book and a list of tracks.
# The returned records will contain the metadata for tone under the metadata key.
# The other key, file, will contain the path to the track on disk.
export def tracks_into_tone_format []: record<book: record, tracks: table> -> table<metadata: record<meta: record>, file: path> {
  let metadata = $in
  $metadata.tracks | par-each {|track|
    {
      book: $metadata.book
      track: $track
    } | into_tone_format | (
      let input = $in;
      {
        metadata: $input
        # Keep the association between the track and its path on disk.
        file: $track.file
      }
    )
  } | sort-by metadata.meta.trackNumber
}

# Calculate the AcoustID of an audio file or files with the fpcalc utility
#
# fpcalc is part of the chromaprint package.
#
# Returns a record containing the duration and the fingerprint.
export def fpcalc []: list<path> -> table<file: path, fingerprint: string, duration: duration> {
  $in | par-each {|file|
    let file = $file | path expand
    let result = do {^fpcalc -json $file} | complete
    if $result.exit_code != 0 {
      log error $"Error running '^fpcalc -json ($file)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
      return null
    }
    let track = $result.stdout | from json
    {
      file: $file
      fingerprint: $track.fingerprint
      duration: (($track.duration * 1000) | math round | into duration --unit ms)
    }
  }
}

# Tag an audio file with tone using the provided metadata
export def tone_tag [
  file: path
  ...tone_args: string
]: record -> path {
  let metadata = $in
  let tone_json = mktemp --suffix ".json" --tmpdir
  log debug $"JSON file for tone: ($tone_json)"
  $metadata | save --force $tone_json
  let result = do {
    (
      ^tone tag
          --meta-tone-json-file $tone_json
          ...$tone_args
          $file
    )
  } | complete
  if $result.exit_code != 0 or "Could not update tags for file" in $result.stdout {
    log error $"Error running '^tone tag --meta-tone-json-file ($tone_json) (...$tone_args) ($file)'\nstderr: ($result.stderr)\nstdout: ($result.stdout)"
    return null
  }

  # Print the helpful output from tone
  print $result.stdout

  rm $tone_json

  $file
}

# Tag audio files with tone using the provided metadata
export def tone_tag_tracks [
  working_directory: directory
  ...tone_args: string
]: record -> list<path> {
  $in | tracks_into_tone_format | par-each {|track|
    $track.metadata | tone_tag $track.file ...$tone_args
  }
}

### MusicBrainz functions

# Functions prefixed with "fetch_" are used to query the MusicBrainz API.
# Functions prefixed with "parse_" are used to parse responses from the MusicBrainz API without making any external calls.
# This allows using unit tests for the functions prefixed with "parse_".

# Get the release group to which a release belongs
export def fetch_musicbrainz_release_group_for_release []: string -> table {
  let release_id = $in
  let url = "https://musicbrainz.org/ws/2/release-group/"
  let query = $"reid:($release_id)" | url encode
  http get --headers [User-Agent $user_agent Accept "application/json"] $"($url)/?query=($query)"
}

# Fetch the front cover image of a release from the Cover Art Archive
export def fetch_release_front_cover [
  working_directory: directory
  size: string = original # original, 1200, 500, or 250
  --retries: int = 3
  --retry-delay: duration = 3sec
]: string -> path {
  let release_id = $in
  let url = "https://coverartarchive.org/release"
  let request = {http get --full --headers [User-Agent $user_agent] $"($url)/($release_id)"}
  let response = retry_http $request $retries $retry_delay
  let front_covers = $response | get body | get images | where front == true | select id image thumbnails
  if ($front_covers | is-empty) {
    return null
  }
  let cover = $front_covers | first

  # thumbnail sizes are 1200, 500, and 250
  let download_url = (
    if $size == "original" {
      $cover | get image
    } else {
      $cover | get thumbnails | get $size
    }
  )
  let filename = $download_url | url parse | get path | path basename
  let destination = $working_directory | path join $filename
  http get --headers [User-Agent $user_agent] $download_url | save --force $destination
  $destination
}

# Fetch a release group from MusicBrainz by ID
export def fetch_musicbrainz_release_group [
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  let release_group_id = $in
  let url = "https://musicbrainz.org/ws/2/release-group"
  let request = {http get --full --headers [User-Agent $user_agent Accept "application/json"] $"($url)/($release_group_id)/?inc=series-rels"}
  retry_http $request $retries $retry_delay
}

# Get a Release with all of the gory details
export def fetch_musicbrainz_release [
  includes: list<string> = [
    aliases
    artist-credits
    labels
    recordings
    release-groups
    media
    genres
    tags
    release-group-rels
    work-rels
    series-rels
    genre-rels
    artist-rels
    label-rels
    recording-level-rels
    release-group-level-rels
    work-level-rels
    url-rels # for Audible ASIN
  ]
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  let release_id = $in
  let url = "https://musicbrainz.org/ws/2/release"
  let request = {http get --full --headers [User-Agent $user_agent Accept "application/json"] $"($url)/($release_id)/?inc=($includes | str join '+')"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error fetching MusicBrainz Release: ($url): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code (ansi red)($response.status)(ansi reset) when fetching MusicBrainz Release: ($url)"
    return null
  }
  $response.body
}

# Get a MusicBrainz Work by id
export def fetch_musicbrainz_work [
  includes: list<string> = [series-rels genres tags]
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  let work_id = $in
  let url = "https://musicbrainz.org/ws/2/work"
  let request = {http get --full --headers [User-Agent $user_agent Accept "application/json"] $"($url)/($work_id)/?inc=($includes | str join '+')"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error fetching MusicBrainz Work: ($url): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code (ansi red)($response.status)(ansi reset) when fetching MusicBrainz Work: ($url)"
    return null
  }
  $response.body
}

# Parse a MusicBrainz Work
export def parse_musicbrainz_work []: record -> record<id: string, title: string, language: string, genres: table<name: string, count: int>, tags: table<name: string, count: int>> {
  let input = $in
  if ($input | is-empty) {
    return null
  }
  let genres_and_tags = $input | select --ignore-errors genres tags | parse_genres_and_tags
  {
    id: $input.id
    title: $input.title
    language: $input.language
    genres: $genres_and_tags.genres
    tags: $genres_and_tags.tags
  }
}

# Fetch and parse a MusicBrainz Work by ID
export def fetch_and_parse_musicbrainz_work [
  cache: closure
  --retries: int = 3
  --retry-delay: duration = 3sec
]: string -> record {
  let musicbrainz_work_id = $in
  let update_function = {|type id| $id | fetch_musicbrainz_work --retries $retries --retry-delay $retry_delay | parse_musicbrainz_work}
  do $cache "work" $musicbrainz_work_id $update_function
}

# Get a Series
export def fetch_musicbrainz_series [
  includes: list<string> = [series-rels genres tags]
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  let series_id = $in
  let url = "https://musicbrainz.org/ws/2/series"
  let request = {http get --full --headers [User-Agent $user_agent Accept "application/json"] $"($url)/($series_id)/?inc=($includes | str join '+')"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error fetching MusicBrainz Series: ($url): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code (ansi red)($response.status)(ansi reset) when fetching MusicBrainz Series: ($url)"
    return null
  }
  $response.body
}

# Parse a MusicBrainz series
export def parse_musicbrainz_series []: record -> record<id: string, name: string, subseries: table<id: string, name: string>, parent_series: table<id: string, name: string>, genres: table<name: string, count: int>, tags: table<name: string, count: int>> {
  let input = $in
  if ($input | is-empty) {
    return null
  }
  let genres_and_tags = $input | select --ignore-errors genres tags | parse_genres_and_tags
  let series = {
    id: $input.id
    name: $input.name
    parent_series: []
    subseries: []
    genres: $genres_and_tags.genres
    tags: $genres_and_tags.tags
  }
  let relations = $input | get --ignore-errors relations
  if ($relations | is-empty) {
    return $series
  }
  let series_relations = $relations | where target-type == "series"
  if ($series_relations | is-empty) {
    return $series
  }
  let parent_series_relations = $series_relations | where direction == "backward"
  let parent_series = (
    if ($parent_series_relations | is-empty) {
      []
    } else {
      $parent_series_relations.series | select id name
    }
  )
  let subseries_relations = $series_relations | where direction == "forward"
  let subseries = (
    if ($subseries_relations | is-empty) {
      []
    } else {
      $subseries_relations.series | select id name
    }
  )
  $series | upsert parent_series $parent_series | upsert subseries $subseries
}

# Fetch and parse a MusicBrainz Series by ID.
export def fetch_and_parse_musicbrainz_series [
  # cache: directory # Cache directory where parsed series are stored in files named according to mbid, i.e. mbid.json.
  cache: closure # Closure that returns parsed series information given a type and a series id
  --retries: int = 3
  --retry-delay: duration = 3sec
]: string -> record {
  let musicbrainz_series_id = $in
  # let cached_series_file = {parent: $cache, stem: $musicbrainz_series_id, extension: "json"} | path join
  let update_cache = {|type id|
    $id | fetch_musicbrainz_series --retries $retries --retry-delay $retry_delay | parse_musicbrainz_series
    # $series | save $cached_series_file
    # $series
  }
  do $cache "series" $musicbrainz_series_id $update_cache
  # if ($cached | is-empty) {
  #   # open $cached_series_file
  # } else {
  # }
}

# Build a tree of subseries going up through the parent series
export def build_series_tree_up [
  depth: int
  # cache: directory # Cache directory where HTTP responses are stored in files named according to mbid, i.e. mbid.json.
  cache: closure # Cache directory where HTTP responses are stored in files named according to mbid, i.e. mbid.json.
  --required-series: list<string>
  --retries: int = 3
  --retry-delay: duration = 3sec
]: record -> record {
  let series = $in

  # log info $"Series: ($series)"
  # log info $"Depth: ($depth)"

  # Base case: No parent series
  if ($series | get --ignore-errors parent_series | is-empty) {
    return $series
  }

  # Alternate base case, this is the last required series.
  if ($required_series != null and ($required_series | length) == 1) and ($required_series | first) == $series.id {
    return $series
  }

  # Hit max depth
  if ($depth <= 0) {
    log error $"Reached max depth at series: ($series). Unwinding!"
    # I could return null here to signal the error.
    return $series
  }

  $series | upsert parent_series (
    # log info $"$series.parent_series: ($series.parent_series | to nuon)";
    # $series.parent_series | each {|parent_series|
      # log info $"$parent_series: ($parent_series | to nuon)";
      # log info $"$parent_series.id: ($parent_series.id)";
    # };
    $series.parent_series | each {|parent_series|
      # log info $"parent_series: ($parent_series)"
      if $required_series == null {
        # log info $"parent_series.id: ($parent_series.id)"
        $parent_series.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay | build_series_tree_up ($depth - 1) $cache
      } else {
        $parent_series.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay | build_series_tree_up ($depth - 1) $cache --required-series ($required_series | filter {|id| $id != $series.id})
      }
    }
  )
}

# Build a tree of subseries under a series
export def build_series_tree [
  depth: int
  # cache: directory # Cache directory where HTTP responses are stored in files named according to mbid, i.e. mbid.json.
  cache: closure
  --required-series: list<string>
  --retries: int = 3
  --retry-delay: duration = 3sec
]: record -> record {
  let series = $in

  # Base case: No subseries (leaf node)
  if ($series | get --ignore-errors subseries | is-empty) {
    return $series
  }

  # Alternate base case, this is the last required series.
  if ($required_series != null and ($required_series | length) == 1) and ($required_series | first) == $series.id {
    return $series
  }

  # Hit max depth
  if ($depth <= 0) {
    log error $"Reached max depth at series: ($series). Unwinding!"
    # I could return null here to signal the error.
    return $series
  }

  $series | upsert subseries (
    $series.subseries | each {|subseries|
      if $required_series == null {
        $subseries.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay | build_series_tree ($depth - 1) $cache
      } else {
        $subseries.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay | build_series_tree ($depth - 1) $cache --required-series ($required_series | filter {|id| $id != $series.id})
      }
    }
  )
}

# # Nest one subseries in another
# export def nest_subseries [
#   series_to_nest: table
# ]: record -> record {
#   let series = $in
#   # Base case: No subseries (leaf node)
#   # if ($series | all {|s| $s | get --ignore-errors subseries | is-empty}) {
#   if ($series | get --ignore-errors subseries | is-empty) {
#     let s = $series_to_nest | where id == $series.id
#     if ($s | is-empty) {
#       return {}
#       # return $series
#     }
#     return ($s | first)
#   }

#   $series | upsert nested_subseries (
#     $series.subseries | each {|s|
#       $s | nest_subseries $series_to_nest
#     }
#   )
# }

export def series_is_in_series [
  id: string
]: record -> bool {
  let series = $in
  # Base case: No subseries (leaf node)
  # if ($series | all {|s| $s | get --ignore-errors subseries | is-empty}) {
  if ($series | get --ignore-errors nested_subseries | is-empty) {
    return ($series.id == $id)
  }

  $series.nested_subseries | any {|s|
    $s | series_is_in_series $id
  }
}


# Organize series into a hierarchy based on subseries relationships
#
# Parent series are at the top of the hierarchy.
# Subseries are nested under their parent series.
# Series are sorted by name when multiple are at the same tier.
export def create_series_tree [
  # cache: directory # todo Use a cache closure to allow unit testing
  cache: closure
  max_depth: int = 10
  --retries: int = 3
  --retry-delay: duration = 3sec
]: table -> table {
  let all_series = $in

  # let all_series_and_subseries = $all_series | append (
  #   # Recursively traverse the series relationships, calling fetch_musicbrainz_series as necessary to fill in missing series
  #   # Need to call out to MusicBrainz for all series data
  # ) | uniq-by id

  # let all_series = $all_series_and_subseries | each {|s|
  #   $s | nest_subseries $all_series_and_subseries
  # }
  # let top_level_series = $all_series | filter {|s|
  #   not ($s | series_is_in_series $s.id)
  # }

  # $top_level_series

  let ancestors_and_series = $all_series | each {|series|
    {
      ancestors: (
        $series
        | build_series_tree_up $max_depth $cache --required-series ($all_series | get id) --retries $retries --retry-delay $retry_delay
        | get_top_parents
        | sort-by name
      )
      series: $series
    }
  # Group by shared ancestor(s)
  } | group-by ancestors --to-table | each {|ancestors_and_series_group|
    {
      # Could try merging here maybe...
      ancestors: ($ancestors_and_series_group.items | first | get ancestors)
      series: ($ancestors_and_series_group.items | get series)
    }
  } | each {|ancestors_and_series|
    let full_series_tree = $ancestors_and_series.ancestors | build_series_tree $max_depth $cache --required-series ($ancestors_and_series.series | get id) --retries $retries --retry-delay $retry_delay
    # Finally, calculate the degrees of separation between the common ancestor
    let series = $ancestors_and_series.series | each {|s|
      let depth = $ancestors_and_series.ancestors | distance_to_top $s
      $s | upsert depth $depth
    }
    {
      ancestor: $full_series_tree
      series: ($series | sort-by depth)
    }
  } | sort-by --custom {|pair|
    # When there are multiple top-level series, the primary series is assumed to be the one with the shortest depth between it and it's common ancestor.
    # Each group will be sorted by the min depth of its series, followed by series without any depth, and any ties will be sorted based on the name of the ancestral series
  }
  # todo Take into account series which have an index vs. those that don't.
}

# Parse the ASIN out of an Audible URL
export def parse_audible_asin_from_url []: string -> string {
  let url = $in
  let parsed = $url | url parse
  if ($parsed.host | str starts-with "www.audible.") {
    $parsed | get path | path parse | get stem | str upcase
  }
}


# Call a function, retrying up to the given number of retries
export def retry [
  request: closure # The function to call
  should_retry: closure # A closure which determines whether to retry or not based on the result of the request closure. True means retry, false means stop.
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
]: nothing -> any {
  for attempt in 1..($retries - 1) {
    let response = do $request
    if not (do $should_retry $response) {
      return $response
    }
    sleep $delay
  }
  do $request
}

# Make an http call, retrying up to the given number of retries
export def retry_http [
  request: closure # The function to call
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
  http_status_codes_to_retry: list<int> = [408 429 500 502 503 504] # HTTP status codes where the request will be retries
]: nothing -> any {
  let should_retry = {|result|
    $result.status in $http_status_codes_to_retry
  }
  retry $request $should_retry $retries $delay
}

# Find release and recording ids linked to an AcoustID fingerprint
#
# Requires an AcoustID application API key.
export def fetch_release_ids_by_acoustid_fingerprint [
  client_key: string # The application API key for the AcoustID server. Stored in the environment variable MEDIA_JUGGLER_ACOUSTID_CLIENT_KEY
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: record<file: path, duration: duration, fingerprint: string> -> record<file: path, http_response: table, result: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> {
  let input = $in

  # Currently, the server doesn't accept durations longer than 32767 seconds.
  # Issue: https://github.com/acoustid/acoustid-server/issues/43
  # PR: https://github.com/acoustid/acoustid-server/pull/179
  if ($input.duration > 32767sec) {
    log info "Duration longer than what is supported on the AcoustID Server"
    return null
  }

  let url = "https://api.acoustid.org/v2/lookup"

  let duration_seconds = ($input.duration / 1sec) | math round

  let payload = $"format=json&meta=recordingids+releaseids&client=($client_key)&fingerprint=($input.fingerprint)&duration=($duration_seconds)"
  let request = {||
    $payload
    | ^gzip --stdout
    | http post --content-type application/x-www-form-urlencoded --full --headers [Content-Encoding gzip] $url
  }

  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error looking up AcoustID fingerprint at ($url) with payload ($payload): ($error.debug.msg)"
      return null
    }
  )

  if ($response.status != 200) {
    return {file: $input.file, "http_response": $response, result: null}
  }

  {
    file: $input.file
    http_response: $response
    result: ($response | get body)
  }
}

# Find the MusicBrainz releases linked to a set of AcoustID fingerprints
#
# Requires an AcoustID application API key.
# retries: int = 3 # The number of retries to attempt for a failed lookup request
export def fetch_release_ids_by_acoustid_fingerprints [
  client_key: string # The application API key for the AcoustID server
  threshold: float = 1.0 # A float value between zero and one, the minimum score required to be considered a match
  fail_fast = true # Immediately return null when a fingerprint has no matches that meet the threshold score
  api_requests_per_second: int = 3 # The number of API requests to make per second. AcoustID only permits up to three requests per second.
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: table<file: path, duration: duration, fingerprint: string> -> table<file: path, fingerprint: string, duration: duration, matches: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> {
  $in | chunks $api_requests_per_second | each {|chunk|
    let matches = (
      $chunk | par-each {|fingerprint|
        let result = $fingerprint | fetch_release_ids_by_acoustid_fingerprint $client_key --retries $retries --retry-delay $retry_delay
        if $result == null {
          log error $"Failed to lookup AcoustID fingerprint on the AcoustID server."
          return null
        }
        if $result.http_response.status != 200 {
          if $result.http_response.status in [401 403] {
            log error $"Failed to lookup AcoustID fingerprint on the AcoustID server. HTTP status code ($result.http_response.status). Check the client API key is correct."
            return null
          }
          log error $"Failed to lookup AcoustID fingerprint on the AcoustID server. HTTP status code ($result.http_response.status)."
          return null
        }
        let match = $result.result.results | where score >= $threshold
        if $fail_fast and ($match | is-empty) {
          return null
        }
        {
          file: $result.file
          fingerprint: $fingerprint.fingerprint
          duration: $fingerprint.duration
          matches: $match
        }
      }
    )
    sleep 1sec
    $matches
  } | flatten
}

# Attempt to find a release based on the AcoustID fingerprints of a set of tracks
#
# Takes as input a table of AcoustID fingerprints, track durations, and matches.
# This is the output of the fetch_release_ids_by_acoustid_fingerprints function.
#
# Returns the releases to which all tracks belong.
export def determine_releases_from_acoustid_fingerprint_matches []: table<file: path, fingerprint: string, duration: duration, matches: table<id: string, recordings: table<id: string, releases: table<id: string>>, score: float>> -> list<string> {
  let tracks = $in
  if ($tracks | is-empty) {
    return null
  }
  let all_possible_release_ids = (
    $tracks | get matches | flatten | get recordings | flatten
  )
  let all_possible_release_ids = (
    if "releases" in ($all_possible_release_ids | columns) {
      $all_possible_release_ids | get releases | flatten | get id | uniq
    } else {
      return null
    }
  )
  $all_possible_release_ids | filter {|release_id|
    $tracks | all {|track|
      $release_id in ($track | get matches | get recordings | flatten | get releases | flatten | get id)
    }
  }
}

# Submit AcoustID fingerprints to the AcoustID server
#
# Requires an AcoustID application API key and an AcoustID user API key.
export def submit_acoustid_fingerprints [
  client_key: string # The application API key for the AcoustID server
  user_key: string # The user's API key for the AcoustID server
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: table<musicbrainz_recording_id: string, duration: duration, fingerprint: string> -> table<index: int, submission_id: string, submission_status: string> {
  let fingerprints = $in
  let endpoint = "https://api.acoustid.org/v2/submit"
  let submission_string = $fingerprints | enumerate | reduce --fold "" {|it, acc|
    # Currently, the server doesn't accept durations longer than 32767 seconds.
    # Issue: https://github.com/acoustid/acoustid-server/issues/43
    # PR: https://github.com/acoustid/acoustid-server/pull/179
    if ($it.item.duration > 32767sec) {
      log error "Duration longer than what is supported on the AcoustID Server. Skipping submission"
      $acc
    } else {
      let duration_seconds = ($it.item.duration / 1sec) | math round
      $acc + $"&mbid.($it.index)=($it.item.musicbrainz_recording_id)&duration.($it.index)=($duration_seconds)&fingerprint.($it.index)=($it.item.fingerprint)"
    }
  }
  if ($submission_string | is-empty) {
    return null
  }

  # todo include fileformat and bitrate?
  let submission_string = $"format=json&client=($client_key)&clientversion=($media_juggler_version)&user=($user_key)" + $submission_string
  # log info $"submission_string: ($submission_string)"

  let request = {||
    (
      $submission_string
      | ^gzip --stdout
      | http post --content-type application/x-www-form-urlencoded --full --headers [Content-Encoding gzip] $endpoint
    )
  }

  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error submitting AcoustID fingerprints to ($endpoint) with payload ($submission_string): ($error.debug)"
      return null
    }
  )

  if ($response.status != 200) {
    log error $"Error submitting AcoustID fingerprints to ($endpoint) with payload ($submission_string). HTTP error code: ($response.status). HTTP response: ($response)"
    return null
  }

  $response.body.submissions
}

# Parse the works from MusicBrainz recording relationships
export def parse_works_from_musicbrainz_relations []: table -> table {
  let relations = $in
  if ($relations | describe) == "list<nothing>" or ($relations | is-empty) or "target-type" not-in ($relations | columns) or "type" not-in ($relations | columns) {
    return null
  }
  let work_relations = $relations | where target-type == "work" | where type == "performance"
  if ($work_relations | is-empty) {
    return null
  }
  (
    $work_relations
    | get work
    | uniq
  )
}

# Parse artists from MusicBrainz recording and release relationships
export def parse_contributor_by_type_from_musicbrainz_relations [
  entity: string # The type of entity, i.e. artist or label
  type: string # vocal, engineer, director, producer, recording, etc.
  attribute: string = "" # attribute to filter on, i.e "spoken vocals"
]: list -> table<id: string, name: string> {
  let relations = $in
  if ($relations | is-empty) or "target-type" not-in ($relations | columns) or "type" not-in ($relations | columns) {
    return null
  }
  let relations = (
    $relations
    | where target-type == $entity
    | where type == $type
    | filter {|relation|
      if ($attribute | is-not-empty) {
        $attribute in $relation.attributes
      } else {
        true
      }
    }
  )
  if ($relations | is-empty) {
    return null
  }
  (
    $relations
    # attribute-credits is used for specific characters, which isn't useful for tagging yet
    | select $entity target-credit # attribute-credits
    | uniq
    | par-each {|relation|
      let name = (
        if "target-credit" in $relation and ($relation.target-credit | is-not-empty) {
          $relation.target-credit
        } else {
          $relation | get $entity | get name
        }
      )
      {
        id: ($relation | get $entity | get id)
        name: $name
      }
    }
  )
}

# Parse contributors from MusicBrainz release, recording, and work relationships
#
# A table of relationships is the input.
export def parse_contributors []: table -> table<id: string, name: string, entity: string, role: string> {
  let relations = $in
  if ($relations | is-empty) or "target-type" not-in ($relations | columns) or "type" not-in ($relations | columns) {
    return null
  }
  let inputs = [
    [entity type attribute role];
    [artist vocal "spoken vocals" narrator]
    [artist writer "" writer]
    [artist illustration "" illustrator]
    [artist "audio director" "" director]
    [artist instrument "" performer]
    [artist adapter "" adapter]
    [artist translator "" translator]
    [artist composer "" composer]
    [artist editor "" editor]
    [artist engineer "" engineer]
    [artist sound "" engineer]
    [artist recording "" engineer]
    [artist producer "" producer]
    [artist mixer "" mixer]
    [artist remixer "" remixer]
    [artist arranger "" arranger]
    [artist lyricist "" lyricist]
    [label distributed "" distributor]
    [label published "" publisher]
  ]

  $inputs | par-each {|input|
    let contributors = $relations | parse_contributor_by_type_from_musicbrainz_relations $input.entity $input.type $input.attribute
    if ($contributors | is-not-empty) {
      $contributors | insert entity $input.entity | insert role $input.role
    }
  } | flatten
}

# Parse series from MusicBrainz relationships
#
# Multiple series are sorted according to index, in descending order, followed by name length, and finally name.
# The goal of this is to order parent series before subseries.
# This is due to the limited series information available when querying a release from MusicBrainz.
# Actually subseries information must be obtained through separate API calls to MusicBrainz.
export def parse_series_from_musicbrainz_relations []: any -> table<id: string, name: string, index: string> {
  let relations = $in
  if ($relations | is-empty) or "target-type" not-in ($relations | columns) or "type" not-in ($relations | columns) {
    return null
  }
  let series = (
    $relations
    | where target-type == "series"
    | where type == "part of"
  )
  if ($series | is-empty) {
    return null
  }
  (
    $series | par-each {|s|
      let name = (
        if "target-credit" in $s and ($s.target-credit | is-not-empty) {
          $s.target-credit
        } else {
          $s.series.name
        }
      )
      {
        name: $name
        id: $s.series.id
        index: ($s.attribute-values | get --ignore-errors number)
      }
    }
    | uniq
    # Try to order the series with the top-level parent series followed by the subseries.
    # Most entities that appear in both a parent series and a subseries will have indices in both.
    # When a series has multiple subseries, the parent series will have the larger indices after the first subseries.
    # Additionally, it can be cleverly deduced that most subseries will have names that are longer than their parent series.
    # This owes to the pension of including the name of the parent series as part of the name of the subseries.
    # The actual subseries relationships can and should be figured out later by making separate API calls to MusicBrainz to get the series relationships.
    | sort-by --custom {|a, b|
      if ($a.index == $b.index) {
        let a_length = ($a.name | str length)
        let b_length = ($b.name | str length)
        if $a_length == $b_length {
          # If they have the same name, that's really bizarre...
          if ($a.name | str downcase) == ($b.name | str downcase) {
            # Someone should probably fix this.
            log warning $"Multiple series have the same name: ($a) and ($b). If this is a duplicate or erroneous, please correct it. Thanks!"
            # Sort by ID I guess...
            $a.id < $b.id
          } else {
            # Sort by the name itself.
            ($a.name | str downcase) < ($b.name | str downcase)
          }
        } else {
          # Sort by shortest to longest name.
          $a_length < $b_length
        }
      } else {
        # Sort by index in reverse.
        $a.index >= $b.index
      }
    }
  )
}

# Parse series from MusicBrainz release, release group, and works
#
# The series are returned in the order of relevance:
# 1. release
# 2. release group
# 3. work
#
# Multiple series of the same type a further sorted according to index, in descending order.
# The goal of this is to order subseries after parent series.
# Of course, this won't help where indices are missing or indices match.
# Unfortunately, separate lookups for each series are necessary to determine if a series is a subseries.
export def parse_series_from_musicbrainz_release []: record -> table<name: string, id: string, index: string, scope: string> {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  let release_series = (
    $metadata
    | get --ignore-errors relations
    | parse_series_from_musicbrainz_relations
    | default "release" scope
  )
  let release_group_series = (
    $metadata
    | get --ignore-errors release-group
    | get --ignore-errors relations
    | parse_series_from_musicbrainz_relations
    | default "release group" scope
  )
  # There could also be recording series, but I haven't come across that yet
  let work_series = (
    $metadata
    | get --ignore-errors media
    | get --ignore-errors tracks
    | flatten
    | get --ignore-errors recording
    | get --ignore-errors relations
    | flatten
    | parse_works_from_musicbrainz_relations
    | (
      let input = $in;
      if ($input | is-empty) {
        null
      } else {
        (
          $input
          | get --ignore-errors relations
          | flatten
          | parse_series_from_musicbrainz_relations
          | default "work" scope
        )
      }
    )
  )
  $release_series | append $release_group_series | append $work_series # | sort-by scope
}

# Parse genres from a MusicBrainz release, release group, and recordings
#
# The genres should also be parsed from associated series and works, but these require separate API calls.
#
# MusicBrainz doesn't really provide genres for audiobooks yet, so most genres are directly imported from tags.
export def parse_genres_and_tags_from_musicbrainz_release []: record -> record<genres: table<name: string, count: int, scope: string>, tags: table<name: string, count: int, scope: string>> {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  let release = (
    $metadata
    | get --ignore-errors tags
    | wrap tags
    | parse_genres_and_tags
    | default "release" scope
  )
  let release_group = (
    $metadata
    | get --ignore-errors release-group
    | get --ignore-errors tags
    | wrap tags
    | parse_genres_and_tags
    | default "release group" scope
  )
  let recording = (
    $metadata
    | get --ignore-errors media
    | get --ignore-errors tracks
    | flatten
    | get --ignore-errors recording
    | get --ignore-errors tags
    | flatten
    | wrap tags
    | parse_genres_and_tags
    | default "recording" scope
  )
  let genres = (
    $release
    | get --ignore-errors genres
    | default "release" scope
    | append (
      $release_group
      | get --ignore-errors genres
      | default "release group" scope
    )
    | append (
      $recording
      | get --ignore-errors genres
      | default "recording" scope
    )
    | filter {|row| ($row | is-not-empty) and "name" in $row and "count" in $row}
    | select --ignore-errors name count scope
  )
  let tags = (
    $release
    | get --ignore-errors tags
    | default "release" scope
    | append (
      $release_group
      | get --ignore-errors tags
      | default "release group" scope
    )
    | append (
      $recording
      | get --ignore-errors tags
      | default "recording" scope
    )
    | filter {|row| ($row | is-not-empty) and "name" in $row and "count" in $row}
    | select --ignore-errors name count scope
  )
  {
    genres: $genres
    tags: $tags
  }
}

# Parse tags from a MusicBrainz release, release group, and recordings
#
# The tags should also be parsed from associated series and works, but these require separate API calls.
export def parse_tags_from_musicbrainz_release []: record -> table {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }
  let tags = (
    []
    | append (
      $metadata
      | get --ignore-errors tags
    )
    | append (
      $metadata
      | get --ignore-errors release-group
      | get --ignore-errors tags
    )
    # recordings
    | append (
      $metadata
      | get --ignore-errors media
      | get --ignore-errors tracks
      | flatten
      | get recording
      | get --ignore-errors tags
      | flatten
    )
  )
  if ($tags | is-empty) or "name" not-in ($tags | columns) or "count" not-in ($tags | columns) {
    return null
  }
  (
    $tags
    | select name count
    | uniq
    # sort by the count, highest to lowest, and then name alphabetically
    | sort-by --custom {|a, b|
      if $a.count == $b.count {
        $a.name < $b.name
      } else {
        $a.count > $b.count
      }
    }
  )
}

# Parse the artist names and ids from the MusicBrainz artist credits
export def parse_musicbrainz_artist_credit []: list -> table {
  $in | enumerate | select index item.artist.id item.name | rename index id name
}

# Parse an Audible ASIN from the URL relationships in a MusicBrainz Release
export def parse_audible_asin_from_musicbrainz_release []: record -> list<string> {
  let metadata = $in
  if relations not-in $metadata {
    return null
  }
  let purchase_urls = (
    $metadata
    | get relations
    | where target-type == url
    | filter {|r|
      $r.type | str starts-with purchase
    }
  )
  if ($purchase_urls | is-empty) {
    return null
  }
  $purchase_urls | get url | get resource | par-each {|url|
    $url | parse_audible_asin_from_url
  }
}

# Parse the data of a MusicBrainz release
export def parse_musicbrainz_release []: record -> record {
  let metadata = $in

  let release_artist_credits = (
    if "artist-credit" in $metadata and ($metadata.artist-credit | is-not-empty) {
      $metadata.artist-credit | parse_musicbrainz_artist_credit
    }
  )
  let release_contributors = (
    if "relations" in $metadata and ($metadata.relations | is-not-empty) {
      $metadata.relations | parse_contributors
    }
  )

  # Track metadata
  let tracks = (
    $metadata
    | get media
    | par-each {|media|
      $media.tracks | par-each {|track|
        let length = (
          if "length" in $track.recording {
            $track.recording.length | into duration --unit ms
          }
        );

        # todo function to join artists with credits
        let track_artist_credits = (
          if "artist-credit" in $track.recording and ($track.recording.artist-credit | is-not-empty) {
            $track.recording.artist-credit | parse_musicbrainz_artist_credit
          }
        )
        let works = (
          if "recording" in $track and "relations" in $track.recording and ($track.recording.relations | is-not-empty) {
            $track.recording.relations | parse_works_from_musicbrainz_relations
          }
        )
        let work_relations = (
          if ($works | is-not-empty) and "relations" in ($works | columns) {
            $works | get relations | flatten
          }
        )
        let track_contributors = (
          if ($track.recording | is-not-empty) and "relations" in ($track.recording | columns) {
            let parsed_contributors = $track.recording.relations | append $work_relations | parse_contributors
            # If artist roles exist at the release level and not at the track level, use them for the track.
            let parsed_contributors = (
              $parsed_contributors | append (
                $release_contributors
                | where role not-in $release_only_contributor_roles
                | get role
                | uniq
                | par-each {|role|
                  if ($parsed_contributors | where role == $role | is-empty) {
                    $release_contributors | where role == $role
                  }
                } | flatten
              )
            )
            (
              # Prefer the name in the track artist credit here, followed by the name in the release artist credit.
              $parsed_contributors
              | (
                let input = $in;
                if ($input | is-not-empty) and ($track_artist_credits | is-not-empty) {
                  $input | join --left $track_artist_credits id
                } else {
                  $input
                }
              )
              | join --left $release_artist_credits id
              | rename id name entity role track_artist_credit_index track_artist_credit release_artist_credit_index release_artist_credit
              | sort-by track_artist_credit_index release_artist_credit_index name
              | each {|contributor|
                let name = (
                  if ($contributor.track_artist_credit | is-not-empty) {
                    $contributor.track_artist_credit
                  } else if ($contributor.release_artist_credit | is-not-empty) {
                    $contributor.release_artist_credit
                  } else {
                    $contributor.name
                  }
                )
                {
                  id: $contributor.id
                  name: $name
                  entity: $contributor.entity
                  role: $contributor.role
                }
              }
            ) | uniq
          }
        )
        let musicbrainz_works = (
          if ($works | is-not-empty) {
            (
              $works
              | each {|work|
                if ($work | get --ignore-errors relations | is-empty) {
                  $work | default [] bookbrainz_work_id
                } else {
                  let bookbrainz_work_id = (
                    let url_relations = $work.relations | where target-type == "url";
                    if ($url_relations | is-not-empty) {
                      let bookbrainz_url_relations = $url_relations | where type == "BookBrainz"
                      if ($bookbrainz_url_relations | is-not-empty) {
                        let bookbrainz_urls = $bookbrainz_url_relations | get --ignore-errors url
                        if ($bookbrainz_urls | is-not-empty) {
                          let bookbrainz_work_urls = $bookbrainz_urls | filter {|url|
                            (
                              ($url.resource | str starts-with "https://bookbrainz.org/work/")
                              or ($url.resource | str starts-with "http://bookbrainz.org/work/")
                            )
                          }
                          if ($bookbrainz_work_urls | is-not-empty) {
                            if ($bookbrainz_work_urls | length) > 1 {
                              log warning $"Multiple BookBrainz Works are linked for the MusicBrainz Work ($work.id)"
                            }
                            $bookbrainz_work_urls.id | first
                          }
                        }
                      }
                    }
                  )
                  $work | insert bookbrainz_work_id $bookbrainz_work_id
                }
              }
              | select id title bookbrainz_work_id
              | uniq
            )
          }
        )
        let genres_and_tags = (
          if "recording" in $track and "tags" in $track.recording and ($track.recording.tags | is-not-empty) {
            let tags = (
              $track
              | get --ignore-errors recording
              | get --ignore-errors tags
              | select name count
            )
            let genres_and_tags = (
              {
                genres: []
                tags: $tags
              }
              | parse_genres_and_tags
            )
            {
              genres: ($genres_and_tags.genres | default recording scope | filter {|row| "name" in $row and "count" in $row})
              tags: ($genres_and_tags.tags | default recording scope | filter {|row| "name" in $row and "count" in $row})
            }
          } else {
            {
              genres: []
              tags: []
            }
          }
        )
        let title = (
          if "title" in $track and ($track.title | is-not-empty) {
            $track.title
          } else {
            $metadata.title
          }
        )
        # The sort name can only be found in aliases.
        let title_sort = (
          if "recording" in $track and ($track.recording | is-not-empty) and "aliases" in $track.recording and ($track.recording | is-not-empty) {
            let matching_aliases = (
              $track.recording.aliases
              | where name == $title
              | filter {|alias| $alias.name != $alias.sort-name}
            )
            if ($matching_aliases | is-not-empty) {
              if ($matching_aliases | length) > 1 {
                log warning $"Multiple aliases match the title exactly for the recording: ($matching_aliases). Using the first one. Please correct this issue on MusicBrainz."
              }
              $matching_aliases.sort-name | first
            }
          }
        )
        let musicbrainz_artist_ids = (
          let ids = $track | get --ignore-errors artist-credit.artist.id;
          if ($ids | is-not-empty) {
            $ids | uniq
          }
        )
        let disc_subtitle = (
          if "title" in $media and ($media.title | is-not-empty) {
            $media.title
          }
        )
        (
          {
            index: $track.position
          }
          | upsert_if_present disc_number $media position
          | upsert_if_value disc_subtitle $disc_subtitle
          | upsert_if_present media $media format
          | upsert_if_present musicbrainz_track_id $track id
          | upsert_if_present title $track
          | upsert_if_value title_sort $title_sort
          | upsert_if_present musicbrainz_recording_id $track.recording id
          | upsert_if_value genres $genres_and_tags.genres
          | upsert_if_value tags $genres_and_tags.tags
          | upsert_if_value musicbrainz_works $musicbrainz_works
          | upsert_if_value contributors $track_contributors
          | upsert_if_value duration $length
          # AcoustID metadata may be supplemented in the provided track metadata
          | upsert_if_present acoustid_fingerprint $track
          | upsert_if_present acoustid_track_id $track
        )
      }
    } | flatten | sort-by index
  )

  let primary_authors = (
    if "contributors" in ($tracks | columns) and ($tracks.contributors | is-not-empty) {
      let writers = $tracks.contributors | flatten | where entity == "artist" | where role == "writer"
      if ($writers | is-not-empty) {
        $writers
        | join $release_artist_credits id
        | rename id name entity role release_artist_credit_index release_artist_credit
        | sort-by release_artist_credit_index name
        # Be sure to use the name in the release artist credit and not the track artist credit
        | each {|writer|
          let name = (
            if ($writer.release_artist_credit | is-not-empty) {
              $writer.release_artist_credit
            } else {
              $writer.name
            }
          )
          {
            id: $writer.id
            name: $name
          }
        }
      # There are no writers associated with any works in the release credits.
      # Try using any artists not attributed with a specific role as the primary authors.
      } else {
        let unassociated = (
          $tracks
          | get contributors
          | where entity == "artist"
          | join --right $release_artist_credits id
          | where role == null
        )
        if ($unassociated | is-empty) {
          # Give up and just use everyone in the artist credit
          $release_artist_credits
        } else {
          $unassociated
        }
      }
    }
  )
  let primary_authors = (
    if ($primary_authors | is-not-empty) {
      $primary_authors | uniq
    }
  )
  let contributors = (
    $primary_authors
    | each {|primary_author|
      if ($primary_author | is-not-empty) {
        {
          id: $primary_author.id
          name: $primary_author.name
          entity: "artist"
          role: "primary author"
        }
      }
    }
    | append $release_contributors
  ) | uniq
  let publication_date = (
    if "date" in $metadata {
      $metadata | get date | into datetime
    }
  )
  let publishers = (
    # todo Also check for publishers in the release relationships.
    if "label-info" in $metadata and "label" in ($metadata.label-info | columns) {
      $metadata.label-info.label | select id name
    }
  )

  let series = $metadata | parse_series_from_musicbrainz_release

  let audible_asin = (
    let audible_asins = $metadata | parse_audible_asin_from_musicbrainz_release;
    # We just kind of ignore all besides the first when there are multiple
    if ($audible_asins | is-not-empty) {
      if ($audible_asins | length) > 1 {
        log warning $"Multiple Audible ASINs found: ($audible_asins). Using the first one."
      }
      $audible_asins | first
    }
  )
  let genres_and_tags = $metadata | parse_genres_and_tags_from_musicbrainz_release

  # Chapters can come from multi-track releases, otherwise, they need to found in another release
  let chapters = (
    if ($tracks | length) > 1 {
      $metadata | parse_chapters_from_musicbrainz_release
    }
  )

  let front_cover_available = (
    "cover-art-archive" in $metadata and $metadata.cover-art-archive.front
  )

  let musicbrainz_artist_ids = (
    let ids = $metadata | get --ignore-errors artist-credit.artist.id;
    if ($ids | is-not-empty) {
      $ids | uniq
    }
  )
  let musicbrainz_release_types = (
    []
    | append (
      $metadata
      | get --ignore-errors release-group.primary-type
    )
    | append (
      $metadata
      | get --ignore-errors release-group.secondary-types
    )
    | str downcase
  )
  let total_discs = (
    if "media" in $metadata and ($metadata.media | is-not-empty) {
      $metadata.media | length
    }
  )
  let total_tracks = $tracks | length

  let musicbrainz_release_country = (
    if "country" in $metadata and ($metadata.country | is-not-empty) {
      $metadata.country | str upcase
    }
  )
  let musicbrainz_release_status = (
    if "status" in $metadata and ($metadata.status | is-not-empty) {
      $metadata.status | str downcase
    }
  )

  # The sort name can only be found in aliases.
  let title_sort = (
    if "aliases" in $metadata and ($metadata.aliases | is-not-empty) {
      let matching_aliases = (
        $metadata.aliases
        | where name == $metadata.title
        | filter {|alias| $alias.name != $alias.sort-name}
      )
      if ($matching_aliases | is-not-empty) {
        if ($matching_aliases | length) > 1 {
          log warning $"Multiple aliases match the title exactly: ($matching_aliases). Using the first one. Please correct this issue on MusicBrainz."
        }
        $matching_aliases.sort-name | first
      }
    }
  )

  # Book metadata
  let book = (
    {}
    | upsert_if_present musicbrainz_release_id $metadata id
    | upsert_if_value musicbrainz_release_group_id (
      if "release-group" in $metadata and "id" in $metadata.release-group {
        $metadata.release-group.id
      }
    )
    | upsert_if_value musicbrainz_release_types $musicbrainz_release_types
    | upsert_if_present title $metadata
    | upsert_if_value title_sort $title_sort
    | upsert_if_value contributors $contributors
    | upsert_if_present isbn $metadata barcode
    | upsert_if_value musicbrainz_release_country $musicbrainz_release_country
    | upsert_if_value musicbrainz_release_status $musicbrainz_release_status
    | upsert_if_present amazon_asin $metadata asin
    | upsert_if_value audible_asin $audible_asin
    | upsert_if_value genres $genres_and_tags.genres
    | upsert_if_value tags $genres_and_tags.tags
    | upsert_if_value publication_date $publication_date
    | upsert_if_value series $series
    | upsert_if_value chapters $chapters
    | upsert_if_value front_cover_available $front_cover_available
    | upsert_if_value publishers $publishers
    | upsert_if_value total_discs $total_discs
    | upsert_if_value total_tracks $total_tracks
    | upsert_if_present packaging $metadata
    | (
      let input = $in;
      if "text-representation" in $metadata {
        $input
        | upsert_if_present script $metadata.text-representation
        | upsert_if_present language $metadata.text-representation
      } else {
        $input
      }
    )
  )

  {
    book: $book
    tracks: $tracks
  }
}

# Fetch the given release id from MusicBrainz and parse it into a normalized data structure
export def fetch_and_parse_musicbrainz_release [
  includes: list<string> = [
    aliases
    artist-credits
    labels
    recordings
    release-groups
    media
    genres
    tags
    release-group-rels
    work-rels
    series-rels
    genre-rels
    artist-rels
    label-rels
    recording-level-rels
    release-group-level-rels
    work-level-rels
    url-rels # for Audible ASIN
  ]
  --retries: int = 3
  --retry-delay: duration = 5sec
]: string -> record {
  let response = $in | fetch_musicbrainz_release --retries $retries --retry-delay $retry_delay $includes
  if ($response | is-empty) {
    return null
  }
  # try {
  $response | parse_musicbrainz_release
  # } catch {|err|
  #   log error $"Parse failed!\n($err)\n($err.msg)\n"
  # }
}


# Get the embedded AcoustID fingerprint or calculate it for the audio files which do not have one.
export def get_acoustid_fingerprint [
  ignore_existing = false # Recalculate the AcoustID even when the tag exists
]: list<path> -> table<file: path, fingerprint: string, duration: duration> {
  let files = $in
  $files | par-each {|file|
    let metadata = $file | parse_audiobook_metadata_from_file
    let fingerprint = (
      if (
        not $ignore_existing
        and "acoustid_fingerprint" in $metadata.track
        and ($metadata.track.acoustid_fingerprint | is-not-empty)
        and "duration" in $metadata.track
        and ($metadata.track.duration | is-not-empty)
      ) {
        {
          file: $file
          fingerprint: $metadata.track.acoustid_fingerprint
          duration: $metadata.track.duration
        }
      }
    )
    if ($fingerprint | is-empty) {
      [$file] | fpcalc | first
    } else {
      $fingerprint
    }
  }
}

# Get the embedded AcoustID fingerprint or calculate it for a track which does not have one.
export def get_acoustid_fingerprint_track [
  ignore_existing = false # Recalculate the AcoustID even when the tag exists
]: record -> record {
  let track = $in
  if (
    not $ignore_existing
    and ($track | get --ignore-errors acoustid_fingerprint | is-not-empty)
    and ($track | get --ignore-errors duration | is-not-empty)
  ) {
    $track
  } else {
    let pair = [$track.file] | fpcalc | first
    (
      $track
      | upsert acoustid_fingerprint $pair.fingerprint
      | upsert duration $pair.duration
    )
  }
}

# Get the embedded AcoustID fingerprint or calculate it for the tracks which do not have one.
export def get_acoustid_fingerprint_tracks [
  ignore_existing = false # Recalculate the AcoustID even when the tag exists
]: table -> table {
  let tracks = $in
  $tracks | par-each {|track|
    $track | get_acoustid_fingerprint_track $ignore_existing
  }
}

# Determine the MusicBrainz Recording IDs and the MusicBrainz Release ID of the given files using their AcoustID fingerprints
export def get_musicbrainz_ids_by_acoustid [
  client_key: string # The application API key for the AcoustID server
  ignore_embedded_acoustid_fingerprints # Recalculate AcoustID fingerprints for all files
  fail_fast = true # Immediately return null when a fingerprint has no matches that meet the threshold score
  --threshold: float = 1.0 # A float value between zero and one, the minimum score required to be considered a match
  --api-requests-per-second: int = 3 # The number of API requests to make per second. AcoustID only permits up to three requests per second.
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: record<book: record, tracks: table> -> record<book: record, tracks: table> {
  let metadata = $in
  if ($metadata | is-empty) or "tracks" not-in $metadata or ($metadata.tracks | is-empty) {
    return null
  }

  let tracks = $metadata.tracks | get_acoustid_fingerprint_tracks $ignore_embedded_acoustid_fingerprints

  # log info $"acoustid_fingerprints: ($acoustid_fingerprints)"
  let acoustid_responses = (
    $tracks
    | select file duration acoustid_fingerprint
    | rename file duration fingerprint
    | fetch_release_ids_by_acoustid_fingerprints $client_key $threshold $fail_fast $api_requests_per_second --retries $retries --retry-delay $retry_delay
  )
  if ($acoustid_responses | is-empty) {
    log error "AcoustID responses missing"
    return null
  }
  # log info $"acoustid_responses: ($acoustid_responses | to nuon)"
  let release_ids = $acoustid_responses | determine_releases_from_acoustid_fingerprint_matches
  if ($release_ids | is-empty) {
    log error "No common release ids found for the AcoustID fingerprints"
    return null
  } else if ($release_ids | length) > 1 {
    log error $"Multiple release ids found for the AcoustID fingerprints: ($release_ids)"
    return null
  }
  let release_id = $release_ids | first
  let track_recording_ids_for_release = (
    $acoustid_responses | flatten | each {|track|
      let recording_ids = (
        $track
        | get matches
        | get recordings
        | filter {|recording|
          $release_id in ($recording.releases.id)
        }
        | get id
      );
      {
        file: $track.file
        acoustid_track_id: $track.matches.id
        musicbrainz_recording_ids: $recording_ids
      }
    }
  )
  let each_track_has_exactly_one_recording_for_the_release = $track_recording_ids_for_release | all {|track|
    ($track.musicbrainz_recording_ids | length) == 1
  }
  if (not $each_track_has_exactly_one_recording_for_the_release) {
    log error "Failed to link each AcoustID track to exactly one recording for the release"
    return null
  }
  let track_recording_ids_for_release = $track_recording_ids_for_release | each {|track|
    (
      $track
      | insert musicbrainz_recording_id ($track.musicbrainz_recording_ids | first)
      | reject musicbrainz_recording_ids
    )
  }

  # Add the AcoustID Track IDs and MusicBrainz Recording IDs for each track.
  let tracks = (
    $tracks
    | reject --ignore-errors acoustid_track_id musicbrainz_recording_id
    # | flatten
    | join --left $track_recording_ids_for_release file
  )

  {
    book: ($metadata.book | upsert musicbrainz_release_id $release_id)
    tracks: $tracks
  }
}

# Determine whether the length of tracks in one set are within a given threshold compared to tracks in another set
export def equivalent_track_durations [
  right: table<index: int, duration: duration>
  threshold: duration = 3sec # The allowed drift between the duration of tracks
]: table<index: int, duration: duration> -> bool {
  let left = $in
  let joined = ($left | rename index left_duration) | join ($right | rename index right_duration) index
  (
    # Same number of tracks
    ($left | length) == ($right | length)
    # Same indices
    and ($joined | length) == ($right | length)
    # Difference is within threshold
    and (
      $joined | all {|track|
        (($track.left_duration - $track.right_duration) | math abs) <= $threshold
      }
    )
  )
}

# Determine if two sets of contributors have at least one distributor in common
#
# If both sets are empty, true is returned.
export def has_distributor_in_common [
  right: table<id: string, name: string, entity: string, role: string>
]: table<id: string, name: string, entity: string, role: string> -> bool {
  let left = $in
  if ($right | is-empty) and ($left | is-empty) {
    return true
  }
  if ($right | is-empty) or ($left | is-empty) {
    return false
  }
  let left_distributors = $left | where role == "distributor"
  let right_distributors = $right | where role == "distributor"
  let joined_on_id = (
    $left_distributors
    | rename id left_name left_entity
    | join ($right_distributors | rename id right_name right_entity) id
    | filter {|distributor|
      $distributor.left_entity == $distributor.right_entity
    }
  )
  if ($joined_on_id | is-not-empty) {
    return true
  }
  let joined_on_name = (
    $left_distributors
    | rename left_id name left_entity
    | join ($right_distributors | rename right_id name right_entity) name
  )
  if ($joined_on_name | is-empty) {
    return false
  }
  $joined_on_name | any {|distributor|
    (
      $distributor.left_entity == $distributor.right_entity
      and (
        ($distributor.left_id | is-empty)
        or ($distributor.right_id | is-empty)
      )
    )
  }
}

# Given a list of MusicBrainz Release audiobook metadata records and metadata of an audiobook, attempt to narrow down the matching releases
#
# The chapters release must be within the duration threshold and must be from the same distributor if one is set.
export def filter_musicbrainz_releases [
  metadata: record<book: record, tracks: table> # Audiobook metadata
  duration_threshold: duration = 3sec # The allowed drift between the duration of tracks
]: table<book: record, tracks: table> -> list<string> {
  let candidates = $in
  # log info $"candidates: ($candidates | to nuon)"
  # log info $"metadata: ($metadata | reject tracks.embedded_pictures | to nuon)"

  if ($metadata | is-empty) or "book" not-in ($metadata) or "tracks" not-in ($metadata) or ($metadata.tracks | is-empty) {
    return null
  }

  if "musicbrainz_release_id" in $metadata.book and ($metadata.book.musicbrainz_release_id | is-not-empty) {
    return [$metadata.book.musicbrainz_release_id]
  }

  # Filter based on the Audible ASIN, track durations, and distributor

  let candidates = (
    if ($metadata.book | get --ignore-errors audible_asin | is-empty) {
      $candidates
    } else {
      $candidates | filter {|candidate|
        ($candidate.book | get --ignore-errors audible_asin) == $metadata.book.audible_asin
      }
    }
  )
  if ($candidates | is-empty) {
    return null
  }
  if ($candidates | length) == 1 {
    return $candidates.book.musicbrainz_release_id
  }

  let candidates = (
    # If for some reason tracks are missing from the audiobook, this won't filter anything based on track lengths
    if ($metadata.tracks | length) == $metadata.book.total_tracks {
      $candidates | filter {|candidate|
        $candidate.tracks | select index duration | equivalent_track_durations ($metadata.tracks | select index duration) $duration_threshold
      }
    } else {
      $candidates
    }
  )
  if ($candidates | is-empty) {
    return null
  }
  if ($candidates | length) == 1 {
    return $candidates.book.musicbrainz_release_id
  }

  let candidates = (
    $candidates | filter {|candidate|
      $candidate.book | get --ignore-errors contributors | has_distributor_in_common ($metadata.book | get --ignore-errors contributors)
    }
  )
  if ($candidates | is-empty) {
    return null
  }
  $candidates.book.musicbrainz_release_id
}

# Tag the files of an audiobook
#
# This function will attempt to identify audiobooks using available information in the following order.
# 1. Embedded MusicBrainz Release and Recording IDs
# 2. Embedded AcoustID fingerprints
# 3. Calculated AcoustID fingerprints
# 4. Via MusicBrainz search using the existing metadata
#
# If results for none of these methods is conclusive, it's recommended to provide the MusicBrainz Release ID.
# AcoustID fingerprints will be submitted automatically when they are not already embedded in the file along with the corresponding MusicBrainz Recording IDs.
# AcoustID fingerprints are also not submitted when they are successfully retrieved from the server.
#
# When an audiobook consists of multiple files, the caller must order the files correctly when the track number tag is missing and MusicBrainz Recording IDs can't be determined via AcoustID or embedded tags.
# I might add logic here in the future to allow ordering recordings based on the natural order of the titles, but track number is usually embedded.
export def tag_audiobook [
  working_directory: directory
  cache: closure # Function to call to check for or update cached values. Looks like {|type, id, update_function| ...}
  submit_all_acoustid_fingerprints = false # AcoustID fingerprints are only submitted for files where one or both of the AcoustID fingerprints and MusicBrainz Recording IDs are updated from the values present in the embedded metadata. Set this to true to submit all AcoustIDs regardless of this.
  combine_chapter_parts = false # Combine chapters split into multiple parts into individual chapters
  ignore_embedded_acoustid_fingerprints = false # Recalculate AcoustID fingerprints for all files
  ignore_embedded_musicbrainz_ids = false # Ignore existing MusicBrainz IDs embedded in the files
  fail_fast = true # Immediately return null when a fingerprint has no matches that meet the threshold score
  --search-score-threshold: int = 100 # An int value between zero and one hundred, the minimum score required to be considered a match when searching MusicBrainz
  --max-track-duration-difference: duration = 3sec # The maximum allowable difference between track durations
  --acoustid-score-threshold: float = 1.0 # A float value between zero and one, the minimum score required to be considered a match when searching AcoustID fingerprints
  --acoustid-client-key: string # The application API key for the AcoustID server
  --acoustid-user-key: string # Submit AcoustID fingerprints to the AcoustID server using the given user API key
  --musicbrainz-release-id: string = "" # The MusicBrainz Release ID associated with the release
  --api-requests-per-second: int = 3 # The number of API requests to make per second. AcoustID only permits up to three requests per second.
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: list<path> -> record<book: record, tracks: table> {
  let audiobook_files = $in
  if ($audiobook_files | is-empty) {
    log error "No audiobook files provided!"
    return null
  }

  let metadata = $audiobook_files | parse_audiobook_metadata_from_files

  # Create a copy of the original embedded metadata to see if AcoustID Fingerprints should be submitted at then end
  let original_metadata = $metadata

  # log info $"$metadata: ($metadata)"

  if "tracks" not-in $metadata or ($metadata.tracks | is-empty) {
    # This shouldn't ever happen
    log error "No track metadata!"
    return null
  }

  let metadata = (
    if ($musicbrainz_release_id | is-not-empty) {
      # todo Wipe existing recording ids here to ensure they don't effect tagging
      # Or otherwise ensure they won't be an issue when tagging
      $metadata | upsert book.musicbrainz_release_id $musicbrainz_release_id
    } else {
      $metadata
    }
  )

  # If missing MusicBrainz Release and/or Recording IDs, try using AcoustID
  let acoustid_metadata = (
    if (
      ($musicbrainz_release_id | is-empty)
      and (
        ($metadata.book | get --ignore-errors musicbrainz_release_id | is-empty)
        or (
          $metadata.tracks
          | any {|track|
            "musicbrainz_recording_id" not-in $track or ($track.musicbrainz_recording_id | is-empty)
          }
        )
      )
    ) {
      (
        $metadata
        | (
          get_musicbrainz_ids_by_acoustid
          $acoustid_client_key
          $ignore_embedded_acoustid_fingerprints
          $fail_fast
          --threshold $acoustid_score_threshold
          --api-requests-per-second $api_requests_per_second
          --retries $retries
          --retry-delay $retry_delay
        )
      )
    }
  )
  let metadata = (
    if ($acoustid_metadata | is-empty) {
      $metadata
    } else {
      $acoustid_metadata
    }
  )

  let metadata = (
    if (
      ($musicbrainz_release_id | is-empty)
      and ($metadata.book | get --ignore-errors musicbrainz_release_id | is-empty)
    ) {
      log info $"Unable to determine MusicBrainz Recording and Release IDs using AcoustID fingerprints"
      let release_candidates = $metadata | search_for_musicbrainz_release --retries $retries --retry-delay $retry_delay
      if ($release_candidates | is-empty) {
        log error $"Unable to find any matching MusicBrainz releases. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
        $metadata
      } else {
        let release_candidates = $release_candidates | where score >= $search_score_threshold
        if ($release_candidates | is-empty) {
          log error $"Unable to find any matching MusicBrainz releases with a perfect score. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
          $metadata
        } else if ($release_candidates | length) > 20 {
          log error $"Found over 20 matching MusicBrainz releases. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
          $metadata
        } else if ($release_candidates | length) == 1 {
          let release_candidate = $release_candidates.id | first
          log info $"Found matching MusicBrainz Release (ansi yellow)($release_candidate)(ansi reset)"
          $metadata | upsert book.musicbrainz_release_id $release_candidate
        } else {
          log debug $"Found multiple MusicBrainz releases with a perfect score. Attempting to narrow down further based on the distributor and track lengths"
          let $release_candidates = $release_candidates | get id | each {|candidate|
            let received_metadata = $candidate | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay [label-rels recordings url-rels]
            if ($received_metadata | is-empty) {
              log error $"Error fetching metadata for MusicBrainz Release (ansi yellow)($candidate)(ansi reset)"
              null
            } else {
              $received_metadata
            }
          }
          if ($release_candidates | any {|r| $r == null}) {
            return null
          }
          let release_candidates = $release_candidates | filter_musicbrainz_releases $metadata $max_track_duration_difference
          if ($release_candidates | is-empty) {
            log error $"Unable to find any matching MusicBrainz releases after filtering. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
            $metadata
          } else if ($release_candidates | length) == 1 {
            let release_candidate = $release_candidates | first
            log info $"Found matching MusicBrainz Release (ansi yellow)($release_candidate)(ansi reset) after filtering"
            $metadata | upsert book.musicbrainz_release_id $release_candidate
          } else {
            # todo Interactively allow selecting an available release
            log error $"Multiple matching MusicBrainz releases remaining after filtering. Please pass the exact MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
            $metadata
          }
        }
      }
    } else {
      log info $"Successfully determined the MusicBrainz Recording and Release IDs using AcoustID fingerprints"
      $metadata
    }
  )

  # todo Validate MBIDs when parsing them.

  if ($metadata | is-empty) or "book" not-in $metadata or "musicbrainz_release_id" not-in $metadata.book or ($metadata.book.musicbrainz_release_id | is-empty) {
    log error "Unable to determine the MusicBrainz Release ID. Aborting. Please supply the MusicBrainz Release ID with the '--musicbrainz-release-id' flag"
    log debug $"$metadata: ($metadata | to nuon)"
    return null
  }
  # Tag the files
  let metadata = (
    $metadata
    | (
      tag_audiobook_tracks_by_musicbrainz_release_id
      $working_directory
      $cache
      $combine_chapter_parts
      --retries $retries
      --retry-delay $retry_delay
    )
  )
  if ($metadata | is-empty) {
    log error "Failed to tag audio tracks!"
    return null
  }

  # Submit AcoustID fingerprints
  if ($acoustid_user_key | is-not-empty) {
    # Calculate the AcoustID fingerprint if necessary
    let tracks = (
      $metadata.tracks | each {|track|
        if ($track | get --ignore-errors "acoustid_fingerprint" | is-empty) {
          $track | get_acoustid_fingerprint_track $ignore_embedded_acoustid_fingerprints
        } else {
          $track
        }
      }
    )
    # Filter out tracks where the MusicBrainz Recording IDs were successfully retrieved by using their AcoustID fingerprints.
    # That means that the AcoustID fingerprints already exist on the server and don't need to be submitted.
    let tracks = (
      if $submit_all_acoustid_fingerprints {
        $tracks
      } else {
        if ($acoustid_metadata | is-empty) {
          $tracks
        } else {
          # Don't filter out tracks where the retrieved MusicBrainz Recording ID differs from the one the track ended up with at the end
          (
            $tracks
            | join ($acoustid_metadata.tracks | rename --column {musicbrainz_recording_id: "retrieved_musicbrainz_recording_id"}) file
            | filter {|track|
              $track.musicbrainz_recording_id != $track.retrieved_musicbrainz_recording_id
            }
          )
        }
      }
    )
    # Filter out tracks which already had the embedded AcoustID fingerprint and corresponding MusicBrainz Recording ID.
    let tracks = (
      if $submit_all_acoustid_fingerprints {
        $tracks
      } else {
        if (
          "acoustid_fingerprint" in ($original_metadata.tracks | columns)
          and "musicbrainz_recording_id" in ($original_metadata.tracks | columns)
        ) {
          # We have both acoustid_fingerprint and musicbrainz_recording_id columns, but one or the other could be missing for individual tracks
          (
            $original_metadata.tracks
            | rename --column {
              acoustid_fingerprint: "original_acoustid_fingerprint"
              musicbrainz_recording_id: "original_musicbrainz_recording_id"
            }
            | join $tracks file
            # Filter out tracks with consistent fingerprints and recording ids
            | filter {|track|
              # Double check if original values are missing or empty for each individual track
              if ($track | get --ignore-errors original_acoustid_fingerprint | is-empty) or ($track | get --ignore-errors original_musicbrainz_recording_id | is-empty) {
                true
              } else {
                not (
                  $track.original_acoustid_fingerprint == $track.acoustid_fingerprint
                  and $track.original_musicbrainz_recording_id == $track.musicbrainz_recording_id
                )
              }
            }
          )
        } else {
          $tracks
        }
      }
    )
    # log info $"tracks: ($tracks)"
    if ($tracks | is-empty) {
      log info "No AcoustID fingerprints will be submitted since tracks already had corresponding AcoustID fingerprints and MusicBrainz Recording IDs on the AcoustID server or embedded in their metadata."
    } else {
      # log info $"$tracks: ($tracks | reject embedded_pictures)"
      let acoustid_submissions = (
        $tracks
        | select musicbrainz_recording_id duration acoustid_fingerprint
        | rename musicbrainz_recording_id duration fingerprint
        | submit_acoustid_fingerprints $acoustid_client_key $acoustid_user_key --retries $retries --retry-delay $retry_delay
      )
      if ($acoustid_submissions | is-not-empty) {
        log info $"Submitted AcoustID fingerprints: ($acoustid_submissions | to nuon)"
      } else {
        log error $"Failed to submit AcoustID fingerprints!"
      }
    }
  }

  $metadata
}

# Parse chapters from tone.
#
# The format is similar to tone's format.
# Unlike the format tone uses, the start and length fields are durations.
# For output via tone, these need to be converted back to milliseconds as integers.
export def parse_chapters_from_tone []: table<start: int, length: int, title: string> -> table<index: int, start: duration, length: duration, title: string> {
  $in | enumerate | each {|chapter|
    {
      index: $chapter.index
      start: ($chapter.item.start | into duration --unit ms)
      length: ($chapter.item.length | into duration --unit ms)
      title: $chapter.item.title
    }
  }
}

# Convert chapters to the format used by tone.
#
# This format is similar to the internal format used for chapters.
# The only difference is that the start and length fields are milliseconds represented by integers.
export def chapters_into_tone_format []: table<index: int, start: duration, length: duration, title: string> -> table<index: int, start: int, length: int, title: string> {
  $in | each {|chapter|
    (
      $chapter
      | update start (($chapter.start / 1ms) | math round)
      | update length (($chapter.length / 1ms) | math round)
      # To make Tone's output nicer
      | insert subtitle ""
    )
  }
}

# Convert chapters to the chapters.txt format used by tone.
export def chapters_into_chapters_txt_format []: table<index: int, start: duration, length: duration, title: string> -> table<string> {
  $in | each {|chapter|
    let offset = $chapter.start | format_chapter_duration
    $"($offset) ($chapter.title)"
  }
}

# Parse chapters from a MusicBrainz Release into a format similar to the one used by tone.
#
# Unlike the format tone uses, the start and length fields are durations.
# For tone, these need to be converted to milliseconds as integers.
export def parse_chapters_from_musicbrainz_release []: record -> table<index: int, start: duration, length: duration, title: string> {
  let metadata = $in
  let chapters = (
    $metadata
    | get media
    | get tracks
    | flatten
    | enumerate
    | each {|recording|
      {
          index: $recording.index
          title: $recording.item.title
          duration: ($recording.item.length | into duration --unit ms)
      }
    }
  )
  let start_offsets = $chapters | get duration | lengths_to_start_offsets
  $chapters | each {|c|
    let start = $start_offsets | get $c.index
    {
      index: $c.index
      start: $start
      length: $c.duration
      title: $c.title
    }
  }
}

# Filter and sort audiobooks based on the chapters tag, returning only the audiobooks which have the highest chapters count
export def audiobooks_with_the_highest_voted_chapters_tag []: table<id: string, tags: table<name: string, count: int>> -> list<string> {
  let candidates = $in
  if ($candidates | is-empty) {
    return null
  }
  let candidates_with_chapters_tag = $candidates | filter {|candidate|
    "chapters" in $candidate.tags.name
  }
  if ($candidates_with_chapters_tag | is-empty) {
    return null
  }
  if ($candidates_with_chapters_tag | length) == 1 {
    return ($candidates_with_chapters_tag | get id)
  }
  let sorted_candidates = (
    $candidates_with_chapters_tag
    | sort-by --custom {|a, b|
      (
        ($a.tags | where name == "chapters" | get count | first)
        >=
        ($b.tags | where name == "chapters" | get count | first)
      )
    }
  )
  let highest_count = ($sorted_candidates | first | get tags | where name == "chapters" | get count | first)
  $sorted_candidates | filter {|candidate|
    ($candidate.tags | where name == "chapters" | get count | first) >= $highest_count
  } | get --ignore-errors id | sort
}

# Given a number of audiobooks and a target audiobook, narrow down the audiobooks that can be used as chapters for the target audiobook
export def filter_musicbrainz_chapters_releases [
  release: record<book: record, tracks: table>
  duration_threshold: duration = 3sec # The allowed drift between the duration of the release and a candidate chapters release
]: table<book: record, tracks: table> -> table<book: record, tracks: table> {
  let candidates = $in
  # log info $"candidates: ($candidates | to nuon)"
  # log info $"release: ($release | reject tracks.embedded_pictures | to nuon)"

  let candidates = (
    if ($release.book | get --ignore-errors audible_asin | is-empty) {
      $candidates
    } else {
      $candidates | filter {|candidate|
        ($candidate.book | get --ignore-errors audible_asin) == $release.book.audible_asin
      }
    }
  )
  if ($candidates | is-empty) {
    return null
  }

  let candidates = $candidates | filter {|candidate|
    if ($release.tracks | length) >= ($candidate.tracks | length) {
      return false
    }
    if ((($release.tracks | get duration | math sum) - ($candidate.tracks | get duration | math sum)) | math abs) > $duration_threshold {
      return false
    }
    if not ($candidate.book | get --ignore-errors contributors | has_distributor_in_common ($release.book | get --ignore-errors contributors)) {
      return false
    }
    true
  }
  if ($candidates | is-empty) {
    return null
  }
  if ($candidates | length) == 1 {
    return $candidates
  }
  # Use the chapters tag to decide between multiple remaining candidates
  if "tags" in ($candidates.book | columns) {
    let highest_voted_chapters = (
      $candidates.book | each {|book|
        let release_tags = (
          $book.tags
          | where scope == "release"
          | reject --ignore-errors scope
        )
        {
          id: $book.musicbrainz_release_id
          tags: $release_tags
        }
      } | audiobooks_with_the_highest_voted_chapters_tag
    )
    $candidates | where book.musicbrainz_release_id in $highest_voted_chapters
  } else {
    return $candidates
  }
}

# Given a release, attempt to find a release in the same release group that has more tracks.
#
# The chapters release must be within the duration threshold and must be from the same distributor if one is set.
#
# Input is the parsed metadata of the MusicBrainz release.
# The output is the chapters in a table formatted for a tone JSON file
export def look_up_chapters_from_similar_musicbrainz_release [
  duration_threshold: duration = 3sec # The allowed drift between the duration of the release and a candidate chapters release
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 1sec # The interval between successive attempts when there is a failure
]: record -> table<index: int, start: duration, length: duration, title: string> {
# ]: table -> table<index: int, start: duration, length: duration, title: string> {
  let release = $in
  if "musicbrainz_release_group_id" not-in $release.book or ($release.book.musicbrainz_release_group_id | is-empty) {
    return null
  }

  let num_tracks = ($release.tracks | length)

  let allowed_statuses = ["official", "pseudo-release"]

  # "https://musicbrainz.org/ws/2/release/?fmt=json&query="
  let url = "https://musicbrainz.org/ws/2/release/"
  let query = $"rgid:($release.book.musicbrainz_release_group_id) AND NOT tracks:1 AND \(status:official OR status:pseudo-release\) AND NOT reid:($release.book.musicbrainz_release_id)"

  let query = (
    $query
    | append_to_musicbrainz_query $release.book musicbrainz_release_country country
    # todo Store year specially compared to full date?
    | append_to_musicbrainz_query $release.book publication_date date --transform {|d|
      let date = $d | format date '%Y-%m-%d'
      if ($date | str ends-with "-01-01") {
        $date | str replace "-01-01" ""
      } else {
        $date
      }
    }
    | append_to_musicbrainz_query $release.book amazon_asin asin
    | append_to_musicbrainz_query $release.book isbn barcode
    | append_to_musicbrainz_query $release.book language lang
    | append_to_musicbrainz_query $release.book script script
  )

  # log info $"query: ($query)"
  let query = $query | url encode
  let request = {http get --full --headers [User-Agent $user_agent Accept "application/json"] $"($url)?query=($query)"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error searching for similar releases: ($url)?query=($query)\t($error.debug.msg)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code ($response.status) when searching for similar releases: ($url)?query=($query)"
    return null
  }

  let candidates = $response | get body | get releases | where score == 100 | get --ignore-errors id
  if ($candidates | is-empty) {
    return null
  }
  # Don't parallelize for the sake of the MusicBrainz API
  let candidates = $candidates | each {|candidate|
    let received_metadata = $candidate | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay [recordings label-rels tags url-rels]
    if ($received_metadata | is-empty) {
      log error $"Error fetching metadata for MusicBrainz Release (ansi yellow)($candidate)(ansi reset)"
      return null
    }
    $received_metadata
  }

  # log info $"$release ($release)"
  let candidates = $candidates | filter_musicbrainz_chapters_releases $release $duration_threshold
  if ($candidates | length) > 1 {
    log warning $"More than one MusicBrainz Release candidate for chapters found: ($candidates | get book.id). Please add or vote up the chapters tag on the desired release."
    return null
  }
  let candidate = $candidates | first
  log info $"Using the MusicBrainz Release (ansi yellow)($candidate.book.musicbrainz_release_id)(ansi reset) for chapters"
  $candidate | get book.chapters
}

# Tag the given audio files using the given MusicBrainz release id
#
# The individual audio files should be provided in a table as input.
# The file key should be used for the path of each file on disk.
#
# The table can also include the MusicBrainz Recording ID using the musicbrainz_recording_id key.
# This ensures that each track is associated with the correct recording.
# It's particularly useful for associating files with recordings using AcoustID fingerprints.
# Without the MusicBrainz Recording ID, tracks must be provided in the correct order as they appear on the release.
# The tracks will be checked against their expected durations in this case to ensure correctness.
#
# In addition to the musicbrainz_recording_id key, the acoustid_fingerprint, audio_duration, and acoustid_track_id tags can also be included.
# The acoustid_fingerprint and acoustid_track_id will be embedded in the files with the other metadata.
# The audio_duration value is used to avoid recalculating the duration of the audio.
# export def tag_audiobook_files_by_musicbrainz_release_id [
#   release_id: string
#   working_directory: directory
#   duration_threshold: duration = 2sec # The acceptable difference in track length of the file vs. the length of the track in MusicBrainz
#   chapters_duration_threshold: duration = 3sec # The acceptable difference in the duration of the release vs. the duration of a MusicBrainz Release for chapters
#   --retries: int = 3
#   --retry-delay: duration = 5sec
# ]: table -> list<path> {
#   let audiobook_files = $in
#   # let current_metadata = (
#   #   $audiobook_files | parse_audiobook_metadata_from_files
#   # )
#   let metadata = (
#     $release_id | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay
#   )
#   if ($metadata | is-empty) {
#     log error $"Failed to fetch MusicBrainz Release (ansi yellow)($release_id)(ansi reset)"
#     return null
#   }
#   # log info $"audiobook_files: ($audiobook_files)"
#   # log info $"audiobook_files.metadata.track: ($audiobook_files.metadata.track)"
#   let tracks = (
#     if (
#       "musicbrainz_recording_id" in ($audiobook_files | columns)
#       and ($audiobook_files.musicbrainz_recording_id | is-not-empty)
#     ) {
#       $metadata.tracks | join $audiobook_files musicbrainz_recording_id
#     } else {
#       let enumerated_audiobook_files = (
#         $audiobook_files | enumerate | each {|f|
#           {
#             index: ($f.index + 1)
#             file: $f.item.file
#           }
#         }
#       )
#       $metadata.tracks | join $enumerated_audiobook_files index
#     }
#   )
#   # log info $"tracks: ($tracks)"
#   for track in $tracks {
#     let duration = (
#       if "audio_duration" in $track and ($track.audio_duration | is-not-empty) {
#         $track.audio_duration
#       } else {
#         $track.file | tone_dump | get audio.duration | into int | into duration --unit ms
#       }
#     )
#     if ($track.duration - $duration | math abs) > $duration_threshold {
#       log error $"The (ansi green)($track)(ansi reset) is ($duration) long, but the MusicBrainz track is ($track.duration) long, which is outside the acceptable duration threshold of ($duration_threshold)"
#       return null
#     }
#   }

#   let chapters = (
#     if ($metadata | get --ignore-errors chapters | is-empty) {
#       $metadata | look_up_chapters_from_similar_musicbrainz_release $chapters_duration_threshold --retries $retries --retry-delay $retry_delay
#     } else {
#       $metadata.chapters
#     }
#   )
#   # log info $"Chapters: ($chapters)"

#   let front_cover = (
#     if "front_cover_available" in $metadata.book and $metadata.book.front_cover_available {
#       $metadata.book.musicbrainz_release_id | fetch_release_front_cover $working_directory
#     }
#   )

#   # let chapters_file = mktemp --suffix ".txt" --tmpdir
#   # if ($chapters | is-not-empty) {
#   #   $chapters | chapters_into_chapters_txt_format | save --force $chapters_file
#   # }

#   let files = (
#     $metadata
#     | update tracks $tracks
#     | reject --ignore-errors book.embedded_pictures
#     | (
#       let input = $in;
#       if ($chapters | is-not-empty) {
#         $input | upsert book.chapters $chapters
#       } else {
#         $input
#       }
#     )
#     | (
#       tone_tag_tracks $working_directory
#       "--taggers" 'remove,*'
#       # Remove all sort fields
#       "--meta-remove-property" "sortalbum"
#       "--meta-remove-property" "sorttitle"
#       "--meta-remove-property" "sortalbumartist"
#       "--meta-remove-property" "sortartist"
#       "--meta-remove-property" "sortcomposer"
#       "--meta-remove-property" "EmbeddedPictures"
#       "--meta-remove-property" "comment"
#       "--meta-cover-file" $front_cover
#       # "--meta-chapters-file" $chapters_file
#     )
#   )

#   # Clean up
#   if ($front_cover | is-not-empty) {
#     rm $front_cover
#   }
#   # if ($chapters_file | is-not-empty) {
#   #   rm $chapters_file
#   # }

#   $files
# }


# Tag the given audiobook tracks using the MusicBrainz Release ID and certain other metadata
#
# The individual audio files should be provided in a table as input.
# The file key should be used for the path of each file on disk.
#
# The table can also include the MusicBrainz Recording ID using the musicbrainz_recording_id key.
# This ensures that each track is associated with the correct recording.
# It's particularly useful for associating files with recordings using AcoustID fingerprints.
# Without the MusicBrainz Recording ID, tracks must be provided in the correct order as they appear on the release.
# The tracks will be checked against their expected durations in this case to ensure correctness.
#
# In addition to the musicbrainz_recording_id key, the acoustid_fingerprint, audio_duration, and acoustid_track_id tags can also be included.
# The acoustid_fingerprint and acoustid_track_id will be embedded in the files with the other metadata.
# The audio_duration value is used to avoid recalculating the duration of the audio.
export def tag_audiobook_tracks_by_musicbrainz_release_id [
  working_directory: directory
  cache: closure
  combine_chapter_parts = false # Combine chapters split into multiple parts into individual chapters
  duration_threshold: duration = 2sec # The acceptable difference in track length of the file vs. the length of the track in MusicBrainz
  chapters_duration_threshold: duration = 3sec # The acceptable difference in the duration of the release vs. the duration of a MusicBrainz Release for chapters
  --retries: int = 3
  --retry-delay: duration = 5sec
]: record<book: record, tracks: table> -> record<book: record, tracks: table> {
  let existing_metadata = $in
  if "book" not-in $existing_metadata or "musicbrainz_release_id" not-in $existing_metadata.book or ($existing_metadata.book.musicbrainz_release_id | is-empty) {
    log error "Missing MusicBrainz Release ID"
    return null
  }
  if "tracks" not-in $existing_metadata or ($existing_metadata.tracks | is-empty) {
    log error "Missing tracks to tag"
    return null
  }
  # Keep / rename only the necessary columns
  let existing_metadata = (
    $existing_metadata | upsert tracks (
      # Rename duration column to audio_duration
      $existing_metadata.tracks | insert audio_duration {|track| $track.duration}
    )
  )
  let musicbrainz_metadata = (
    $existing_metadata.book.musicbrainz_release_id | fetch_and_parse_musicbrainz_release --retries $retries --retry-delay $retry_delay
  )
  if ($musicbrainz_metadata | is-empty) {
    log error $"Failed to fetch MusicBrainz Release (ansi yellow)($existing_metadata.book.musicbrainz_release_id)(ansi reset)"
    return null
  }

  # log info $"audiobook_files: ($audiobook_files)"
  # log info $"musicbrainz_metadata: ($musicbrainz_metadata)"
  let tracks = (
    if (
      "musicbrainz_recording_id" in ($existing_metadata.tracks | columns)
      and ($existing_metadata.tracks.musicbrainz_recording_id | is-not-empty)
    ) {
      # todo Verify that no individual recording ids are missing?
      $musicbrainz_metadata.tracks | join --right $existing_metadata.tracks musicbrainz_recording_id
      # log info $"x: ($x | reject embedded_pictures | to nuon)"
    } else {
      let enumerated_tracks = (
        $existing_metadata.tracks | enumerate | each {|t|
          $t.item | upsert index ($t.index + 1)
        }
      )
      $musicbrainz_metadata.tracks | join $enumerated_tracks index
    }
  )

  # log info $"tracks: ($tracks)"
  for track in $tracks {
    let duration = (
      if "audio_duration" in $track and ($track.audio_duration | is-not-empty) {
        $track.audio_duration
      } else {
        log error "Missing track audio duration for some reason!"
        return null
      }
    )
    if ($track.duration - $duration | math abs) > $duration_threshold {
      log error $"The (ansi green)($track)(ansi reset) is ($duration) long, but the MusicBrainz track is ($track.duration) long, which is outside the acceptable duration threshold of ($duration_threshold)"
      return null
    }
  }
  # log info $"musicbrainz_metadata: ($musicbrainz_metadata)"
  # log info $"tracks: ($tracks)"
  let musicbrainz_metadata = $musicbrainz_metadata | upsert tracks $tracks

  # This should only be necessary to check at the point where renaming occurs
  # Verify that there is only one release-group, work, or other kind of series for a book.
  # if "series" in $metadata.book and $metadata.book.series != null {
  #   if "scope" in ($metadata.book.series | columns) {
  #     let release_group_series = $metadata.book.series | where scope == "release group"
  #     if ($release_group_series | is-empty) {
  #       # Fall back to the work series if there is no release group series
  #       let work_series = $metadata.book.series | where scope == "work"
  #       if ($work_series | is-empty) {
  #         # Use whatever series exist are at this point
  #         if ($metadata.book.series | length) > 1 {
  #           log warning "More than one non release group / non work series exists when no release group series exist. Not yet able to determine series and subseries ordering."
  #         } else if ($metadata.book.series | length) == 1 {
  #           log warning "Will fall back to non release group / non work series because no release group or work series exist"
  #         }
  #       } else if ($work_series | length) != 1 {
  #         log warning "More than one work series exists when no release group series exist. Not yet able to determine series and subseries ordering."
  #       } else {
  #         log warning "Will fall back to work series because no release group series exists"
  #       }
  #     } else if ($release_group_series | length) != 1 {
  #       log warning $"More than one release group series exists. Not yet able to determine series and subseries ordering."
  #     }
  #   } else {
  #     log warning $"No scope available for series: ($metadata.book.series)"
  #   }
  # }

  # Fetch additional MusicBrainz Series info, such as genres, tags, and series relationships
  # todo Attach series to tracks?
  # todo Determine series order based on parent and subseries relationships
  let musicbrainz_metadata = (
    if ($musicbrainz_metadata | get --ignore-errors book.series | is-empty) {
      $musicbrainz_metadata
    } else {
      $musicbrainz_metadata | update book.series (
        $musicbrainz_metadata.book.series | each {|series|
          $series | merge ($series.id | fetch_and_parse_musicbrainz_series $cache --retries $retries --retry-delay $retry_delay)
        }
      )
    }
  )

  # Incorporate the series genres and tags into the book genres and tags.
  # Prefer those belonging to a series.
  let musicbrainz_metadata = (
    if ($musicbrainz_metadata | get --ignore-errors book.series | is-empty) {
      $musicbrainz_metadata
    } else {
      (
        $musicbrainz_metadata
        | upsert book.genres (
          $musicbrainz_metadata.book.series | each {|series|
            if ($series | get --ignore-errors genres | is-empty) {
              $series.genres
            } else {
              $series.genres | default ($series.scope + " series") scope
            }
          } | (
            let input = $in;
            # if ($input | is-not-empty) and "genres" in ($input | columns) {
            if ($input | is-not-empty) and "genres" in $input {
              $input.genres | uniq-by name scope | append $musicbrainz_metadata.book.genres
            } else {
              $input
            }
          )
        )
        | upsert book.tags (
          $musicbrainz_metadata.book.series | each {|series|
            if ($series | get --ignore-errors tags | is-empty) {
              $series.tags
            } else {
              $series.tags | default ($series.scope + " series") scope
            }
          } | (
            let input = $in;
            # if ($input | is-not-empty) and "tags" in ($input | columns) {
            if ($input | is-not-empty) and "tags" in $input {
              $input.tags | uniq-by name scope | append $musicbrainz_metadata.book.tags
            } else {
              $input
            }
          )
        )
      )
    }
  )

  # Fetch the genres and tags from the MusicBrainz Works
  # todo Apply series tags and genres of work series to relevant tracks?
  let musicbrainz_metadata = (
    $musicbrainz_metadata | update tracks (
      $musicbrainz_metadata.tracks | each {|track|
        if ($track | get --ignore-errors musicbrainz_works | is-empty) {
          $track
        } else {
          let musicbrainz_works = $track.musicbrainz_works | each {|musicbrainz_work|
            $musicbrainz_work | merge ($musicbrainz_work.id | fetch_and_parse_musicbrainz_work $cache --retries $retries --retry-delay $retry_delay)
          }
          let genres = $musicbrainz_works.genres | flatten | uniq-by name | default work scope
          let tags = $musicbrainz_works.tags | flatten | uniq-by name | default work scope
          (
            $track
            | update musicbrainz_works $musicbrainz_works
            | upsert genres (
              if ($track | get --ignore-errors genres | is-empty) {
                $genres
              } else {
                if ($genres | is-empty) {
                  $track | get --ignore-errors genres
                } else {
                  # Prefer the genres from the works
                  $genres | append $track.genres | uniq-by name scope
                }
              }
            )
            | upsert tags (
              if ($track | get --ignore-errors tags | is-empty) {
                $tags
              } else {
                if ($tags | is-empty) {
                  $track | get --ignore-errors tags
                } else {
                  # Prefer the tags from the works
                  $tags | append $track.tags | uniq-by name scope
                }
              }
            )
          )
        }
      }
    )
  )

  let chapters = (
    if "chapters" not-in $musicbrainz_metadata.book or ($musicbrainz_metadata.book.chapters | is-empty) {
      let chapters = $musicbrainz_metadata | look_up_chapters_from_similar_musicbrainz_release $chapters_duration_threshold --retries $retries --retry-delay $retry_delay
      if ($chapters | is-not-empty) {
        $chapters
      } else {
        if "chapters" in $existing_metadata.book and ($existing_metadata.book.chapters | is-not-empty) {
          # todo Should probably add flag to select whether to lookup or reuse existing chapters
          $existing_metadata.book.chapters
        }
      }
    }
  )
  let chapters = (
    if ($chapters | is-empty) or not $combine_chapter_parts {
      $chapters
    } else {
      $chapters | combine_chapter_parts
    }
  )

  let front_cover = (
    if "front_cover_available" in $musicbrainz_metadata.book and $musicbrainz_metadata.book.front_cover_available {
      $musicbrainz_metadata.book.musicbrainz_release_id | fetch_release_front_cover $working_directory
    }
  )

  let tone_args = (
    [
      "--taggers" 'remove,*'
      # Remove all sort fields
      "--meta-remove-property" "sortalbum"
      "--meta-remove-property" "sorttitle"
      "--meta-remove-property" "sortalbumartist"
      "--meta-remove-property" "sortartist"
      "--meta-remove-property" "sortcomposer"
      "--meta-remove-property" "comment"
    ]
    | append (
      if ($front_cover | is-not-empty) {
        # Drop any embedded pictures, only using the downloaded cover file
        ["--meta-remove-property" "EmbeddedPictures" "--meta-cover-file" $front_cover]
      }
    )
  )

  let files = (
    $musicbrainz_metadata
    | (
      let input = $in;
      if ($chapters | is-empty) {
        $input
      } else {
        $input | upsert book.chapters $chapters
      }
    )
    | (
      let input = $in;
      if ($front_cover | is-empty) {
        $input
      } else {
      # Drop any embedded pictures, only using the downloaded cover file
        $input | reject --ignore-errors book.embedded_pictures
      }
    )
    | tone_tag_tracks $working_directory ...$tone_args
  )

  # Clean up
  if ($front_cover | is-not-empty) {
    rm $front_cover
  }

  $musicbrainz_metadata
}

# Parse genres and tags from MusicBrainz metadata
#
# Since MusicBrainz doesn't yet support genres / themes for books, genres are generally determined from the tags.
# Tags become the genres, with a few special tags filtered out, which remain in the tags table.
# Genres and tags are then sorted by count from highest to lowest and then by name
#
# Any genres in the input table will be in the output genres table.
export def parse_genres_and_tags []: any -> record<genres: table<name: string, count: int>, tags: table<name: string, count: int>> { # record<genres: table<name: string, count: int>, tags: table<name: string, count: int>> -> record<genres: table<name: string, count: int>, tags: table<name: string, count: int>> {
  let input = $in
  if ($input | is-empty) {
    return null
  }

  # sort by the count, highest to lowest, and then name alphabetically
  let sort = {|a, b|
    if (
      ($a | is-empty)
      or ($b | is-empty)
      or "name" not-in ($a | columns)
      or "name" not-in ($b | columns)
      or "count" not-in ($a | columns)
      or "count" not-in ($b | columns)
    ) {
      return true
    }
    if $a.count == $b.count {
      $a.name < $b.name
    } else {
      $a.count > $b.count
    }
  }

  if ($input | get --ignore-errors tags | is-empty) or "tags" not-in ($input | columns) {
    if "genres" in ($input | columns) and ($input | get --ignore-errors genres | is-not-empty) {
      return {
        genres: ($input | get --ignore-errors genres | sort-by --custom $sort | uniq-by name)
        tags: []
      }
    }
    return {
      genres: []
      tags: []
    }
  }

  let genres = $input | get --ignore-errors genres | append (
    $input.tags
    # | select name count
    | filter {|tag|
      $tag.name not-in $musicbrainz_non_genre_tags
    }
  ) | sort-by --custom $sort | uniq-by name

  let tags = (
    $input.tags
    # | select name count
    | filter {|tag|
      $tag.name not-in ($genres | get --ignore-errors name)
    }
    # sort by the count, highest to lowest, and then name alphabetically
    | sort-by --custom $sort
    | uniq-by name
  )

  {
    genres: $genres
    tags: $tags
  }
}

# Append the the value for the given key in the given metadata to a MusicBrainz search query for the given search term
#
# Uses the 'AND' conjunction when appending to a non-empty query.
# Special lucene characters are properly escaped in the value.
export def append_to_musicbrainz_query [
  metadata: record
  key: string
  musicbrainz_search_term: string
  --transform: closure
]: string -> string {
  let query = $in
  if ($metadata | is-empty) {
    return $query
  }
  let prefix = (
    if ($query | is-empty) {
      ""
    } else {
      " AND "
    }
  )
  let transform = (
    if $transform == null {
      {|v| $v}
    } else {
      $transform
    }
  )
  if ($metadata | get --ignore-errors $key | is-not-empty) {
    let value = do $transform ($metadata | get $key) | escape_special_lucene_characters
    if ($value | is-not-empty) {
      $query + $"($prefix)($musicbrainz_search_term):\"($value)\""
    } else {
      $query
    }
  } else {
    $query
  }
}

# Escape special Lucene characters in a string with a backslash
export def escape_special_lucene_characters []: any -> string {
  let input = $in
  if ($input | describe) != "string" {
    return $input
  }
  const special_lucene_characters = ['\' '+' '-' '&&' '||' '!' '(' ')' '{' '}' '[' ']' '^' '"' '~' '*' '?' ':' '/']
  $special_lucene_characters | reduce --fold $input {|character, acc|
    $acc | str replace --all $character ('\' + $character)
  }
}

# Using metadata from the audio tracks, search for a MusicBrainz Release
export def search_for_musicbrainz_release [
  use_tags: bool = false
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: record -> table {
  let metadata = $in
  if ($metadata | is-empty) {
    return null
  }

  if ($metadata.book | get --ignore-errors musicbrainz_release_id | is-not-empty) {
    return [[musicbrainz_release_id]; [$metadata.book.musicbrainz_release_id]]
  }

  let url = "https://musicbrainz.org/ws/2/release/"

  let artists = (
    if ($metadata.book | get --ignore-errors contributors | is-not-empty) {
      let release_artists = $metadata.book.contributors | where entity == artist
      let track_artists = (
        if ($metadata.tracks | get --ignore-errors contributors | is-not-empty) {
          let track_artists = $metadata.tracks.contributors | uniq | where entity == artist
          if ($track_artists | is-not-empty) {
            $track_artists | where type in [narrator, writer]
          }
        }
      );
      $release_artists | append $track_artists
    }
  );

  # The release must be an Audiobook, Audio drama, or Spokenword
  let query = "primarytype:Other AND (secondarytype:Audiobook OR secondarytype:\"Audio drama\" OR secondarytype:Spokenword)"

  let query = (
    if ($artists | is-not-empty) {
      $query + (
        $artists | get --ignore-errors id | reduce {|it, acc|
          $acc + $" AND arid:\"($it | escape_special_lucene_characters)\""
        }
      )
    } else {
      $query
    }
  )
  let query = (
    if ($artists | is-not-empty) {
      $query + (
        $artists | get --ignore-errors name | reduce {|it, acc|
          $acc + $" AND artistname:\"($it | escape_special_lucene_characters)\""
        }
      )
    } else {
      $query
    }
  )
  let query = (
    # Audiobooks should have either an ASIN or a barcode, likely an ISBN, set, but not both simultaneously.
    # Prefer the ISBN if both are set.
    # todo Maybe both should be included?
    if ($metadata.book | get --ignore-errors isbn | is-not-empty) {
      $query + $" AND barcode:\"($metadata.book.isbn | escape_special_lucene_characters)\""
    } else if ($metadata.book | get --ignore-errors amazon_asin | is-not-empty) {
      $query + $" AND asin:\"($metadata.book.amazon_asin | escape_special_lucene_characters)\""
    } else {
      $query
    }
  )

  let tags = (
    let genres = (
      if ($metadata.book | get --ignore-errors genres | is-not-empty) {
        $metadata.book.genres
      }
    );
    let tags = (
      if ($metadata.book | get --ignore-errors tags | is-not-empty) {
        $metadata.book.tags
      }
    );
    $genres | append $tags
  )
  let query = (
    if $use_tags and ($tags | is-not-empty) {
      $query + $tags | reduce {|it, acc|
        $acc + $" AND tag:\"($it | escape_special_lucene_characters)\""
      }
    } else {
      $query
    }
  )

  let query = (
    if ($metadata.book | get --ignore-errors title | is-not-empty) {
      let title = $metadata.book.title | escape_special_lucene_characters
      $query + $" AND \(release:\"($title)\" OR alias:\"($title)\"\)"
    } else {
      $query
    }
  )

  let query = (
    $query
    | append_to_musicbrainz_query $metadata.book musicbrainz_release_country country
    # todo Store year specially compared to full date?
    | append_to_musicbrainz_query $metadata.book publication_date date --transform {|d|
      let date = $d | format date '%Y-%m-%d'
      if ($date | str ends-with "-01-01") {
        $date | str replace "-01-01" ""
      } else {
        $date
      }
    }
    | append_to_musicbrainz_query $metadata.book media format
    | append_to_musicbrainz_query $metadata.book publishers laid --transform {|l| $l | get --ignore-errors id}
    | append_to_musicbrainz_query $metadata.book publishers label --transform {|l| $l | get --ignore-errors name}
    | append_to_musicbrainz_query $metadata.book language lang
    | append_to_musicbrainz_query $metadata.book mediums total_discs
    | append_to_musicbrainz_query $metadata.book packaging packaging
    | append_to_musicbrainz_query $metadata.book script script
    | append_to_musicbrainz_query $metadata.book musicbrainz_release_status status
    | append_to_musicbrainz_query $metadata.book total_tracks tracks
    | append_to_musicbrainz_query $metadata.book musicbrainz_release_group_id rgid
  )
  # todo discids, discidsmedium, and tracksmedium?

  log debug $"query: ($query)"

  let query = $query | url encode

  log debug $"request: http get --full --headers [User-Agent ($user_agent) Accept \"application/json\"] ($url)?query=($query)"

  let request = {http get --full --headers [User-Agent $user_agent Accept "application/json"] $"($url)?query=($query)"}
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error searching for a release: ($url)?&query=($query)\t($error.debug.msg)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP status code ($response.status) when searching for a release: ($url)?query=($query)"
    return null
  }

  let releases = $response | get body | get releases
  if ($releases | is-empty) {
    return null
  }
  $releases | sort-by --reverse score
}

##### chapterz.nu #####

# Get a list of start offsets from a list of durations
export def lengths_to_start_offsets []: list<duration> -> list<duration> {
  let lengths = $in | enumerate
  $lengths | each {|i|
      $lengths | where index < $i.index | reduce --fold 0ms {|it,acc|
          $it.item + $acc
      }
  }
}

# Format the duration of a chapter in format used for audiobook chapters
export def format_chapter_duration []: duration -> string {
    # HH:MM:SS.fff
    let time = $in
    let hours = (
        ($time // 1hr)
        | fill --alignment right --character "0" --width 2
    )
    let minutes = (
        ($time mod 1hr // 1min)
        | fill --alignment right --character "0" --width 2
    )
    let seconds = (
        ($time mod 1min // 1sec)
        | fill --alignment right --character "0" --width 2
    )
    let fractional_seconds = (
        ($time mod 1sec / 1sec * 1000 // 1)
        | fill --alignment right --character "0" --width 3
    )
    $"($hours):($minutes):($seconds).($fractional_seconds)"
}

export def round_to_second_using_cumulative_offset []: list<duration> -> list<duration> {
    let i = $in
    $i | reduce --fold {durations: [], cumulative_offset: 0.0} {|it, acc|
    # $i | reduce {|it, acc|
        let seconds = $it / 1sec
        let floor = $seconds // 1
        let ceil = ($seconds // 1) + 1
        let floor_offset = $floor - $seconds
        let ceil_offset = $ceil - $seconds
        let duration_and_offset = (
            if (($acc.cumulative_offset + $floor_offset) | math abs) <= (($acc.cumulative_offset + $ceil_offset) | math abs) {
                # round down
                {
                    cumulative_offset: ($acc.cumulative_offset + $floor_offset)
                    duration: ($floor | into int | into duration --unit sec)
                }
            } else {
                # round up
                {
                    cumulative_offset: ($acc.cumulative_offset + $ceil_offset)
                    duration: ($ceil | into int | into duration --unit sec)
                }
            }
        )

        {
            durations: ($acc.durations | append $duration_and_offset.duration)
            cumulative_offset: $duration_and_offset.cumulative_offset
        }
    } | get durations
}

# Parse chapters out of MusicBrainz recordings data.
# $release | get media
export def chapters_from_musicbrainz_release_media []: table -> string {
  (
    $in
    | get tracks
    | flatten
    | each {|recording|
      # Unfortunately, lengths are in seconds and not milliseconds.
      let time = ($recording.length | into duration --unit ms | lengths_to_start_offsets | each {|t| $t | format_chapter_duration})
      $"($time) ($recording.title)"
    }
    | str join "\n"
  )
}

# Determine if the chapters are named according to standard defaults.
#
# Default naming schemes:
#
# Libro.fm: Title - Track <x>
# Audible: Chapter <x>
#
export def has_default_chapters []: table<index: int, title: string, duration: duration> -> bool {
    let chapters = $in
    if ($chapters | is-empty) {
        return false
    }
    (
        (
            $chapters | all {|c|
                $c.title =~ '^Chapter [0-9]+$'
            }
        ) or (
            $chapters | all {|c|
                $c.title =~ ' - Track [0-9]+$'
            }
        )
    )
}

# Rename chapters.
#
# Note that the indices most be 1-based and not 0-based.
#
export def rename_chapters [
    --chapter-word: string = "Chapter" # The string to use for the name of each chapter. This is usually "Chapter".
    --offset: int # The difference between the track indices and the chapter numbers, i.e. the chapter number is the track index minus this value
    --prefix: string # A prefix to add before the name of each chapter
    --suffix: string # A suffix to add after the name of each chapter
]: table<index: int, title: string, duration: duration> -> table<index: int, title: string, duration: duration> {
    let chapters = $in
    if ($chapters | length) <= 1 {
        return $chapters
    }
    let chapters = $chapters | sort-by index
    # todo Handle indexing automatically when it isn't 1-based.
    if ($chapters | first | get index) != 1 {
      error make {msg: "rename_chapters requires 1-based indices"}
    }
    let offset = (
        if $offset == null {
            let c = $chapters | first;
            if $c.duration < 1min {
                1
            } else {
                0
            }
        } else {
            $offset
        }
    )
    $chapters | each {|c|
        if $c.index == 1 {
            if $c.duration < 1min {
                $c | update title "Opening Credits"
            } else {
                if $c.index - $offset == 0 {
                    $c | update title "Opening Credits / Prologue"
                } else {
                    $c | update title $"Opening Credits / ($prefix)($chapter_word) ($c.index - $offset)($suffix)"
                }
            }
        } else if $c.index == ($chapters | length) {
            if $c.duration < 3min {
                $c | update title "End Credits"
            } else {
                $c | update title $"($prefix)($chapter_word) ($c.index - $offset)($suffix) / End Credits"
            }
        } else {
            if $c.index - $offset == 0 {
                if $c.duration < 1min {
                    $c | update title "Epigraph"
                } else {
                    $c | update title "Prologue"
                }
            } else {
                $c | update title $"($prefix)($chapter_word) ($c.index - $offset)($suffix)"
            }
        }
    }
}

# Parse the Part, Chapter, and Title portions of a chapter.
export def parse_chapter_title []: string -> record<part: string, part_title: string, chapter: string, chapter_title: string, chapter_part: string> {
    let input = $in
    let split = str index-of "/"
    (
        $input
        # todo Split into multiple rows if there's a '/'.
        | parse --regex '(?<part>Part \w+)?(?<part_title>: \"[\w\s]+\")?(?:,\s)?(?<chapter>[\w\s/]+(?:\s\d+)?)(?<chapter_title>: \"[\w\s]+\")?(?:,\s)?(?<chapter_part>Part \d+)?'
        | each {|c|
            {
                part: $c.part
                part_title: (
                    $c.part_title
                    | str trim --char ':' --left
                    | str trim --left
                    | str trim --char '"'
                    | str trim --char "'"
                )
                chapter: $c.chapter
                chapter_title: (
                    $c.chapter_title
                    | str trim --char ':' --left
                    | str trim --left
                    | str trim --char '"'
                    | str trim --char "'"
                )
                chapter_part: $c.chapter_part
            }
        }
        | first
    )
}

# Combine chapters split into multiple parts into complete chapters
#
# Only works for chapters titled according to the MusicBrainz Audiobook style guidelines.
export def combine_chapter_parts []: table<index: int, title: string, duration: duration> -> table<index: int, title: string, duration: duration> {
  let chapters = $in
  let index_offset = $chapters.index | first
  (
    # Parse each title into the title and part portions
    $chapters
    | each {|chapter|
      $chapter | update title (
        $chapter.title
        | parse --regex '(?P<title>.*?)(?P<part>, Part [0-9]+)?$'
        | first
      )
    }
    | reduce {|it acc|
      if ($acc | is-empty) {
        $acc | append $it
      } else {
        let last = (
          if ($acc | describe | str starts-with record) {
            $acc
          } else {
            $acc | last
          }
        )
        if $last.title.title == $it.title.title {
          let updated = $last | update duration ($last.duration + $it.duration)
          if $acc == $last {
            $updated
          } else {
            $acc | drop | append $updated
          }
        } else {
          $acc | append $it
        }
      }
    }
    | enumerate
    | each {|chapter|
      {
        index: ($chapter.index + $index_offset)
        title: $chapter.item.title.title
        duration: $chapter.item.duration
      }
    }
  )
}

##### End chapterz.nu #####
