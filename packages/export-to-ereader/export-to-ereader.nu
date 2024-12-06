#!/usr/bin/env nu

use std log

let ereader_profiles = [
    [model height width volume];
    ["Kobo Elipsa 2E" 1872 1404 "KOBOeReader"]
]

# Losslessly optimize images
export def optimize_images []: [list<path> -> record] {
    let paths = $in
    # Ignore config paths to ensure that lossy compression is not enabled.
    log debug $"Running command: (ansi yellow)image_optim --config-paths \"\" --recursive ($paths | str join ' ')(ansi reset)"
    let result = ^image_optim --config-paths "" --recursive ...$paths | complete
    if ($result.exit_code != 0) {
        log error $"Exit code ($result.exit_code) from command: (ansi yellow)image_optim --config-paths \"\" --recursive ($paths)(ansi reset)\n($result.stderr)\n"
        return null
    }
    (
        $result.stdout
        | lines --skip-empty
        | last
        | (
            let line = $in;
            if "------" in $line {
                { difference: 0, bytes: 0 }
            } else {
                $line
                | parse --regex 'Total:\W+(?P<difference>.+)%\W+(?P<bytes>.+)'
                | first
            }
        )
    )
}

# Losslessly optimize the images in a ZIP archive such as an EPUB or CBZ
export def optimize_images_in_zip []: [path -> path] {
    let archive = ($in | path expand)
    log debug $"Optimizing images in (ansi yellow)($archive)(ansi reset)"
    let temporary_directory = (mktemp --directory)
    let extraction_path = ($temporary_directory | path join "extracted")
    log debug $"Extracting zip archive to (ansi yellow)($extraction_path)(ansi reset)"
    ^unzip -q $archive -d $extraction_path
    let reduction = [$extraction_path] | optimize_images
    log info $"The archive (ansi yellow)($archive)(ansi reset) was reduced by (ansi purple_bold)($reduction.bytes)(ansi reset), a (ansi purple_bold)($reduction.difference)%(ansi reset) reduction in size"
    log debug $"Compressing directory (ansi yellow)($extraction_path)(ansi reset) as (ansi yellow)($archive)(ansi reset)"
    cd $extraction_path
    ^zip --quiet --recurse-paths $archive .
    cd -
    rm --force --recursive $temporary_directory
    $archive
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

# Convert a copy for my primary e-reader:
# Kobo Elipsa 2E: 1404x1872 (Gamma 1.8).
# todo I'm not sure this is even really necessary
# Using the correct resolution does seem to result in much faster page loads.
# Although, maybe that's due to using webp?
# I should verify.
export def convert_for_ereader [
    suffix: string # Suffix to add to the CBZ filename
    --format: string # The image format to convert to
    --height: string # The height of the converted images
    --quality: string # The quality setting to use for the encoder
    --width: string # The width of the converted images
]: [path -> path] {
    let cbz = $in
    let components = ($cbz | path parse)
    # todo Use some sort of wrapper to print out command-line of command being run?
    # log debug $"Running command: cbconvert --filter 7 --format ($format) --height ($height) --outdir ($components.parent) --quality ($quality) --suffix ($suffix) --width ($width) ($cbz)"
    (
        ^cbconvert convert
            # --filter 7 # Use the highest quality resampling filter.
            --filter 4 # Tried 0, 1, 2, 3, 4, 5, 6, 7
            --fit
            --format $format
            --height $height
            --outdir $components.parent
            --quality $quality
            --suffix $suffix
            --width $width
            $cbz
    )
    $components | update stem ($components.stem + $suffix) | path join
}

# Convert a comic for an e-reader
def main [
    ereader: string # Create a copy of the comic book optimized for this specific e-reader, i.e. "Kobo Elipsa 2E"
    ...files: path # The paths to CBZ files to convert for the ereader. Prefix paths with "minio:" to download them from the MinIO instance
    --ereader-subdirectory: string = "Books/Manga" # The subdirectory on the e-reader in-which to copy
    --no-copy-to-ereader # Don't copy the E-Reader specific format to a mounted e-reader
    --output-directory: directory # Directory to place files when not being uploaded
    --skip-image-optimization # Don't attempt to optimize the size of the image files with image_optim
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

    if not $no_copy_to_ereader {
      if (^findmnt --target /run/media/jordan/KOBOeReader | complete | get exit_code) != 0 {
        ^udisksctl mount --block-device /dev/disk/by-label/KOBOeReader --no-user-interaction
        # todo Parse the mountpoint from the output of this command
      }
    }

    for original_file in $files {

    log info $"Importing the file (ansi purple)($original_file)(ansi reset)"

    let temporary_directory = (mktemp --directory --tmpdir-path ~/.cache)
    log info $"Using the temporary directory (ansi yellow)($temporary_directory)(ansi reset)"

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
    if $input_format != "cbz" {
        log error "Unsupported format. Only CBZ files are supported!"
    }

    let image_format = ($file | get_image_extension)
    if $image_format == null {
        log error "Failed to determine the image file format"
        exit 1
    }

    # todo Detect if another lossless format, i.e. webp, is being used and if so, convert those to jxl as well.
    # if $image_format in ["png"] {
    #     $file | convert_to_lossless_jxl
    # }

    # Use PNG for lossless codecs and jpeg for lossy.
    let ereader_cbz = (
        # Don't convert or use KCC because it won't look right when converting jpegs with cbconvert 1.1.0.
        if $image_format in ["jpeg" "jpg"] {
            (
                let components = ($file | path parse);
                let temp = (
                    {
                        parent: ($env.HOME + "/Downloads"),
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
                        stem: ($components.stem + "_kobo_elipsa_2e"),
                        extension: $components.extension
                    }
                    | path join
                );
                (^flatpak run --command=kcc-c2e io.github.ciromattia.kcc --profile KoE --manga-style --forcecolor --format CBZ --output $temp --targetsize 10000 --upscale $temp);
                mv $kcc_output $output;
                rm $temp;
                $output
            )
        } else {
            (
                $file
                | convert_for_ereader ("_" + ($ereader | str replace --all " " "_" | str downcase))
                --format (if $image_format in [ "avif", "jxl", "png", ] { "png" } else { "jpeg" })
                # --format "png"
                --height ($ereader_profiles | where model == $ereader | first | get height)
                --quality 100
                # --quality (if $image_format in [ "avif", "jxl", "png", ] { 100 } else { 80 })
                --width ($ereader_profiles | where model == $ereader | first | get width)
            )
        }
    )

    if not $skip_image_optimization {
      $ereader_cbz | optimize_images_in_zip
    }

    if $no_copy_to_ereader {
        mv $ereader_cbz $output_directory
    } else {
        let username = (^id --name --user)
        let mounted_volume_name = ($ereader_profiles | where model == $ereader | first | get volume)
        mkdir (["/run/media" $username $mounted_volume_name $ereader_subdirectory] | path join)
        let safe_basename = (($ereader_cbz | path basename) | str replace --all ":" "_")
        let target = (["/run/media" $username $mounted_volume_name $ereader_subdirectory $safe_basename] | path join)
        log info $"Copying (ansi yellow)($ereader_cbz)(ansi reset) to (ansi yellow)($target)(ansi reset)"
        cp $ereader_cbz $target
    }

    rm --force --recursive $temporary_directory

    } catch {
        log error $"Conversion of (ansi red)($original_file)(ansi reset) failed!"
        continue
    }

    }

    if not $no_copy_to_ereader {
      if (^findmnt --target /run/media/jordan/KOBOeReader | complete | get exit_code) == 0 {
        ^udisksctl unmount --block-device /dev/disk/by-label/KOBOeReader --no-user-interaction
      }
    }
}
