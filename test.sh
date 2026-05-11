#!/bin/sh
# One-packet budget guard.
#
# The pitch of this site: the whole HTTP response fits in the first TCP segment,
# so the page arrives in a single round trip after the handshake — no slow-start
# ramp, no second flight. A typical segment carries MSS ≈ 1460 bytes. Response
# headers (status line + ~10 headers) eat ~360 of those, so the gzipped HTML body
# gets a hard budget of ~1100 bytes. This test fails if we blow it — or if a
# build step / external resource sneaks back in.
#
# Usage: sh test.sh   (zero dependencies: sh, gzip, wc, grep)

set -eu
cd "$(dirname "$0")"

MSS=1460
HEADERS_EST=360
BUDGET_GZIP=$(( MSS - HEADERS_EST ))   # 1100

fail=0
note() { echo "FAIL: $*"; fail=1; }

raw=$(wc -c < index.html)
gz=$(gzip -9 -c index.html | wc -c)
echo "index.html: ${raw} B raw -> ${gz} B gzip   (budget ${BUDGET_GZIP} B, segment ${MSS} B)"

[ "$gz" -le "$BUDGET_GZIP" ] || note "gzipped body ${gz} B exceeds ${BUDGET_GZIP} B — won't fit one segment with headers"

# the card must actually contain its essentials
for needle in \
  '<title>Leonid Zharikov</title>' \
  'rel="canonical" href="https://farwydi.dev"' \
  'cdn.farwydi.dev/CV-Leonid-Zharikov-EU.pdf' \
  'github.com/farwydi' \
  't.me/farwydi' \
  'linkedin.com/in/farwydi'
do
  grep -qF "$needle" index.html || note "missing in index.html: $needle"
done

# the page must be self-contained — every external ref is another round trip
grep -qiE '<script' index.html              && note "page references a <script> — should be zero JS"
grep -qiE '<link[^>]+stylesheet' index.html && note "page links an external stylesheet — CSS must be inlined"

# no build step / deps allowed back into the repo
for f in package.json package-lock.json node_modules vite.config.js tailwind.config.js postcss.config.js dist; do
  [ -e "$f" ] && note "$f reappeared — this site has no build step"
done

if [ "$fail" -eq 0 ]; then
  echo "OK — one segment, one round trip, self-contained, content intact"
fi
exit "$fail"
