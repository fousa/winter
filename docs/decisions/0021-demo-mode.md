# 0021 — A demo mode with a sample club

- **Status**: accepted
- **Date**: 2026-10-23

## Context
App Review has to be able to use an app. Winter cannot get past its setup
without a zweef.app club schema and an API key, and that key opens the club's
whole account — members' personal and financial data included (ADR 0013,
SECURITY.md). Handing a real club's key to Apple is not acceptable, and
zweef.app offers no demo club. Apple's guideline 2.1 allows a built-in demo
mode instead of a demo account when an account cannot be given out for legal
or security reasons.

## Decision
The setup assistant's first page offers "Try with a sample club". It opens
the app on the fictional club the previews use — members, aircraft, rolling
stock and projects, two timers running, finished sessions waiting — with:

- an in-memory database, its own UserDefaults suite and an in-memory secret
  store, so nothing reaches the device's real data or Keychain;
- a fake zweef.app (`FakeZweefAPI.sampleClub()`) that answers with that same
  club and accepts uploads without sending anything, so every feature,
  "Upload" and pull to refresh included, works end to end;
- the settings behind the admin code 123456, shown on the page that starts
  the demo.

A "Demo" button on the home screen says what it is and leads back out. Leaving
the demo, or quitting the app, throws it away. The app keeps one
`AppEnvironment` per mode and swaps them while it runs.

## Consequences
- App Review can try everything without a key; the review notes explain the
  demo and why there is no demo account.
- A club can look at the app before asking its board for a key.
- The sample data and the fake API ship in release builds. They contain
  nothing real.

## Alternatives considered
- **A demo account**: needs a zweef.app demo club, which does not exist.
- **Real credentials for App Review**: would expose a real club's members.
