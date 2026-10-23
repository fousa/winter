# Features

One folder per screen, each with its view, its `@Observable` view model and its
previews: `Home`, `StartSheet`, `StopSheet`, `Confirmation`, `Sync`,
`Setup`, `Settings`.

Views hold no logic beyond presentation; decisions come from `Domain` and
mutations go through `SessionStore`. See
[docs/architecture.md](../docs/architecture.md). Built in phase 2 of
[PLAN.md](../PLAN.md).
