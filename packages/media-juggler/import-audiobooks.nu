#!/usr/bin/env nu

# ~/Projects/media-juggler/packages/import-comics/import-comics.nu --output-directory ~/Downloads ~/Downloads/ComicTagger-x86_64.AppImage ...(^mc find --name '*.cbz' "jwillikers/media/Books/Books/Ryoko Kui" | lines | par-each {|l| "minio:" + $l})

use std log
use media-juggler-lib *

# Losslessly optimize images
export def optimize_images []: [list<path> -> record] {
    let paths = $in
    # Ignore config paths to ensure that lossy compression is not enabled.
    log debug $"Running command: (ansi yellow)image_optim --config-paths \"\" --recursive ($paths | str join ' ')(ansi reset)"
    let result = ^image_optim --config-paths "" --recursive --threads ((^nproc | into int) / 2) ...$paths | complete
    if ($result.exit_code != 0) {
        log error $"Exit code ($result.exit_code) from command: (ansi yellow)image_optim --config-paths \"\" --recursive ($paths)(ansi reset)\n($result.stderr)\n"
        return null
    }
    log debug $"image_optim stdout:\n($result.stdout)\n"
    (
        $result.stdout
        | lines --skip-empty
        | last
        | (
            let line = $in;
            log debug $"image_optim line: ($line)";
            if "------" in $line {
                { difference: 0.0, bytes: (0.0 | into filesize) }
            } else {
                $line
                | parse --regex 'Total:\W+(?P<difference>.+)%\W+(?P<bytes>.+)'
                | first
                | (
                    let i = $in;
                    {
                        difference: ($i.difference | into float),
                        bytes: ($i.bytes | into filesize),
                    }
                )
            }
        )
    )
}

# Get the image extension used in a comic book archive
export def get_image_extension []: [path -> string] {
    let cbz = $in
    let file_extensions = (
        ^unzip -l $cbz
        | lines
        | drop nth 0 1
        | drop 2
        | str trim
        | parse "{length}  {date} {time}   {name}"
        | get name
        | path parse
        | where extension != "xml"
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
    } else if (($file_extensions | length) > 1) {
        log error $"Multiple file extensions found: ($file_extensions)"
        null
    } else {
        $file_extensions | first
    }
}

# Fetch metadata for the EPUB and embed it
#
# The metadata for Authors and Title from the ComicVine Calibre plugin are corrected here.
# The title includes the issue number twice in the name, which is kind of ugly, so that is fixed.
# All creators are tagged as authors which is incorrect.
# To accommodate this, authors must be passed directly.
#
export def beet_import [
    # beet_executable: path # Path to the Beets executable to use
    config: path # Path to the Beets config to use
    library: path # Path to the Beets library to use
    # --search-id
    # --set
    --working-directory: directory
]: [path -> record] {
    let m4b = $in
    let output_directory = $working_directory | path join beets
    rm --force --recursive $output_directory
    # (
    #     ^beet
    #     --config $config
    #     --directory $output_directory
    #     --library $library
    #     import --move
    #     $m4b
    # )
    (
        ^podman run \
            --detach \
            --env "PUID=0" \
            --env "PGID=0" \
            --mount $"type=bind,src=($output_directory),dst=/audiobooks" \
            --mount $"type=bind,src=($m4b | path dirname),dst=/input" \
            --name "beets-audible" \
            --rm \
            --volume $"($config | path dirname):/config:Z" \
            --volume $"($config | path dirname)/scripts:/custom-cont-init.d:Z" \
            "lscr.io/linuxserver/beets:2.0.0"
    )
    ^podman exec --interactive --tty beets-audible beet import --move $"/input/($m4b | path basename)"
    ^podman stop beets-audible
    let author_directory = (ls --full-paths $output_directory | get name | first)
    let imported_m4b = (glob $"($author_directory)/*.m4b" | first)
    let directory = ($imported_m4b | path basename)
    let cover = (glob $"($directory)/*.{jpeg,jpg,jxl,png}" | first)
    {
        m4b: $imported_m4b,
        cover: $cover
    }
}

# Decrypt and convert an AAX file from Audible to an M4B file.
export def decrypt_audible [
    activation_bytes: string # Audible activation bytes
    --working-directory: directory
]: [path -> path] {
    let aax = $in
    let stem = $aax | path parse | get stem
    let m4b = ({ parent: $working_directory, stem: $stem, extension: "m4b" } | path join)
    ^ffmpeg -activation_bytes $activation_bytes -i $aax -c copy $m4b
    $m4b
}

# Embed the cover art to an M4B file
export def embed_cover []: [record -> path] {
    let audiobook = $in
    if $audiobook.cover == null {
        ^tone tag --auto-import=covers $audiobook.m4b
    } else {
        ^tone tag --meta-cover-file $audiobook.cover $audiobook.m4b
    }
    $audiobook
}

export def sanitize_minio_filename []: [string -> string] {
    $in | str replace --all "!" ""
}

# Import an audiobook to my collection.
#
# This script performs several steps to process the audiobook file.
#
# 1. Decrypt the Audible book if it is from Audible.
# 2. Tag the audiobook.
#
def main [
    beets_config: path # The Beets config file to use
    beets_library: path # The Beets library to use
    ...files: path # The paths to M4A and M4B files to tag and upload. Prefix paths with "minio:" to download them from the MinIO instance
    --audible-activation-bytes: string # The Audible activation bytes used to decrypt the AAX file
    --delete # Delete the original file
    --minio-alias: string = "jwillikers" # The alias of the MinIO server used by the MinIO client application
    --minio-path: string = "media/Books/Audiobooks" # The upload bucket and directory on the MinIO server. The file will be uploaded under a subdirectory named after the author.
    --output-directory: directory # Directory to place files when not being uploaded
    --skip-upload # Don't upload files to the server
] {
    let output_directory = (
        if $output_directory == null {
            "." | path expand
        } else {
            $output_directory
        }
    )
    mkdir $output_directory

    if ($files | is-empty) {
        log error "No files provided"
        exit 1
    }

    for original_file in $files {

    log info $"Importing the file (ansi purple)($original_file)(ansi reset)"

    let temporary_directory = (mktemp --directory)
    log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

    let audible_activation_bytes = (
        if $audible_activation_bytes != null {
            $audible_activation_bytes
        } else if "AUDIBLE_ACTIVATION_BYTES" in $env {
            $env.AUDIBLE_ACTIVATION_BYTES
        } else {
            null
        }
    )

    try {

    let file = (
        if ($original_file | str starts-with "minio:") {
            let file = ($original_file | str replace "minio:" "")
            ^mc cp $file $"($temporary_directory)/($file | path basename)"
            [$temporary_directory ($file | path basename)] | path join
        } else {
            cp $original_file $temporary_directory
            [$temporary_directory ($original_file | path basename)] | path join
        }
    )

    let input_format = ($file | path parse | get extension)

    let audiobook = (
        # Assume AAX files are from Audible and require decryption.
        if $input_format == "aax" {
            if $audible_activation_bytes == null {
                log error "Audible activation bytes must be provided to decrypt Audible audiobooks"
                exit 1
            }
            $file
            | decrypt_audible $activation_bytes --working-directory $temporary_directory
            | beet_import $beets_config $beets_library
            | (
                let i = $in;
                {
                    m4b: $i.m4b,
                    cover: ($i.cover | optimize_cover)
                }
            ) | embed_cover
        } else if $input_format in ["m4a", "m4b"] {
            $file
            | beet_import $beets_config $beets_library
            | (
                let i = $in;
                {
                    m4b: $i.m4b,
                    cover: ($i.cover | optimize_cover)
                }
            ) | embed_cover
        } else if $input_format == [null, "zip"] {
            # todo Support importing zip files and directories containing mp3 files using m4b-tool
        } else {
            log error $"Unsupported input file type (ansi red_bold)($input_format)(ansi reset)"
            exit 1
        }
    )

    # log debug $"Fetching and writing metadata to '($formats.cbz)' with ComicTagger"
    # log debug $"The ComicTagger result is:\n(ansi green)($tag_result.result)(ansi reset)\n"
    # log debug "Renaming the CBZ according to the updated metadata"

    # let formats = $formats | (
    #     let format = $in;
    #     $format | update cbz ($format.cbz | comictagger_rename_cbz --comictagger $comictagger)
    # )

    # let comic_metadata = ($tag_result.result | get md)

    # Authors are considered to be creators with the role of "Writer" in the ComicVine metadata
    # let authors = ($comic_metadata | get credits | where role == "Writer" | get person)
    # log debug $"Authors determined to be (ansi purple)'($authors)'(ansi reset)"

    let authors_subdirectory = ($audiobook.m4b | path dirname | path relative-to $working_directory | path split | drop nth 0 | path join)
    let minio_target_directory =  [$minio_alias $minio_path $authors_subdirectory] | path join | sanitize_minio_filename
    let minio_target_destination = (
        let components = ($audiobook.m4b | path parse);
        { parent: $minio_target_directory, stem: $components.stem, extension: $components.extension } | path join | sanitize_minio_filename
    )
    if $skip_upload {
        mv $audiobook.m4b $output_directory
    } else {
        log info $"Uploading (ansi yellow)($audiobook.m4b)(ansi reset) to (ansi yellow)($minio_target_destination)(ansi reset)"
        ^mc mv $audiobook.m4b $minio_target_destination
    }

    if $delete {
        log debug "Deleting the original file"
        if ($original_file | str starts-with "minio:") {
            let actual_path = ($original_file | str replace "minio:" "")
            if ($actual_path | sanitize_minio_filename) == $minio_target_destination {
                log info $"Not deleting the original file (ansi yellow)($original_file)(ansi reset) since it was overwritten by the updated file"
            } else {
                log info $"Deleting the original file on MinIO (ansi yellow)($actual_path)(ansi reset)"
                ^mc rm $actual_path
            }
        } else {
            log info $"Deleting the original file (ansi yellow)($original_file)(ansi reset)"
            rm $original_file
        }
    }
    log debug $"Removing the working directory (ansi yellow)($temporary_directory)(ansi reset)"
    rm --force --recursive $temporary_directory

    } catch {
        log error $"Import of (ansi red)($original_file)(ansi reset) failed!"
        continue
    }

    }
}