# Configuration and installation (open source)

The app is open source and has to be usable by any club on zweef.app. That is why **nothing club-specific or secret lives in the code or the repository**. Everything is configured on first launch (or through MDM) and stored on the device.

## What has to be configured
| Setting | Stored in | Required | Note |
|---|---|---|---|
| Connection mode | UserDefaults | yes | `proxy` (recommended) or `direct` |
| Proxy URL | UserDefaults | with proxy | e.g. `https://winter-proxy.<account>.workers.dev` |
| Device token | **Keychain** | with proxy | a long random string, unique per device |
| Club schema (`{club}`) | UserDefaults | with direct | from the zweef.app club settings |
| zweef.app API key | **Keychain** | with direct | `X-API-KEY` |
| Club name | UserDefaults (cache) | automatic | fetched from zweef.app (`GET /club.json`) during "Test connection" and on every refresh; cannot be entered by hand |
| Closing time | SwiftData `AppSettings` | yes | 21:00 by default |
| Tasks | SwiftData | yes | a default list (Glider, Winch, Hangar and workshop, Grounds, Clubhouse, Something else), seeded in the setup language and editable; edited labels are club data and are not translated |
| Reporting language | SwiftData `AppSettings` | yes | `en`/`nl`/`fr` for the text sent to zweef.app; defaults to the device language during setup ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)) |
| `category` / `status` for zweef.app | UserDefaults | yes | `Maintenance` / `in_aanvraag` by default |
| Admin code | **Keychain** (hashed) | yes | six digits; protects only the settings screen, not everyday use |

Keychain items use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so they stay out of backups and off other devices.

## Connection modes
- **Proxy (recommended)**: the club deploys the Worker from `proxy/` with its own API key. The device only knows the proxy URL and a device token, which the club can revoke. This follows zweef.app's advice not to keep the key client-side. Every device gets its own token, so each can be revoked separately.
- **Direct**: for clubs without technical people. The club schema and the API key are stored in the device's Keychain. The settings screen shows a clear warning: the key grants access to all member data and financial data, and a device in the hangar is physically reachable.

Both modes use the same `ZweefAPI` interface; only the transport layer differs (`ProxyTransport` vs `DirectTransport`).

## First launch: the setup assistant
It appears for as long as the configuration is incomplete. The steps:
1. **Welcome** — what the app does, what you need (a proxy URL + token, or a club schema + API key).
2. **Connection** — pick a mode, fill in the fields (key fields as `SecureField`, pasting allowed), tap "Test connection" → `GET /maintenance-hours/periods.json`. On success it fetches the club name (`GET /club.json`) and shows "Connected to <club name>" plus the active period; on failure a clear error (401, wrong URL, no internet). Skipping it while offline is allowed: the app works, syncing follows later.
3. **Club** — shows the fetched club name for confirmation ("Is this your club?"); then the closing time and the task list (pre-filled in the language the setup is running in). Without internet during setup the club name appears after the first successful connection; until then the app shows "Winter". The reporting language for zweef.app is set here too, defaulting to the current device language.
4. **Admin code** — six digits, entered twice.
5. **Done** — the members are fetched (if there is internet); a tip to turn on Guided Access.

## Changing settings later
- The hidden entrance: long-press (3 s) on the title (the club name) → admin code → the settings screen.
- The same fields as the setup, plus: "Refresh members now", "Change token", "Erase everything on this device" (with a confirmation; it warns if there are still sessions that have not been uploaded).
- Admin code forgotten → delete the app and reinstall it (local data and the Keychain go with it; warn about this in the README).

## MDM / Managed App Configuration (optional)
Clubs with Apple Business Manager or an MDM can skip the setup. The app reads `UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")`:

| Key | Type |
|---|---|
| `connectionMode` | String (`proxy`/`direct`) |
| `proxyURL` | String |
| `deviceToken` | String |
| `clubSchema` | String |
| `closingTime` | String (`HH:mm`) |

When present: the values are adopted (secrets go straight into the Keychain) and setup step 2 is skipped. Managed values are read-only in the settings screen.

## Generic for every club
Winter contains nothing tied to a single club:
- The **club name** and the **members** (with photos) come from zweef.app.
- The **aircraft** come from `material.json`, the **maintenance period** from `maintenance-hours/periods.json`.
- The **task list**, the **closing time**, the **reporting language** and the zweef.app values for `category`/`status` are configurable, with sensible defaults.
- The **UI language** follows the device: English, Dutch or French, with English as the fallback. Not a setting in the app.
- Copy and examples in the code and the previews use fictional clubs and members.

## Repository hygiene
- No keys, tokens, club schemas or real member data in the repository, not even in previews or tests (fixtures are anonymised).
- Build settings through `Config/Shared.xcconfig`; personal values (`DEVELOPMENT_TEAM`, `BUNDLE_ID_PREFIX`) in `Config/Local.xcconfig`, which is in `.gitignore`. Example: `Config/Local.xcconfig.example`.
- Proxy secrets only through `wrangler secret put`.
- Every club deploys its own proxy; there is no shared central server.
