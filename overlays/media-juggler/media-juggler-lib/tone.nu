# Functions for reading and writing audiobook metadata with tone

use std log

use chapters.nu *
use constants.nu *
use utils.nu *

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
        } | flatten | where {|item| $item != null}
      )
      if ($duplicate_series | is-not-empty) {
        log error $"Multiple series with the same name present: ($duplicate_series). Only the first series will be used and duplicate series will be ignored."
      }
      $series | uniq-by name
    }
  )
  # log debug $"Parsed series from tone metadata: ($series | to json)"
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
          $metadata.additionalFields."bookBrainz Work Id" | parse_parallel_multi_value_tag | wrap bookbrainz_work_id
        }
      )
      let open_library_work_id = (
        if "openLibrary Work Id" in $metadata.additionalFields {
          $metadata.additionalFields."openLibrary Work Id" | parse_parallel_multi_value_tag | wrap open_library_work_id
        }
      )
      let wikidata_work_id = (
        if "wikidata Work Id" in $metadata.additionalFields {
          $metadata.additionalFields."wikidata Work Id" | parse_parallel_multi_value_tag | wrap wikidata_work_id
        }
      )
      let names = (
        if "work" in $metadata.additionalFields {
          $metadata.additionalFields.work | parse_parallel_multi_value_tag | wrap title
        }
      )
      (
        $ids
        | merge_or_input $names
        | merge_or_input $bookbrainz_work_id
        | merge_or_input $open_library_work_id
        | merge_or_input $wikidata_work_id
      )
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
            $input | get --optional additionalFields
          } else {
            $input
          }
        )
        | get --optional $role
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
    } | flatten | where {|contributor|
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
            $input | get --optional additionalFields
          } else {
            $input
          }
        )
        | get --optional $role
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
    if ($metadata | get --optional comment | is-not-empty) and ($all_contributors | where role == "distributor" | is-empty) {
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
  let book_contributors = (
    if ($book_contributors | is-not-empty) {
      $book_contributors | sort-by entity role name id
    } else {
      $book_contributors
    }
  )
  let track_contributors = $all_contributors | where role not-in $release_only_contributor_roles
  let track_contributors = (
    if ($track_contributors | is-not-empty) {
      $track_contributors | sort-by entity role name id
    } else {
      $track_contributors
    }
  )

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
        | upsert_if_present hardcover_book_slug $metadata.additionalFields "hardcover Book Slug"
        | upsert_if_present hardcover_edition_id $metadata.additionalFields "hardcover Edition Id"
        | upsert_if_present open_library_edition_id $metadata.additionalFields "openLibrary Edition Id"
        | upsert_if_present wikidata_edition_id $metadata.additionalFields "wikidata Edition Id"
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
        # It's possible to get chapters from the metadata which aren't in the required format.
        # The case where this happened returned chapters without the title field.
        # This just drops any chapters where the title field is missing.
        let chapters = (
          $metadata.chapters
          | where {|chapter| $chapter | get --optional title | is-not-empty }
        )
        $input | upsert chapters ($chapters | parse_chapters_from_tone)
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
    if ($book | get --optional total_tracks | is-empty) {
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
export def convert_series_for_group_tag []: list -> string { #table<name: string, index: string> -> string {
  let series = $in
  $series | each {|s|
    if "index" in $s and ($s.index | is-not-empty) {
      $s.name + " #" + $s.index
    } else {
      $s.name
    }
  } | str join ";"
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
        } | flatten | where {|item| $item != null}
      )
      if ($duplicate_series | is-not-empty) {
        log error $"Multiple series with the same name present: ($duplicate_series). Only the first series will be used and duplicate series will be ignored."
      }
      $series | uniq-by name | convert_series_for_group_tag
    }
  )
  # log debug $"group: ($group | to json)"
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
    $track_tags | append $book_tags | uniq | where {|tag| $tag not-in ["chapters"]} | join_multi_value
  )

  let additionalFields = (
    {}
    # book metadata
    | upsert_if_value tags $tags
    | upsert_if_value "MusicBrainz Album Type" ($metadata.book | get --optional musicbrainz_release_types | join_multi_value)
    | upsert_if_value "MusicBrainz Album Artist Id" ($primary_authors | get --optional id | join_multi_value)
    | upsert_if_present "MusicBrainz Release Group Id" $metadata.book musicbrainz_release_group_id
    | upsert_if_present "MusicBrainz Album Id" $metadata.book musicbrainz_release_id
    | upsert_if_present "Hardcover Book Slug" $metadata.book hardcover_book_slug
    | upsert_if_present "Hardcover Edition Id" $metadata.book hardcover_edition_id
    | upsert_if_present "OpenLibrary Edition Id" $metadata.book open_library_edition_id
    | upsert_if_present "Wikidata Edition Id" $metadata.book wikidata_edition_id
    | upsert_if_present "MusicBrainz Album Release Country" $metadata.book musicbrainz_release_country
    | upsert_if_present "MusicBrainz Album Status" $metadata.book musicbrainz_release_status
    | upsert_if_present script $metadata.book
    # For audiobookshelf to be happy, publisher has to go in additionalFields for some reason.
    # todo I'm not sure audiobookshelf supports multiple values for the publisher
    | upsert_if_value publisher ($metadata.book | get --optional publishers | get --optional name | join_multi_value)
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
        $metadata.track.contributors | where role == "writer" | get --optional id | join_multi_value
      }
    )
    | upsert_if_value "MusicBrainz Work Id" ($metadata.track | get --optional musicbrainz_works | get --optional id | join_multi_value)
    | upsert_if_value "BookBrainz Work Id" ($metadata.track | get --optional musicbrainz_works | get --optional bookbrainz_work_id | join_parallel_multi_value)
    | upsert_if_value "OpenLibrary Work Id" ($metadata.track | get --optional musicbrainz_works | get --optional open_library_work_id | join_parallel_multi_value)
    | upsert_if_value "Wikidata Work Id" ($metadata.track | get --optional musicbrainz_works | get --optional wikidata_work_id | join_parallel_multi_value)
    | upsert_if_value "MusicBrainz Label Id" ($metadata.track | get --optional publishers | get --optional id | join_multi_value)
    | upsert_if_value "work" ($metadata.track | get --optional musicbrainz_works | get --optional title | join_parallel_multi_value)
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
        }
        let r = (
          if ($r | is-empty) {
            $r
          } else {
            $r | reduce {|it, acc|
              $acc | merge_or_input $it
            }
          }
        );
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
      | upsert_if_value albumArtist ($primary_authors | get --optional name | join_multi_value)
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
      | upsert_if_value publisher ($metadata.book | get --optional publishers | get --optional name | join_multi_value)
      | upsert_if_value label ($metadata.book | get --optional publishers | get --optional name | join_multi_value)
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
  try {
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
  } catch {|err|
    log error $"Parse failed!\n($err)\n($err.msg)\n"
    return null
  }
  } | sort-by metadata.meta.trackNumber
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
  let tracks_in_tone_format = $in | tracks_into_tone_format
  if ($tracks_in_tone_format | is-empty) {
    return null
  }
  $tracks_in_tone_format | par-each {|track|
    # log
    $track.metadata | tone_tag $track.file ...$tone_args
  }
}
