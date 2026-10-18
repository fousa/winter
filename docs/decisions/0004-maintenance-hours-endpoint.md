# 0004 — Hours as maintenance hours in zweef.app, approved there

- **Status**: accepted
- **Date**: 2026-10-18

## Context
When the project started, the public API had no endpoint for work hours. In October 2026 `maintenance-hours` endpoints were added, including a `status` field (example: `in_aanvraag`).

## Decision
Every session becomes one registration through `POST /maintenance-hours.json`, with status `in_aanvraag`. Approving and correcting is done by the board in zweef.app. The iPad allows no corrections after upload.

## Consequences
- The iPad does not need any admin features.
- Dedup is necessary because the POST has no client key (a tag in `description`, see zweef-api.md).
- The allowed values for `category`, `project` and `status` still need confirming.

## Alternatives considered
- Using notes or ledger entries (the earlier workaround): not summable, or it shows up on invoices.
