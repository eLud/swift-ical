import Foundation
import XCTest
@testable import ICalendar

final class LibicalFixtureTests: XCTestCase {
    func testParsesVendoredLibicalICSFixtures() throws {
        let fixtureURLs = try validICSFixtureURLs()

        XCTAssertFalse(fixtureURLs.isEmpty)
        for url in fixtureURLs {
            let source = try String(contentsOf: url, encoding: .utf8)
            let document = try ICalendarDocument.parse(source)
            XCTAssertFalse(document.components.isEmpty, url.lastPathComponent)

            let serialized = try document.serialized()
            let reparsed = try ICalendarDocument.parse(serialized)
            XCTAssertEqual(reparsed, document, url.lastPathComponent)
        }
    }

    func testMalformedLibicalICSFixturesFailWithoutCrashing() throws {
        let malformedNames = ["caltime.ics"]

        for name in malformedNames {
            let url = try fixtureURL(named: name)
            let source = try String(contentsOf: url, encoding: .utf8)
            XCTAssertThrowsError(try ICalendarDocument.parse(source), name)
        }
    }

    func testCuratedLibicalRecurrenceGoldenCases() throws {
        let cases = try LibicalRecurrenceFixture.load(
            Bundle.module.url(
                forResource: "icalrecur_test",
                withExtension: "txt"
            ).unwrap()
        )
        let selected = cases.filter { Self.supportedRecurrenceCaseIDs.contains($0.id) }

        XCTAssertEqual(selected.count, Self.supportedRecurrenceCaseIDs.count)
        for recurrenceCase in selected {
            let actual = try recurrenceCase.expandedInstances()
            XCTAssertEqual(actual, recurrenceCase.instances, recurrenceCase.description)
        }
    }

    func testClassifiesFullLibicalRecurrenceCorpus() throws {
        let cases = try LibicalRecurrenceFixture.load(
            Bundle.module.url(
                forResource: "icalrecur_test",
                withExtension: "txt"
            ).unwrap()
        )
        let outcomes = cases.map { recurrenceCase in
            RecurrenceCompatibilityOutcome(fixture: recurrenceCase, actual: try? recurrenceCase.expandedInstances())
        }
        let supported = outcomes.filter(\.passes)
        let knownGaps = outcomes.filter { !$0.passes }

        XCTAssertEqual(cases.count, 146)
        XCTAssertEqual(supported.count, 78)
        XCTAssertEqual(knownGaps.count, 68)
        XCTAssertTrue(
            Self.supportedRecurrenceCaseIDs.isSubset(of: Set(supported.map(\.fixture.id))),
            "Curated supported cases must be included in the dynamic compatibility pass set."
        )
    }

    private static let supportedRecurrenceCaseIDs: Set<String> = [
        "Yearly in June and July for 10 occurrences|FREQ=YEARLY;COUNT=10;BYMONTH=6,7|19970610T090000",
        "Every other year on January, February, and March for 10 occurrences|FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3|19970310T090000",
        "Every third year on the 1st, 100th, and 200th day for 10 occurrences|FREQ=YEARLY;INTERVAL=3;COUNT=10;BYYEARDAY=1,100,200|19970101T090000",
        "Every 20th Monday of the year|FREQ=YEARLY;BYDAY=20MO;COUNT=3|19970519T090000",
        "Every Thursday in March|FREQ=YEARLY;BYMONTH=3;BYDAY=TH;COUNT=11|19970313T090000",
        "Monthly on the first Friday for 10 occurrences|FREQ=MONTHLY;COUNT=10;BYDAY=1FR|19970905T090000",
        "Monthly on the first Friday until December 24, 1997|FREQ=MONTHLY;UNTIL=19971224T000000Z;BYDAY=1FR|19970905T090000",
        "Monthly on the third-to-last day of the month|FREQ=MONTHLY;BYMONTHDAY=-3;COUNT=6|19970928T090000",
        "Monthly on the 2nd and 15th of the month for 10 occurrences|FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2,15|19970902T090000",
        "Every Friday the 13th|FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13;COUNT=5|19970902T090000"
    ]

    private func validICSFixtureURLs() throws -> [URL] {
        let validNames = Set([
            "0.ics",
            "1.ics",
            "1-1.ics",
            "2445.ics",
            "calendar.ics",
            "classify.ics"
        ])
        let directory = Bundle.module.resourceURL!
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { validNames.contains($0.lastPathComponent) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func fixtureURL(named name: String) throws -> URL {
        let url = Bundle.module.resourceURL!.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }
}

private struct LibicalRecurrenceFixture {
    var description: String
    var rule: String
    var start: String
    var instances: [String]

    var id: String {
        "\(description)|\(rule)|\(start)"
    }

    static func load(_ url: URL) throws -> [LibicalRecurrenceFixture] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var result: [LibicalRecurrenceFixture] = []
        var currentDescription: String?
        var currentRule: String?
        var currentStart: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                continue
            }
            if line.hasPrefix("#") {
                currentDescription = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("RRULE:") {
                currentRule = String(line.dropFirst("RRULE:".count))
            } else if line.hasPrefix("DTSTART:") {
                currentStart = String(line.dropFirst("DTSTART:".count))
            } else if line.hasPrefix("INSTANCES:"),
                      let description = currentDescription,
                      let rule = currentRule,
                      let start = currentStart {
                let instances = String(line.dropFirst("INSTANCES:".count))
                    .split(separator: ",")
                    .map(String.init)
                result.append(
                    LibicalRecurrenceFixture(
                        description: description,
                        rule: rule,
                        start: start,
                        instances: instances
                    )
                )
                currentRule = nil
                currentStart = nil
            }
        }

        return result
    }

    func expandedInstances() throws -> [String] {
        let source = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        UID:fixture
        DTSTART:\(start)
        RRULE:\(rule)
        END:VEVENT
        END:VCALENDAR
        """
        let event = try XCTUnwrap(try ICalendarDocument.parse(source).events.first)
        let startDate = try ICalDateTime.parse(start).dateValue(timeZoneResolver: FixedUTCResolver())
        let rangeEnd = try rangeEndDate(startDate: startDate)
        return try event.occurrences(
            between: startDate.addingTimeInterval(-1),
            and: rangeEnd,
            timeZoneResolver: FixedUTCResolver()
        )
        .map { format($0.start, like: start) }
    }

    private func rangeEndDate(startDate: Date) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let lastInstance = instances.last,
              !lastInstance.hasPrefix("***"),
              let lastDate = try? ICalDateTime.parse(lastInstance).dateValue(timeZoneResolver: FixedUTCResolver())
        else {
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate.addingTimeInterval(366 * 24 * 60 * 60)
        }
        return calendar.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate.addingTimeInterval(24 * 60 * 60)
    }

    private func format(_ date: Date, like sample: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let suffix = sample.hasSuffix("Z") ? "Z" : ""
        return String(
            format: "%04d%02d%02dT%02d%02d%02d%@",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0,
            suffix
        )
    }
}

private struct RecurrenceCompatibilityOutcome {
    var fixture: LibicalRecurrenceFixture
    var actual: [String]?

    var passes: Bool {
        actual == fixture.instances
    }
}

private struct FixedUTCResolver: ICalTimeZoneResolving {
    func timeZone(for kind: ICalDateTime.Kind) -> TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }
}

private extension Optional {
    func unwrap(file: StaticString = #filePath, line: UInt = #line) throws -> Wrapped {
        try XCTUnwrap(self, file: file, line: line)
    }
}
