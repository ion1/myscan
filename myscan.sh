#!/bin/bash

# myscan – a simple document scanner
#
# Copyright © 2013 Johan Kiviniemi <devel@johan.kiviniemi.name>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -eu

set -o pipefail  # bashism

TEXTDOMAIN=myscan
export TEXTDOMAIN

for arg; do
  case "$arg" in
    -*)
      >&2 printf "USAGE: %s [FILENAME.pdf]\n" "$0"
      exit 1
      ;;
  esac
done

programs_exist=true
for f in gettext.sh mktemp zenity scanimage gawk convert unpaper pdftk; do
  if ! >/dev/null 2>&1 type "$f"; then
    >&2 printf "Missing program: %s\n" "$f"
    programs_exist=false
  fi
done
"$programs_exist"

set +u
. gettext.sh
set -u

res=300
res_low=100
mode=Color

dir="$(xdg-user-dir DOCUMENTS 2>/dev/null || :)"
dir="${dir:-$HOME}"

if [ "$#" -gt 0 ]; then
  output_file="$1"
else
  output_file="$dir/scan-$(date +%Y%m%d-%H%M%S).pdf"
  output_file="$(
    zenity --file-selection --save --confirm-overwrite \
           --title="$(gettext 'Scan to file')" --filename="$output_file" \
           --file-filter="*.pdf"
  )"
fi

case "$output_file" in
  "") exit ;;
  *.[Pp][Dd][Ff]) ;;
  *) output_file="$output_file.pdf" ;;
esac

base="${output_file%.[Pp][Dd][Ff]}"

output_low_file="$base.low.pdf"

temp_dir="$(mktemp -d "$base.temp-XXXXXXXXXX")"

log_file="$temp_dir/myscan-log.txt"
exec >"$log_file" 2>&1
trap 'if [ "$?" != 0 ] && [ -e "$log_file" ]; then
        zenity --error \
               --text="$(gettext "Sorry, scanning failed. Opening log.")" || :
        gedit --wait "$log_file" || :
      fi
      rm -fr "$temp_dir"
     ' 0 1 2 13 15
set -x

page=0
more_pages=true
pages_file="$temp_dir/pages"
pages_low_file="$temp_dir/pages.low"

children=

while "$more_pages"; do
  page="$(($page+1))"

  scan_pnm="$temp_dir/$page.scan.pnm"
  contrast_pnm="$temp_dir/$page.contrast.pnm"
  unpaper_pnm="$temp_dir/$page.unpaper.pnm"
  scan_pdf="$temp_dir/$page.processed.pdf"
  scan_low_pdf="$temp_dir/$page.processed.low.pdf"

  >>"$pages_file"     printf "%s\n" "$scan_pdf"
  >>"$pages_low_file" printf "%s\n" "$scan_low_pdf"

  LC_ALL=C scanimage --resolution "$res" --mode "$mode" \
                     --compression None --progress 2>&1 >"$scan_pnm" | \
    (gawk 'BEGIN { RS="[\r\n]" }
           match($0, /^Progress: ([0-9]+\.[0-9]+)%$/, m) {
             print m[1]; fflush()
           }
           { print $0 >"/dev/stderr" }
          ' || :) | \
    (zenity --progress --text="$(eval_gettext 'Scanning page $page')" \
            --auto-close --no-cancel || :)

  (
    convert -verbose "$scan_pnm" -level "20%,80%" "$contrast_pnm"
    rm -f "$scan_pnm"
    unpaper --dpi "$res" --no-noisefilter --no-blurfilter --no-grayfilter \
            --no-deskew --overwrite -v "$contrast_pnm" "$unpaper_pnm"
    rm -f "$contrast_pnm"
    convert -verbose -units PixelsPerInch -density "$res" "$unpaper_pnm" \
            -compress Zip "$scan_pdf"
    convert -verbose -units PixelsPerInch -density "$res" "$unpaper_pnm" \
            -resample "$res_low" -density "$res_low" \
            -compress JPEG -quality '75%' "$scan_low_pdf"
    rm -f "$unpaper_pnm"
  ) &
  children="${children:+$children }$!"

  if ! zenity --question \
              --text="$(gettext 'Scan another page to the same document?')"
  then
    more_pages=false
  fi
done

for c in $children; do
  wait "$c"
done

xargs -a "$pages_file" -d "\n" -x \
  sh -euc 'o="$1"; shift; pdftk "$@" output "$o"' -- "$output_file"

xargs -a "$pages_low_file" -d "\n" -x \
  sh -euc 'o="$1"; shift; pdftk "$@" output "$o"' -- "$output_low_file"

</dev/null >/dev/null 2>&1 setsid xdg-open "$output_file" &

# vi:set et sw=2 sts=2:
