# Proxy

A small Cloudflare Worker that holds the zweef.app API key. The app sends `Authorization: Bearer <device token>` and is only allowed to make these calls:

- `GET /club.json` (the club name)
- `GET /accounts.json`
- `GET /material.json`
- `GET /maintenance-hours/periods.json`
- `GET /maintenance-hours/{current|id}/hours.json`
- `POST /maintenance-hours.json`

## Deploy
```sh
npm i -g wrangler
wrangler login
wrangler secret put ZWEEF_API_KEY
wrangler secret put CLUB
wrangler secret put DEVICE_TOKENS   # e.g. one long random string per device, comma-separated
wrangler deploy
```

Every club deploys its own proxy with its own key; there is no central server.

Creating a device token:
```sh
openssl rand -hex 32
```
Enter the proxy URL and this token on the app's first launch, or later in Settings (long-press the title → admin code).

Testing locally: copy `.dev.vars.example` to `.dev.vars` and run `wrangler dev`.

Revoking a device = removing its token from `DEVICE_TOKENS` and redeploying.

A small Rails route can do the same thing if you would rather not use Cloudflare.
