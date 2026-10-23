# 0006 — A native SwiftUI app for iPadOS 26 with Liquid Glass

- **Status**: accepted; the device and orientation part is superseded by [0009](0009-universal-app-iphone-and-ipad.md), and member tiles are glass since [0014](0014-glass-member-tiles.md)
- **Date**: 2026-10-18

## Context
The app runs on a single iPad, has to work offline, store reliably and sync in the background. The author is an iOS developer.

## Decision
Native SwiftUI, Swift 6, SwiftData, iPadOS 26 as the minimum. The design follows the iOS 26 HIG: Liquid Glass on the control layer, opaque content, the system font and system colours. Landscape only on iPad.

> Superseded in part: the app is a universal iPhone and iPad app without orientation locks. See [ADR 0009](0009-universal-app-iphone-and-ipad.md). Everything else in this ADR — native SwiftUI, Swift 6, SwiftData, iOS 26 HIG, Liquid Glass — still stands.

## Consequences
- Access to the Keychain, BackgroundTasks, NWPathMonitor, Guided Access and MDM configuration.
- Clubs with older devices (without iOS/iPadOS 26) cannot use the app.

## Alternatives considered
- A web app/PWA: weaker offline storage and no real background sync.
- A cross-platform framework: no added value, and no access to the platform APIs above.
