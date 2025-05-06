#!/usr/bin/env nu

use import-music.nu *

use std assert

def test_beet_secrets_from_env_none [] {
  let expected = {}
  assert equal (with-env {} {beet_secrets_from_env}) $expected
}

def test_beet_secrets_from_env_all_empty [] {
  let expected = {}
  assert equal (
    with-env {
      BEETS_ACOUSTID_APIKEY: ""
      BEETS_DISCOGS_TOKEN: ""
      BEETS_FANARTTV_KEY: ""
      BEETS_GOOGLE_KEY: ""
      BEETS_LASTFM_KEY: ""
      BEETS_BING_CLIENT_SECRET: ""
    } {
      beet_secrets_from_env
    }
  ) $expected
}

def test_beet_secrets_from_env_one [] {
  let expected = {
    fetchart: {
      fanarttv_key: "Pp9Yd^PgiX*&AR"
    }
  }
  assert equal (
    with-env {
      BEETS_FANARTTV_KEY: "Pp9Yd^PgiX*&AR"
    } {
      beet_secrets_from_env
    }
  ) $expected
}

def test_beet_secrets_from_env_all [] {
  let expected = {
    acoustid: {
      apikey: "W75seRNKI8&#4&"
    }
    discogs: {
      user_token: "Snv3Uxysi$wtC!6#PtEX^LJV"
    }
    fetchart: {
      fanarttv_key: "Pp9Yd^PgiX*&AR"
      google_key: "ssV1Cd$kBMu!H#@*bQF8rPyFhe"
      lastfm_key: "QB@vkRnew6Ajtn9kwzLcdX%Qt@HM!khiTbNfFNAdyf^"
    }
    lyrics: {
      # bing_client_secret: "ytub9ZaYY6Ugk5JZ!$LQp3nDcTPrU0tbfg!VYsXmh7PsiXI9@qb2C#!J!Fsr&U308"
      google_API_key: "ssV1Cd$kBMu!H#@*bQF8rPyFhe"
    }
  }
  assert equal (
    with-env {
      BEETS_ACOUSTID_APIKEY: "W75seRNKI8&#4&"
      BEETS_DISCOGS_TOKEN: "Snv3Uxysi$wtC!6#PtEX^LJV"
      BEETS_FANARTTV_KEY: "Pp9Yd^PgiX*&AR"
      BEETS_GOOGLE_KEY: "ssV1Cd$kBMu!H#@*bQF8rPyFhe"
      BEETS_LASTFM_KEY: "QB@vkRnew6Ajtn9kwzLcdX%Qt@HM!khiTbNfFNAdyf^"
      # BEETS_BING_CLIENT_SECRET: "ytub9ZaYY6Ugk5JZ!$LQp3nDcTPrU0tbfg!VYsXmh7PsiXI9@qb2C#!J!Fsr&U308"
    } {
      beet_secrets_from_env
    }
  ) $expected
}

def main [] [] {
  test_beet_secrets_from_env_none
  test_beet_secrets_from_env_all_empty
  test_beet_secrets_from_env_one
  test_beet_secrets_from_env_all
  echo "All tests passed!"
}
