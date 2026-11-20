# Functions for probing and converting audio files

use std log

# Determine of the embedded cover in a video stream is set incorrectly
export def has_bad_video_stream []: record<streams: table, format: record> -> bool {
  let ffprobe_output = $in
  if ($ffprobe_output | is-empty) {
    return false
  }
  let streams = $ffprobe_output | get --optional streams
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
  let streams = $ffprobe_output | get --optional streams
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
  let format = $ffprobe_output | get --optional format;
  if ($format | is-empty) {
    log error "The ffprobe output is missing the format field"
    return null
  }
  {
    container: $format.format_name
    audio_codec: $audio_stream.codec_name
    audio_channel_layout: ($audio_stream | get --optional channel_layout)
  }
}

# Parse the output from the ffprobe command
export def parse_ffprobe_output []: record<streams: table, format: record> -> record<audio_streams: table, video_streams: table, format: record<format_name: string, format_long_name: string>> {
  let ffprobe_output = $in
  let streams = $ffprobe_output | get --optional streams
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
    let format = $ffprobe_output | get --optional format;
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
    --no-conversion
    --no-interaction
    --output-file $output_file
    ...$args
    "--"
    ...$files
  )
  $output_file
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

# Parse the bit rate of an audio file from the output of the ffprobe command.
#
# Returns an integer representing the bit rate in kbit/s or null if there is a parsing error.
export def parse_ffprobe_audio_bit_rate []: [record<streams: table, format: record> -> int] {
  let ffprobe_output = $in
  if ($ffprobe_output | is-empty) {
    log error "parse_ffprobe_audio_bit_rate: provided ffprobe output is empty"
    return null
  }
  let streams = $ffprobe_output | get --optional streams
  if ($streams | is-empty) {
    log error $"parse_ffprobe_audio_bit_rate: no streams in ffprobe output: ($ffprobe_output)"
    return null
  }
  let audio_streams = $streams | where codec_type == "audio"
  if ($audio_streams | is-empty) {
    log error $"parse_ffprobe_audio_bit_rate: no audio streams in ffprobe output: ($streams)"
    return null
  }
  if ($audio_streams | length) > 1 {
    log warning $"parse_ffprobe_audio_bit_rate: multiple audio streams in ffprobe output: ($audio_streams)\nOnly the first audio stream will be used."
  }
  let audio_stream = $audio_streams | first
  let bit_rate = (
    if "bit_rate" in $audio_stream {
      $audio_stream | get bit_rate
    } else {
      log warning $"parse_ffprobe_audio_bit_rate: no bit rate for audio stream: ($audio_stream)."
      return null
    }
  )
  # Convert to kilobits-per-second (kbit/s) from bits-per-second (bps).
  ((($bit_rate | into int) / 1000) | math round --precision 0) | into int
}

# Get the bit rate of an audio file in kbit/s from the output of the file command.
export def parse_file_audio_bit_rate []: [string -> int] {
  let file_output = $in
  if ($file_output | is-empty) {
    return null
  }
  let parsed = $file_output | parse --regex '(?P<bit_rate>[0-9]+) kbps'
  if ($parsed | is-empty) {
    log error $"parse_file_audio_bit_rate: Failed to parse bit rate from the output of: ($file_output)"
    return null
  }
  if ($parsed | length) > 1 {
    log error $"parse_file_audio_bit_rate: Parsed more than one audio bit rate from the file output: ($file_output)"
    return null
  }
  let bit_rate = $parsed.bit_rate | first | into int
  if ($bit_rate) <= 0 {
    log error $"parse_file_audio_bit_rate: Parsed invalid bit rate (ansi purple)($bit_rate)(ansi reset) from the file output: ($file_output)"
    return null
  }
  $bit_rate
}

# Parse the audio format of a media file from the output of the ffprobe command.
#
# Returns the format of the file from ffprobe or null if there is a parse error.
export def parse_ffprobe_file_format []: [record -> int] {
  let ffprobe_output = $in
  if ($ffprobe_output | is-empty) {
    log error "parse_ffprobe_file_format: provided ffprobe output is empty"
    return null
  }
  let format = $ffprobe_output | get --optional format
  if ($format | is-empty) {
    log error $"parse_ffprobe_file_format: no format in ffprobe output: ($ffprobe_output)"
    return null
  }
  let file_format = $format | get --optional format_name
  if ($file_format | is-empty) {
    log error $"parse_ffprobe_file_format: no file format in ffprobe output: ($format)"
    return null
  }
  let file_format = (
    if $file_format == "mov,mp4,m4a,3gp,3g2,mj2" {
      let compatible_brands = $format.tags.compatible_brands | str downcase | split row " "
      if "m4a" in $compatible_brands {
        "m4a"
      } else if "m4b" in $compatible_brands {
        "m4b"
      } else {
        let file_extension = $format.filename | path parse | get extension
        if $file_extension in ["aac", "m4a"] {
          "m4a"
        } else if $file_extension in ["m4b"] {
          "m4b"
        } else {
          $file_extension
        }
      }
    } else {
      $file_format
    }
  )
  $file_format
}
