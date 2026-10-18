# 0013 — No proxy: the app talks to zweef.app directly

- **Status**: accepted
- **Date**: 2026-10-18
- **Supersedes**: [0003](0003-proxy-for-the-api-key.md)

## Context
[ADR 0003](0003-proxy-for-the-api-key.md) put a Cloudflare Worker between the
app and zweef.app, so the club's API key never reached the device. The app kept
a small, revocable device token instead, and the Worker forwarded only the six
endpoints the app needs.

The project owner does not want it. The reasons against it are real: it is a
second thing to deploy and keep working, it needs a Cloudflare account that
somebody in the club has to retain access to after the person who set it up
moves on, and it puts a dependency in front of a feature whose entire design
assumes the network is unreliable anyway.

So the proxy is removed, and direct mode — which [ADR 0003](0003-proxy-for-the-api-key.md)
already provided for clubs without technical people — becomes the only mode.

## Decision
The app talks to `https://admin.gliding.app/club/{club}/api` itself, with the
club's API key in the Keychain. There is no proxy, no device token, no
connection mode to choose: the setup assistant asks for the club schema and the
API key, and that is the whole connection.

`proxy/` is deleted. `ProxyTransport` and `ConnectionMode` go with it, along
with the device-token secret and the MDM keys that configured them.

## Consequences
This trades away protection that was real, and the record should say so plainly
rather than pretend the simplification is free.

- **The key is on the device, and it opens everything.** Verified against a real
  club: that one key reads every member's address, date of birth, national
  registry number, medical dates and emergency contacts, reads and writes the
  club's financial ledgers, and can modify accounts and flights. The app only
  ever calls six endpoints, but nothing stops whoever holds the key.
- **Revocation is now club-wide.** A lost or stolen device means rotating the
  club's API key in zweef.app and re-entering the new one on every other device
  and in every other integration that used it. With the proxy, one token was
  deleted and nothing else was touched.
- **It goes against zweef.app's own advice**, which says in as many words: *do
  not expose the token clientside.*
- The mitigations that remain are the ones the app can offer by itself:
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so the key is not in a
  backup and cannot move to another device, a clear warning in the setup and the
  settings screen, no key in any log, and the advice to keep the shared device in
  Guided Access and physically secured. [SECURITY.md](../../SECURITY.md) now
  leads with rotating the key, because that is the only recovery left.
- One fewer thing to deploy, one fewer account to keep, one fewer component
  between an hour and zweef.app. The code loses a transport, a mode, a secret
  and three MDM keys.

## Alternatives considered
- **Keep the proxy as the default** (the 0003 position): better protection,
  rejected as unwanted complexity. The arguments are preserved in 0003.
- **Keep the proxy as an option alongside direct**: this is what 0003 already
  described, and keeping it would mean maintaining and documenting a mode nobody
  intends to run — the worst of both.
- **Scope the key down in zweef.app**: the right fix, and not ours to make. If
  zweef.app ever offers a read-only or scoped key, this ADR should be revisited
  immediately: it would give most of the proxy's benefit with none of its cost.
