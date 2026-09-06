# voacap-skill

A Claude Code skill for running HF (shortwave) radio propagation
predictions using [VOACAP](https://www.voacap.com/), via the
[voacapl](https://github.com/jawatson/voacapl) Linux/GFortran port.

**[reid-n0rc.github.io/voacap-skill](https://reid-n0rc.github.io/voacap-skill/)**
&mdash; what it is, how to install it, and fun things to try.

The skill lives in `.claude/skills/voacap/`. It clones and builds
`voacapl` on demand (see `setup.sh`) rather than vendoring the engine's
source in this repo, so it stays in sync with upstream.

See [`.claude/skills/voacap/SKILL.md`](.claude/skills/voacap/SKILL.md) for
usage.

## Quick start

```
.claude/skills/voacap/scripts/setup.sh
python3 .claude/skills/voacap/scripts/voacap_predict.py \
  --tx-name "London" --tx-lat 51.5 --tx-lon -0.13 \
  --rx-name "New York" --rx-lat 40.7 --rx-lon -74.0 \
  --month 9 --ssn 60 --freqs 7.1 14.2 21.2
```

Requires `git`, `gfortran`, `automake`, and `autoreconf`.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md): work happens on `dev`/feature
branches, `main` is PR-only and CI-gated, and the skill tracks the latest
`jawatson/voacapl` release (checked daily; see
`.github/workflows/check-upstream-release.yml`).
