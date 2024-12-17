#!/usr/bin/env nu

# ~/Projects/media-juggler/packages/import-comics/import-comics.nu --output-directory ~/Downloads ~/Downloads/ComicTagger-x86_64.AppImage ...(^mc find --name '*.cbz' "jwillikers/media/Books/Books/Ryoko Kui" | lines | par-each {|l| "minio:" + $l})

# todo Place the Calibre library and database in the temporary directory

use std log
use media-juggler-lib *

# $env.NU_LOG_LEVEL = "DEBUG"

# Publishers excluded from ComicTagger matches.
let excluded_publishers = [
    "Azbooka"
    "Carlsen Verlag"
    "Crunchyroll SA"
    "Crunchyroll SAS"
    "Daewon C.I."
    "Dargaud"
    "Darkwood"
    "Delcourt"
    "Editorial Ivrea"
    "Edizioni BD"
    "Edizioni Star Comics"
    "Egmont Ehapa Verlag "
    "Europe Comics"
    "Éditions Glénat "
    "Image"
    "Jademan"
    "Japonica Polonica Fantastica"
    "Ki-oon"
    "Kodansha"
    "Kurokawa"
    "Milky Way Ediciones"
    "M&C"
    "NBM"
    "Norma Editorial"
    "Pika Édition"
    "Planeta DeAgostini"
    "Scary Go Round"
    "Schibsted"
    "Shueisha"
    "Shogakukan"
    "Siam Inter"
    "Soleil"
    "Square Enix"
    "Tong Li Publishing Co."
    "Tokyopop GmbH"
]

# Tag CBZ file with ComicTagger using Comic Vine
export def tag_cbz [
    comictagger: path
    --comic-vine-issue-id: string # The Comic Vine issue id. Useful when nothing else works.
    # --excluded-publishers: list<string> # A list of publishers to exclude
    --interactive # Ask for input from the user
]: path -> record {
    let cbz = $in
    let args = (
        [] | append (
            if $comic_vine_issue_id != null {
                $"--id=($comic_vine_issue_id)"
            }
        )
    )
    let result = (
        if $interactive {
            (
                ^$comictagger
                --cv-use-series-start-as-volume
                --filename-parser "original"
                --interactive
                --no-cr
                --no-gui
                --online
                --parse-filename
                --publisher-filter ...$excluded_publishers
                --save
                --tags-write "CIX"
                --use-publisher-filter
                $cbz
            )
            (
                ^$comictagger
                --json
                --print
                --no-gui
                --tags-read "CIX"
                $cbz
            ) | from json
        } else {
            (
                ^$comictagger
                --cv-use-series-start-as-volume
                --filename-parser "original"
                --json
                --no-cr
                --no-gui
                --online
                --parse-filename
                --publisher-filter ...$excluded_publishers
                --save
                --tags-read "CR,CIX"
                --tags-write "CIX"
                --use-publisher-filter
                ...$args
                $cbz
            )
            | from json
        }
    )
    { cbz: $cbz, result: $result }
}

# Rename the comic according to the ComicInfo metadata
export def comictagger_rename_cbz [
    --comictagger: path # ComicTagger executable
]: path -> path {
    let cbz = $in
    (
        ^$comictagger
        --no-cr
        --no-gui
        --rename
        --tags-read "CIX"
        --template '{series} ({volume}) #{issue} ({year})'
        $cbz
        | lines --skip-empty
        | last
        | (
            let output = $in;
            log debug $"ComicTagger rename output: ($output)";
            if $output == "Filename is already good!" {
                $cbz
            } else {
                let new_name = (
                    $output
                    | parse --regex 'renamed \'(?P<original>.+\.cbz)\' -> \'(?P<renamed>.+\.cbz)\''
                    | get renamed
                    | first
                    | (
                        let filename = $in;
                        ($cbz | path parse | get parent) | path join $filename
                    )
                )
                log debug $"Renamed (ansi yellow)($cbz)(ansi reset) to (ansi yellow)($new_name)(ansi reset)"
                $new_name
            }
        )
    )
}

# Update ComicInfo metadata with ComicTagger
export def comictagger_update_metadata [
    metadata: string # Key and values to update in the metadata in a YAML-like syntax
    --comictagger: path # ComicTagger executable
]: path -> path {
    let cbz = $in
    (
        ^$comictagger
            --metadata $metadata
            --no-cr
            --no-gui
            --quiet
            --save
            --tags-read "CIX"
            --tags-write "CIX"
            $cbz
    )
    $cbz
}

# Import my comic or manga file to my collection.
#
# This script performs several steps to process the comic or manga file.
#
# 1. Decrypt the ACSM file.
# 2. Convert from EPUB to the CBZ format.
# 4. Fetch and add metadata in the ComicInfo.xml format.
# 5. Upload the file to object storage.
#
# Information that is not provided will be gleaned from the title of the EPUB file if possible.
#
# The final file is named according to Jellyfin's recommendation.
# The name will look like "<series> (<series-year>) #<issue> (<issue-year>).cbz".
#
def main [
    comictagger: path = "./ComicTagger-x86_64.AppImage" # Temporarily required until the Nix package is available
    ...files: string # The paths to ACSM, EPUB, and CBZ files to convert, tag, and upload. Prefix paths with "minio:" to download them from the MinIO instance
    --archive-pdf # Archive input PDF files under the --minio-archival-path instead of uploading them to the primary bucket. This will cause a high quality CBZ file to be generated and uploaded to the primary storage server.
    --clear-comictagger-cache # Clear the ComicTagger cache to force it to pull in updated data
    --comic-vine-issue-id: string # The Comic Vine issue id. Useful when nothing else works, but not recommended as it doesn't seem to verify the cover image.
    --delete # Delete the original file
    --ereader: string # Create a copy of the comic book optimized for this specific e-reader, i.e. "Kobo Elipsa 2E"
    --ereader-subdirectory: string = "Books/Manga" # The subdirectory on the e-reader in-which to copy
    # --ignore-epub-title # Don't use the EPUB title for the Comic Vine lookup
    --isbn: string
    --interactive # Ask for input from the user
    --keep-acsm # Keep the ACSM file after conversion. These stop working for me before long, so no point keeping them around.
    # --issue: string # The issue number
    # --issue-year: string # The publication year of the issue
    --manga: string = "YesAndRightToLeft" # Whether the file is manga "Yes", right-to-left manga "YesAndRightToLeft", or not manga "No". Refer to https://anansi-project.github.io/docs/comicinfo/documentation#manga
    --minio-alias: string = "jwillikers" # The alias of the MinIO server used by the MinIO client application
    --minio-path: string = "media/Books/Books" # The upload bucket and directory on the MinIO server. The file will be uploaded under a subdirectory named after the author.
    --minio-archival-path: string = "media-archive/Books/Books" # The upload bucket and directory on the MinIO server where EPUBs will be archived. The file will be uploaded under a subdirectory named after the author.
    --no-copy-to-ereader # Don't copy the E-Reader specific format to a mounted e-reader
    --output-directory: directory # Directory to place files when not being uploaded
    # --series: string # The name of the series
    # --series-year: string # The initial publication year of the series, also referred to as the volume
    --skip-upload # Don't upload files to the server
    --title: string # The title of the comic or manga issue
    --upload-ereader-cbz # Upload the E-Reader specific format to the server
] {
    if ($files | is-empty) {
        log error "No files provided"
        exit 1
    }

    if $comic_vine_issue_id != null and ($files | length) > 1 {
        log error "Setting the comic vine issue id for multiple files is not allowed as it will result in overwriting the final file"
        exit 1
    }

    if $isbn != null and ($files | length) > 1 {
        log error "Setting the ISBN for multiple files is not allowed as it will result in overwriting the final file"
        exit 1
    }

    let output_directory = (
        if $output_directory == null {
            "." | path expand
        } else {
            $output_directory
        }
    )
    mkdir $output_directory

    let username = (^id --name --user)
    let ereader_disk_label = (
      if $ereader == null {
        null
      } else {
        $ereader_profiles | where model == $ereader | first | get disk_label
      }
    )
    let ereader_mountpoint = (["/run/media" $username $ereader_disk_label] | path join)
    let ereader_target_directory = ([$ereader_mountpoint $ereader_subdirectory] | path join)
    if $ereader != null and not $no_copy_to_ereader {
      if (^findmnt --target $ereader_target_directory | complete | get exit_code) != 0 {
        ^udisksctl mount --block-device ("/dev/disk/by-label/" | path join $ereader_disk_label) --no-user-interaction
        # todo Parse the mountpoint from the output of this command
      }
      mkdir $ereader_target_directory
    }

    if $clear_comictagger_cache {
      log debug "Clearing the ComicTagger cache"
      rm --force --recursive ([$env.HOME ".cache" "ComicTagger"] | path join)
    }

    # let results = null
    # let original_file = $files | first
    let results = $files | each {|original_file|

    log info $"Importing the file (ansi purple)($original_file)(ansi reset)"

    let temporary_directory = (mktemp --directory "import-comics.XXXXXXXXXX")
    log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

    try {

    let file = (
        if ($original_file | str starts-with "minio:") {
            let file = ($original_file | str replace "minio:" "")
            let target = [$temporary_directory ($file | path basename)] | path join
            log debug $"Downloading the file (ansi yellow)($file)(ansi reset) from MinIO to (ansi yellow)($target)(ansi reset)"
            ^mc cp $file $target
            $target
        } else {
            let target = [$temporary_directory ($original_file | path basename)] | path join
            log debug $"Copying the file (ansi yellow)($original_file)(ansi reset) to (ansi yellow)($target)(ansi reset)"
            cp $original_file $target
            $target
        }
    )

    let original_input_format = ($file | path parse | get extension)

    let original_comic_info = (
        let comic_info_file = ($original_file | str replace "minio:" "" | path dirname | path join "ComicInfo.xml");
        if ($original_file | str starts-with "minio:") {
            if (^mc stat $comic_info_file | complete).exit_code == 0 {
                $comic_info_file
            }
        } else {
            if ($comic_info_file | path exists) {
                $comic_info_file
            }
        }
    )

    if $original_comic_info != null {
        log debug $"Found Comic Info file (ansi yellow)($original_comic_info)(ansi reset)"
    }

    let comic_info = (
        if $original_comic_info != null {
            let comic_info_file = ($original_file | str replace "minio:" "" | path dirname | path join "ComicInfo.xml")
            if ($original_file | str starts-with "minio:") {
                let target = [$temporary_directory ($comic_info_file | path basename)] | path join
                log debug $"Downloading the file (ansi yellow)($original_comic_info)(ansi reset) to (ansi yellow)($target)(ansi reset)"
                ^mc cp $original_comic_info $target
            } else {
                let target = [$temporary_directory ($comic_info_file | path basename)] | path join
                log debug $"Copying the file (ansi yellow)($original_file)(ansi reset) to (ansi yellow)($target)(ansi reset)"
                cp $original_comic_info $target
            }
            [$temporary_directory ($comic_info_file | path basename)] | path join
        } else {
          null
        }
    )

    let original_opf = (
        let opf_file = ($original_file | str replace "minio:" "" | path dirname | path join "metadata.opf");
        if ($original_file | str starts-with "minio:") {
            if (^mc stat $opf_file | complete).exit_code == 0 {
                $opf_file
            }
        } else {
            if ($opf_file | path exists) {
                $opf_file
            }
        }
    )

    if $original_opf != null {
        log debug $"Found OPF metadata file (ansi yellow)($original_opf)(ansi reset)"
    }

    let opf = (
        if $original_opf != null {
            let opf_file = ($original_file | str replace "minio:" "" | path dirname | path join "ComicInfo.xml")
            if ($original_file | str starts-with "minio:") {
                let target = [$temporary_directory ($opf_file | path basename)] | path join
                log debug $"Downloading the file (ansi yellow)($original_opf)(ansi reset) to (ansi yellow)($target)(ansi reset)"
                ^mc cp $original_opf $target
            } else {
                let target = [$temporary_directory ($opf_file | path basename)] | path join
                log debug $"Copying the file (ansi yellow)($original_file)(ansi reset) to (ansi yellow)($target)(ansi reset)"
                cp $original_opf $target
            }
            [$temporary_directory ($opf_file | path basename)] | path join
        } else {
          null
        }
    )

    let original_cover = (
        if ($original_file | str starts-with "minio:") {
            let file = $original_file | str replace "minio:" ""
            let covers = (
                ^mc find ($file | path dirname) --name 'cover.*'
                | lines --skip-empty
                | filter {|f|
                    let components = ($f | path parse);
                    $components.stem == "cover" and $components.extension in $image_extensions
                }
            )
            if not ($covers | is-empty) {
                if ($covers | length) > 1 {
                    log error $"Found multiple files looking for the cover image file:\n($covers)\n"
                    exit 1
                } else {
                    $covers | first
                }
            }
        } else {
            let covers = (glob $"($original_file | path dirname)/cover.{($image_extensions | str join ',')}")
            if not ($covers | is-empty) {
                if ($covers | length) > 1 {
                    log error $"Found multiple files looking for the cover image file:\n($covers)\n"
                    exit 1
                } else {
                    $covers | first
                }
            }
        }
    )

    if $original_cover != null {
        log debug $"Found the cover file (ansi yellow)($original_cover)(ansi reset)"
    }

    # todo Incorporate the original cover file?
    # let cover = (
    #     if ($input_format == "pdf" and $original_cover != null) {
    #         if ($original_file | str starts-with "minio:") {
    #             ^mc cp $original_cover $"($temporary_directory)/($original_cover | path basename)"
    #         } else {
    #             cp $original_cover $"($temporary_directory)/($original_cover | path basename)"
    #         }
    #         $"($temporary_directory)/($original_cover | path basename)"
    #     } else {
    #       null
    #     }
    # )

    let original_comic_files = [$original_file] | append $original_comic_info | append $original_cover | append $original_opf
    log debug $"The original files for the comic are (ansi yellow)($original_comic_files)(ansi reset)"

    let output_format = (
        if $original_input_format == "pdf" and not $archive_pdf {
            "pdf"
        } else {
            "cbz"
        }
    )

    let formats = (
        if $original_input_format == "acsm" {
            log debug "Decrypting and converting the ACSM file to an EPUB"
            { epub: ($file | acsm_to_epub $temporary_directory) }
        } else if $original_input_format == "epub" {
            { epub: $file }
        } else if $original_input_format in ["cbz" "zip"] {
            { cbz: $file }
        } else if $original_input_format == "pdf" {
          { pdf: $file }
        } else {
            log error $"Unsupported input file type (ansi red_bold)($original_input_format)(ansi reset)"
            exit 1
        }
    )

    let input_format = (
        if $original_input_format == "acsm" {
            "epub"
        } else {
            $original_input_format
        }
    )

    if "epub" in $formats {
        log debug "Optimizing the EPUB"
        $formats.epub | optimize_images_in_zip | polish_epub
    }

    # Try to get the ISBN from the comics metadata.
    let isbn = (
        if $isbn == null {
            log debug "Attempting to get the ISBN from existing metadata"
            $file | get_metadata $temporary_directory | isbn_from_metadata $temporary_directory
        } else {
          $isbn
        }
    )

    # Generate a CBZ from the PDF format which may be used to extract the ISBN.
    let formats = (
        if "pdf" in $formats {
            log debug "Generating a CBZ from the PDF"
            $formats | insert cbz ($formats.pdf | cbconvert --format "jpeg" --quality 90)
        } else {
            $formats
        }
    )

    # Try to get the ISBN from the pages in the comic
    let isbn = (
        if $isbn == null {
            log debug "Attempting to get the ISBN from the first ten and last ten pages of the comic"
            let isbn_numbers = $file | isbn_from_pages $temporary_directory
            if ($isbn_numbers | is-empty) {
                # Check images of the PDF for the ISBN if text doesn't work out.
                if $input_format == "pdf" and "cbz" in $formats {
                    let isbn_from_cbz = $formats.cbz | isbn_from_pages $temporary_directory
                    if ($isbn_from_cbz | is-empty) {
                        null
                    } else if ($isbn_from_cbz | length) > 1 {
                        # todo Allow selecting from one of these ISBNs interactively?
                        log warning $"Found multiple potential ISBNs in the book's pages: ($isbn_from_cbz). Ignoring the ISBNs."
                    } else {
                        $isbn_from_cbz | first
                    }
                } else {
                    null
                }
            } else if ($isbn_numbers | length) > 1 {
                # todo Allow selecting from one of these ISBNs interactively?
                log warning $"Found multiple potential ISBNs in the book's pages: ($isbn_numbers). Ignoring the ISBNs."
                null
            } else {
                $isbn_numbers | first
            }
        } else {
            $isbn
        }
    )
    if $isbn == null {
        log warning $"Unable to determine the ISBN from metadata or the pages of the comic"
    } else {
        log debug $"The ISBN is (ansi purple)($isbn)(ansi reset)"
    }

    # todo Should existing metadata be merged with the fetched metadata?
    # Right now, existing metadata is completely ignored except for the Comic Info already embedded in a CBZ because ComicTagger will read that.

    # Fetch ebook metadata using the ISBN
    let formats = (
        if $isbn != null {
            log debug $"Fetching book metadata for the ISBN (ansi purple)($isbn)(ansi reset)"
            $formats | update $input_format (
                $formats
                | get $input_format
                | fetch_book_metadata --isbn $isbn $temporary_directory
                | export_book_to_directory $temporary_directory
                | embed_book_metadata $temporary_directory
                | get book
            )
        } else {
            $formats
        }
    )

    # Rename input file according to metadata
    let formats = (
        $formats
        | update $input_format (
            if $comic_vine_issue_id == null {
                let target = $formats | get $input_format | comic_file_name_from_metadata $temporary_directory
                log debug $"Renaming (ansi yellow)($formats | get $input_format)(ansi reset) to (ansi yellow)($target)(ansi reset)"
                mv ($formats | get $input_format) $target
                $target
            } else {
                $formats | get $input_format
            }
        )
        | (
            let i = $in;
            if $input_format == "pdf" and "cbz" in $i {
                # Rename the CBZ according to the name of the PDF
                let target = $i | get $input_format | path parse | update extension cbz | path join
                mv $i.cbz $target
                $i | update cbz $target
            } else {
                $i
            }
        )
    )

    # Generate a CBZ from the EPUB and PDF formats
    let formats = (
        if "epub" in $formats {
            log debug "Generating a CBZ from the EPUB"
            $formats | insert cbz ($formats.epub | epub_to_cbz --working-directory $temporary_directory)
        } else if "pdf" in $formats {
            log debug "Updating the CBZ for the PDF"
            let cbz = (
                $formats.cbz
                | (
                let archive = $in;
                if $comic_info != null {
                    {
                        archive: $archive,
                        comic_info: (open $comic_info),
                    }
                    | inject_comic_info
                } else {
                    $archive
                }
                )
            )
            if $comic_info != null {
                log debug $"Removing the sidecar ComicInfo file (ansi yellow)($comic_info)(ansi reset)"
                rm $comic_info
            }
            $formats | update cbz $cbz
        } else {
            $formats
        }
    )

    log debug $"Fetching and writing metadata to (ansi yellow)($formats.cbz)(ansi reset) with ComicTagger"
    let tag_result = (
        $formats.cbz | tag_cbz $comictagger --comic-vine-issue-id $comic_vine_issue_id
    )
    log debug $"The ComicTagger result is:\n(ansi green)($tag_result.result)(ansi reset)\n"

    if ($tag_result.result.status == "match_failure") {
        # todo Add stderr from ComicTagger here
        # todo Use make error?
        log error $"Failed to tag ($original_file)"
        rm --force --recursive $temporary_directory
        return {
            file: $original_file
            # todo Add stderr from ComicTagger here
            error: "ComicTagger failed to match the comic!"
        }
    }

    log debug "Renaming the CBZ according to the updated metadata from ComicTagger"
    let formats = $formats | (
        let format = $in;
        $format | update cbz ($format.cbz | comictagger_rename_cbz --comictagger $comictagger)
    )

    let comic_metadata = ($tag_result.result | get md)

    # Authors are considered to be creators with the role of "Writer" in the ComicVine metadata
    let authors = (
      let credits = $comic_metadata | get credits;
      let authors = $credits | where role in ["Artist" "Inker" "Penciller" "Writer"] | get person;
      if ($authors | is-empty) {
        $credits | where role == "Other" | get person
      } else {
        $authors
      } | sort | uniq
    )
    log debug $"The authors are (ansi purple)'($authors)'(ansi reset)"

    # We keep the name of the series in the title to keep things organized.
    # Displaying only "Vol. 4" as the title can be confusing.
    log debug "Including the series as part of the title and making it consistent"
    let title = (
        if $title == null {
            $comic_metadata
            | (
                let metadata = $in;
                # todo Handle issue_title?
                # If the volume is most likely just a single issue, just use the series as the name
                if $metadata.issue_count == 1 and (((date now) - ($metadata.volume | into string | into datetime)) | format duration yr) > 2yr {
                  if $metadata.title == null or $metadata.title == $metadata.series {
                    $metadata.series
                  } else {
                    if ($metadata.title | str starts-with $"($metadata.series): ") {
                        $metadata.title
                    } else {
                        $"($metadata.series): ($metadata.title)"
                    }
                  }
                } else {
                    let sanitized_title = (
                        if $metadata.title == null {
                            null
                        } else {
                            # todo Use a regex here so that this ignores incorrect series and issue information?
                            if ($metadata.title | str starts-with $"($metadata.series), Vol. ($metadata.issue): ") {
                                $metadata.title | str replace $"($metadata.series), Vol. ($metadata.issue): " ""
                            } else if ($metadata.title | str starts-with $"($metadata.series), Vol. ($metadata.issue)") {
                                $"Volume ($metadata.issue)"
                            } else {
                                $metadata.title
                            }
                        }
                    )
                    if $sanitized_title == null or $sanitized_title =~ 'Volume [0-9]+' or $sanitized_title =~ 'Vol. [0-9]+' {
                        $"($metadata.series), Vol. ($metadata.issue)"
                    } else {
                        $"($metadata.series), Vol. ($metadata.issue): ($sanitized_title)"
                    }
                }
            )
        } else {
            $title
        }
    )

    let previous_title = ($comic_metadata | get title)
    log info $"Rewriting the title from (ansi yellow)'($previous_title)'(ansi reset) to (ansi yellow)'($title)'(ansi reset)"
    # let sanitized_title = $title | str replace --all '"' '\"'
    # todo Read from YAML file to ensure proper string escaping of single / double quotes?
    # let metadata_yaml = $"manga: \"($manga)\", title: \"($sanitized_title)\""
    # let metadata_yaml = (
    #   if $isbn != null {
    #     $metadata_yaml
    #   } else {
    #     $metadata_yaml + $", GTIN: \"($isbn)\""
    #   }
    # )
    # $formats.cbz | comictagger_update_metadata $metadata_yaml --comictagger $comictagger

    # Add the ISBN to the ComicInfo
    log info "Updating the ComicInfo"
    (
        $formats.cbz
        | extract_comic_info_xml $temporary_directory
        # todo Determine BlackAndWhite automatically.
        # | upsert_comic_info {BlackAndWhite: $}
        | (
            let info = $in;
            if $isbn == null {
                $info
            } else {
                $info | upsert_comic_info {tag: "GTIN", value: $isbn}
            }
        )
        | upsert_comic_info {tag: "Manga", value: $manga}
        | upsert_comic_info {tag: "Title", value: $title}
        | {
            archive: $formats.cbz
            comic_info: $in
        }
        | inject_comic_info
    )

    let formats = (
        # Update the metadata in the EPUB and rename it to match the filename of the CBZ
        if "epub" in $formats {
            # Update the metadata in the EPUB file.
            $formats.epub | (
                tag_epub_comic_vine
                (if $comic_vine_issue_id == null { $comic_metadata.issue_id } else { $comic_vine_issue_id })
                $authors
                $title
                --working-directory $temporary_directory
            )
            let stem = ($formats.cbz | path parse | get stem)
            let renamed_epub = ({ parent: ($formats.epub | path parse | get parent), stem: $stem, extension: "epub" } | path join)
            mv $formats.epub $renamed_epub
            $formats | update epub $renamed_epub
        # Rename the PDF
        } else if "pdf" in $formats {
            let stem = ($formats.cbz | path parse | get stem)
            let renamed_pdf = ({ parent: ($formats.pdf | path parse | get parent), stem: $stem, extension: "pdf" } | path join)
            if $formats.pdf != $renamed_pdf {
              log debug $"Renaming the PDF from ($formats.pdf) to ($renamed_pdf)";
              mv $formats.pdf $renamed_pdf
            }
            let comic_info = $formats.cbz | extract_comic_info $temporary_directory;
            log debug "Extracted ComicInfo.xml";
            let cover_url = $comic_metadata._cover_image;
            let cover = (
                {
                    parent: $temporary_directory
                    stem: "cover"
                    extension: ($cover_url | path parse | get extension)
                } | path join
            );
            http get --raw $cover_url | save --force $cover;
            [$cover] | optimize_images;
            log debug $"Downloaded cover (ansi yellow)($cover)(ansi reset)";
            $formats
            | update pdf $renamed_pdf
            | insert comic_info $comic_info
            | insert cover $cover
            | (
                let input = $in;
                log debug "Updating PDF in table";
                log debug $"Input:\n($input)\n";
                # todo untested
                if $archive_pdf {
                    log debug "Creating JPEG-XL CBZ from PDF";
                    $input
                    | update cbz (
                      $formats.pdf
                      | convert_to_lossless_jxl
                      | (
                        let cbz = $in;
                        {
                            archive: $cbz
                            comic_info: (open $formats.comic_info)
                        }
                    ) | inject_comic_info
                  )
                } else {
                    log debug "Dropping cbz from formats";
                    $input | reject cbz
                }
            )
        } else {
            $formats
        }
    )
    log debug "Finished renaming files";

    if "cbz" in $formats {
        let image_format = ($formats.cbz | get_image_extension)
        if $image_format == null {
            log error "Failed to determine the image file format"
            exit 1
        }

        # todo Detect if another lossless format, i.e. webp, is being used and if so, convert those to jxl as well.
        if $image_format in ["png"] {
            $formats.cbz | convert_to_lossless_jxl
        } else if $image_format != "jxl" {
            $formats.cbz | optimize_images_in_zip
        }
    }

    # Not sure if "webp" would really be any better than jpeg here or not...
    # I'm assuming it might at least be a little bit smaller given cbconvert doesn't appear to use mozjpeg.
    # Use PNG for lossless codecs and webp for lossy.
    # CBconvert appears to always use lossy webp encoding.
    let formats = (
        if $ereader == null {
            $formats
        } else {
            $formats
            | insert ereader_cbz (
                $formats
                | get $input_format
                | convert_for_ereader $ereader $temporary_directory
            )
        }
    )

    # todo Functions archive_epub, upload_cbz, and perhaps copy_cbz_to_ereader

    let authors_subdirectory = ($authors | str join ", ")
    let minio_target_directory = (
        [$minio_alias $minio_path $authors_subdirectory]
        | append (
            if $output_format == "pdf" {
                $formats.pdf | path parse | get stem
            } else {
                null
            }
        )
        | path join
        | sanitize_minio_filename
    )
    log debug $"MinIO target directory: ($minio_target_directory)"
    let minio_target_destination = (
        let components = (
            if $output_format == "pdf" {
                $formats.pdf
            } else {
                $formats.cbz
            } | path parse
        );
        { parent: $minio_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
    )
    log debug $"MinIO target destination: ($minio_target_destination)"
    if $skip_upload {
        mv ($formats | get $output_format) $output_directory
        if $output_format == "pdf" {
          mv $formats.comic_info $output_directory
          mv $formats.cover $output_directory
        }
    } else {
        log info $"Uploading (ansi yellow)($formats | get $output_format)(ansi reset) to (ansi yellow)($minio_target_destination)(ansi reset)"
        ^mc mv ($formats | get $output_format) $minio_target_destination
        if $output_format == "pdf" {
          let comic_info_target_destination = [$minio_target_directory ($formats.comic_info | path basename)] | path join
          log info $"Uploading (ansi yellow)($formats.comic_info)(ansi reset) to (ansi yellow)($comic_info_target_destination)(ansi reset)"
          ^mc mv $formats.comic_info $comic_info_target_destination
          let cover_target_destination = [$minio_target_directory ($formats.cover | path basename)] | path join
          log info $"Uploading (ansi yellow)($formats.cover)(ansi reset) to (ansi yellow)($cover_target_destination)(ansi reset)"
          ^mc mv $formats.cover $cover_target_destination
        }
    }

    # Keep the EPUB for archival purposes.
    # I have Calibre reduce the size of images in a so-called "lossless" manner.
    # If anything about that isn't actually lossless, that's not good...
    # Guess I'm willing to take that risk right now.
    let minio_archival_target_directory = (
        [$minio_alias $minio_archival_path $authors_subdirectory]
        | append (
            if $input_format == "pdf" and $archive_pdf {
                $formats.pdf | path parse | get stem
            } else {
                null
            }
        )
        | path join
        | sanitize_minio_filename
    )
    if "epub" in $formats {
        let minio_archival_destination = (
            let components = ($formats.epub | path parse);
            { parent: $minio_archival_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
        )
        if $skip_upload {
            mv $formats.epub $output_directory
        } else {
            log info $"Uploading (ansi yellow)($formats.epub)(ansi reset) to (ansi yellow)($minio_archival_destination)(ansi reset)"
            ^mc mv $formats.epub $minio_archival_destination
        }
    } else if "pdf" in $formats and $archive_pdf  {
        let minio_pdf_archival_destination = (
            let components = ($formats.pdf | path parse);
            { parent: $minio_archival_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
        )
        let minio_comic_info_archival_destination = (
            let components = ($formats.comic_info | path parse);
            { parent: $minio_archival_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
        )
        let minio_cover_archival_destination = (
            let components = ($formats.cover | path parse);
            { parent: $minio_archival_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
        )
        if $skip_upload {
            mv $formats.pdf $output_directory
            mv $formats.comic_info $output_directory
            mv $formats.cover $output_directory
        } else {
            log info $"Uploading (ansi yellow)($formats.pdf)(ansi reset) to (ansi yellow)($minio_pdf_archival_destination)(ansi reset)"
            ^mc mv $formats.pdf $minio_pdf_archival_destination
            log info $"Uploading (ansi yellow)($formats.comic_info)(ansi reset) to (ansi yellow)($minio_comic_info_archival_destination)(ansi reset)"
            ^mc mv $formats.comic_info $minio_comic_info_archival_destination
            log info $"Uploading (ansi yellow)($formats.cover)(ansi reset) to (ansi yellow)($minio_cover_archival_destination)(ansi reset)"
            ^mc mv $formats.cover $minio_cover_archival_destination
        }
    }

    if ereader_cbz in $formats {
        if $no_copy_to_ereader {
            let safe_basename = (($formats.ereader_cbz | path basename) | str replace --all ":" "_")
            let target = ([$ereader_target_directory $safe_basename] | path join)
            log info $"Copying (ansi yellow)($formats.ereader_cbz)(ansi reset) to (ansi yellow)($target)(ansi reset)"
            cp $formats.ereader_cbz $target
        }
        if $upload_ereader_cbz {
            log info $"Uploading (ansi yellow)($formats.ereader_cbz)(ansi reset) to (ansi yellow)($minio_target_directory)/($formats.ereader_cbz | path basename)(ansi reset)"
            ^mc mv $formats.ereader_cbz $minio_target_directory
        }
        if $no_copy_to_ereader and not $upload_ereader_cbz {
            mv $formats.ereader_cbz $output_directory
        }
    }

    if $delete {
        log debug "Deleting the original file"
        let uploaded_paths = (
            [$minio_target_destination]
            | append
            (if "epub" in $formats {
                ([$minio_archival_target_directory ($formats.epub | path basename)] | path join | sanitize_minio_filename)
            } else {
                null
            })
            | append
            (if "comic_info" in $formats {
                ([$minio_target_directory ($formats.comic_info | path basename)] | path join | sanitize_minio_filename)
            } else {
                null
            })
            | append
            (if "cover" in $formats {
                ([$minio_target_directory ($formats.cover | path basename)] | path join | sanitize_minio_filename)
            } else {
                null
            })
        )
        log debug $"Uploaded paths: ($uploaded_paths)"
        if ($original_file | str starts-with "minio:") {
            let actual_path = ($original_file | str replace "minio:" "")
            log debug $"Actual path: ($actual_path)"
            if ($actual_path | sanitize_minio_filename) in $uploaded_paths {
                log info $"Not deleting the original file (ansi yellow)($original_file)(ansi reset) since it was overwritten by the updated file"
            } else {
                log info $"Deleting the original file on MinIO (ansi yellow)($actual_path)(ansi reset)"
                ^mc rm $actual_path
                if $input_format == "pdf" {
                    if $original_comic_info != null and $original_comic_info not-in $uploaded_paths {
                        log info $"Deleting the Comic Info file on MinIO (ansi yellow)($original_comic_info)(ansi reset)"
                        ^mc rm $original_comic_info
                    }
                    if $original_cover != null and $original_cover not-in $uploaded_paths {
                        log info $"Deleting the cover file on MinIO (ansi yellow)($original_cover)(ansi reset)"
                        ^mc rm $original_cover
                    }
                }
            }
        } else {
            log info $"Deleting the original file (ansi yellow)($original_file)(ansi reset)"
            rm $original_file
            if $input_format == "pdf" {
                if $original_comic_info != null and $original_comic_info not-in $uploaded_paths {
                    log info $"Deleting the Comic Info file (ansi yellow)($original_comic_info)(ansi reset)"
                    ^rm $original_comic_info
                }
                if $original_cover != null and $original_cover not-in $uploaded_paths {
                    log info $"Deleting the cover file (ansi yellow)($original_cover)(ansi reset)"
                    ^rm $original_cover
                }
            }
        }
    }
    log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
    rm --force --recursive $temporary_directory
    {
        file: $original_file
    }
    } catch {|err|
        rm --force --recursive $temporary_directory
        log error $"Import of (ansi red)($original_file)(ansi reset) failed!\n($err.msg)\n"
        {
            file: $original_file
            error: $err.msg
        }
    }
    }

    if $ereader != null and not $no_copy_to_ereader {
      if (^findmnt --target $ereader_target_directory | complete | get exit_code) == 0 {
        ^udisksctl unmount --block-device ("/dev/disk/by-label/" | path join $ereader_disk_label) --no-user-interaction
      }
    }

    $results | to json | print

    let errors = $results | default null error | where error != null
    if ($errors | is-not-empty) {
        log error $"(ansi red)Failed to import the following files due to errors!(ansi reset)"
        $errors | get file | $"(ansi red)($in)(ansi reset)" | print --stderr
        exit 1
    }
}
