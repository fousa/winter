# 0009 — One universal app for iPhone and iPad, fully adaptive

- **Status**: accepted
- **Date**: 2026-10-18
- **Supersedes**: the device and orientation part of [0006](0006-native-ipados-26.md)

## Context
[ADR 0006](0006-native-ipados-26.md) assumed exactly one device: a landscape iPad on the workshop wall. That is still the main way the app is used, but it rules out two things clubs will want. Not every club has a spare iPad for the workshop, and a committee member who wants to look at the day's hours or stop a forgotten timer has a phone in their pocket, not the wall-mounted iPad. A landscape-only app on an iPhone is also simply wrong under the iOS 26 HIG, which expects layouts to follow the size classes rather than a fixed device.

## Decision
One universal app target for iPhone and iPad, minimum iOS/iPadOS 26.

- **No orientation locks.** All orientations on both devices. Layout follows the horizontal and vertical size classes, never the device model or a hardcoded screen size.
- **The same model on both.** No login on either device, the member list is the way in, and anyone may stop anyone's timer. The iPhone is the same app in a compact layout, not a different product ([ADR 0002](0002-no-member-login.md) is unchanged).
- The iPad in landscape stays the reference design and the mockups stay the source for layout, sizes and copy; the compact layouts are derived from it (see [design.md](../design.md)).

## Consequences
- **Running timers stay on the device they were started on.** The local database is the source of truth ([ADR 0001](0001-offline-first.md)) and zweef.app has no concept of a running timer, so an iPhone cannot show or stop a timer that is running on the workshop iPad. Each device closes its own day and uploads its own sessions. The app has to be honest about this: the "Working now" bar is about *this device*, and the copy says so.
- One device is still the normal setup for a club. Extra devices are useful for a club without a shared iPad, or for a committee member logging their own hours; they are not a second screen onto the iPad.
- Every screen needs a compact-width variant, and the floating bar and the two-column sheets need a compact-height variant for iPhone landscape.
- Each device needs its own device token, so each can be revoked separately ([ADR 0003](0003-proxy-for-the-api-key.md)).
- Guided Access and "keep the screen on" only make sense for the shared workshop device; on a personal iPhone they are left alone.
- Testing has to cover both size classes; previews are pinned to an iPad and an iPhone.

## Alternatives considered
- **iPad only** (the 0006 position): the simplest, but it excludes clubs without a workshop iPad and it makes the hours unreachable away from the wall.
- **A separate iPhone app or target**: two targets, two layers of copy and twice the maintenance, with no behaviour that actually differs.
- **A personal-device mode on iPhone** (remember who you are, skip the member picker): a nicer phone experience, but it introduces a notion of identity on a device, which is exactly what [ADR 0002](0002-no-member-login.md) avoids. Can be reconsidered in a later ADR if clubs ask for it.
- **Syncing running timers between devices** (CloudKit or through the proxy): it would make the bar device-independent, but it needs a shared backend or CloudKit, it breaks offline-first guarantees, and it conflicts with "no backend of our own beyond the proxy".
