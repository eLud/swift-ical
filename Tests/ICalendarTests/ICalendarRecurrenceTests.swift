import Foundation
import XCTest
@testable import ICalendar

final class ICalendarRecurrenceTests: XCTestCase {
    func testExpandsDailyCountRule() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=DAILY;COUNT=3",
            dtstart: "20260519T090000Z"
        )
        let range = try dateRange("20260519T000000Z", "20260523T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2026-05-19T09:00:00Z",
            "2026-05-20T09:00:00Z",
            "2026-05-21T09:00:00Z"
        ])
    }

    func testExpandsYearlyByMonthRuleLikeLibicalFixture() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=YEARLY;COUNT=4;BYMONTH=6,7",
            dtstart: "19970610T090000Z"
        )
        let range = try dateRange("19970101T000000Z", "20000101T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "1997-06-10T09:00:00Z",
            "1997-07-10T09:00:00Z",
            "1998-06-10T09:00:00Z",
            "1998-07-10T09:00:00Z"
        ])
    }

    func testExpandsYearlyByWeekNumberUsingRFCWeekOne() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=YEARLY;BYWEEKNO=53;COUNT=1",
            dtstart: "20230101T000000Z"
        )
        let range = try dateRange("20230101T000000Z", "20280101T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2027-01-03T00:00:00Z"
        ])
    }

    func testExpandsDateOnlyRecurrenceIgnoringTimeParts() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=DAILY;BYMINUTE=1,2,3,4;INTERVAL=2;COUNT=3",
            dtstart: "20241018"
        )
        let range = try dateRange("20241018T000000Z", "20241025T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { ymd($0.start) }, [
            "20241018",
            "20241020",
            "20241022"
        ])
    }

    func testExpandsWeeklyByDayRule() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=WEEKLY;COUNT=4;BYDAY=MO,WE",
            dtstart: "20260518T090000Z"
        )
        let range = try dateRange("20260518T000000Z", "20260601T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2026-05-18T09:00:00Z",
            "2026-05-20T09:00:00Z",
            "2026-05-25T09:00:00Z",
            "2026-05-27T09:00:00Z"
        ])
    }

    func testExpandsMonthlyBySetPositionRule() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=MONTHLY;COUNT=3;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1",
            dtstart: "20260501T090000Z"
        )
        let range = try dateRange("20260501T000000Z", "20260801T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2026-05-01T09:00:00Z",
            "2026-06-01T09:00:00Z",
            "2026-07-01T09:00:00Z"
        ])
    }

    func testAppliesRDateAndExDate() throws {
        let source = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        UID:abc
        DTSTART:20260519T090000Z
        RRULE:FREQ=DAILY;COUNT=3
        RDATE:20260525T090000Z
        EXDATE:20260520T090000Z
        END:VEVENT
        END:VCALENDAR
        """
        let event = try XCTUnwrap(try ICalendarDocument.parse(source).events.first)
        let range = try dateRange("20260519T000000Z", "20260526T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2026-05-19T09:00:00Z",
            "2026-05-21T09:00:00Z",
            "2026-05-25T09:00:00Z"
        ])
    }

    private func parseSingleEvent(rrule: String, dtstart: String) throws -> ICalEvent {
        let source = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        UID:abc
        DTSTART:\(dtstart)
        RRULE:\(rrule)
        END:VEVENT
        END:VCALENDAR
        """
        return try XCTUnwrap(try ICalendarDocument.parse(source).events.first)
    }

    private func dateRange(_ start: String, _ end: String) throws -> (start: Date, end: Date) {
        (
            try ICalDateTime.parse(start).dateValue(timeZoneResolver: FoundationTimeZoneResolver()),
            try ICalDateTime.parse(end).dateValue(timeZoneResolver: FoundationTimeZoneResolver())
        )
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func ymd(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
