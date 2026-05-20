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

    func testExpandsYearlyOrdinalWeekdayWithinByMonth() throws {
        let firstFriday = try parseSingleEvent(
            rrule: "FREQ=YEARLY;BYDAY=1FR;BYMONTH=4;UNTIL=20150101T000000Z",
            dtstart: "20100402T120000Z"
        )
        let lastFriday = try parseSingleEvent(
            rrule: "FREQ=YEARLY;BYDAY=-1FR;BYMONTH=10;UNTIL=20150101T000000Z",
            dtstart: "20101029T120000Z"
        )
        let range = try dateRange("20100101T000000Z", "20150101T000000Z")

        XCTAssertEqual(try firstFriday.occurrences(between: range.start, and: range.end).map { iso($0.start) }, [
            "2010-04-02T12:00:00Z",
            "2011-04-01T12:00:00Z",
            "2012-04-06T12:00:00Z",
            "2013-04-05T12:00:00Z",
            "2014-04-04T12:00:00Z"
        ])
        XCTAssertEqual(try lastFriday.occurrences(between: range.start, and: range.end).map { iso($0.start) }, [
            "2010-10-29T12:00:00Z",
            "2011-10-28T12:00:00Z",
            "2012-10-26T12:00:00Z",
            "2013-10-25T12:00:00Z",
            "2014-10-31T12:00:00Z"
        ])
    }

    func testExpandsYearlyByMonthDayUsingStartMonthWhenByMonthIsAbsent() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=YEARLY;BYMONTHDAY=29;COUNT=3",
            dtstart: "20240229"
        )
        let range = try dateRange("20240229T000000Z", "20330101T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { ymd($0.start) }, [
            "20240229",
            "20280229",
            "20320229"
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

    func testExpandsYearlyByWeekNumberIntervalsUsingWeekYear() throws {
        let week53 = try parseSingleEvent(
            rrule: "FREQ=YEARLY;BYWEEKNO=53;BYDAY=TU,SA;INTERVAL=6;UNTIL=20170101T000000Z",
            dtstart: "20100102T000000"
        )
        let week1 = try parseSingleEvent(
            rrule: "FREQ=YEARLY;BYWEEKNO=1;BYDAY=MO,TU;INTERVAL=3;UNTIL=20320101",
            dtstart: "20241231"
        )
        let week53Interval6FromNonMatchingStart = try parseSingleEvent(
            rrule: "FREQ=YEARLY;BYWEEKNO=53;INTERVAL=6;BYDAY=TH;COUNT=1",
            dtstart: "20270103T000000Z"
        )
        let week53Interval5FromNonMatchingStart = try parseSingleEvent(
            rrule: "FREQ=YEARLY;BYWEEKNO=53;INTERVAL=5;BYDAY=TH;COUNT=1",
            dtstart: "20270103T000000Z"
        )
        let week53Range = try dateRange("20100101T000000Z", "20170101T000000Z")
        let week1Range = try dateRange("20241231T000000Z", "20320101T000000Z")
        let issue1223Range = try dateRange("20270103T000000Z", "20940102T000000Z")

        XCTAssertEqual(try week53.occurrences(
            between: week53Range.start,
            and: week53Range.end,
            timeZoneResolver: RecurrenceTestUTCResolver()
        ).map { iso($0.start) }, [
            "2010-01-02T00:00:00Z",
            "2015-12-29T00:00:00Z",
            "2016-01-02T00:00:00Z"
        ])
        XCTAssertEqual(try week1.occurrences(between: week1Range.start, and: week1Range.end).map { ymd($0.start) }, [
            "20241231",
            "20280103",
            "20280104",
            "20301230",
            "20301231"
        ])
        XCTAssertEqual(try week53Interval6FromNonMatchingStart.occurrences(
            between: issue1223Range.start,
            and: issue1223Range.end
        ).map { iso($0.start) }, [
            "2093-12-31T00:00:00Z"
        ])
        XCTAssertEqual(try week53Interval5FromNonMatchingStart.occurrences(
            between: issue1223Range.start,
            and: issue1223Range.end
        ).map { iso($0.start) }, [
            "2032-12-30T00:00:00Z"
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

    func testExpandsDateOnlyUntilRecurrence() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=DAILY;BYMONTHDAY=20,-2;UNTIL=20250401",
            dtstart: "20250220"
        )
        let range = try dateRange("20250220T000000Z", "20250402T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { ymd($0.start) }, [
            "20250220",
            "20250227",
            "20250320",
            "20250330"
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

    func testExpandsWeeklyBySetPositionUsingFullPeriodCandidates() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=WEEKLY;BYDAY=MO,TU,SU,SA,TH;BYSETPOS=3,2;COUNT=4",
            dtstart: "20240102T120000Z"
        )
        let range = try dateRange("20240101T000000Z", "20240120T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2024-01-02T12:00:00Z",
            "2024-01-04T12:00:00Z",
            "2024-01-09T12:00:00Z",
            "2024-01-11T12:00:00Z"
        ])
    }

    func testExpandsHourlyBySetPositionUsingFullHourCandidates() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=HOURLY;BYMINUTE=0,10,20,30,40,50;BYSETPOS=-2,3;INTERVAL=2;COUNT=5",
            dtstart: "20241023T154000Z"
        )
        let range = try dateRange("20241023T150000Z", "20241023T210000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2024-10-23T15:40:00Z",
            "2024-10-23T17:20:00Z",
            "2024-10-23T17:40:00Z",
            "2024-10-23T19:20:00Z",
            "2024-10-23T19:40:00Z"
        ])
    }

    func testExpandsHourlyByMinuteCandidatesAcrossIntervalBuckets() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=HOURLY;BYHOUR=3,6;BYMINUTE=5,15,25;INTERVAL=7;COUNT=6",
            dtstart: "20250101T030500Z"
        )
        let range = try dateRange("20250101T000000Z", "20250108T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2025-01-01T03:05:00Z",
            "2025-01-01T03:15:00Z",
            "2025-01-01T03:25:00Z",
            "2025-01-07T06:05:00Z",
            "2025-01-07T06:15:00Z",
            "2025-01-07T06:25:00Z"
        ])
    }

    func testExpandsMinutelyBySetPositionUsingFullMinuteCandidates() throws {
        let event = try parseSingleEvent(
            rrule: "FREQ=MINUTELY;BYSECOND=0,10,20,30,40,50;BYSETPOS=-2,3;INTERVAL=2;COUNT=5",
            dtstart: "20241023T001540Z"
        )
        let range = try dateRange("20241023T001500Z", "20241023T002100Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "2024-10-23T00:15:40Z",
            "2024-10-23T00:17:20Z",
            "2024-10-23T00:17:40Z",
            "2024-10-23T00:19:20Z",
            "2024-10-23T00:19:40Z"
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

private struct RecurrenceTestUTCResolver: ICalTimeZoneResolving {
    func timeZone(for kind: ICalDateTime.Kind) -> TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }
}
