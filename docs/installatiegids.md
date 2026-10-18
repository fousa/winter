# Installatiegids voor clubs

Deze gids is voor de persoon in je club die de iPad klaarzet. Je hoeft geen programmeur te zijn, maar je hebt beheertoegang tot zweef.app nodig. Reken op ongeveer een uur.

## Wat je nodig hebt
- Een iPad met iPadOS 26 of later, bij voorkeur met een standaard of muurhouder.
- Een zweef.app-account met toegang tot de beheerpagina's (om een API-sleutel te maken).
- De **schema-naam** van je club in zweef.app (te vinden in de clubinstellingen).
- Voor de aanbevolen opzet: een gratis Cloudflare-account en een computer met Node.js.

## Stap 1 — Kies hoe de iPad met zweef.app praat
| | Proxy (aanbevolen) | Direct |
|---|---|---|
| Waar staat de zweef.app-sleutel? | Bij Cloudflare, niet op de iPad | In de Keychain van de iPad |
| Wat als de iPad gestolen wordt? | Token intrekken, klaar | Sleutel in zweef.app intrekken en een nieuwe maken |
| Technische kennis | Een paar commando's uitvoeren | Geen |

De zweef.app-documentatie raadt af om de sleutel op een toestel te bewaren. Kies daarom de proxy als het enigszins kan.

## Stap 2 — API-sleutel aanmaken in zweef.app
1. Log in op zweef.app met een beheeraccount.
2. Ga naar de beheerpagina's en maak een API-sleutel (API token) aan.
3. Bewaar de sleutel in een wachtwoordmanager. Je hebt hem in stap 3 of 5 nodig.

## Stap 3 — Proxy opzetten (alleen bij proxy)
Volg [proxy/README.md](../proxy/README.md). Samengevat:
```sh
npm i -g wrangler
wrangler login
cd proxy
wrangler secret put ZWEEF_API_KEY   # de sleutel uit stap 2
wrangler secret put CLUB            # de schema-naam van je club
openssl rand -hex 32                # maak een apparaattoken, kopieer het
wrangler secret put DEVICE_TOKENS   # plak het token
wrangler deploy                     # noteer de URL die verschijnt
```
Je hebt nu een **proxy-URL** en een **apparaattoken**.

## Stap 4 — App installeren
Via TestFlight, Apple Business Manager of zelf bouwen met Xcode (zie de [README](../README.md#zelf-bouwen)).

## Stap 5 — Eerste start
De app opent met de setup-assistent:
1. **Verbinding**: kies Proxy en vul de proxy-URL en het apparaattoken in, of kies Direct en vul de schema-naam en de API-sleutel in. Tik op **Verbinding testen**; je zou de actieve onderhoudsperiode moeten zien.
2. **Club**: de app toont de naam van je club zoals die in zweef.app staat; controleer of het de juiste is. Stel daarna het sluitingsuur (wanneer vergeten timers automatisch stoppen) en de takenlijst in.
3. **Beheercode**: zes cijfers. Bewaar ze bij de andere clubwachtwoorden; zonder deze code kan je de instellingen niet meer wijzigen.
4. **Klaar**: de leden en hun foto's worden opgehaald zodra er internet is.

## Stap 6 — iPad vergrendelen in de app
1. Instellingen › Toegankelijkheid › Begeleide toegang: aanzetten en een toegangscode instellen.
2. Open de app en klik drie keer op de zij- of thuisknop om Begeleide toegang te starten.
3. Zet Instellingen › Scherm en helderheid › Automatisch vergrendelen op "Nooit" (de app dimt zelf).
4. Hou de iPad aan de lader.

## Instellingen achteraf wijzigen
Druk 3 seconden op de titel (de naam van je club) en geef de beheercode in. Je kan dan de verbinding, het token, het sluitingsuur, de taken en de beheercode aanpassen, en de verbinding opnieuw testen.

## Problemen oplossen
| Probleem | Oplossing |
|---|---|
| "Verbinding geweigerd" | Token of sleutel klopt niet of is ingetrokken. Controleer in Instellingen. |
| Statusknop blijft oranje | Geen internet. Uren blijven bewaard; open het syncscherm om te zien hoeveel er wachten. |
| Sessie "geweigerd" in het syncscherm | zweef.app aanvaardde de registratie niet (bv. lid niet meer actief). Los het op in zweef.app en tik op "Opnieuw". |
| Verkeerde clubnaam | De naam komt uit zweef.app; pas hem daar aan. De iPad neemt hem over bij de volgende refresh. |
| Nieuw lid staat er niet bij | Leden worden ververst wanneer er internet is. Of: Instellingen › Leden nu verversen. |
| Beheercode vergeten | App verwijderen en opnieuw installeren. **Let op:** sessies die nog niet geüpload zijn gaan dan verloren. Kijk eerst in het syncscherm of alles geüpload is. |
| iPad gestolen of kwijt | Proxy: verwijder het token uit `DEVICE_TOKENS` en deploy opnieuw. Direct: trek de API-sleutel in zweef.app in. |
