# Contributing

Thanks for wanting to help! This app is built by and for gliding clubs. Contributions are welcome: bug reports, documentation improvements, translations, code.

## Before you start
1. Read the [documentation index](docs/README.md), especially [CLAUDE.md](CLAUDE.md) (the settled decisions) and the [ADRs](docs/decisions/README.md).
2. Planning something bigger? Open an issue first so we can discuss it. A change that goes against an ADR starts with a new ADR.

## Development environment
- macOS with Xcode 27.1 or later, plus [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- `Winter.xcodeproj` is generated and is not in git. Run `xcodegen generate` after cloning, and again whenever you add a file or change `project.yml`.
- Optional: copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and fill in `DEVELOPMENT_TEAM` and `BUNDLE_ID_PREFIX`. Without it the project still builds, under `com.example`.
- Before pushing, build the Release configuration once (`xcodebuild build -scheme Winter -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`): Xcode Cloud archives Release, and anything only defined under `#if DEBUG` — the preview helpers, `SampleData` launch arguments — breaks it there and nowhere else.
- Build with the iOS 27.1 SDK (Xcode 27.1) or later. Built with 27.0, the app runs in a compatibility window on the iPhone Duo instead of filling its screen; set the Xcode Cloud workflow to 27.1 too.
- Xcode Cloud builds the releases (ADR 0016). It generates the project itself with `ci_scripts/ci_post_clone.sh`; the workflow needs the environment variables `WINTER_BUNDLE_ID_PREFIX` (e.g. `be.example`) and `WINTER_DEVELOPMENT_TEAM`. Xcode's warning that the scheme "may only exist locally" is expected.
- You do not need a zweef.app key to develop: previews and tests use `FakeZweefAPI`.
- To look at a screen on a simulator without going through the setup assistant, launch a Debug build with the argument `-sampleClub 3`: the app opens on the home screen of the fictional club with three timers running, in memory and with no connection. In Xcode this goes under Product → Scheme → Edit Scheme → Arguments; from the command line, `xcrun simctl launch <udid> be.fousa.winter -sampleClub 3` (with your own bundle identifier). Add `-sampleScreen sync` to open the sync screen with a few finished sessions in it, `-sampleScreen stop` to open the stop sheet of the first running timer, or `-sampleScreen start` to start a timer as if a member had, showing the confirmation that follows. With `-sampleScreen stop`, `-sampleAlert stop` or `-sampleAlert delete` also opens that confirmation. `-demo` opens the demo exactly as "Try with a sample club" on the setup's first page does, with its "Demo" button to leave it (ADR 0021).

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
- UI strings go in the String Catalog, never hard-coded in views. Write them in English (the source language) and do not build sentences by concatenation.
- Domain rules are pure functions with tests.

## Translations
The app ships in **English, Dutch and French**, and only those three ([ADR 0010](docs/decisions/0010-three-languages-en-nl-fr.md)).

- English (`en`) is the source language: new strings are added in English and the other two follow.
- Dutch (`nl`) and French (`fr`) corrections are very welcome — open a PR with just the catalog change. Keep the terms consistent with the [glossary](docs/glossary.md) and add any new term to it.
- A fourth language needs a new ADR first, not just a catalog: it is a promise to keep it reviewed every release. Please open an issue to discuss it, ideally offering to review that language.
- No machine translation without a speaker of the language reading it.
- Check your change at the largest Dynamic Type size; French is the longest language and is where labels break first.

## Testing
- All tests must pass before a PR is merged.
- New logic in `Domain/` or `Data/` needs tests; always inject time.
- Always anonymise fixtures containing zweef.app JSON.

## Secrets and privacy
- **Never** put API keys, tokens, club schemas or real member data in the repository, in issues or in screenshots.
- There is no CI and no automated scan ([ADR 0011](docs/decisions/0011-no-continuous-integration.md)): check your own diff before pushing. A PR with a secret in it will not be merged. If something does leak, read [SECURITY.md](SECURITY.md).

## Questions
Open an issue with the `question` label.
