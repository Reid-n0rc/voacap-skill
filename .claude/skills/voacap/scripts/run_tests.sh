#!/bin/sh
# Smoke-tests the skill against whatever voacapl build setup.sh last produced.
# Intended to run after setup.sh, in CI and locally. Exits non-zero on failure.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREDICT="$SCRIPT_DIR/voacap_predict.py"

fail() {
    echo "TEST FAILED: $1" >&2
    exit 1
}

echo "== Test 1: London -> New York, basic run produces a parseable, sane result =="
OUT=$(python3 "$PREDICT" \
    --tx-name "London" --tx-lat 51.5 --tx-lon -0.13 \
    --rx-name "New York" --rx-lat 40.7 --rx-lon -74.0 \
    --month 9 --ssn 60 --freqs 7.1 14.2 21.2 --json)

python3 - "$OUT" <<'EOF'
import json, sys
data = json.loads(sys.argv[1])
hours = data["hours"]
assert len(hours) == 24, f"expected 24 hourly blocks, got {len(hours)}"
rels = [e["rel"] for h in hours for e in h["freqs"] if e["rel"] is not None]
assert rels, "no REL values were parsed at all"
assert any(0.0 <= r <= 1.0 for r in rels), "no REL value fell in the expected 0-1 range"
assert any(r > 0.3 for r in rels), "no hour/frequency produced a plausible non-trivial REL"
print(f"OK: {len(hours)} hours, {len(rels)} REL samples, max REL={max(rels):.2f}")
EOF

echo "== Test 2: antipodal-ish long path (Sydney -> Cape Town) still runs cleanly =="
python3 "$PREDICT" \
    --tx-name "Sydney" --tx-lat -33.87 --tx-lon 151.2 \
    --rx-name "Cape Town" --rx-lat -33.9 --rx-lon 18.4 \
    --month 12 --ssn 80 --freqs 10.1 14.1 18.1 24.9 --json > /dev/null \
    || fail "long-path prediction did not complete"

echo "== Test 3: a full 11-frequency request is accepted =="
python3 "$PREDICT" \
    --tx-name "Tokyo" --tx-lat 35.7 --tx-lon 139.7 \
    --rx-name "Nairobi" --rx-lat -1.3 --rx-lon 36.8 \
    --month 3 --ssn 90 \
    --freqs 3.5 5.3 7.1 9.4 12.1 15.2 18.1 21.2 24.9 28.3 29.7 --json > /dev/null \
    || fail "11-frequency prediction did not complete"

echo "All voacap skill smoke tests passed."
