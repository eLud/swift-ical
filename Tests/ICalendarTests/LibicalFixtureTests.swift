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
        XCTAssertEqual(supported.count, 120)
        XCTAssertEqual(knownGaps.count, 26)
        XCTAssertTrue(
            Self.supportedRecurrenceCaseIDs.isSubset(of: Set(supported.map(\.fixture.id))),
            "Curated supported cases must be included in the dynamic compatibility pass set."
        )
    }

    func testSummarizesKnownRecurrenceGapCategories() throws {
        let cases = try LibicalRecurrenceFixture.load(
            Bundle.module.url(
                forResource: "icalrecur_test",
                withExtension: "txt"
            ).unwrap()
        )
        let knownGaps = cases
            .map { RecurrenceCompatibilityOutcome(fixture: $0, actual: try? $0.expandedInstances()) }
            .filter { !$0.passes }

        let categoryCounts = knownGaps.reduce(into: [RecurrenceGapCategory: Int]()) { counts, outcome in
            for category in outcome.fixture.gapCategories {
                counts[category, default: 0] += 1
            }
        }

        XCTAssertEqual(
            categoryCounts,
            [
                .unsortedOrDuplicateByList: 17,
                .bySetPosition: 16,
                .negativeSelector: 12,
                .yearlyFrequency: 11,
                .timePartExpansion: 10,
                .dateOnlyStart: 9,
                .hourlyFrequency: 5,
                .monthlyFrequency: 4,
                .weekdayOrdinalSelector: 4,
                .byWeekNumber: 3,
                .dailyFrequency: 2,
                .minutelyFrequency: 2,
                .weeklyFrequency: 2
            ]
        )
    }

    private static let supportedRecurrenceCaseIDs: Set<String> = [
        "Yearly in June and July for 10 occurrences|FREQ=YEARLY;COUNT=10;BYMONTH=6,7|19970610T090000",
        "Every other year on January, February, and March for 10 occurrences|FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3|19970310T090000",
        "Every third year on the 1st, 100th, and 200th day for 10 occurrences|FREQ=YEARLY;INTERVAL=3;COUNT=10;BYYEARDAY=1,100,200|19970101T090000",
        "Every 20th Monday of the year|FREQ=YEARLY;BYDAY=20MO;COUNT=3|19970519T090000",
        "Monday of week number 20 (where the default start of the week is Monday)|FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO;COUNT=3|19970512T090000",
        "Monday of week number 20 (where the start of the week is Sunday)|FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO;WKST=SU;COUNT=3|19970512T090000",
        "Monday of week number 20 (where the start of the week is Friday)|FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO;WKST=FR;COUNT=3|19970512T090000",
        "Every Thursday in March|FREQ=YEARLY;BYMONTH=3;BYDAY=TH;COUNT=11|19970313T090000",
        "Monthly on the first Friday for 10 occurrences|FREQ=MONTHLY;COUNT=10;BYDAY=1FR|19970905T090000",
        "Monthly on the first Friday until December 24, 1997|FREQ=MONTHLY;UNTIL=19971224T000000Z;BYDAY=1FR|19970905T090000",
        "Monthly on the third-to-last day of the month|FREQ=MONTHLY;BYMONTHDAY=-3;COUNT=6|19970928T090000",
        "Monthly on the 2nd and 15th of the month for 10 occurrences|FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2,15|19970902T090000",
        "Every Friday the 13th|FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13;COUNT=5|19970902T090000",
        "time-related BY* should be ignored if DTSTART is date-only|FREQ=DAILY;BYMINUTE=1,2,3,4;INTERVAL=2;COUNT=3|20241018",
        "github issue1143|FREQ=YEARLY;BYWEEKNO=53;COUNT=1|20230101T000000Z"
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

    var gapCategories: Set<RecurrenceGapCategory> {
        let fields = ruleFields
        var result: Set<RecurrenceGapCategory> = []

        if !start.contains("T") {
            result.insert(.dateOnlyStart)
        }
        if fields["BYSETPOS"] != nil {
            result.insert(.bySetPosition)
        }
        if fields["BYWEEKNO"] != nil {
            result.insert(.byWeekNumber)
        }
        if fields.keys.contains(where: { ["BYHOUR", "BYMINUTE", "BYSECOND"].contains($0) }) {
            result.insert(.timePartExpansion)
        }
        if hasNegativeSelector(in: fields) {
            result.insert(.negativeSelector)
        }
        if fields["BYDAY", default: []].contains(where: { $0.contains(where: \.isNumber) }) {
            result.insert(.weekdayOrdinalSelector)
        }
        if hasUnsortedOrDuplicateBYList(in: fields) {
            result.insert(.unsortedOrDuplicateByList)
        }
        if let frequency = fields["FREQ"]?.first,
           let category = RecurrenceGapCategory(frequency: frequency) {
            result.insert(category)
        }

        return result
    }

    private var ruleFields: [String: [String]] {
        rule.split(separator: ";").reduce(into: [String: [String]]()) { fields, field in
            let parts = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                return
            }
            fields[String(parts[0]).uppercased()] = parts[1].split(separator: ",").map(String.init)
        }
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
        let startDate = try parseDateOrDateTime(start).dateValue(timeZoneResolver: FixedUTCResolver())
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
              let lastDate = try? parseDateOrDateTime(lastInstance).dateValue(timeZoneResolver: FixedUTCResolver())
        else {
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate.addingTimeInterval(366 * 24 * 60 * 60)
        }
        return calendar.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate.addingTimeInterval(24 * 60 * 60)
    }

    private func format(_ date: Date, like sample: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        if !sample.contains("T") {
            return String(
                format: "%04d%02d%02d",
                components.year ?? 0,
                components.month ?? 0,
                components.day ?? 0
            )
        }
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

    private func parseDateOrDateTime(_ raw: String) throws -> ICalDateTime {
        if raw.contains("T") {
            return try ICalDateTime.parse(raw)
        }
        let date = try ICalDate.parse(raw)
        return ICalDateTime(date: date, hour: 0, minute: 0, second: 0, kind: .date)
    }

    private func hasNegativeSelector(in fields: [String: [String]]) -> Bool {
        fields.contains { key, values in
            key.hasPrefix("BY") && values.contains { $0.hasPrefix("-") }
        }
    }

    private func hasUnsortedOrDuplicateBYList(in fields: [String: [String]]) -> Bool {
        fields.contains { key, values in
            guard key.hasPrefix("BY"), values.count > 1 else {
                return false
            }
            let normalized = values.map { $0.uppercased() }
            return normalized != Array(Set(normalized)).sorted()
        }
    }
}

private struct RecurrenceCompatibilityOutcome {
    var fixture: LibicalRecurrenceFixture
    var actual: [String]?

    var passes: Bool {
        actual == fixture.instances
    }
}

private enum RecurrenceGapCategory: String, CaseIterable, Hashable {
    case dateOnlyStart = "date-only DTSTART"
    case bySetPosition = "BYSETPOS"
    case byWeekNumber = "BYWEEKNO"
    case timePartExpansion = "BYHOUR/BYMINUTE/BYSECOND"
    case negativeSelector = "negative BY* selector"
    case weekdayOrdinalSelector = "ordinal BYDAY"
    case unsortedOrDuplicateByList = "unsorted or duplicate BY* list"
    case secondlyFrequency = "FREQ=SECONDLY"
    case minutelyFrequency = "FREQ=MINUTELY"
    case hourlyFrequency = "FREQ=HOURLY"
    case dailyFrequency = "FREQ=DAILY"
    case weeklyFrequency = "FREQ=WEEKLY"
    case monthlyFrequency = "FREQ=MONTHLY"
    case yearlyFrequency = "FREQ=YEARLY"

    init?(frequency: String) {
        switch frequency.uppercased() {
        case "SECONDLY":
            self = .secondlyFrequency
        case "MINUTELY":
            self = .minutelyFrequency
        case "HOURLY":
            self = .hourlyFrequency
        case "DAILY":
            self = .dailyFrequency
        case "WEEKLY":
            self = .weeklyFrequency
        case "MONTHLY":
            self = .monthlyFrequency
        case "YEARLY":
            self = .yearlyFrequency
        default:
            return nil
        }
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
