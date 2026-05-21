import Foundation
import XCTest
@testable import ICalendar

final class ICalendarBuilderTests: XCTestCase {
    func testBuilderProducesValidCalendarThatRoundTrips() throws {
        let start = try ICalDateTime.parse("20260519T120000Z")
        let end = try ICalDateTime.parse("20260519T130000Z")
        let stamp = try ICalDateTime.parse("20260501T090000Z")
        let rule = try ICalRecurrenceRule.parse("FREQ=WEEKLY;COUNT=3;BYDAY=TU")

        let document = try ICalendarBuilder(
            prodID: "-//swift-ical//Builder Tests//EN",
            events: [
                ICalEventBuilder(
                    uid: "builder-1",
                    start: start,
                    stamp: stamp,
                    end: end,
                    summary: "Hello, builder",
                    description: "Line one\nLine two; with commas, too",
                    location: "Room A",
                    categories: ["TEAM", "R&D"],
                    recurrenceRules: [rule],
                    recurrenceDates: [try ICalDateTime.parse("20260526T120000Z")],
                    exceptionDates: [try ICalDateTime.parse("20260519T120000Z")]
                )
            ]
        ).document()

        let serialized = try document.serialized()
        let reparsed = try ICalendarDocument.parse(serialized)
        let event = try XCTUnwrap(reparsed.events.first)

        XCTAssertEqual(reparsed, document)
        XCTAssertEqual(reparsed.validate().filter { $0.severity == .error }, [])
        XCTAssertEqual(event.uid, "builder-1")
        XCTAssertEqual(event.summary, "Hello, builder")
        XCTAssertEqual(event.component.firstProperty(.description)?.textValue, "Line one\nLine two; with commas, too")
        XCTAssertEqual(event.component.firstProperty(.location)?.textValue, "Room A")
        XCTAssertEqual(event.component.firstProperty(.categories)?.rawValue, "TEAM,R&D")
        XCTAssertEqual(event.recurrenceRules.map(\.rawValue), [rule.rawValue])
        XCTAssertTrue(serialized.contains("DESCRIPTION:Line one\\nLine two\\; with commas\\, too"))
    }

    func testBuilderSupportsDurationAndOccurrenceExpansion() throws {
        let start = try ICalDateTime.parse("20260519T120000Z")
        let stamp = try ICalDateTime.parse("20260501T090000Z")
        let rule = try ICalRecurrenceRule.parse("FREQ=DAILY;COUNT=2")
        let document = try ICalendarBuilder(
            events: [
                ICalEventBuilder(
                    uid: "builder-2",
                    start: start,
                    stamp: stamp,
                    duration: ICalDuration(seconds: 3_600),
                    summary: "Duration Event",
                    recurrenceRules: [rule]
                )
            ]
        ).document()

        let event = try XCTUnwrap(document.events.first)
        let range = try dateRange("20260519T000000Z", "20260522T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2026-05-19T12:00:00Z",
            "2026-05-20T12:00:00Z"
        ])
        XCTAssertEqual(occurrences.map { iso($0.end) }, [
            "2026-05-19T13:00:00Z",
            "2026-05-20T13:00:00Z"
        ])
    }

    func testBuilderRejectsEndAndDurationTogether() throws {
        let start = try ICalDateTime.parse("20260519T120000Z")
        let end = try ICalDateTime.parse("20260519T130000Z")
        let stamp = try ICalDateTime.parse("20260501T090000Z")

        XCTAssertThrowsError(try ICalEventBuilder(
            uid: "builder-3",
            start: start,
            stamp: stamp,
            end: end,
            duration: ICalDuration(seconds: 600)
        ).component()) { error in
            XCTAssertEqual(error as? ICalendarBuilderError, .mutuallyExclusiveEventEndAndDuration)
        }
    }

    func testBuilderGroupsRDateValuesByKind() throws {
        let start = ICalDateTime(
            date: try ICalDate.parse("20260519"),
            hour: 0,
            minute: 0,
            second: 0,
            kind: .date
        )
        let stamp = try ICalDateTime.parse("20260501T090000Z")
        let event = try ICalEventBuilder(
            uid: "builder-4",
            start: start,
            stamp: stamp,
            recurrenceDates: [
                ICalDateTime(
                    date: try ICalDate.parse("20260520"),
                    hour: 0,
                    minute: 0,
                    second: 0,
                    kind: .date
                ),
                try ICalDateTime.parse("20260521T120000Z")
            ]
        ).component()

        let rdates = event.properties(.rdate)

        XCTAssertEqual(rdates.count, 2)
        XCTAssertTrue(rdates.contains { $0.firstParameter("VALUE")?.values == ["DATE"] && $0.rawValue == "20260520" })
        XCTAssertTrue(rdates.contains { $0.firstParameter("VALUE") == nil && $0.rawValue == "20260521T120000Z" })
    }

    func testDurationAndRecurrenceRawValueRoundTrip() throws {
        let duration = ICalDuration(seconds: 90_661)
        let rule = ICalRecurrenceRule(
            frequency: .monthly,
            until: try ICalDateTime.parse("20261231T235959Z"),
            count: 3,
            byDay: [.init(ordinal: 1, symbol: .monday)],
            bySetPos: [1]
        )

        XCTAssertEqual(try ICalDuration.parse(duration.rawValue), duration)
        XCTAssertEqual(try ICalRecurrenceRule.parse(rule.rawValue), rule)
    }

    func testBuilderAcceptsSwiftDateInputsInUTC() throws {
        let start = try instant("2026-05-19T12:00:00Z")
        let end = try instant("2026-05-19T13:00:00Z")
        let stamp = try instant("2026-05-01T09:00:00Z")
        let recurrenceDate = try instant("2026-05-26T12:00:00Z")
        let exceptionDate = try instant("2026-06-02T12:00:00Z")

        let document = try ICalendarBuilder(
            events: [
                ICalEventBuilder(
                    uid: "builder-date-utc",
                    startDate: start,
                    stampDate: stamp,
                    endDate: end,
                    dateTimeEncoding: .utc,
                    summary: "Date-backed event",
                    recurrenceDates: [recurrenceDate],
                    exceptionDates: [exceptionDate]
                )
            ]
        ).document()

        let serialized = try document.serialized()
        let event = try XCTUnwrap(document.events.first)

        XCTAssertTrue(serialized.contains("DTSTAMP:20260501T090000Z"))
        XCTAssertTrue(serialized.contains("DTSTART:20260519T120000Z"))
        XCTAssertTrue(serialized.contains("DTEND:20260519T130000Z"))
        XCTAssertTrue(serialized.contains("RDATE:20260526T120000Z"))
        XCTAssertTrue(serialized.contains("EXDATE:20260602T120000Z"))
        XCTAssertEqual(event.start?.rawValue, "20260519T120000Z")
    }

    func testBuilderAcceptsSwiftDateInputsWithTimeZoneIdentifier() throws {
        let start = try instant("2026-05-19T16:00:00Z")
        let stamp = try instant("2026-05-01T09:00:00Z")
        let recurrenceDate = try instant("2026-05-26T16:00:00Z")

        let document = try ICalendarBuilder(
            events: [
                ICalEventBuilder(
                    uid: "builder-date-tzid",
                    startDate: start,
                    stampDate: stamp,
                    dateTimeEncoding: .timeZone("America/Toronto"),
                    recurrenceDates: [recurrenceDate]
                )
            ]
        ).document()

        let serialized = try document.serialized()

        XCTAssertTrue(serialized.contains("DTSTART;TZID=America/Toronto:20260519T120000"))
        XCTAssertTrue(serialized.contains("RDATE;TZID=America/Toronto:20260526T120000"))
        XCTAssertTrue(serialized.contains("DTSTAMP:20260501T090000Z"))
    }

    func testBuilderSupportsSingleDayAllDayEvents() throws {
        let document = try ICalendarBuilder(
            events: [
                ICalEventBuilder(
                    uid: "builder-all-day-single",
                    allDayDate: try ICalDate.parse("20260521"),
                    stampDate: try instant("2026-05-01T09:00:00Z"),
                    summary: "Anniversary",
                    recurrenceDates: [try ICalDate.parse("20270521")],
                    exceptionDates: [try ICalDate.parse("20280521")]
                )
            ]
        ).document()

        let serialized = try document.serialized()
        let event = try XCTUnwrap(document.events.first)

        XCTAssertTrue(serialized.contains("DTSTAMP:20260501T090000Z"))
        XCTAssertTrue(serialized.contains("DTSTART;VALUE=DATE:20260521"))
        XCTAssertTrue(serialized.contains("RDATE;VALUE=DATE:20270521"))
        XCTAssertTrue(serialized.contains("EXDATE;VALUE=DATE:20280521"))
        XCTAssertFalse(serialized.contains("DTEND;VALUE=DATE"))
        XCTAssertEqual(event.start?.kind, .date)
        XCTAssertEqual(try reparsed(serialized), document)
    }

    func testBuilderSupportsMultiDayAllDayEventsWithExclusiveEndDate() throws {
        let document = try ICalendarBuilder(
            events: [
                ICalEventBuilder(
                    uid: "builder-all-day-range",
                    allDayStart: try ICalDate.parse("20260521"),
                    allDayEnd: try ICalDate.parse("20260524"),
                    stampDate: try instant("2026-05-01T09:00:00Z"),
                    summary: "Long weekend"
                )
            ]
        ).document()

        let serialized = try document.serialized()

        XCTAssertTrue(serialized.contains("DTSTART;VALUE=DATE:20260521"))
        XCTAssertTrue(serialized.contains("DTEND;VALUE=DATE:20260524"))
        XCTAssertEqual(try ICalendarDocument.parse(serialized), document)
    }

    func testBuilderRejectsAllDayEndDateBeforeOrEqualToStartDate() throws {
        XCTAssertThrowsError(try ICalEventBuilder(
            uid: "builder-all-day-invalid",
            allDayStart: try ICalDate.parse("20260521"),
            allDayEnd: try ICalDate.parse("20260521"),
            stampDate: try instant("2026-05-01T09:00:00Z")
        ).component()) { error in
            XCTAssertEqual(
                error as? ICalendarBuilderError,
                .invalidAllDayDateRange(
                    start: ICalDate(year: 2026, month: 5, day: 21),
                    end: ICalDate(year: 2026, month: 5, day: 21)
                )
            )
        }
    }

    private func dateRange(_ start: String, _ end: String) throws -> (start: Date, end: Date) {
        (
            try ICalDateTime.parse(start).dateValue(timeZoneResolver: FoundationTimeZoneResolver()),
            try ICalDateTime.parse(end).dateValue(timeZoneResolver: FoundationTimeZoneResolver())
        )
    }

    private func reparsed(_ serialized: String) throws -> ICalendarDocument {
        try ICalendarDocument.parse(serialized)
    }

    private func instant(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else {
            XCTFail("Failed to parse ISO8601 instant \(value)")
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
