# Proxy

Kleine Cloudflare Worker die de zweef.app API-sleutel bewaart. De iPad stuurt `Authorization: Bearer <apparaattoken>` en mag alleen deze calls doen:

- `GET /club.json` (clubnaam)
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
wrangler secret put DEVICE_TOKENS   # bv. een lange random string per iPad, komma-gescheiden
wrangler deploy
```

Elke club deployt haar eigen proxy met haar eigen sleutel; er is geen centrale server.

Een apparaattoken maken:
```sh
openssl rand -hex 32
```
Vul de proxy-URL en dit token in bij de eerste start van de app, of later in Instellingen (lang drukken op de titel → beheercode).

Lokaal testen: kopieer `.dev.vars.example` naar `.dev.vars` en draai `wrangler dev`.

Een iPad intrekken = zijn token uit `DEVICE_TOKENS` halen en opnieuw deployen.

Een kleine Rails-route kan hetzelfde doen als je liever geen Cloudflare gebruikt.
