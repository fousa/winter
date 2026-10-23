# 0007 — No voice notes, free-text field or CSV export

- **Status**: accepted, amended by [0019](0019-description-is-times-and-a-comment.md) (an optional comment when stopping)
- **Date**: 2026-10-18

## Context
Every extra feature makes the app more complex, for users and for developers.

## Decision
When stopping, you only pick a task and optionally an aircraft. There is no text field, no voice recording or dictation, and no CSV export. All reporting happens in zweef.app.

## Consequences
- A simpler screen and fewer mistakes.
- Details that do not fit in a task/aircraft have to be added in zweef.app.

## Alternatives considered
- Recording a spoken note (proposed earlier, rejected).
- CSV over AirDrop as a safety net (proposed earlier, rejected).
