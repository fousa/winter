# 0008 — Open source, configuratie op het toestel

- **Status**: aanvaard
- **Datum**: 2026-10-18

## Context
De app moet bruikbaar zijn voor elke club met zweef.app, niet alleen voor de club van de maker.

## Beslissing
De code is open source (MIT). Er staat niets club-specifieks of geheims in de repo. Bij de eerste start configureert een setup-assistent de verbinding, de club en een beheercode; achteraf kan alles in de app aangepast worden achter die beheercode. Geheimen staan in de Keychain. Clubs met een MDM kunnen de configuratie meegeven als Managed App Configuration.

## Gevolgen
- De app heet Winter en is generiek: clubnaam, leden, toestellen en periode komen uit zweef.app; takenlijst, sluitingsuur en zweef.app-waarden zijn instelbaar.
- Geheimen-scanning (gitleaks) in CI.
- Testdata en fixtures zijn geanonimiseerd.

## Overwogen alternatieven
- Gesloten app per club: meer werk voor de maker, minder bijdragen.
