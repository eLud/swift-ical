import Foundation
import XCTest
@testable import ICalendar

final class RFC5545FixtureTests: XCTestCase {
    func testRFC5545ExampleFixturesRoundTripAndValidate() throws {
        for name in Self.fixtureNames {
            let document = try parseFixture(named: name)
            let serialized = try document.serialized()
            let reparsed = try ICalendarDocument.parse(serialized)

            XCTAssertEqual(reparsed, document, name)
            XCTAssertEqual(document.validate().filter { $0.severity == .error }, [], name)
        }
    }

    func testRFC5545FreeBusyReplyUnfoldsStructuredPeriodList() throws {
        let document = try parseFixture(named: "rfc5545-freebusy-reply")
        let freeBusy = try XCTUnwrap(document.components.first?.children.first?.firstProperty(.freebusy))

        XCTAssertEqual(
            freeBusy.rawValue,
            "19971015T050000Z/PT8H30M,19971015T160000Z/PT5H30M,19971015T223000Z/PT6H30M"
        )
    }

    func testRFC5545JournalFixturePreservesFoldedEscapedText() throws {
        let document = try parseFixture(named: "rfc5545-journal-minutes")
        let description = try XCTUnwrap(document.components.first?.children.first?.firstProperty(.description))

        XCTAssertTrue(description.textValue.contains("Participants include Joe, Lisa, and Bob."))
        XCTAssertTrue(description.textValue.contains("\n2. Telephone Conference:"))
        XCTAssertTrue(description.textValue.contains("Henry Miller (Handsoff Insurance)"))
    }

    func testRFC5545DailyCountRecurrenceExample() throws {
        let document = try parseFixture(named: "rfc5545-recur-daily-count")
        let event = try XCTUnwrap(document.events.first)
        let range = try dateRange("19970902T000000Z", "19970912T000000Z")
        let occurrences = try event.occurrences(between: range.start, and: range.end)

        XCTAssertEqual(occurrences.map { iso($0.start) }, [
            "1997-09-02T13:00:00Z",
            "1997-09-03T13:00:00Z",
            "1997-09-04T13:00:00Z",
            "1997-09-05T13:00:00Z",
            "1997-09-06T13:00:00Z",
            "1997-09-07T13:00:00Z",
            "1997-09-08T13:00:00Z",
            "1997-09-09T13:00:00Z",
            "1997-09-10T13:00:00Z",
            "1997-09-11T13:00:00Z"
        ])
    }

    private static let fixtureNames = [
        "rfc5545-event-meeting",
        "rfc5545-event-anniversary",
        "rfc5545-todo-due-date",
        "rfc5545-journal-minutes",
        "rfc5545-freebusy-reply",
        "rfc5545-timezone-new-york-2007",
        "rfc5545-recur-daily-count"
    ]

    private func parseFixture(named name: String) throws -> ICalendarDocument {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "ics"))
        let source = try String(contentsOf: url, encoding: .utf8)
        return try ICalendarDocument.parse(source)
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
}
