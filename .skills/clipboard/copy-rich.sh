#!/usr/bin/env bash
# Copy Markdown from stdin to the macOS clipboard as rich text (HTML) with the Markdown as the plain-text fallback.
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/plain.md"
pandoc --from gfm --to html --wrap none --syntax-highlighting=none "$tmp/plain.md" -o "$tmp/rich.html"

osascript -l JavaScript - "$tmp/rich.html" "$tmp/plain.md" <<'JXA'
ObjC.import('AppKit');
function run(argv) {
  const read = (path) => $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  const pb = $.NSPasteboard.generalPasteboard;
  pb.clearContents;
  pb.setStringForType(read(argv[0]), $.NSPasteboardTypeHTML);
  pb.setStringForType(read(argv[1]), $.NSPasteboardTypeString);
}
JXA
