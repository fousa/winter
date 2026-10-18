# Contributing

Thanks for wanting to help! This app is built by and for gliding clubs. Contributions are welcome: bug reports, documentation improvements, translations, code.

## Before you start
1. Read the [documentation index](docs/README.md), especially [CLAUDE.md](CLAUDE.md) (the settled decisions) and the [ADRs](docs/decisions/README.md).
2. Planning something bigger? Open an issue first so we can discuss it. A change that goes against an ADR starts with a new ADR.

## Development environment
- macOS with Xcode 26 or later.
- Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and fill in `DEVELOPMENT_TEAM` and `BUNDLE_ID_PREFIX`.
- You do not need a zweef.app key to develop: previews and tests use `FakeZweefAPI`.
- For the proxy: Node.js and `wrangler` (see [proxy/README.md](proxy/README.md)).

## How we work
- Branch from `main`: `feature/<short-name>`, `fix/<short-name>` or `docs/<short-name>`.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/) in English, e.g. `feat(sync): retry uploads with backoff`.
- One logical change per pull request; fill in the PR template.
- Update the documentation in the same PR as the behaviour change (spec, design, data model, sync or API).
- Add a line to [CHANGELOG.md](CHANGELOG.md) under "Unreleased".

## Code
- Swift 6 with strict concurrency; follow the structure in [docs/architecture.md](docs/architecture.md).
- No third-party dependencies without discussing it in an issue first.
- Public types and non-trivial functions get a DocC comment (`///`) that explains *why*, not just *what*.
- UI strings go in the String Catalog (`nl-BE`), never hard-coded in views.
- Domain rules are pure functions with tests.

## Testing
- All tests must pass before a PR is merged.
- New logic in `Domain/` or `Data/` needs tests; always inject time.
- Always anonymise fixtures containing zweef.app JSON.

## Secrets and privacy
- **Never** put API keys, tokens, club schemas or real member data in the repository, in issues or in screenshots.
- CI runs a secret scan; a PR with a detected secret will not be merged. If something does leak, read [SECURITY.md](SECURITY.md).

## Questions
Open an issue with the `question` label.
