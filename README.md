# Winter

**Winter** is an open-source iPhone and iPad app for any gliding club that uses [zweef.app / GlidingApp](https://zweef.app). Members log their maintenance hours with start/stop, without logging in — usually on a shared iPad in the workshop, and just as well on a phone. The app works fully offline and syncs the hours to zweef.app (maintenance hours) as soon as there is a connection.

## Features
- Start and stop in two taps, with member photos
- Fully offline; automatic sync when connected, with a sync status screen
- Anyone can close the day once no timers are running; forgotten timers stop automatically at the closing time
- Registrations arrive in zweef.app as "pending approval", so the board approves them
- One universal app for iPhone and iPad, in any orientation, designed for iOS 26 with Liquid Glass
- Available in English, Dutch and French, following the device's language

## Requirements
- An iPhone or iPad running iOS/iPadOS 26 or later
- A zweef.app account with admin rights, to create an API key
- Recommended: a (free) Cloudflare account for the proxy

## Installing it for your club
The full step-by-step guide is in [docs/installation-guide.md](docs/installation-guide.md). In short:

1. **Set up the proxy** (recommended): see [`proxy/README.md`](proxy/README.md). You get a proxy URL and create one device token per device.
2. **Install the app** on the device (TestFlight, Apple Business Manager, or build it yourself — see below).
3. **First launch**: the setup assistant asks for the proxy URL and the device token (or, without a proxy, the club schema and the API key), the closing time and an admin code. The app fetches your club's name from zweef.app itself.
4. **Turn on Guided Access** on the shared workshop device (Settings › Accessibility › Guided Access).

Each device keeps its own hours and uploads them itself. A timer that is running on the workshop iPad can only be stopped on that iPad — zweef.app has no notion of a running timer, so there is nothing to sync it through ([ADR 0009](docs/decisions/0009-universal-app-iphone-and-ipad.md)).

Every setting is documented in [`docs/configuration.md`](docs/configuration.md), including MDM configuration.

## Building it yourself
1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and fill in your `DEVELOPMENT_TEAM` and `BUNDLE_ID_PREFIX`. (Optional: it builds under `com.example` without this.)
3. Run `xcodegen generate` to create `Winter.xcodeproj`, then open it in Xcode 26 and build it for your iPhone or iPad.

## Documentation
Everything lives in [`docs/`](docs/README.md): the installation guide for clubs, configuration, the functional specification, architecture, data model, synchronisation, the zweef.app API, design, and the [design decisions](docs/decisions/README.md).

## Contributing
Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Report security problems as described in [SECURITY.md](SECURITY.md). Never put keys, tokens or real member data in the repository.

## Status
In design: the documentation, mockups and proxy are ready; the app itself is being built according to [PLAN.md](PLAN.md).

## License
[MIT](LICENSE)
