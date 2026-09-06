# Contributing

- Do development work on `dev` (or a feature branch cut from it), never
  directly on `main`.
- `main` is protected: it only changes via pull request, and a PR can only
  merge once the CI workflow (build voacapl + run the skill's smoke tests)
  passes.
- `run_tests.sh` covers the skill's own prediction script plus every
  documented `voacapl` CLI form (`-v`, default and explicit in/out files,
  `--run-dir`, all `--absorption-mode` values, `area calc`, and `batch`).
- The skill always builds against the **latest GitHub release** of
  [jawatson/voacapl](https://github.com/jawatson/voacapl), not a specific
  commit — `setup.sh` resolves "latest" at run time. Pass `--release <tag>`
  to pin/test against a specific one.
- Signed commits are preferred but not required (branch protection does not
  enforce `required_signatures`).
- A daily scheduled workflow
  (`.github/workflows/check-upstream-release.yml`) checks whether upstream
  has published a new release; if so it builds and smoke-tests against it
  and, if that fails, opens a GitHub issue assigned to `Reid-n0rc` labeled
  `upstream-regression`.
- On Windows there's no source build: `install.ps1` / `setup.ps1` install
  the native NTIA/ITS Windows VOACAP engine (`voacapw.exe`) from a pinned
  installer snapshot (see `setup.ps1`'s `-InstallerUrl` default) instead.
  `voacap_predict.py`'s `find_engine()` picks `voacapl` vs. `voacapw.exe`
  based on `sys.platform`. Since that installer isn't a versioned release
  feed, a second daily workflow
  (`.github/workflows/check-windows-engine.yml`) just re-runs the full
  install+prediction smoke test against `main` and files an issue labeled
  `windows-engine-regression` on failure, to catch the pinned mirror
  moving or changing.
