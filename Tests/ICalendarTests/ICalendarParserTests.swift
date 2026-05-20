import Foundation
import XCTest
@testable import ICalendar

final class ICalendarParserTests: XCTestCase {
    func testParsesCalendarEventAndTypedFields() throws {
        let source = """
        BEGIN:VCALENDAR\r
        VERSION:2.0\r
        PRODID:-//swift-ical//Tests//EN\r
        BEGIN:VEVENT\r
        UID:123\r
        DTSTART:20260519T120000Z\r
        DTEND:20260519T130000Z\r
        SUMMARY:Hello\\, calendar\r
        END:VEVENT\r
        END:VCALENDAR\r
        """

        let document = try ICalendarDocument.parse(source)

        XCTAssertEqual(document.calendars.count, 1)
        XCTAssertEqual(document.events.count, 1)
        XCTAssertEqual(document.events[0].uid, "123")
        XCTAssertEqual(document.events[0].summary, "Hello, calendar")
        XCTAssertEqual(document.events[0].start?.rawValue, "20260519T120000Z")
    }

    func testPreservesUnknownPropertiesAndParameters() throws {
        let source = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        UID:abc
        X-MY-PROP;X-FOO="a,b";ALTREP="cid:part1":some:value
        END:VEVENT
        END:VCALENDAR
        """

        let document = try ICalendarDocument.parse(source)
        let event = try XCTUnwrap(document.components.first?.children.first)
        let property = try XCTUnwrap(event.properties.first { $0.name.rawName == "X-MY-PROP" })

        XCTAssertEqual(property.rawValue, "some:value")
        XCTAssertEqual(property.parameters[0], ICalParameter(name: "X-FOO", values: ["a,b"]))
        XCTAssertEqual(property.parameters[1], ICalParameter(name: "ALTREP", values: ["cid:part1"]))
    }

    func testUnfoldsFoldedLines() throws {
        let source = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        UID:abc
        DESCRIPTION:hello
         world
        END:VEVENT
        END:VCALENDAR
        """

        let document = try ICalendarDocument.parse(source)
        let description = document.events[0].component.firstProperty(.description)

        XCTAssertEqual(description?.rawValue, "helloworld")
    }

    func testSerializesWithCRLFAndRoundTrips() throws {
        let source = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        UID:abc
        SUMMARY:Round trip
        END:VEVENT
        END:VCALENDAR
        """

        let document = try ICalendarDocument.parse(source)
        let serialized = try document.serialized()
        let reparsed = try ICalendarDocument.parse(serialized)

        XCTAssertTrue(serialized.contains("\r\n"))
        XCTAssertEqual(reparsed, document)
    }

    func testFoldsLongSerializedLines() throws {
        let longSummary = String(repeating: "a", count: 90)
        let document = ICalendarDocument(components: [
            ICalComponent(name: .vcalendar, properties: [
                ICalProperty(name: .known(.version), rawValue: "2.0")
            ], children: [
                ICalComponent(name: .vevent, properties: [
                    ICalProperty(name: .known(.uid), rawValue: "abc"),
                    ICalProperty(name: .known(.summary), rawValue: longSummary)
                ])
            ])
        ])

        let serialized = try document.serialized()

        XCTAssertTrue(serialized.contains("\r\n "))
        XCTAssertEqual(try ICalendarDocument.parse(serialized), document)
    }

    func testRejectsMismatchedEnd() {
        let source = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        END:VTODO
        END:VCALENDAR
        """

        XCTAssertThrowsError(try ICalendarDocument.parse(source))
    }

    func testControlCharacterPolicyCanOmitOrError() throws {
        let source = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDESCRIPTION:a\u{0015}b\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
        let omitted = try ICalendarDocument.parse(source, options: ParseOptions(controlCharacterPolicy: .omit))

        XCTAssertEqual(omitted.events[0].component.firstProperty(.description)?.rawValue, "ab")
        XCTAssertThrowsError(try ICalendarDocument.parse(source, options: ParseOptions(controlCharacterPolicy: .error)))
    }
}
