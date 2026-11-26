# Functions for comic books, including ComicInfo.xml, MetronInfo.xml, and Comic Vine

use std log

use archives.nu *
use constants.nu *
use identifiers.nu *
use images.nu *
use metadata.nu *
use utils.nu *

export def upsert_comic_info [
  field: record<tag: string, value>
]: record -> record {
  let comic_info = $in
  if ($field.tag | is-empty) or ($field.value | is-empty) {
    return $comic_info
  }
  # log debug $"upsert_comic_info: field: ($field)"
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
            [null null ($field.value | into string)]
          ]
        }
      )
    )
  )
}

export def drop_field_comic_info [
  field: string
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
        | where tag != $field
      )
    )
  )
}

export def upsert_comic_info_content [
  field: record<tag: string, content: any>
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
          content: $field.content
        }
      )
    )
  )
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

# Extract the MetronInfo.xml file from an archive
export def extract_metron_info_xml [
  working_directory: directory # The scratch-space directory to use
]: path -> record {
  let archive = $in
  if not ($archive | has_metron_info) {
    return null
  }
  let metron_info_file = $archive | extract_file_from_archive "MetronInfo.xml" $working_directory
  if $metron_info_file == null {
    return null
  }
  let metron_info = $metron_info_file | open
  rm $metron_info_file
  $metron_info
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

# Extract the MetronInfo.xml file from an archive
export def extract_metron_info [
  working_directory: directory # The scratch-space directory to use
]: path -> path {
  let archive = $in
  ^unzip $archive "MetronInfo.xml" -d $working_directory
  [$working_directory "MetronInfo.xml"] | path join
}

export def has_metron_info []: [
  path -> bool
] {
  let archive = $in
  (
    $archive
    | list_files_in_archive
    | path basename
    | any {|name| $name == "MetronInfo.xml"}
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

# Inject MetronInfo data into a zip archive
#
# Takes a record containing the archive and MetronInfo.xml file
export def inject_metron_info []: [
  record<archive: path, metron_info: record> -> path
] {
  let input = $in
  if ($input.archive | has_metron_info) {
    ^zip --delete $input.archive "MetronInfo.xml"
  }
  let temporary_directory = mktemp --directory
  let target = [$temporary_directory "MetronInfo.xml"] | path join
  $input.metron_info | to xml | save $target
  ^zip --junk-paths $input.archive $target
  rm $target
  rm $temporary_directory
  $input.archive
}

# Convert a ZIP archive containing images to a CBZ or standardize the file names in an existing CBZ.
#
# The archive must have image files named according to the order in which they are in.
# Cover images which have the word cover in the name are detected and handled properly.
# For flexibility, natural sorting is used to determine the order of the image files.
# The image file names are standardizes for the output CBZ.
#
# Removes any image thumbnails that are named with a file path stem ending with '-thumb'.
# These are present in Nook EPUBs.
#
# For input archives which are already CBZs, the CBZ will be overwritten.
# todo Change the behavior to avoid overwriting anything.
export def zip_archive_to_cbz [
  --working-directory: directory # Directory to work in
]: path -> path {
  let archive = $in
  let output_cbz = (
    {
      parent: $working_directory,
      stem: (
        $archive
        | path parse
        | get stem
      ),
      extension: "cbz"
    }
    | path join
  )
  let cbz = mktemp --suffix ".cbz" --tmpdir-path $working_directory
  # Delete the file in order to be able to create a new zip archive with the name.
  rm $cbz

  log debug $"Extracting contents of the ZIP archive (ansi yellow)($archive)(ansi reset) to (ansi yellow)($working_directory)/exploded(ansi reset)"
  ^unzip -q $archive -d ($working_directory | path join "exploded")

  # todo Should sort really take into account directory names like it does here?
  let image_files = (glob --no-dir --no-symlink $"($working_directory)/exploded/**/*.{($image_extensions | str join ',')}") | sort --natural | path parse | enumerate

  # Filter out thumbnails that have a stem that ends in '-thumb'
  let image_files = $image_files | where {|image_file| not ($image_file.item | get stem | str ends-with '-thumb') }
  if ($image_files | is-empty) {
    log error $"No images found under the directory (ansi yellow)($working_directory)/exploded/(ansi reset)"
    return null
  }

  let covers = $image_files | where item.stem =~ 'cover' | sort-by index
  let pages = $image_files | where item.stem !~ 'cover' | sort-by index
  let pages = $covers | append $pages

  let image_subdirectory = (mktemp --directory)
  log debug $"Organizing images for the CBZ file in the directory (ansi yellow)($image_subdirectory)(ansi reset)"

  # Detect and remove duplicate covers.
  # Prefer whichever file is larger.
  # Be careful as covers for manga are often follow the cover with exact same cover image but without text, making the pages very similar yet only one is an actual cover.
  let pages_with_duplicate_covers = $pages | get item | each {|page| $page | path join}
  # log debug $"pages_with_duplicate_covers: ($pages_with_duplicate_covers)"
  let pages_without_duplicate_covers = $pages_with_duplicate_covers | remove_duplicate_covers
  # log debug $"pages_without_duplicate_covers: ($pages_without_duplicate_covers)"
  if ($pages_with_duplicate_covers | length) != ($pages_without_duplicate_covers | length) {
    let duplicate_covers = $pages_with_duplicate_covers | where $it not-in $pages_without_duplicate_covers
    log info $"Duplicate covers detected: ($duplicate_covers). Deleting them."
    rm ...$duplicate_covers
  }

  let pages = $pages_without_duplicate_covers | each {|page| $page | path parse} | enumerate
  # log debug $"pages: ($pages)"

  # Rename everything for consistency.
  let number_of_digits = (($pages | length) - 1) | into string | str length
  let pages = (
    $pages | each {|p|
      let old_page = $p.item | path join
      let new_page = {
        parent: $image_subdirectory
        stem: (
          let page_name = (
            if $p.index == 0 {
              "cover"
            } else {
              "page"
            }
          );
          ($p.index | fill --alignment r --character '0' --width $number_of_digits) + "_" + $page_name
        )
        extension: $p.item.extension
      } | path join
      mv --no-clobber $old_page $new_page
      $new_page
    }
  )
  # log debug $"Pages (ansi yellow)($pages)(ansi reset)"

  if ($archive | has_comic_info) {
    $archive | extract_comic_info $image_subdirectory
  }

  if ($archive | has_metron_info) {
    $archive | extract_metron_info $image_subdirectory
  }

  log debug $"Compressing the contents of the directory (ansi yellow)($image_subdirectory)(ansi reset) into the CBZ file (ansi yellow)($cbz)(ansi reset)"
  log debug $"Running command: ^zip --junk-paths --quiet --recurse-paths ($cbz) ($image_subdirectory)"
  ^zip --junk-paths --quiet --recurse-paths $cbz $image_subdirectory
  # ^zip -jqr $cbz $image_subdirectory
  rm --force --recursive ($working_directory | path join "exploded")
  rm --force --recursive $image_subdirectory
  mv $cbz $output_cbz
  $output_cbz
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

  log debug $"Extracting contents of the PDF (ansi yellow)($pdf)(ansi reset) to (ansi yellow)($working_directory)/exploded(ansi reset)"
  ^unzip -q $pdf -d ($working_directory | path join "pdf")

  let image_files = (glob $"($working_directory)/exploded/**/*.{avif,bmp,jpeg,jpg,jxl,png,tiff,webp}")
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
  rm --force --recursive $"($working_directory)/exploded"
  $cbz
}

# Parse data from Comic Vine
#
# todo Test.
export def parse_comic_vine_issue_and_volume []: [
  record<issue: record, volume: record> -> record
] {
  let responses = $in
  let issue = $responses.issue
  let volume = $responses.volume
  let publication_date = (
    if ($issue | get --optional store_date | is-empty) {
    } else {
      $issue.store_date | into datetime
    }
  );
  let year = (
    if ($publication_date | is-empty) {
    } else {
      $publication_date | format date "%Y"
    }
  );
  let month = (
    if ($publication_date | is-empty) {
    } else {
      $publication_date | format date "%m"
    }
  );
  let day = (
    if ($publication_date | is-empty) {
    } else {
      $publication_date | format date "%d"
    }
  );
  # Rewrite credits to match ComicTagger's format.
  #  [[person, role, primary, language]; ["Some Person", Editor, false, ""]]
  let credits = (
    $issue.person_credits | reduce --fold [] {|person credits_acc|
      $credits_acc | append (
        $person.role
        | split row ","
        | str trim
        | str capitalize
        | each {|role|
          {
            person: $person.name
            id: $person.id
            role: $role
            primary: false
            language: ""
          }
        }
      )
    }
  )

  let ids = (
    [
      [type id];
      [comic_vine_issue_id (
        # if ($issue.issue_id | str starts-with "4000-") {
        #   $issue.issue_id
        # } else {
          "4000-" + ($issue.id | into string)
        # }
      )]
      [comic_vine_volume_id (
        # if ($issue.volume.id | into string | str starts-with "4050-") {
        #   $issue.volume.id
        # } else {
          "4050-" + ($issue.volume.id | into string)
        # }
      )]
    ]
  )

  {
    issue_id: $issue.id
    issue: $issue.issue_number
    series: ($issue.volume.name | use_unicode_in_title)
    title: (
      if ($issue | get --optional name | is-not-empty) {
        $issue.name | use_unicode_in_title
      }
    )
    description: $issue.description
    volume: $volume.start_year
    issue_count: $volume.count_of_issues
    ids: []
    characters: ($issue.character_credits | select --optional name id)
    genres: []
    tags: []
    publication_date: $publication_date
    year: $year
    month: $month
    day: $day
    # $volume_data.description
    publishers: [$volume.publisher.name]
    # $data.store_date
    # $data.cover_date
    credits: $credits
    series_id: $issue.volume.id
    _cover_image: [0, "", $issue.image.original_url]
  }
}

# Read a ComicInfo.xml file into the internal data structure
#
# https://anansi-project.github.io/docs/comicinfo/documentation
# https://wiki.kavitareader.com/guides/metadata/comics/
export def from_comic_info_xml []: [record -> record] {
  let comic_info_xml = $in
  if ($comic_info_xml | is-empty) {
    error make {
      msg: "empty ComicInfo XML data"
      labels: [
          {text: "in" span: (metadata $in).span}
      ]
      help: $"pipe in the ComicInfo XML data"
    }
  }
  if ($comic_info_xml | get --optional tag) != "ComicInfo" {
    error make {
      msg: "top-level tag of ComicInfo XML is not ComicInfo"
      labels: [
          {text: "in" span: (metadata $in).span}
      ]
      help: $"use valid ComicInfo XML data where the top-level tag is ComicInfo"
    }
  }
  let comic_info_xml = ($comic_info_xml | get --optional content)
  if ($comic_info_xml | is-empty) {
    error make {
      msg: "missing content for ComicInfo XML data"
      labels: [
          {text: "in" span: (metadata $in).span}
      ]
      help: $"use valid ComicInfo XML data"
    }
  }

  # Parse the ComicInfo.xml data into a more usable JSON format.
  let json = (
    $comic_info_fields
    | reduce --fold {} {|comic_info_field, acc|
      let tags = ($comic_info_xml | where tag == $comic_info_field.tag)
      if ($tags | is-empty) {
        return $acc
      }
      if ($tags | length) > 1 {
        error make {
          msg: "duplicate tag in ComicInfo XML data"
          labels: [
              {text: "comic_info_xml" span: (metadata $comic_info_xml).span}
          ]
          help: $"duplicate tag in ComicInfo.xml: (ansi red)($comic_info_field.tag)(ansi reset)"
        }
      }
      let value = $tags | first | get content | first | get content
      if ($value | is-empty) {
        return $acc
      }
      if ($comic_info_field.delimiter | is-empty) {
        return ($acc | insert $comic_info_field.tag $value)
      }
      $acc | insert $comic_info_field.tag ($value | split row $comic_info_field.delimiter | str trim)
    }
  )
  # log debug $"json: ($json | to nuon)"

  # Include a mapping from the ComicInfo roles Penciller and Inker to the Artist Comic Vine role.
  # The Colorist role is kind of optional for that mapping.
  let comic_vine_roles_map = (
    $comic_vine_roles_map
    | append [[comic_vine_roles comic_info_roles]; [[Cover Artist] [Penciller Inker Colorist CoverArtist]]]
    | append [[comic_vine_roles comic_info_roles]; [[Cover Artist] [Penciller Inker CoverArtist]]]
    | append [[comic_vine_roles comic_info_roles]; [[Artist] [Penciller Inker]]]
  )
  let comic_info_contributors = $comic_vine_roles_map.comic_info_roles | flatten | uniq | reduce --fold [] {|comic_info_role acc|
    let contributors_for_role = $json | get --optional $comic_info_role
    if ($contributors_for_role | is-empty) {
      return $acc
    }
    $acc | append (
      $contributors_for_role | each {|contributor|
        {
          person: $contributor
          role: $comic_info_role
        }
      }
    )
  }
  # | group-by --to-table person
  # log debug $"comic_info_contributors: ($comic_info_contributors)"

  let contributors = (
    if ($comic_info_contributors | is-empty) {
    } else {
      $comic_info_contributors.person | uniq | reduce --fold [] {|person acc|
        # I need to remove the matched roles so that they aren't matched again.
        # log debug $"person: ($person)"
        let roles = (
          $comic_vine_roles_map
          # Sort by the number of ComicInfo roles first so that we find the best Comic Vine role based on the highest number of matching ComicInfo roles.
          | sort-by --custom {|a b| ($a.comic_info_roles | length) >= ($b.comic_info_roles | length)}
          | reduce --fold {} {|comic_vine_role_mapping comic_vine_roles_acc|
            # If all roles have been matched, we're done.
            if ($comic_vine_roles_acc | is-not-empty) and ($comic_vine_roles_acc.matched_comic_info_roles | length) >= ($comic_info_contributors | where person == $person | get role | uniq | length) {
              return $comic_vine_roles_acc
            }
            let person_roles = $comic_info_contributors | where person == $person | get role
            let unmatched_comic_info_roles = (
              if ($comic_vine_roles_acc | is-empty) {
                $person_roles
              } else {
                $person_roles | where {|role| $role not-in $comic_vine_roles_acc.matched_comic_info_roles}
              }
            )
            # All required ComicInfo roles are in the person's roles.
            if ($comic_vine_role_mapping.comic_info_roles | all {|comic_info_role| $comic_info_role in $unmatched_comic_info_roles }) {
              {
                matched_comic_info_roles: (
                  if ($comic_vine_roles_acc | get --optional comic_info_roles | is-empty) {
                    $comic_vine_role_mapping.comic_info_roles
                  } else {
                    $comic_vine_roles_acc.comic_info_roles | append $comic_vine_role_mapping.comic_info_roles
                  }
                )
                comic_vine_roles: (
                  if ($comic_vine_roles_acc | get --optional comic_vine_roles | is-empty) {
                    $comic_vine_role_mapping.comic_vine_roles
                  } else {
                    $comic_vine_roles_acc.comic_vine_roles | append $comic_vine_role_mapping.comic_vine_roles
                  }
                )
              }
            } else {
              $comic_vine_roles_acc
            }
          } | get comic_vine_roles
        )
        # log debug $"roles: ($roles)"
        $roles | reduce --fold $acc {|role inner_acc|
          # $inner_acc | append {
          #   person: $person
          #   role: $role
          #   primary: false
          #   language: ""
          # }
            $inner_acc | append [
              [person role primary language];
              [$person $role false ""]
            ]
        }
          # $roles | each {|role|
            # [
            #   [person role primary language];
            #   [$person $role false null]
            # ]
            # {
            #   person: $person
            #   role: $role
            #   primary: false
            #   language: ""
            # }
          # }
        # )
      }
    }
  )
  # log debug $"contributors: ($contributors)"
  let contributors = (
    if ($contributors | is-not-empty) {
      $contributors | sort-by --custom {|a b|
        if $a.person == $b.person {
          $a.role < $b.role
        } else {
          $a.person < $b.person
        }
      }
    }
  )

  # let contributors = (
  #   $comic_vine_roles_map.comic_info_roles
  #   # Sort by the number of roles first.
  #   | sort-by --custom {|a b| ($a | length) >= ($b | length)}
  #   | reduce --fold [] {|mapping acc|
  #     # Where each contributor
  #     let contributors = $json | where {|it|  }
  #     if ($contributors | is-empty) {
  #       return $acc
  #     }
  #     $acc | append (
  #       $contributors | each {|contributor|
  #         {
  #           person: $contributor
  #           role: $tag.role
  #         }
  #       }
  #     )
  #   }
  # )

  let imprints = (
    if ($json | get --optional Imprint | is-empty) {
    } else {
      $json.Imprint | split row "," | reduce --fold [] {|imprint acc|
        if ($imprint | str starts-with " ") {
          if ($acc | is-empty) {
            $acc | append ($imprint | str trim)
          } else {
            if ($imprint | str trim | str downcase) in ["llc" "inc" "inc." "ltd", "co", "company", "corporation", "corp", "limited"] {
              # This is probably a suffix for the previous imprint, so it should be included with the previous imprint rather than as its own imprint.
              let last_index  = ($acc | length) - 1
              $acc | update $last_index (($acc | last) + ", " + ($imprint | str trim))
            } else {
              $acc | append ($imprint | str trim)
            }
          }
        } else {
          $acc | append ($imprint | str trim)
        }
      }
    }
  )
  let publishers = (
    if ($json | get --optional Publisher | is-empty) {
    } else {
      $json.Publisher | split row "," | reduce --fold [] {|publisher acc|
        if ($publisher | str starts-with " ") {
          if ($acc | is-empty) {
            $acc | append ($publisher | str trim)
          } else {
            if ($publisher | str trim | str downcase) in ["llc" "inc" "inc." "ltd", "co", "company", "corporation", "corp", "limited"] {
              # This is probably a suffix for the previous imprint, so it should be included with the previous imprint rather than as its own imprint.
              let last_index  = ($acc | length) - 1
              $acc | update $last_index (($acc | last) + ", " + ($publisher | str trim))
            } else {
              $acc | append ($publisher | str trim)
            }
          }
        } else {
          $acc | append ($publisher | str trim)
        }
      }
    }
  )

  # Check for erroneous volume titles in this field.
  let chapter_title = (
    if ($json | get --optional "Title" | is-empty) {

    } else {
      if $json.Title =~ ' (?:(?:Vol\.)|(?:Volume)|(?:Book)) .+$' {
        # This is almost certainly a volume title and will be omitted.
      } else {
        $json.Title
      }
    }
  )

  let issue = (
    if ($json | get --optional Manga | is-empty) or (($json | get --optional Manga | is-not-empty) and $json.Manga == "No") {
        $json | get --optional Number
    } else {
      # This is manga, so the Number field should be the chapter index.
      # The issue number should come from the Volume field in this case.
      let volume = $json | get --optional Volume
      if ($volume | is-empty) {
        # If the Volume is missing or if the title looks like it's for a volume, use the Number field as the issue.
        # if ($json | get --optional "Title" | is-empty) {
        #   $json | get --optional Number
        # } else {
        #   if $json.Title =~ ' (?:(?:Vol\.)|(?:Volume)|(?:Book)) .+$' {
        #     $json | get --optional Number
        #   } else {
        #     # Nothing
        #   }
        # }
      } else {
        $volume
      }
    }
  )

  let volume = (
    if ($json | get --optional Manga | is-empty) or (($json | get --optional Manga | is-not-empty) and $json.Manga == "No") {
      $json | get --optional Volume
    } else {
      # This is manga, so the Volume is used as the volume number in the series.
      # Ignore this field in that case.
    }
  )

  let chapter_index = (
    if ($json | get --optional Manga | is-empty) or (($json | get --optional Manga | is-not-empty) and $json.Manga == "No") {
      # Chapter index is only for manga.
    } else {
      $json | get --optional Number
    }
  )

  # Issue count can be the number of chapters or the number of volumes for manga.
  let issue_count = (
    if ($json | get --optional Manga | is-empty) or (($json | get --optional Manga | is-not-empty) and $json.Manga == "No") {
      $json | get --optional Count
    } else {
      if ($chapter_index | is-empty) {
        # Assume the Count field holds the number of chapters if the chapter_index exists.
      } else {
        $json | get --optional Count
      }
    }
  )

  let chapter_count = (
    if ($json | get --optional Manga | is-empty) or (($json | get --optional Manga | is-not-empty) and $json.Manga == "No") {
      # Only used for manga
    } else {
      if ($chapter_index | is-empty) {
        # Assume the Count field holds the number of volumes if there is no chapter index.
        $json | get --optional Count
      } else {
      }
    }
  )

  let ids_and_urls = (
    if ($json | get --optional Web | is-empty) {
    } else {
      $json.Web | reduce --fold [] {|url acc| |
        $acc | append (
          let id = (
            # We always need to try the hardcover_edition_id before the hardcover_book_slug in order to get both.
            $book_identifiers | reject hardcover_edition_id | columns | prepend hardcover_edition_id | reduce --fold {} {|identifier_type identifier_acc|
              # Book identifier has been determined.
              if ($identifier_acc | is-not-empty) {
                return $identifier_acc
              }
              # log debug $"id ($url)"
              # log debug $"id ($identifier_type)"
              let id = $url | identifier_from_url $identifier_type
              # log debug $"id ($id)"
              if ($id | is-not-empty) {
                if ("hardcover_book_slug" in ($id | columns) and "hardcover_edition_id" in ($id | columns)) {
                  [
                    [url type id];
                    [$url hardcover_edition_id $id.hardcover_edition_id]
                    [$url hardcover_book_slug $id.hardcover_book_slug]
                  ]
                } else {
                  {
                    url: $url
                    type: $identifier_type
                    id: ($id | get $identifier_type)
                  }
                }
              }
            }
          );
          if ($id | is-empty) {
            {
              url: $url
              type: null
              id: null
            }
          } else {
            $id
          }
        )
      }
    }
  )
  let ids = (
    if ($ids_and_urls | is-not-empty) {
      $ids_and_urls | where {|it| ($it.id | is-not-empty)} | reject --optional url | sort-by type
    }
  )
  let links = (
    if ($ids_and_urls | is-not-empty) {
      $ids_and_urls | where {|it| ($it.id | is-empty)} | get url | sort
    }
  )

  # Series fields in priority order: SeriesSort, LocalizedSeries, Series
  let series_fields = [SeriesSort LocalizedSeries Series]
  let series = (
    $series_fields | reduce --fold [] {|series_field, acc|
      if ($json | get --optional $series_field | is-empty) {
        return $acc
      }
      $acc | append (
        {
          name: ($json | get $series_field)
        }
      )
    }
  )

  let publication_date = (
    if ([Year Month Day] | all {|it| $it in ($json | columns)}) {
      []
      | append ($json | get --optional Year)
      | append ($json | get --optional Month)
      | append ($json | get --optional Day)
      | str join "-"
      | into datetime --timezone UTC
    }
  )

  # let narrative_fields = [Locations Characters Teams MainCharacterOrTeam]
  # let narrative = $narrative_fields | reduce --fold {narrative: {}} {|narrative_field, acc|
  #   if ($json | get --optional $narrative_field | is-empty) {
  #     return $acc
  #   }
  #   (
  #     $acc
  #     | update narrative (
  #       $acc.narrative
  #       | insert $narrative_field (
  #         $json | get $narrative_field
  #       )
  #     )
  #   )
  # }
  # StoryArc and StoryArcNumber have to handled specially for the narrative field.

  # todo
  # AlternativeSeries
  # AlternativeCount

  let issue_id = (
    if ($ids | is-not-empty) {
      $ids | where type == "comic_vine_issue_id" | get id | first
    }
  )

  let language = (
    let language = $json | get --optional LanguageISO;
    if ($language | is-not-empty) {
      try {
        $language | from_language_code
      } catch {|error|
        log warning $"Unknown language code in ComicInfo: (ansi red)($language)(ansi reset)"
        null
      }
    }
  )

  let genres = (
    if ($json | get --optional Genre | is-not-empty) {
      $json.Genre | sanitize_genres_or_tags $genre_allowlist
    }
  )

  let tags = (
    if ($json | get --optional Tags | is-not-empty) {
      # Tags have such a broad range that sanitizing them might prove difficult.
      # I need a way to ensure I don't lose any tags on accident.
      # $json.Tags | sanitize_genres_or_tags $tag_allowlist
      $json.Tags
    }
  )

  let comic_info_age_rating = (
    if ($json | get --optional AgeRating | is-not-empty) and $json.AgeRating in ($age_rating_map.comic_info | uniq) {
      $json.AgeRating
    }
  )

  (
    {}
    | upsert_if_value "comic_info_age_rating" $comic_info_age_rating
    | upsert_if_value "chapter_title" $chapter_title
    | upsert_if_value "chapter_index" $chapter_index
    | upsert_if_value "issue_count" $issue_count
    | upsert_if_value "issue_id" $issue_id
    | upsert_if_present "series" $json "Series"
    | upsert_if_value "issue" $issue
    | upsert_if_value "volume" $volume
    | upsert_if_value "credits" $contributors
    | upsert_if_value "ids" $ids
    | upsert_if_value "links" $links
    | upsert_if_value "language" $language
    | upsert_if_present "isbn" $json "GTIN"
    | upsert_if_present "manga" $json "Manga"
    | upsert_if_present "description" $json "Summary"
    | upsert_if_present "comment" $json "Notes"
    | upsert_if_value "publication_date" $publication_date
    | upsert_if_value publishers $publishers
    | upsert_if_value imprints $imprints
    | upsert_if_present year $json "Year"
    | upsert_if_present month $json "Month"
    | upsert_if_present day $json "Day"
    | upsert_if_value "genres" $genres
    | upsert_if_value "tags" $tags
    | upsert_if_present "series_groups" $json "SeriesGroup"
    | upsert_if_present "scan_information" $json "ScanInformation"
    | upsert_if_present "page_count" $json "PageCount"
    | upsert_if_present "format" $json "Format"
  )
}

# Remove commas from a name for a ComicInfo field which lists multiple names
#
# Kavita splits the names in these fields on commas, so a comma in a name, like "Yen Press, LLC", would split it into two names.
export def sanitize_comic_info_name []: string -> string {
  $in | str replace --all "," "" | str replace --all --regex '\s+' " " | str trim
}

# Convert the manga value to the values used by ComicInfo
#
# Booleans are converted to "Yes" and "No".
# https://anansi-project.github.io/docs/comicinfo/documentation#manga
export def comic_info_manga_value []: any -> string {
  let manga = $in
  if ($manga | describe) == "bool" {
    if $manga { "Yes" } else { "No" }
  } else {
    $manga
  }
}

# Convert the internal data structure for a comic to a ComicInfo.xml
#
# https://anansi-project.github.io/docs/comicinfo/documentation
# https://wiki.kavitareader.com/guides/metadata/comics/
export def into_comic_info_xml []: [record -> record] {
  let data = $in
  if ($data | is-empty) {
    error make {
      msg: "empty comic data"
      labels: [
          {text: "in" span: (metadata $in).span}
      ]
      help: $"pipe in the comic data"
    }
  }

  let data = (
    if ($data | get --optional manga) == null {
      $data
    } else {
      $data | update manga ($data.manga | comic_info_manga_value)
    }
  )

  let creators = (
    $data | get --optional credits.person | uniq | reduce --fold [] {|creator creator_acc|
      let creator_comic_vine_roles = $data.credits | where person == $creator | get role | uniq
      # for each set of comic_vine_roles that is a subset of the creator's roles,
      # add the creator with each of the target roles
      $creator_acc | append (
        $comic_vine_roles_map
        | reduce --fold [] {|comic_vine_roles acc|
          if ($comic_vine_roles.comic_vine_roles | all {|role| $role in $creator_comic_vine_roles}) {
            $acc | append (
              $comic_vine_roles.comic_info_roles | each {|role|
                {
                  person: $creator
                  role: $role
                }
              }
            )
          } else {
            $acc
          }
        }
        | uniq
      )
    }
  ) | where {|creator| $creator.role | is-not-empty}
  let creators = (
    if ($creators | is-empty) {
      null
    } else {
      # log debug $"Creators: ($creators)"
      # log debug $"Creators grouped-by role: ($creators | group-by --to-table role)"
      $creators | group-by --to-table role | reduce --fold {} {|role acc|
        $acc | insert $role.role $role.items.person
      }
    }
  )

  let urls = $data.ids | each {|id|
    if $id.type == "hardcover_book_slug" {
      ""
    } else if $id.type == "hardcover_edition_id" {
      if "hardcover_book_slug" in ($data | get --optional ids.type) {
        $id.id | identifier_into_url $id.type --hardcover-book-slug ($data.ids | where type == "hardcover_book_slug" | get id | first)
      } else {
        $id.id | identifier_into_url $id.type
      }
    } else if $id.type == "comic_vine_issue_id" {
      let i = (
        if ($id.id | str starts-with "4000-") {
          $id.id
        } else {
          "4000-" + $id.id
        }
      )
      $i | identifier_into_url $id.type
    } else if $id.type == "comic_vine_volume_id" {
      let i = (
        if ($id.id | str starts-with "4050-") {
          $id.id
        } else {
          "4050-" + $id.id
        }
      )
      $i | identifier_into_url $id.type
    } else {
      $id.id | identifier_into_url $id.type
    }
  } | where {|url| $url | is-not-empty } | append ($data | get --optional links) | sort | uniq | str join " "

  # todo
  # AgeRating (Normalize to Metron's / Kavita's supported ones)
  # AlternativeSeries
  # AlternativeCount

  let publication_date = $data | get --optional publication_date
  let publication_date_parts = (
    if ($publication_date | is-not-empty) {
      {
        year: ($publication_date | format date "%Y")
        month: ($publication_date | format date "%m")
        day: ($publication_date | format date "%d")
      }
    }
  )

  # Kavita can parse Comic Vine and Metron IDs in a specific format from the Notes section.
  # ComicVine [CVDB734524]
  # MetronTagger- [issue_id:156409]
  # todo support parsing these from the ComicInfo.xml as well.
  let notes = (
    let notes = $"Tagged with MediaJuggler import-comics.nu version ($media_juggler_version) at (date now | date to-timezone UTC | format date %+).";
    let comic_vine_issue_ids = $data.ids | where type == "comic_vine_issue_id";
    let notes = (
      if ($comic_vine_issue_ids | is-not-empty) {
        let comic_vine_issue_id = $comic_vine_issue_ids.id | first | str replace "4000-" ""
        $"($notes) ComicVine [CVDB($comic_vine_issue_id)]."
      } else {
        $notes
      }
    );
    let metron_issue_ids = $data.ids | where type == "metron_issue_id";
    if ($metron_issue_ids | is-not-empty) {
      let metron_issue_id = $metron_issue_ids.id | first
      $"($notes) MetronTagger- [issue_id:($metron_issue_id)]."
    } else {
      $notes
    }
  )

  # todo Teams?
  # todo main character?
  let comic_info_xml = (
    {
      tag: "ComicInfo"
      attributes: {}
      content: []
    }
    | upsert_comic_info {tag: "GTIN", value: ($data | get --optional isbn)}
    | upsert_comic_info {tag: "Series", value: ($data | get --optional series)}
    # | upsert_comic_info {tag: "Format", value: ($data | get --optional format)}
    | upsert_comic_info {
      tag: "Genre"
      value: (
        if ($data | get --optional genres | is-empty) {
          null
        } else {
          $data.genres | sort | str join ","
        }
      )
    }
    | upsert_comic_info {
      tag: "Tags"
      value: (
        if ($data | get --optional tags | is-empty) {
          null
        } else {
          $data.tags | sort | str join ","
        }
      )
    }
    | upsert_comic_info {tag: "AgeRating", value: ($data | get --optional comic_info_age_rating)}
    | upsert_comic_info {tag: "Count", value: ($data | get --optional issue_count)}
    | upsert_comic_info {
      tag: "PageCount"
      value: (
        if ($data | get --optional page_count | is-not-empty) {
          $data.page_count | into string
        }
      )
    }
    | upsert_comic_info {tag: "Title", value: ($data | get --optional chapter_title)}
    | upsert_comic_info {tag: "Publisher", value: ($data | get --optional publishers | each {|publisher| $publisher | sanitize_comic_info_name } | str join ",")}
    | upsert_comic_info {
      tag: "Imprint"
      value: (
        if ($data | get --optional imprints | is-not-empty) {
          $data.imprints | each {|imprint| $imprint | sanitize_comic_info_name } | str join ","
        }
      )
    }
    | upsert_comic_info {tag: "Summary", value: ($data | get --optional description)}
    | upsert_comic_info {tag: "Notes", value: $notes}
    | upsert_comic_info {
      tag: "Characters"
      value: (
        if ($data | get --optional characters | is-empty) {
          null
        } else {
          $data.characters.name | each {|character| $character | sanitize_comic_info_name } | sort | str join ","
        }
      )
    }
    | upsert_comic_info {tag: "Day", value: ($publication_date_parts | get --optional day)}
    | upsert_comic_info {tag: "Month", value: ($publication_date_parts | get --optional month)}
    | upsert_comic_info {tag: "Year", value: ($publication_date_parts | get --optional year)}
    | upsert_comic_info {tag: "Manga", value: ($data | get --optional manga)}
    | upsert_comic_info {
      tag: "Number"
      value: (
        $data | get --optional (
          if ($data | get --optional manga) != "No" {
            ""
          } else {
            "issue"
          }
        )
      )
    }
    | upsert_comic_info {
      tag: "Volume"
      value: (
        $data | get --optional (
          if ($data | get --optional manga) != "No" {
            "issue"
          } else {
            "volume"
          }
        )
      )
    }
    | upsert_comic_info {tag: "LanguageISO", value: ($data | get --optional language | into_language_code ietf_bcp_47)}
    | upsert_comic_info {tag: "Web", value: $urls}
  )
  # log debug $"creators: ($creators)"
  # $comic_info_xml
  let comic_info_xml = $creators | columns | reduce --fold $comic_info_xml {|role acc|
    $acc | upsert_comic_info {tag: $role, value: ($creators | get $role | each {|person| $person | sanitize_comic_info_name } | uniq | sort | str join ",")}
  }
  # log debug $"Comic info: ($comic_info_xml | to nuon)"
  $comic_info_xml
}

export def get_comic_vine_issue [
  cache: closure
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> record] {
  let comic_vine_id = $in
  let comic_vine_id = (
    if ($comic_vine_id | str starts-with "4000-") {
      $comic_vine_id
    } else {
      "4000-" + $comic_vine_id
    }
  )
  for var in [COMIC_VINE_API_KEY] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      return null
    }
  }

  let update_cache = {|type id|
    log debug $"Getting Comic Vine data for issue ($id) from (ansi yellow)https://comicvine.gamespot.com/api/issue/($comic_vine_id)/?api_key=<api-key>&format=json(ansi reset)"
    let request = {
      (
        http get
          --full
          --headers {
            "User-Agent": $user_agent
            "Accept": "application/json"
          }
          $"https://comicvine.gamespot.com/api/issue/($id)/?api_key=($env.COMIC_VINE_API_KEY)&format=json"
      )
    }
    let response = (
      try {
        retry_http $request $retries $retry_delay
      } catch {|error|
        log error $"Error getting Comic Vine data for issue ($id) from (ansi yellow)https://comicvine.gamespot.com/api/issue/($id)/?api_key=<api-key>&format=json(ansi reset): ($error.debug)"
        return null
      }
    )
    if ($response.status != 200) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Comic Vine issue data with Comic Vine ID ($id) from (ansi yellow)https://comicvine.gamespot.com/api/issue/($id)/?api_key=<api-key>&format=json(ansi reset): ($response.body)"
      return null
    }
    # log debug $"response.body: ($response.body)"
    $response.body.results
  }
  do $cache "comic-vine-issue" $comic_vine_id $update_cache ""
}

export def get_comic_vine_volume [
  cache: closure
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> record] {
  let comic_vine_id = $in
  let comic_vine_id = (
    if ($comic_vine_id | str starts-with "4050-") {
      $comic_vine_id
    } else {
      "4050-" + $comic_vine_id
    }
  )
  for var in [COMIC_VINE_API_KEY] {
    if ($env | get --optional $var | is-empty) {
      log error $"The environment variable ($var) must be set."
      return null
    }
  }

  let update_cache = {|type id|
    let request = {
      (
        http get
          --full
          --headers {
            "User-Agent": $user_agent
            "Accept": "application/json"
          }
          $"https://comicvine.gamespot.com/api/volume/($id)/?api_key=($env.COMIC_VINE_API_KEY)&format=json"
      )
    }
    let response = (
      try {
        retry_http $request $retries $retry_delay
      } catch {|error|
        log error $"Error getting Comic Vine data for volume ($id) from (ansi yellow)https://comicvine.gamespot.com/api/volume/($id)/?api_key=<api-key>&format=json(ansi reset): ($error.debug)"
        return null
      }
    )
    if ($response.status != 200) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Comic Vine volume data with Comic Vine ID ($id) from (ansi yellow)https://comicvine.gamespot.com/api/volume/($comic_vine_id)/?api_key=<api-key>&format=json(ansi reset): ($response.body)"
      return null
    }
    $response.body.results
  }
  do $cache "comic-vine-issue" $comic_vine_id $update_cache ""
}
