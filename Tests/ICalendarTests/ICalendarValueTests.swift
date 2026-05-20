import Foundation
import XCTest
@testable import ICalendar

final class ICalendarValueTests: XCTestCase {
    func testParsesDateTimeKinds() throws {
        XCTAssertEqual(try ICalDate.parse("20260519").rawValue, "20260519")
        XCTAssertEqual(
            ICalDateTime(
                date: ICalDate(year: 2026, month: 5, day: 19),
                hour: 0,
                minute: 0,
                second: 0,
                kind: .date
            ).rawValue,
            "20260519"
        )
        XCTAssertEqual(try ICalDateTime.parse("20260519T120304Z").kind, .utc)
        XCTAssertEqual(
            try ICalDateTime.parse("20260519T120304", timeZoneID: "America/Toronto").kind,
            .timeZone("America/Toronto")
        )
    }

    func testRejectsImpossibleGregorianDates() {
        XCTAssertThrowsError(try ICalDate.parse("20230231"))
        XCTAssertThrowsError(try ICalDate.parse("20250229"))
        XCTAssertThrowsError(try ICalDateTime.parse("20230231T120000Z"))
    }

    func testParsesDurationsPeriodsAndOffsets() throws {
        XCTAssertEqual(try ICalDuration.parse("P1DT2H").seconds, 93_600)
        XCTAssertEqual(try ICalDuration.parse("-PT30M").seconds, -1_800)
        XCTAssertEqual(try ICalValue.parseUTCOffset("-0500"), -18_000)

        let period = try ICalPeriod.parse("20260519T120000Z/PT1H")
        XCTAssertEqual(period.start.rawValue, "20260519T120000Z")
        XCTAssertEqual(period.end, .duration(ICalDuration(seconds: 3_600)))
    }

    func testDecodesTextValues() {
        XCTAssertEqual(ICalValue.decodeText("Hello\\nA\\,B\\;C\\\\D"), "Hello\nA,B;C\\D")
    }

    func testRejectsInvalidRecurrenceNumericSelectors() {
        let invalidRules = [
            "FREQ=DAILY;BYSECOND=61",
            "FREQ=DAILY;BYMINUTE=60",
            "FREQ=DAILY;BYHOUR=24",
            "FREQ=YEARLY;BYMONTH=0",
            "FREQ=MONTHLY;BYMONTHDAY=0",
            "FREQ=YEARLY;BYYEARDAY=367",
            "FREQ=YEARLY;BYWEEKNO=-54",
            "FREQ=MONTHLY;BYSETPOS=0",
            "FREQ=YEARLY;BYDAY=0MO",
            "FREQ=YEARLY;BYDAY=54MO"
        ]

        for rule in invalidRules {
            XCTAssertThrowsError(try ICalRecurrenceRule.parse(rule), rule)
        }
    }
}
