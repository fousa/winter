# 0003 — API-sleutel via een proxy, directe modus als uitzondering

- **Status**: aanvaard
- **Datum**: 2026-10-18

## Context
De zweef.app API gebruikt één sleutel per club (`X-API-KEY`) die toegang geeft tot alle ledengegevens en financiële data. De zweef.app-documentatie zegt uitdrukkelijk de sleutel niet client-side te gebruiken. Een iPad in een hangar is fysiek bereikbaar.

## Beslissing
Standaard praat de app met een kleine proxy (Cloudflare Worker) die elke club zelf deployt. De proxy bewaart de sleutel, laat alleen de nodige endpoints door en aanvaardt per iPad een intrekbaar apparaattoken. Voor clubs zonder technische mensen bestaat een directe modus waarin de sleutel in de Keychain van de iPad staat, met een duidelijke waarschuwing.

## Gevolgen
- Clubs moeten één keer een Worker deployen (gedocumenteerd in de installatiegids).
- Een gestolen iPad wordt onschadelijk gemaakt door zijn token in te trekken.
- De app heeft twee transportlagen achter hetzelfde protocol.

## Overwogen alternatieven
- Altijd direct: eenvoudiger, maar tegen het advies van zweef.app.
- Een centrale proxy voor alle clubs: zou de sleutels van alle clubs bij één partij leggen.
