# Contributing

- Do development work on `dev` (or a feature branch cut from it), never
  directly on `main`.
- `main` is protected: it only changes via pull request, and a PR can only
  merge once the CI workflow (build voacapl + run the skill's smoke tests)
  passes.
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
