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
        let supportedDescriptions = Set([
            "Yearly in June and July for 10 occurrences",
            "Every other year on January, February, and March for 10 occurrences",
            "Every third year on the 1st, 100th, and 200th day for 10 occurrences",
            "Every 20th Monday of the year",
            "Every Thursday in March",
            "Monthly on the first Friday for 10 occurrences",
            "Monthly on the first Friday until December 24, 1997",
            "Monthly on the third-to-last day of the month",
            "Monthly on the 2nd and 15th of the month for 10 occurrences",
            "Every Friday the 13th"
        ])
        let selected = cases.filter { supportedDescriptions.contains($0.description) }

        XCTAssertEqual(selected.count, supportedDescriptions.count)
        for recurrenceCase in selected {
            let actual = try recurrenceCase.expandedInstances()
            XCTAssertEqual(actual, recurrenceCase.instances, recurrenceCase.description)
        }
    }

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
        let rangeEnd = rangeEndDate(startDate: startDate)
        return try event.occurrences(
            between: startDate.addingTimeInterval(-1),
            and: rangeEnd,
            timeZoneResolver: FixedUTCResolver()
        )
        .map { format($0.start, like: start) }
    }

    private func rangeEndDate(startDate: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(byAdding: .year, value: 50, to: startDate) ?? startDate.addingTimeInterval(50 * 366 * 24 * 60 * 60)
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
