#!/bin/sh
# How fast does the card arrive?
#
# Two parts:
#   1) bytes on the wire — raw / gzip / brotli, the estimated HTTP response,
#      and how many TCP segments that takes (the number that decides whether
#      it's one round trip or several).
#   2) a loopback fetch loop — serves the file locally and times TTFB / total
#      over a handful of requests. Loopback has no real RTT, so this measures
#      server parse + IO overhead, not network latency; the wire-size figure
#      above is what governs real-world first-paint.
#
# Usage: sh bench.sh   (deps: sh, gzip, wc; optional: brotli, python3, curl)

set -eu
cd "$(dirname "$0")"

f=index.html
MSS=1460
HEADERS_EST=360

raw=$(wc -c < "$f")
gz=$(gzip -9 -c "$f" | wc -c)

printf '%-26s %6d B\n'            'raw'           "$raw"
printf '%-26s %6d B   %3d%% of raw\n' 'gzip -9'  "$gz" "$(( gz * 100 / raw ))"
if command -v brotli >/dev/null 2>&1; then
  br=$(brotli -q 11 -c "$f" | wc -c)
  printf '%-26s %6d B   %3d%% of raw\n' 'brotli -q11' "$br" "$(( br * 100 / raw ))"
  body=$br
else
  body=$gz
fi

resp=$(( body + HEADERS_EST ))
segs=$(( (resp + MSS - 1) / MSS ))
printf '%-26s %6d B   (body + ~%d B headers)\n' 'est. HTTP response' "$resp" "$HEADERS_EST"
printf '%-26s %6d\n' "TCP segments (MSS ${MSS})" "$segs"
if [ "$resp" -le $(( MSS * 10 )) ]; then
  printf '%-26s %s\n' 'verdict' "fits the initial congestion window — 1 round trip"
else
  printf '%-26s %s\n' 'verdict' "needs $(( (resp + MSS*10 - 1) / (MSS*10) )) round trip(s) before slow-start ramps"
fi

# loopback timing — only if we can actually serve + curl
if command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  port=8731
  python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 &
  pid=$!
  trap 'kill "$pid" 2>/dev/null || true' EXIT
  # wait for it to come up
  i=0; while [ "$i" -lt 30 ]; do curl -s -o /dev/null "http://127.0.0.1:$port/$f" && break; i=$((i+1)); sleep 0.1; done
  echo
  echo "loopback fetch  http://127.0.0.1:$port/$f  (10x, http.server sends it uncompressed):"
  i=0
  while [ "$i" -lt 10 ]; do
    curl -s -o /dev/null \
      -w '  ttfb=%{time_starttransfer}s  total=%{time_total}s  down=%{size_download}B\n' \
      "http://127.0.0.1:$port/$f"
    i=$(( i + 1 ))
  done
else
  echo
  echo "(install python3 + curl for the loopback timing loop)"
fi
