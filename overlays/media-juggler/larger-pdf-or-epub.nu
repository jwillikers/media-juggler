#!/usr/bin/env nu

# A script to compare file sizes between EPUB and PDF files and choose the one that is larger by a decent percentage
def main [
    directory: directory # The directory containing the files to compare
]: {
    (
    glob *.{pdf}
    | sort
    | where {||
        $in
        | path parse
        | update extension "epub"
        | path join
        | path exists
    }
    | each {|f|
        {
            pdf: $f,
            pdf_size: (ls $f | get size | first),
            epub: ($f | path parse | update extension "epub" | path join)
            epub_size: (
                ls ($f | path parse | update extension "epub" | path join)
                | get size
                | first
            )
        }
    } | each {|f|
        let average = (($f.pdf_size + $f.epub_size) / 2)
        let min = [$f.pdf_size $f.epub_size] | math min
        let max = [$f.pdf_size $f.epub_size] | math max
        let percent_difference = ((($max - $min) / $average) * 100)
        $f
        | insert difference ($max - $min)
        | insert percent_difference $percent_difference
    }
    | sort-by --reverse difference
    # Comment out after here to see the size comparisons.
    | each {|f|
        if $f.percent_difference < 5 {
            [$f.epub]
        } else if $f.pdf_size > $f.epub_size {
            [$f.pdf]
        } else {
            [$f.epub]
        }
    }
    | flatten
    )
}
