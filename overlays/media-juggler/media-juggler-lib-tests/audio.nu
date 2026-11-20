# Tests for the audio functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *

const test_data_dir = path self ../test-data

def test_parse_container_and_audio_codec_from_ffprobe_output_aax [] {
  let input = open ([$test_data_dir "ffprobe_output_aax.json"] | path join)
  let expected = {
    audio_codec: "aac"
    container: "mov,mp4,m4a,3gp,3g2,mj2"
    audio_channel_layout: null
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_flac [] {
  let input = open ([$test_data_dir "ffprobe_output_flac.json"] | path join)
  let expected = {
    audio_codec: "flac"
    container: "flac"
    audio_channel_layout: "stereo"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_m4b_aac [] {
  let input = open ([$test_data_dir "ffprobe_output_m4b_aac.json"] | path join)
  let expected = {
    audio_codec: "aac"
    container: "mov,mp4,m4a,3gp,3g2,mj2"
    audio_channel_layout: "mono"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_mp3 [] {
  let input = open ([$test_data_dir "ffprobe_output_mp3.json"] | path join)
  let expected = {
    audio_codec: "mp3"
    container: "mp3"
    audio_channel_layout: "mono"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_oga_flac [] {
  let input = open ([$test_data_dir "ffprobe_output_oga_flac.json"] | path join)
  let expected = {
    audio_codec: "flac"
    container: "ogg"
    audio_channel_layout: "stereo"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_opus [] {
  let input = open ([$test_data_dir "ffprobe_output_opus.json"] | path join)
  let expected = {
    audio_codec: "opus"
    container: "ogg"
    audio_channel_layout: "stereo"
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output_wav [] {
  let input = open ([$test_data_dir "ffprobe_output_wav.json"] | path join)
  let expected = {
    audio_codec: "pcm_s16le"
    container: "wav"
    audio_channel_layout: null
  }
  assert equal ($input | parse_container_and_audio_codec_from_ffprobe_output) $expected
}

def test_parse_container_and_audio_codec_from_ffprobe_output [] {
  test_parse_container_and_audio_codec_from_ffprobe_output_aax
  test_parse_container_and_audio_codec_from_ffprobe_output_flac
  test_parse_container_and_audio_codec_from_ffprobe_output_m4b_aac
  test_parse_container_and_audio_codec_from_ffprobe_output_mp3
  test_parse_container_and_audio_codec_from_ffprobe_output_oga_flac
  test_parse_container_and_audio_codec_from_ffprobe_output_opus
  test_parse_container_and_audio_codec_from_ffprobe_output_wav
}

####

def test_parse_ffprobe_file_format_aax [] {
  let input = open ([$test_data_dir "ffprobe_output_aax.json"] | path join)
  let expected = "m4b"
  assert equal ($input | parse_ffprobe_file_format) $expected
}

def test_parse_ffprobe_file_format_flac [] {
  let input = open ([$test_data_dir "ffprobe_output_flac.json"] | path join)
  let expected = "flac"
  assert equal ($input | parse_ffprobe_file_format) $expected
}

def test_parse_ffprobe_file_format_m4b_aac [] {
  let input = open ([$test_data_dir "ffprobe_output_m4b_aac.json"] | path join)
  let expected = "m4a"
  assert equal ($input | parse_ffprobe_file_format) $expected
}

def test_parse_ffprobe_file_format_mp3 [] {
  let input = open ([$test_data_dir "ffprobe_output_mp3.json"] | path join)
  let expected = "mp3"
  assert equal ($input | parse_ffprobe_file_format) $expected
}

def test_parse_ffprobe_file_format_oga_flac [] {
  let input = open ([$test_data_dir "ffprobe_output_oga_flac.json"] | path join)
  let expected = "ogg"
  assert equal ($input | parse_ffprobe_file_format) $expected
}

def test_parse_ffprobe_file_format_opus [] {
  let input = open ([$test_data_dir "ffprobe_output_opus.json"] | path join)
  let expected = "ogg"
  assert equal ($input | parse_ffprobe_file_format) $expected
}

def test_parse_ffprobe_file_format_wav [] {
  let input = open ([$test_data_dir "ffprobe_output_wav.json"] | path join)
  let expected = "wav"
  assert equal ($input | parse_ffprobe_file_format) $expected
}

def test_parse_ffprobe_file_format [] {
  test_parse_ffprobe_file_format_aax
  test_parse_ffprobe_file_format_flac
  test_parse_ffprobe_file_format_m4b_aac
  test_parse_ffprobe_file_format_mp3
  test_parse_ffprobe_file_format_oga_flac
  test_parse_ffprobe_file_format_opus
  test_parse_ffprobe_file_format_wav
}

####

def test_parse_ffprobe_audio_bit_rate_aax [] {
  let input = open ([$test_data_dir "ffprobe_output_aax.json"] | path join)
  let expected = 63 # 62794 # 64 kbps
  assert equal ($input | parse_ffprobe_audio_bit_rate) $expected
}

def test_parse_ffprobe_audio_bit_rate_flac [] {
  let input = open ([$test_data_dir "ffprobe_output_flac.json"] | path join)
  let expected = null
  assert equal ($input | parse_ffprobe_audio_bit_rate) $expected
}

def test_parse_ffprobe_audio_bit_rate_m4b_aac [] {
  let input = open ([$test_data_dir "ffprobe_output_m4b_aac.json"] | path join)
  let expected = 64 # 64010 # 64 kbps
  assert equal ($input | parse_ffprobe_audio_bit_rate) $expected
}

def test_parse_ffprobe_audio_bit_rate_mp3 [] {
  let input = open ([$test_data_dir "ffprobe_output_mp3.json"] | path join)
  let expected = 72 # 71824 # 64 kbps?
  assert equal ($input | parse_ffprobe_audio_bit_rate) $expected
}

def test_parse_ffprobe_audio_bit_rate_oga_flac [] {
  let input = open ([$test_data_dir "ffprobe_output_oga_flac.json"] | path join)
  let expected = null
  assert equal ($input | parse_ffprobe_audio_bit_rate) $expected
}

def test_parse_ffprobe_audio_bit_rate_opus [] {
  let input = open ([$test_data_dir "ffprobe_output_opus.json"] | path join)
  let expected = null
  assert equal ($input | parse_ffprobe_audio_bit_rate) $expected
}

def test_parse_ffprobe_audio_bit_rate_wav [] {
  let input = open ([$test_data_dir "ffprobe_output_wav.json"] | path join)
  let expected = 1411 # 1411200 # 1,411 kbps
  assert equal ($input | parse_ffprobe_audio_bit_rate) $expected
}

def test_parse_ffprobe_audio_bit_rate [] {
  test_parse_ffprobe_audio_bit_rate_aax
  test_parse_ffprobe_audio_bit_rate_flac
  test_parse_ffprobe_audio_bit_rate_m4b_aac
  test_parse_ffprobe_audio_bit_rate_mp3
  test_parse_ffprobe_audio_bit_rate_oga_flac
  test_parse_ffprobe_audio_bit_rate_opus
  test_parse_ffprobe_audio_bit_rate_wav
}

def test_parse_file_audio_bit_rate_mp3_64kbps [] {
  let input = "Audio file with ID3 version 2.3.0, contains: MPEG ADTS, layer III, v1, 64 kbps, 44.1 kHz, Monaural"
  let expected = 64
  assert equal ($input | parse_file_audio_bit_rate) $expected
}

def test_parse_file_audio_bit_rate_mp3_128kbps [] {
  let input = "Audio file with ID3 version 2.4.0, contains: MPEG ADTS, layer III, v1, 128 kbps, 44.1 kHz, Monaural"
  let expected = 128
  assert equal ($input | parse_file_audio_bit_rate) $expected
}

def test_parse_file_audio_bit_rate_flac [] {
  let input = "FLAC audio bitstream data, 16 bit, stereo, 44.1 kHz, 9419172 samples"
  let expected = null
  assert equal ($input | parse_file_audio_bit_rate) $expected
}

def test_parse_file_audio_bit_rate_oga [] {
  let input = "Ogg data, Opus audio, version 0.1, stereo, 44100 Hz (Input Sample Rate)"
  let expected = null
  assert equal ($input | parse_file_audio_bit_rate) $expected
}

def test_parse_file_audio_bit_rate_wav [] {
  let input = "RIFF (little-endian) data, WAVE audio, Microsoft PCM, 16 bit, stereo 44100 Hz"
  let expected = null
  assert equal ($input | parse_file_audio_bit_rate) $expected
}

def test_parse_file_audio_bit_rate_m4b [] {
  let input = "ISO Media, Apple iTunes ALAC/AAC-LC (.M4A) Audio"
  let expected = null
  assert equal ($input | parse_file_audio_bit_rate) $expected
}

def test_parse_file_audio_bit_rate [] {
  test_parse_file_audio_bit_rate_mp3_64kbps
  test_parse_file_audio_bit_rate_mp3_128kbps
  test_parse_file_audio_bit_rate_flac
  test_parse_file_audio_bit_rate_oga
  test_parse_file_audio_bit_rate_wav
  test_parse_file_audio_bit_rate_m4b
}

def test_has_bad_video_stream_bad [] {
  let input = open ([$test_data_dir "ffprobe_bad_video_stream.json"] | path join)
  assert ($input | has_bad_video_stream)
}

def test_has_bad_video_stream_good [] {
  let input = open ([$test_data_dir "ffprobe_output_m4b_aac.json"] | path join)
  assert not ($input | has_bad_video_stream)
}

def test_has_bad_video_stream [] {
  test_has_bad_video_stream_bad
  test_has_bad_video_stream_good
}

# Run the tests in this module
export def run_tests [] {
  test_parse_file_audio_bit_rate
  test_parse_container_and_audio_codec_from_ffprobe_output
  test_parse_ffprobe_file_format
  test_parse_ffprobe_audio_bit_rate
  test_has_bad_video_stream
}
