# Physical Constraints Design Spec

## Goal

Design DayStruct so it behaves like a whiteboard:

- finite visible space
- explicit tradeoffs
- low cognitive overhead
- high alignment with real daily capacity

This spec prioritizes execution over capture depth.

## Core Product Principles

1. Space is a feature, not a limitation.
2. Every new commitment must displace something else.
3. The default view must fit on one screen.
4. Old commitments should fade or disappear unless recommitted.
5. The system optimizes for "what gets done this week," not archival completeness.

## Primary Surface: The Board

The default screen is a fixed-capacity board with four lanes:

1. `Today` (max 5 cards)
2. `Now` (max 3 cards)
3. `Waiting` (max 3 cards)
4. `Later` (max 20 cards, compact cards)

Rules:

1. No infinite scrolling on `Today`, `Now`, or `Waiting`.
2. `Now` and `Today` must always be fully visible without scrolling on laptop-sized screens.
3. If a lane is full, adding a card requires replacing/moving an existing card first.

## Card Model (Minimal)

Each card has:

- `title`
- `area`
- `status` (`later`, `today`, `now`, `waiting`, `done`, `archived`)
- `updated_at`
- `staleness_score` (derived)

Optional fields (not shown by default):

- `project_id`
- `notes`
- `due_date`

## Interaction Constraints

### Add Flow

1. Quick capture always lands in `Later`.
2. If `Later` is full, user must:
   - archive one card, or
   - promote one card out, or
   - cancel capture.

### Promote Flow (`Later -> Today -> Now`)

1. Drag/drop or keyboard promote.
2. If destination lane is full, open a replacement chooser:
   - "Replace card X"
   - "Cancel"

### Completion Flow

1. Marking done removes card from active lanes immediately.
2. Done cards are not shown on board by default.
3. A small "Done today: N" counter remains visible for motivation.

## Decay and Recommitment

To prevent silent backlog growth, cards decay visually and operationally.

1. Card aging states:
   - `fresh` (0-3 days)
   - `aging` (4-10 days)
   - `stale` (11+ days)
2. Stale cards are visually dimmed and sorted lower within lane.
3. Weekly review prompt:
   - "You have N stale cards. Recommit or archive."
4. Cards not touched for 30 days auto-archive unless pinned.

## Weekly Ritual (System-Supported)

Lightweight weekly flow (10-15 minutes):

1. Clear `Now` fully.
2. Rebuild `Today` for next workday.
3. Resolve stale cards (`recommit` or `archive`).
4. Confirm max active focus count per area for next week.

No mandatory full-backlog review.

## Area Balancing (Reality Constraint)

Each area has a weekly slot budget (example):

- Personal: 6
- Work: 10
- Health: 4
- Family: 4

When `Today` cards are chosen, UI shows area budget usage.
If an area is starved for 2+ weeks, show a nudge in planning view.

## UI/UX Notes

1. Board-first layout, dense but calm.
2. Clear card hierarchy: title first, area chip second.
3. Micro-interactions:
   - subtle card lift on drag
   - soft drop animation
   - quick success flash on done
4. Aging state should be obvious but not alarming.
5. No modal-heavy workflow for common actions.

## Non-Goals (for v1)

1. No auto-clustering by AI.
2. No dependency graph visualization on board.
3. No advanced project hierarchy.
4. No complex notification engine.

## AI Role in This Model

AI is assistive, not generative by default.

Allowed:

1. Rewrite vague cards into clear next actions.
2. Suggest 3-card `Now` set from `Today`.
3. Summarize stale cards before weekly recommit/archive.

Disallowed by default:

1. Bulk creation of new tasks.
2. Automatic categorization without confirmation.
3. Silent reshuffling of priorities.

## Implementation Plan

### Phase 1: Hard Limits + Board

1. Build fixed-capacity lanes.
2. Enforce replacement on full lanes.
3. Add done counter and hidden done archive.

### Phase 2: Decay + Weekly Flow

1. Add aging states and stale visuals.
2. Add weekly stale resolution prompt.
3. Add 30-day auto-archive with undo.

### Phase 3: Area Budgets + AI Assist

1. Area slot budgets in planning view.
2. AI action rewriting and "pick my Now 3" suggestions.
3. Keep all AI suggestions explicit and user-confirmed.

## Success Metrics

1. Active board count remains within lane limits >95% of days.
2. Median stale cards decreases week over week.
3. User opens board and selects first task in under 30 seconds.
4. Weekly ritual completion at least once per week.
5. Reduced ratio of captured vs completed tasks over time.

