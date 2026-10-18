# 0011 — No continuous integration

- **Status**: accepted
- **Date**: 2026-10-18
- **Supersedes**: the CI secret-scanning consequence of [0008](0008-open-source-configuration.md)

## Context
[ADR 0008](0008-open-source-configuration.md) assumed a CI pipeline would scan
commits for secrets, and the contributor guide promised that tests run on every
pull request. The project owner does not want CI to run at all.

A gliding club's maintenance-hours app is also a small, slow-moving codebase
with a single maintainer. The things CI would guard — do the tests pass, did a
token slip into a commit — are things that happen on a laptop a few seconds
before the push.

## Decision
The repository has no CI: no GitHub Actions, no workflow files, no automated
checks on push or on pull requests.

The guarantees stay, enforced by the maintainer instead of by a runner:

- Tests pass before anything is merged. `xcodegen generate` and then the Winter
  scheme's tests, locally.
- No secrets in commits. The rule is in [SECURITY.md](../../SECURITY.md) and
  [CONTRIBUTING.md](../../CONTRIBUTING.md), and the review is a human reading
  the diff.
- The documentation is updated in the same change as the behaviour
  ([CLAUDE.md](../../CLAUDE.md)).

## Consequences
- A contributor's pull request is not checked automatically; the maintainer runs
  the tests before merging, and says so in the review.
- A leaked secret is caught by review or not at all, which makes the
  revoke-first advice in [SECURITY.md](../../SECURITY.md) the real safety net
  rather than a fallback.
- Anyone who wants the checks locally can run them in a git hook of their own.
  That is a personal setup, not something the repository installs or expects.
- If the project ever grows past one maintainer, this is the ADR to revisit.

## Alternatives considered
- **CI on pull requests only**: still CI, and still runs on every contribution.
- **A committed pre-commit hook**: git does not install hooks from a clone, so
  it would be documentation pretending to be enforcement.
