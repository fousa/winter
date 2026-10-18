# Security and privacy

## What needs protecting
- **The zweef.app API key**: it grants access to all of a club's member data and financial data.
- **Device tokens**: they give one device access to the club's proxy.
- **Member data**: names, photos and hours worked by club members.

## How the app protects it
- No secrets in the code or the repository. Everything is configured on the device ([docs/configuration.md](docs/configuration.md)).
- Secrets live in the Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (not in backups, not transferable).
- In the recommended proxy setup the API key never reaches the device ([ADR 0003](docs/decisions/0003-proxy-for-the-api-key.md)). The proxy only forwards the endpoints the app needs.
- The settings screen sits behind an admin code (hashed with a salt, with a delay after failed attempts).
- Logs never contain tokens, keys or personal data.
- Member data stays on the device and in zweef.app; there is no other server.

## If something leaks
| What | Do this right away |
|---|---|
| API key | Revoke it in the zweef.app admin pages, create a new one, and put it in the proxy (`wrangler secret put ZWEEF_API_KEY`) or in the app's settings |
| Device token | Remove that device's token from `DEVICE_TOKENS`, redeploy the proxy, and set a new token in the app on that device |
| A secret in a commit | Revoke it as above. Removing it from history is not enough: treat it as leaked. |

## Reporting a vulnerability
Please do **not** report security problems in a public issue. Use GitHub *Private vulnerability reporting* (the repository's "Security" tab). You will get a response within a week.
