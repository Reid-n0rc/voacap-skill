#!/bin/sh
# Smoke-tests the skill and the underlying voacapl CLI against whatever
# build setup.sh last produced. Intended to run after setup.sh, in CI and
# locally. Exits non-zero on failure.
#
# Covers:
#   - the skill's own prediction script (voacap_predict.py)
#   - every voacapl CLI form documented in its man page:
#       voacapl -v
#       voacapl <itshfbc>                          (default in/out files)
#       voacapl <itshfbc> <infile> <outfile>        (explicit in/out files)
#       voacapl --run-dir=<dir> <itshfbc> ...        (run-dir override)
#       voacapl --absorption-mode=<mode> <itshfbc> ... (absorption mode)
#       voacapl <itshfbc> area calc <areafile>       (area calculation)
#       voacapl <itshfbc> batch                      (batch circuits)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PREDICT="$SCRIPT_DIR/voacap_predict.py"

fail() {
    echo "TEST FAILED: $1" >&2
    exit 1
}

VOACAPL_BIN="$(command -v voacapl || true)"
if [ -z "$VOACAPL_BIN" ] && [ -x "$REPO_ROOT/local/bin/voacapl" ]; then
    VOACAPL_BIN="$REPO_ROOT/local/bin/voacapl"
fi
[ -n "$VOACAPL_BIN" ] || fail "could not find the voacapl binary"

ITSHFBC="${VOACAP_ITSHFBC:-$HOME/itshfbc}"
[ -d "$ITSHFBC/run" ] || fail "run directory not found: $ITSHFBC/run (has makeitshfbc been run?)"

require_end_of_run() {
    grep -q "END OF RUN" "$1" || fail "$1 is missing the expected END OF RUN marker"
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

echo "== Test 4: voacapl -v prints a version =="
"$VOACAPL_BIN" -v 2>&1 | grep -qi "release\|version" \
    || fail "voacapl -v did not print a version string"

echo "== Test 5: voacapl <itshfbc> (default input/output files) =="
"$VOACAPL_BIN" -s "$ITSHFBC" || fail "default-args invocation failed"
require_end_of_run "$ITSHFBC/run/voacapx.out"

echo "== Test 6: voacapl <itshfbc> <infile> <outfile> (explicit filenames) =="
cp "$ITSHFBC/run/voacapx.dat" "$ITSHFBC/run/cli_test_in.dat"
"$VOACAPL_BIN" -s "$ITSHFBC" cli_test_in.dat cli_test_out.out \
    || fail "explicit in/out filenames invocation failed"
require_end_of_run "$ITSHFBC/run/cli_test_out.out"
rm -f "$ITSHFBC/run/cli_test_in.dat" "$ITSHFBC/run/cli_test_out.out"

echo "== Test 7: voacapl --run-dir=<dir> ... =="
RUNDIR=$(mktemp -d)
cp "$ITSHFBC/run/voacapx.dat" "$RUNDIR/rundir_test.dat"
"$VOACAPL_BIN" -s "--run-dir=$RUNDIR" "$ITSHFBC" rundir_test.dat rundir_test.out \
    || { rm -rf "$RUNDIR"; fail "--run-dir invocation failed"; }
require_end_of_run "$RUNDIR/rundir_test.out"
rm -rf "$RUNDIR"

echo "== Test 8: voacapl --absorption-mode=<mode> ... =="
for MODE in W I A a; do
    cp "$ITSHFBC/run/voacapx.dat" "$ITSHFBC/run/absorb_test.dat"
    "$VOACAPL_BIN" -s "--absorption-mode=$MODE" "$ITSHFBC" absorb_test.dat absorb_test.out \
        || fail "--absorption-mode=$MODE invocation failed"
    require_end_of_run "$ITSHFBC/run/absorb_test.out"
    rm -f "$ITSHFBC/run/absorb_test.dat" "$ITSHFBC/run/absorb_test.out"
done

echo "== Test 9: voacapl <itshfbc> area calc <areafile> =="
rm -f "$ITSHFBC/areadata/default/default.vg1"
"$VOACAPL_BIN" -s "$ITSHFBC" area calc default/default.voa \
    || fail "area calc invocation failed"
[ -f "$ITSHFBC/areadata/default/default.vg1" ] \
    || fail "area calc did not produce the expected default.vg1 output"
rm -f "$ITSHFBC/areadata/default/default.vg1"

echo "== Test 10: voacapl <itshfbc> batch =="
echo "(voacapl=$VOACAPL_BIN itshfbc=$ITSHFBC)"
BATCH_LOG=$(mktemp)
BATCH_OK=0
for ATTEMPT in 1 2; do
    set +e
    "$VOACAPL_BIN" -s "$ITSHFBC" batch > "$BATCH_LOG" 2>&1
    BATCH_RC=$?
    set -e
    echo "(attempt $ATTEMPT: batch exit=$BATCH_RC, $(wc -l < "$BATCH_LOG" | tr -d ' ') lines of output)"
    if [ "$BATCH_RC" -eq 0 ] && grep -q "Batch processing for VOACAP is complete" "$BATCH_LOG"; then
        BATCH_OK=1
        break
    fi
    echo "attempt $ATTEMPT did not complete as expected; output was:"
    cat "$BATCH_LOG"
done
[ "$BATCH_OK" -eq 1 ] || { rm -f "$BATCH_LOG"; fail "batch invocation failed twice in a row"; }
rm -f "$BATCH_LOG"

echo "All voacap skill and voacapl CLI smoke tests passed."
