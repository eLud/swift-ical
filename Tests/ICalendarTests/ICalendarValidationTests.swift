import Foundation
import XCTest
@testable import ICalendar

final class ICalendarValidationTests: XCTestCase {
    func testValidCalendarHasNoStructuralIssues() throws {
        let document = try ICalendarDocument.parse(
            """
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//swift-ical//Tests//EN
            BEGIN:VEVENT
            UID:abc
            DTSTAMP:20260519T120000Z
            DTSTART:20260519T130000Z
            SUMMARY:Valid
            END:VEVENT
            END:VCALENDAR
            """
        )

        XCTAssertEqual(document.validate(), [])
    }

    func testReportsMissingRequiredPropertiesWithoutBlockingParse() throws {
        let document = try ICalendarDocument.parse(
            """
            BEGIN:VCALENDAR
            BEGIN:VEVENT
            UID:abc
            END:VEVENT
            END:VCALENDAR
            """
        )

        let issues = document.validate()

        XCTAssertTrue(issues.contains { $0.code == .missingRequiredProperty && $0.message.contains("VERSION") })
        XCTAssertTrue(issues.contains { $0.code == .missingRequiredProperty && $0.message.contains("PRODID") })
        XCTAssertTrue(issues.contains { $0.code == .missingRequiredProperty && $0.message.contains("DTSTAMP") })
        XCTAssertTrue(issues.contains { $0.code == .missingRequiredProperty && $0.message.contains("DTSTART") })
    }

    func testReportsInvalidKnownComponentNesting() throws {
        let document = try ICalendarDocument.parse(
            """
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//swift-ical//Tests//EN
            BEGIN:VEVENT
            UID:abc
            DTSTAMP:20260519T120000Z
            DTSTART:20260519T130000Z
            BEGIN:VTODO
            UID:todo
            DTSTAMP:20260519T120000Z
            END:VTODO
            END:VEVENT
            END:VCALENDAR
            """
        )

        XCTAssertTrue(document.validate().contains {
            $0.code == .invalidChildComponent &&
                $0.componentPath.map(\.rawName) == ["VCALENDAR", "VEVENT", "VTODO"]
        })
    }

    func testReportsDuplicateSingletonAndMutuallyExclusiveProperties() throws {
        let document = try ICalendarDocument.parse(
            """
            BEGIN:VCALENDAR
            VERSION:2.0
            VERSION:2.0
            PRODID:-//swift-ical//Tests//EN
            BEGIN:VEVENT
            UID:abc
            UID:def
            DTSTAMP:20260519T120000Z
            DTSTART:20260519T130000Z
            DTEND:20260519T140000Z
            DURATION:PT1H
            END:VEVENT
            END:VCALENDAR
            """
        )

        let issues = document.validate()

        XCTAssertTrue(issues.contains { $0.code == .duplicateSingletonProperty && $0.message.contains("VERSION") })
        XCTAssertTrue(issues.contains { $0.code == .duplicateSingletonProperty && $0.message.contains("UID") })
        XCTAssertTrue(issues.contains { $0.code == .mutuallyExclusiveProperties && $0.message.contains("DTEND") })
    }

    func testUnknownComponentsAreWarnings() throws {
        let document = try ICalendarDocument.parse(
            """
            BEGIN:X-CUSTOM
            END:X-CUSTOM
            """
        )

        let issues = document.validate()

        XCTAssertTrue(issues.contains { $0.severity == .error && $0.code == .topLevelComponentMustBeVCalendar })
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.code == .unknownComponent })
    }
}
