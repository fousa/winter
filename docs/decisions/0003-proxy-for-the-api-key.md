# 0003 — The API key through a proxy, direct mode as the exception

- **Status**: superseded by [0013](0013-no-proxy.md)
- **Date**: 2026-10-18

## Context
The zweef.app API uses one key per club (`X-API-KEY`) that grants access to all member data and financial data. The zweef.app documentation explicitly says not to use the key client-side. An iPad in a hangar is physically reachable.

## Decision
By default the app talks to a small proxy (a Cloudflare Worker) that each club deploys itself. The proxy holds the key, only forwards the endpoints we need, and accepts a revocable device token per iPad. For clubs without technical people there is a direct mode in which the key lives in the iPad's Keychain, with a clear warning.

> Superseded: the proxy was removed and direct mode became the only mode. See
> [ADR 0013](0013-no-proxy.md), which records what that costs. The reasoning
> below is kept because it is the argument to re-read if zweef.app ever offers a
> scoped key.

## Consequences
- Clubs have to deploy a Worker once (documented in the installation guide).
- A stolen iPad is rendered harmless by revoking its token.
- The app has two transport layers behind the same protocol.

## Alternatives considered
- Always direct: simpler, but against zweef.app's advice.
- One central proxy for all clubs: that would put every club's key in one party's hands.
