# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- `mix setup` — install deps and build assets
- `mix phx.server` — start dev server at localhost:4000
- `iex -S mix phx.server` — start with interactive shell
- `mix test` — run all tests
- `mix test test/path/to/test.exs` — run single test file
- `mix test --failed` — re-run failed tests
- `mix format` — format code
- `mix precommit` — compile (warnings-as-errors), unlock unused deps, format, test

## Architecture

Phoenix 1.8 LiveView app (Elixir). GTD-style task and day planning tool. No database — uses JSON file persistence.

### State management
- `DayStruct.Store` (GenServer) is the single source of truth for all app state
- State persisted to `data/state.json` with debounced writes (500ms) and automatic backups in `data/backups/`
- LiveViews subscribe to store updates via PubSub (`DayStruct.PubSub`, topic `"store:updates"`)
- Config override: `:store_data_dir` app env (used in tests to isolate data via `tmp/test_data`)

### Data models (`lib/day_struct/models/`)
Plain Elixir structs (no Ecto schemas): `Task`, `Area`, `InboxItem`, `DayPlan`, `TimeBlock`. Constructed via `Model.new/1`, serialized to/from JSON via `State.to_json/from_json`.

### Task lifecycle
Inbox capture → process to Task (status: `ready`) → schedule as TimeBlock (status: `active`) → complete all blocks (status: `done`)

### Routes
- `/` — BoardLive (task board)
- `/inbox` — InboxLive (inbox capture & processing)
- `/area/:id` — AreaLive (area detail)
- `/day` or `/day/:date` — DayPlanLive (daily schedule with time blocks)

### Frontend
- Tailwind CSS v4 (no config file, uses `@import` syntax in `app.css`)
- esbuild for JS bundling
- Assets in `assets/js/` and `assets/css/`

## Guidelines

See `AGENTS.md` for detailed Phoenix, LiveView, Elixir, HTML/HEEx, JS/CSS, and testing guidelines.
