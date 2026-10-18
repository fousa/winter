# 0006 — Native SwiftUI-app voor iPadOS 26 met Liquid Glass

- **Status**: aanvaard
- **Datum**: 2026-10-18

## Context
De app draait op één iPad, moet offline werken, betrouwbaar opslaan en in de achtergrond synchroniseren. De maker is iOS-ontwikkelaar.

## Beslissing
Native SwiftUI, Swift 6, SwiftData, minimaal iPadOS 26. Design volgens de iOS 26 HIG: Liquid Glass op de controllaag, opake content, systeemfont en -kleuren. Alleen liggende stand op iPad.

## Gevolgen
- Toegang tot Keychain, BackgroundTasks, NWPathMonitor, Guided Access en MDM-configuratie.
- Clubs met oudere iPads (zonder iPadOS 26) kunnen de app niet gebruiken.

## Overwogen alternatieven
- Web-app/PWA: zwakkere offline-opslag en geen echte achtergrondsync.
- Cross-platform framework: geen meerwaarde voor één iPad.
