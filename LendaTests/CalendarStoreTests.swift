import XCTest
@testable import Lenda

/// Interface tests for `CalendarStore`. Treats the store as the observable boundary it
/// is for views: after each public API call, what does `access` / `days` / `timeAxis`
/// look like? No internal helpers are tested directly.
@MainActor
final class CalendarStoreTests: XCTestCase {

    private func makeStore(
        source: FakeCalendarSource = FakeCalendarSource(),
        windowPast: Int = 40,
        windowFuture: Int = 40,
        initialPast: Int = 3,
        initialFuture: Int = 4,
        expansionPad: Int = 2
    ) -> CalendarStore {
        CalendarStore(
            source: source,
            calendar: TestDate.calendar,
            today: TestDate.referenceToday,
            windowPastDays: windowPast,
            windowFutureDays: windowFuture,
            initialPastDays: initialPast,
            initialFutureDays: initialFuture,
            expansionPadDays: expansionPad,
            axisPadDays: 40
        )
    }

    // MARK: - Access lifecycle

    func test_initialState_isUnknownAndEmpty() {
        let store = makeStore()
        XCTAssertEqual(store.access, .unknown)
        XCTAssertTrue(store.days.isEmpty)
    }

    func test_grantedAccess_loadsDaysWithTodayMarked() async {
        let source = FakeCalendarSource()
        source.events = [.make(start: TestDate.date(day: 10, hour: 9),
                               end: TestDate.date(day: 10, hour: 10))]
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        XCTAssertEqual(store.access, .granted)
        // `days` is the full fixed window — its length never changes after grant,
        // which is the layout-stability contract the scroll view relies on.
        XCTAssertEqual(store.days.count, 40 + 40)
        let today = store.days.first(where: { $0.isToday })
        XCTAssertNotNil(today)
        XCTAssertEqual(today?.timedEvents.count, 1)
    }

    func test_ensureLoaded_neverChangesDayCount() async {
        let store = makeStore()
        await store.requestAccessAndLoad()
        let countBefore = store.days.count
        store.ensureLoaded(around: TestDate.date(day: 25))
        store.ensureLoaded(around: TestDate.date(month: 2, day: 1))
        XCTAssertEqual(store.days.count, countBefore,
                       "event loading must never grow or shrink the day array")
    }

    func test_deniedAccess_setsDeniedAndLeavesDaysEmpty() async {
        let source = FakeCalendarSource()
        source.accessOutcome = .deny
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        XCTAssertEqual(store.access, .denied)
        XCTAssertTrue(store.days.isEmpty)
    }

    func test_accessThrowing_setsDeniedAndExposesError() async {
        let source = FakeCalendarSource()
        source.accessOutcome = .throwError(NSError(domain: "T", code: 1))
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        XCTAssertEqual(store.access, .denied)
        XCTAssertNotNil(store.lastError)
    }

    // MARK: - Bucketing

    func test_eventsAreBucketedByLocalDay() async {
        let source = FakeCalendarSource()
        source.events = [
            .make(id: "mon", start: TestDate.date(day: 10, hour: 9),
                  end: TestDate.date(day: 10, hour: 10)),
            .make(id: "tue", start: TestDate.date(day: 11, hour: 14),
                  end: TestDate.date(day: 11, hour: 15))
        ]
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        let mon = store.dayBucket(for: TestDate.date(day: 10))
        let tue = store.dayBucket(for: TestDate.date(day: 11))
        XCTAssertEqual(mon?.timedEvents.map(\.id).first?.hasPrefix("mon"), true)
        XCTAssertEqual(tue?.timedEvents.map(\.id).first?.hasPrefix("tue"), true)
    }

    func test_multiDayEvent_splitsAcrossDayBuckets() async {
        let source = FakeCalendarSource()
        source.events = [.make(
            id: "long",
            start: TestDate.date(day: 10, hour: 22),
            end: TestDate.date(day: 11, hour: 2)
        )]
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        let day10 = store.dayBucket(for: TestDate.date(day: 10))?.timedEvents ?? []
        let day11 = store.dayBucket(for: TestDate.date(day: 11))?.timedEvents ?? []
        XCTAssertEqual(day10.count, 1)
        XCTAssertEqual(day11.count, 1)
        XCTAssertEqual(day10.first?.startMinute, 22 * 60)
        XCTAssertEqual(day10.first?.endMinute, 24 * 60)
        XCTAssertEqual(day11.first?.startMinute, 0)
        XCTAssertEqual(day11.first?.endMinute, 2 * 60)
    }

    func test_allDayEvents_areKeptSeparate() async {
        let source = FakeCalendarSource()
        source.events = [.make(
            id: "holiday",
            start: TestDate.date(day: 11),
            end: TestDate.date(day: 12),
            isAllDay: true
        )]
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        let bucket = store.dayBucket(for: TestDate.date(day: 11))
        XCTAssertEqual(bucket?.allDayEvents.count, 1)
        XCTAssertEqual(bucket?.timedEvents.count, 0)
    }

    // MARK: - Time axis

    func test_timeAxis_reflectsLoadedEvents() async {
        let source = FakeCalendarSource()
        source.events = [.make(
            start: TestDate.date(day: 10, hour: 9),
            end: TestDate.date(day: 10, hour: 10)
        )]
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        let ticks = store.timeAxis.hourTicks(totalWidth: 1000)
        // Hour 9 hosted an event; hour 2 didn't — so 9 must be wider.
        XCTAssertGreaterThan(ticks[9].width, ticks[2].width)
        XCTAssertFalse(ticks[9].isEmpty)
        XCTAssertTrue(ticks[2].isEmpty)
    }

    func test_timeAxis_withNoEvents_fallsBackToBusinessHours() async {
        let store = makeStore()
        await store.requestAccessAndLoad()
        // No events → business-hours bias: 10am must be wider than 2am.
        let ticks = store.timeAxis.hourTicks(totalWidth: 1000)
        XCTAssertGreaterThan(ticks[10].width, ticks[2].width)
    }

    // MARK: - Range expansion

    func test_ensureLoaded_expandsRangeForwardWhenDateBeyondEnd() async {
        let source = FakeCalendarSource()
        let store = makeStore(source: source, initialPast: 3, initialFuture: 4, expansionPad: 2)
        await store.requestAccessAndLoad()
        let beforeQueries = source.queryCount
        let originalEnd = store.rangeEnd

        // Day deep in the future.
        store.ensureLoaded(around: TestDate.date(day: 25))
        XCTAssertGreaterThan(source.queryCount, beforeQueries, "expansion should trigger a reload")
        XCTAssertGreaterThan(store.rangeEnd, originalEnd)
        XCTAssertTrue(store.days.contains(where: { TestDate.calendar.isDate($0.date, inSameDayAs: TestDate.date(day: 25)) }))
    }

    func test_ensureLoaded_expandsRangeBackwardWhenDateBeforeStart() async {
        let source = FakeCalendarSource()
        let store = makeStore(source: source, initialPast: 3, initialFuture: 4, expansionPad: 2)
        await store.requestAccessAndLoad()
        let originalStart = store.rangeStart

        store.ensureLoaded(around: TestDate.date(month: 2, day: 1))
        XCTAssertLessThan(store.rangeStart, originalStart)
    }

    func test_ensureLoaded_isNoOpInsideExistingRange() async {
        let source = FakeCalendarSource()
        let store = makeStore(source: source, initialPast: 3, initialFuture: 4, expansionPad: 2)
        await store.requestAccessAndLoad()
        let queriesAfterInitial = source.queryCount

        store.ensureLoaded(around: TestDate.referenceToday)
        XCTAssertEqual(source.queryCount, queriesAfterInitial,
                       "no expansion should mean no extra source queries")
    }

    // MARK: - Layout-stability contract

    func test_bucketIDs_stableAcrossEventLoads() async {
        let store = makeStore()
        await store.requestAccessAndLoad()
        let idsBefore = store.days.map(\.id)
        store.ensureLoaded(around: TestDate.date(day: 25))
        store.ensureLoaded(around: TestDate.date(month: 2, day: 1))
        XCTAssertEqual(store.days.map(\.id), idsBefore,
                       "loading events must not change row identities — that's what keeps scroll geometry stable")
    }

    func test_timeAxis_doesNotShiftWhenScrollingLoadsMoreEvents() async {
        let source = FakeCalendarSource()
        source.events = [
            .make(id: "near", start: TestDate.date(day: 10, hour: 9),
                  end: TestDate.date(day: 10, hour: 10)),
            .make(id: "far", start: TestDate.date(day: 25, hour: 5),
                  end: TestDate.date(day: 25, hour: 6))
        ]
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        let axisBefore = store.timeAxis
        store.ensureLoaded(around: TestDate.date(day: 25))
        XCTAssertEqual(store.dayBucket(for: TestDate.date(day: 25))?.timedEvents.count, 1,
                       "the far event should be loaded into its bucket")
        XCTAssertEqual(store.timeAxis, axisBefore,
                       "scroll-driven loading must not move the axis; only reload() rebuilds it")
    }

    // MARK: - Incremental fetching

    func test_ensureLoaded_fetchesOnlyTheMissingSlice() async {
        let source = FakeCalendarSource()
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        let oldEnd = store.rangeEnd
        store.ensureLoaded(around: TestDate.date(day: 25))
        XCTAssertEqual(source.lastQueryWindow?.0, oldEnd,
                       "forward expansion must query from where the loaded range ended, not re-fetch everything")
    }

    func test_reload_refetchesExactlyTheLoadedRange() async {
        let source = FakeCalendarSource()
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        let queriesBefore = source.queryCount
        store.reload()
        XCTAssertEqual(source.queryCount, queriesBefore + 1)
        XCTAssertEqual(source.lastQueryWindow?.0, store.rangeStart)
        XCTAssertEqual(source.lastQueryWindow?.1, store.rangeEnd)
    }

    func test_recurringOccurrences_shareAnID_butAllSurvive() async {
        // EventKit gives every occurrence of a recurring event the same
        // identifier. Dedup must key on id + start so occurrences don't collapse.
        let source = FakeCalendarSource()
        source.events = [
            .make(id: "weekly", start: TestDate.date(day: 10, hour: 9),
                  end: TestDate.date(day: 10, hour: 10)),
            .make(id: "weekly", start: TestDate.date(day: 11, hour: 9),
                  end: TestDate.date(day: 11, hour: 10))
        ]
        let store = makeStore(source: source)
        await store.requestAccessAndLoad()
        XCTAssertEqual(store.dayBucket(for: TestDate.date(day: 10))?.timedEvents.count, 1)
        XCTAssertEqual(store.dayBucket(for: TestDate.date(day: 11))?.timedEvents.count, 1)
    }

    // MARK: - Index lookups

    func test_dayIndex_boundsAndLookup() async {
        let store = makeStore()
        await store.requestAccessAndLoad()
        XCTAssertEqual(store.dayIndex(for: store.windowStart), 0)
        XCTAssertEqual(store.dayIndex(for: TestDate.referenceToday), 40)
        XCTAssertNil(store.dayIndex(for: TestDate.date(month: 1, day: 1)),
                     "dates before the window have no index")
        XCTAssertNil(store.dayIndex(for: store.windowEnd),
                     "windowEnd is exclusive — it has no bucket")
        XCTAssertEqual(store.dayBucket(for: TestDate.referenceToday)?.isToday, true)
    }

    // MARK: - Month bar driver

    func test_monthsInRange_coversAllLoadedDays() async {
        let store = makeStore()
        await store.requestAccessAndLoad()
        let months = store.monthsInRange
        XCTAssertGreaterThanOrEqual(months.count, 3, "loaded range should span at least 3 months")
        for day in store.days {
            let inSomeMonth = months.contains {
                TestDate.calendar.isDate(day.date, equalTo: $0, toGranularity: .month)
            }
            XCTAssertTrue(inSomeMonth, "every loaded day must fall inside the months bar list")
        }
    }
}
