# Security and privacy

## What needs protecting
- **The zweef.app API key.** This is the big one. Verified against a real club: that single key reads every member's email, phone, home address, date of birth, national registry number, medical validity dates and emergency contacts; it reads and writes the club's financial ledgers; and it can modify accounts and flights. The app itself only ever calls six endpoints, but nothing stops whoever holds the key.
- **Member data**: names and the hours members worked, stored on the device.

## Where the key lives
On the device, in the Keychain. There is no proxy in front of it ([ADR 0013](docs/decisions/0013-no-proxy.md)) — that was weighed and deliberately dropped, and the trade is recorded there rather than hidden.

This goes against zweef.app's own advice, which says in as many words: *do not expose the token clientside*. So be clear-eyed about it:

- A club's API key on a device in a workshop is only as safe as the device.
- Keep the shared device physically secured, and in Guided Access so the app cannot be left.
- Use a device passcode. The Keychain protects the key at rest, but not on an unlocked device in someone's hands.
- **If a device is lost or stolen, create a new API key in zweef.app immediately** and enter it on every device and in every integration that used the old one. That is the only revocation available: there is no per-device token to delete.

## What the app does to limit the damage
- No secrets in the code or the repository. Everything is configured on the device ([docs/configuration.md](docs/configuration.md)).
- The key is stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so it is not in a backup and cannot be restored onto another device.
- The key is never shown after it is entered: the settings screen displays "••••••• (set)" and never reads the value back into a view.
- The key is never part of an MDM payload. A managed configuration is readable on the device, so only the club schema and the closing time can be pushed.
- The app decodes four fields of a member — id, first name, last name, active — and ignores the sixty-odd others the API returns. What it never decodes it can never store, log or leak.
- The app only ever calls six endpoints, none of them financial.
- Logs never contain the key or personal data; the sync log a member can read on the device carries counts, not names.
- The settings screen sits behind an admin code (salted SHA-256, with a growing delay after wrong attempts). It protects the key and the erase button from a curious member — not a device in a lab, and the code says so.
- Member data stays on the device and in zweef.app; there is no other server.

## If something leaks
| What | Do this right away |
|---|---|
| API key | Revoke it in the zweef.app admin pages, create a new one, and enter it in the app's settings on every device that used it |
| A device is lost or stolen | Same: rotate the key. Everything on that device was readable with it |
| A secret in a commit | Revoke it as above. Removing it from history is not enough: treat it as leaked |

## If zweef.app ever offers a scoped key
A read-only or scope-limited key would remove most of this risk at no cost to the club. If that appears, [ADR 0013](docs/decisions/0013-no-proxy.md) should be revisited the same week.

## Reporting a vulnerability
Please do **not** report security problems in a public issue. Use GitHub *Private vulnerability reporting* (the repository's "Security" tab). You will get a response within a week.

## The demo
The demo mode ([ADR 0021](docs/decisions/0021-demo-mode.md)) runs on an in-memory database, its own UserDefaults suite, an in-memory secret store and a fake zweef.app. It cannot read or change the device's real hours, settings or Keychain, and it never connects to zweef.app. Its settings code, 123456, is public on purpose and protects nothing real.
