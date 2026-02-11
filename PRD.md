# Day Struct — Product Requirements Document

## Problem

There is always more to do than time allows. Without deliberate structure, one area of life (typically work) consumes all available time and attention. Existing task management tools either impose rigid systems (strict GTD, Kanban) or provide no structure at all (plain lists). What's needed is a system that:

1. Protects time for each important life area regardless of how busy other areas get
2. Surfaces the most important thing to do next within each area
3. Keeps work-in-progress visible and low
4. Reduces friction for capture, planning, and review
5. Feels like manipulating tangible objects, not filling out forms

## Core Concepts

### Area
A distinct part of life that must receive attention regardless of pressure from other areas. All areas are equally "first priority" at the top level. Examples: Private, Work, Family, Health/Movement, Friends.

- An area contains tasks (directly or via projects)
- Within an area, tasks have relative ordering — not a strict queue, but a loose priority that surfaces what matters most
- WIP is tracked per area

### Task
A concrete action to be performed. A task:

- Belongs to exactly one area (directly, or via a project)
- Has a title and optional notes
- Can depend on other tasks (forming a DAG) — a task cannot be started until its dependencies are resolved
- Has a status: `inbox` | `ready` | `active` | `done` | `dropped`
- Has a relative position/priority within its area

### Project
A conceptual grouping of related tasks. A project:

- Belongs to exactly one area
- Contains tasks
- Helps with thinking and planning, but does not directly drive execution order
- Has a title and optional notes

**Note:** Projects are out of scope for v0.1 but the data model should accommodate them.

### Inbox
The single capture point for raw input. Anything goes in — half-formed thoughts, links, reminders. During processing, inbox items are either:

- Converted into a task (assigned to an area, given a title)
- Kept as a reference note (out of scope for v0.1)
- Discarded

### Day Plan
A selection of tasks pulled from across areas that represents "what I intend to do tomorrow" (or today). The day plan:

- Is assembled the evening before (or morning of)
- Pulls from the top of each area's priority ordering
- Provides a focused view: "here is what today looks like"
- Can be reordered within the day
- Completed tasks are checked off; unfinished tasks return to their area

## v0.1 Scope

### In scope
- **Areas**: CRUD, display, reorder
- **Tasks**: CRUD, assign to area, reorder within area, status transitions, DAG dependencies
- **Inbox**: Capture raw text, process into tasks or discard
- **Day Plan**: Select tasks for today/tomorrow, view as focused list, mark done, return unfinished to area
- **WIP visualization**: See active tasks per area at a glance

### Out of scope (future)
- Projects
- Systems & Experiments
- Multiple input sources (email, e-Boks)
- Reviews / reflection workflows
- Multi-user / sharing
- Mobile-specific UI
- Search and filtering

## Technical Architecture

### Stack
- **Elixir + Phoenix LiveView** — server-rendered real-time UI
- **Persistence**: JSON files on disk, managed by a GenServer that holds state in memory and writes to disk on changes
- **No external database** for v0.1

### Data Storage

A single `data/` directory containing:

```
data/
  state.json          # Primary state file
  backups/            # Timestamped backups before each write
    state-2026-02-10T08:30:00.json
```

The `state.json` file contains the full application state:

```json
{
  "areas": [
    {
      "id": "uuid",
      "name": "Private",
      "position": 0,
      "created_at": "iso8601"
    }
  ],
  "tasks": [
    {
      "id": "uuid",
      "area_id": "uuid",
      "title": "Fix kitchen faucet",
      "notes": "",
      "status": "ready",
      "position": 0,
      "depends_on": [],
      "created_at": "iso8601",
      "updated_at": "iso8601"
    }
  ],
  "inbox": [
    {
      "id": "uuid",
      "raw_text": "Something about the car",
      "created_at": "iso8601"
    }
  ],
  "day_plans": [
    {
      "date": "2026-02-11",
      "entries": [
        {
          "task_id": "uuid",
          "position": 0,
          "completed": false
        }
      ]
    }
  ]
}
```

### State Management

A `DayStruct.Store` GenServer:

- Loads `state.json` into memory on boot
- All reads are from memory (fast)
- All writes update memory, then async persist to disk
- Before each write, copies the previous file to `backups/`
- Exposes a clean API: `Store.list_areas()`, `Store.add_task(attrs)`, `Store.reorder_task(id, new_position)`, etc.

### LiveView UI

Single-page app feel with multiple live views:

1. **Board view** (default) — columns per area, tasks ordered by priority, active tasks highlighted. Drag-and-drop reordering.
2. **Inbox view** — list of raw captures with inline processing: type a title, pick an area, convert to task. Or discard.
3. **Day Plan view** — today's plan as a focused checklist. Pick tasks from areas to add. Check off as done.

### Key Interactions

- **Drag and drop** for reordering tasks within an area and between areas
- **Quick capture**: always-visible input field for inbox items (keyboard shortcut to focus)
- **Inline editing**: click a task to edit title/notes in place
- **Status transitions**: visual actions to move tasks through states
- **Dependency visualization**: when a task has unresolved dependencies, it appears dimmed/locked with a note about what blocks it

## UX Principles

1. **Objects, not forms** — tasks should feel like physical cards you move around, not rows in a database
2. **Minimal friction** — capturing a thought should take < 3 seconds
3. **Visibility over memory** — the system should show you what matters, not require you to remember
4. **Calm defaults** — don't shout. Use subtle visual hierarchy. The most important thing should be quietly obvious.
5. **Respect for areas** — no area should be invisible. If an area is being neglected, the UI should make that gently apparent.

## Open Questions

1. **How should "relative ordering" work in practice?** Pure drag-and-drop? Explicit high/medium/low? Numbered positions? The notes suggest it shouldn't be a strict queue but needs some ordering.
2. **What does "active" mean vs "ready"?** Is "active" = "I'm working on this right now" (true WIP)? Or "this is available to work on"?
3. **How many areas are typical?** This affects layout — 3-5 areas fit columns, 10+ needs a different approach.
4. **Should the day plan be time-blocked?** Or just an ordered list of intentions?
5. **Backup strategy** — how many backups to keep? Auto-prune after N days?
