---
name: voacap
description: Run HF (shortwave) radio propagation predictions between two locations using the VOACAP engine (voacapl, cloned/built from jawatson/voacapl). Use when the user asks about HF/shortwave propagation, best frequency/band for a radio circuit, MUF/LUF, signal reliability or SNR between two points, or to "run a VOACAP/voacapl prediction".
---

# VOACAP propagation prediction

This skill runs point-to-point HF propagation predictions using `voacapl`
(the Linux/GFortran port of NTIA/ITS VOACAP, https://github.com/jawatson/voacapl),
and reports predicted circuit reliability (REL) and signal-to-noise ratio
(SNR) per hour and per frequency between a transmitter and receiver
location.

## One-time setup

`voacapl` must be cloned+built and `~/itshfbc` (its data directory) must be
initialized before predictions can run.

```
scripts/setup.sh
```

This clones `jawatson/voacapl` into `vendor/voacapl` (skipped if already
present), builds it into `<repo>/local/` via the normal
`configure && make && make install` cycle (skipped if `voacapl` is already
built or on `PATH`), and runs `makeitshfbc` to populate `~/itshfbc` (skipped
if already done). Safe to re-run. Requires `git`, `gfortran`, `automake`,
and `autoreconf` on the system.

## Running a prediction

```
python3 scripts/voacap_predict.py \
  --tx-name "London" --tx-lat 51.5 --tx-lon -0.13 \
  --rx-name "New York" --rx-lat 40.7 --rx-lon -74.0 \
  --month 9 --ssn 60 \
  --freqs 7.1 14.2 21.2
```

Prints a table with one row per UTC hour (0-24), the best-performing
frequency in that hour, and REL/SNR for every frequency tried. Pass `--json`
for structured output instead.

Required arguments: `--tx-name/--tx-lat/--tx-lon`, `--rx-name/--rx-lat/--rx-lon`,
`--month` (1-12), `--freqs` (up to 11 frequencies in MHz). Longitude is
signed: positive = East, negative = West.

Key optional arguments (defaults shown):
- `--year` (current year), `--ssn 100` (sunspot number — ask the user for a
  current/forecast value, or note that 100 is just a placeholder; this
  script does not fetch space-weather data itself)
- `--day-fraction 0.0` — 0.0 requests VOACAP's monthly-median prediction
  (the normal case). A specific day-of-month can be requested but is rarely
  needed.
- `--hours 1 24` and `--lmt` — hour range and UTC (default) vs. local-mean-time
- `--tx-power-kw 0.1`, `--tx-antenna`/`--rx-antenna` (paths relative to
  `itshfbc/antennas/`, default to the generic `default/const17.voa` transmit
  / `default/swwhip.voa` receive pair shipped with voacapl — swap these out
  when the user cares about a specific real antenna)
- `--req-reliability 50`, `--req-snr 24` (typical SSB voice threshold),
  `--noise 145` (man-made noise; magnitude of dBW at 3 MHz — 145=quiet/suburban,
  150=quiet rural, 164=remote, 140.4=residential), `--min-angle 3`
  (minimum radiation takeoff angle in degrees)
- `--itshfbc PATH` if the data directory isn't at `~/itshfbc`

Each run writes a uniquely-named input/output file pair under
`itshfbc/run/` and deletes them afterwards unless `--keep-files` is passed
(useful for inspecting the raw VOACAP output, e.g. to answer questions this
skill's summary doesn't cover, such as MUF or takeoff angle detail).

## Notes for interpreting results

- REL (reliability) is the predicted fraction of days in the month the
  circuit meets the required SNR, 0-1. Above ~0.7-0.8 is generally
  considered a solid/reliable circuit; below ~0.3 is marginal-to-unusable.
- When asked "what's the best band/frequency", scan across the hour range
  the user cares about and report the frequency with the highest REL (and
  SNR as a tiebreaker) per hour — the script's default table already does
  this per hour.
- This is a monthly-median statistical model, not a real-time forecast: it
  reflects typical ionospheric conditions for the given month/SSN, not
  today's actual space weather.
- If the user gives a date, convert it to `--month`/`--year` and a
  reasonable `--ssn` (look one up or ask if precision matters); this skill
  does not do that conversion itself.
