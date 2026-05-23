# Lenda

A smarter iPhone week view for your iCloud / iOS calendars.

## Why

iCal's week view wastes most of its space on empty hours and forces horizontal
scrolling to see a whole day. Lenda does the opposite:

- **7 day rows stacked vertically**, today on top. Each row is a full day rendered
  horizontally.
- **No horizontal scrolling.** Every day fits edge to edge.
- **Dynamic hour width.** The time axis is shared across the week. Hours where
  *no day* has any event get compressed to a thin hatched strip; busy hours
  expand to fill the rest of the width. So 2 AM – 7 AM with nothing happening
  becomes a sliver, and your 9–11 AM crunch gets the real estate it deserves.
- **Time stays aligned across days,** so you can scan a column and compare
  what's happening at, say, 10 AM across the week.
- **Today is highlighted** with an accent border and a live "now" indicator.

## Architecture

- `LendaApp.swift` – `@main` SwiftUI entry point, wires up `CalendarStore`.
- `CalendarStore.swift` – EventKit access, loads the next 7 days into
  `DayBucket`s.
- `Models.swift` – `DayEvent`, `DayBucket` data types.
- `TimeAxis.swift` – the piecewise-linear time-to-x mapping that compresses
  empty hours. Pure logic, unit-testable.
- `WeekView.swift` – top-level layout. Builds the shared `TimeAxis` from every
  timed event in the week, then renders a header + 7 stacked `DayRowView`s.
- `DayRowView.swift` – one day. Renders the day's track with compressed-zone
  hatching, hour gridlines, lane-packed event blocks, and (on today) a "now"
  bar.
- `TimeAxisHeader.swift` – the hour labels along the top.
- `EventBlock.swift` – one event rectangle.

## How the time axis works

`TimeAxis.build(from:)` takes every timed event's `(startMinute, endMinute)`
across the whole week, unions them with a 30-minute padding, then walks the
day from 00:00 → 24:00:

1. Anywhere events overlap → **dense** segment, weight = its minute span.
2. Gaps shorter than 90 min → stay **dense** (so neighboring meetings don't
   look weirdly far apart).
3. Gaps ≥ 90 min → **compressed**, weight = 30 (≈ half an hour's worth of
   pixels regardless of how many real hours it spans).

The total weight maps to the available width, and `x(forMinute:totalWidth:)`
returns a piecewise-linear x for any time-of-day. Every day row uses the same
axis, so columns line up.

## Requirements

- Xcode 16 or newer (uses file-system-synchronized project groups).
- iOS 17 deployment target.
- The first launch will request Calendar access via `EKEventStore`.

## Build & run

```
open Lenda.xcodeproj
```

Pick a simulator (iPhone 15 or newer) or your device, and ⌘R. On a fresh
simulator you'll want to add a few events in the Calendar app first so there's
something to render.
