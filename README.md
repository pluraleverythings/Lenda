# Lenda

[![CI](https://github.com/pluraleverythings/lenda/actions/workflows/ci.yml/badge.svg)](https://github.com/pluraleverythings/lenda/actions/workflows/ci.yml)

A smarter iPhone calendar timeline.

## What it does

iCal's week view wastes most of its space on empty hours and forces horizontal
scrolling to see a whole day. Lenda inverts that:

- **Day rows stacked vertically**, each day rendered horizontally as a full
  24-hour track.
- **No horizontal scrolling.** Every day fits edge-to-edge.
- **Dynamic hour width.** A time axis is computed from the union of every
  event in the loaded window. Hours where *no day* has events collapse to a
  thin tinted strip; busy hours expand to fill the rest. Time stays aligned
  across rows, so you can scan a column.
- **Vertical scrolling in both directions.** The view opens with today at the
  top; scroll up to revisit the recent past, down to look ahead. The loaded
  range expands lazily as you scroll past either edge.
- **Month bar across the top.** Tap any month to jump there; the bar
  highlights/centers the month of whichever day is currently at the top of
  the viewport.
- **Today** gets a single warm-orange accent — a thin bar in the day label,
  the day number, and a 1pt "now" line in the track. Everything else is
  neutral.

## Look & feel

Dieter Rams territory: no cards, no shadows, no rounded chips, no gradients.
Hairline rules separate sections. Events are pale tinted fills with a 2pt
colored edge bar identifying the source calendar — colour is functional, not
decorative. The compressed zones are simply a slightly darker surface — no
hatching, no icons. The single warm accent (Braun-orange) is reserved for
"today" and "now".

## Architecture

```
Lenda/
  LendaApp.swift               @main, wires up CalendarStore + ContentView
  ContentView.swift            NavigationStack chrome
  CalendarTimelineView.swift   Top-level layout (month bar + axis + scroll list)
  MonthBar.swift               Horizontal month strip; tap to jump, auto-tracks visible day
  DayRowView.swift             One day; renders compressed zones, ticks, packed events, "now" line
  TimeAxisHeader.swift         Hour labels along the top, aligned with the tracks
  EventBlock.swift             One event rectangle
  PermissionView.swift         Calendar access onboarding

  CalendarSource.swift         protocol + plain SourceEvent struct (EventKit-free)
  EventKitCalendarSource.swift production implementation
  CalendarStore.swift          @MainActor ObservableObject; owns loaded days + TimeAxis
  DayBucket.swift              One day's projected events
  DayEvent.swift               SourceEvent projected onto a single day
  LanePacker.swift             Greedy lane assignment for overlapping events
  TimeAxis.swift               Piecewise-linear time-to-x mapping + AxisLayout helper
  Theme.swift                  Dieter Rams design tokens (DR namespace)
```

The `CalendarSource` protocol is the boundary that keeps EventKit out of the
rest of the app — and lets `LendaTests` drive `CalendarStore` with a fake.

## Tests

`LendaTests` covers the public interfaces of the logic layer:

- `TimeAxisTests` — boundary invariants (0 → 0, 1440 → totalWidth, monotonic),
  compression behavior across event densities, hour-tick ordering and
  uniqueness, determinism.
- `LanePackerTests` — non-overlap on each lane, minimum-lane assignment, lane
  reuse after a cluster ends, stable start-time ordering.
- `CalendarStoreTests` — access lifecycle (grant / deny / throw), bucketing
  by day, multi-day splits, all-day handling, time-axis derivation, lazy
  range expansion via `ensureLoaded(around:)`, month-bar coverage.

Run with ⌘U in Xcode or `xcodebuild test -scheme Lenda -destination 'platform=iOS Simulator,name=iPhone 15'`.

## Build & run

Requires Xcode 16+. Deployment target: iOS 17.

```
open Lenda.xcodeproj
```

Pick an iPhone simulator and ⌘R. Add a few events in the simulator's Calendar
app first so there's something to render.
