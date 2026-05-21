# swift-ical

`swift-ical` is a pure Swift iCalendar package. The runtime has no C dependency and is intended to work anywhere SwiftPM and Foundation are available.

The current implementation focuses on RFC 5545 iCalendar parsing, lossless component preservation, serialization, typed event access, and recurrence expansion.

## Alpha Status

`swift-ical` is approaching its first alpha release. The current API is useful
for parsing, inspecting, building, serializing, validating, and expanding common
RFC 5545 calendar data, but it should still be treated as pre-1.0.

Supported today:

- Lossless `.ics` parsing and serialization with unknown properties, parameters, components, and `X-` extensions preserved.
- Typed access for common `VEVENT` fields.
- Builder APIs for timed events, Swift `Date` inputs, all-day events, recurrence dates, exception dates, organizer, attendees, status, transparency, class, URL, and common text fields.
- Recurrence expansion for common RFC 5545 rules, including `RDATE` and `EXDATE`, with guardrails for large expansions.
- Non-blocking structural validation via `validate()`.

Known limitations before a stable `1.0`:

- Parsed `VTIMEZONE` components are preserved, but custom timezone transition expansion is not complete yet; Foundation-backed IANA timezone lookup is the primary path today.
- Typed convenience APIs currently focus on `VCALENDAR` and `VEVENT`; broader first-class builders/views for `VTODO`, `VJOURNAL`, `VFREEBUSY`, and `VALARM` can follow.
- Validation is intentionally lightweight and structural. Successful parsing does not mean the document is fully semantically valid for every RFC 5545 method or scheduling workflow.
- The fixture suite covers RFC examples and vendored libical cases, but more scrubbed real-world exports from Apple Calendar, Google Calendar, Outlook, Fastmail, Nextcloud, and similar clients would improve interop confidence.

## Usage

```swift
import ICalendar

let document = try ICalendarDocument.parse(icsString)

for event in document.events {
    print(event.uid ?? "missing uid")
    print(event.summary ?? "untitled")
    print(event.start?.rawValue ?? "missing start")
}

let serialized = try document.serialized()
```

## Building Calendars

```swift
let document = try ICalendarBuilder(
    prodID: "-//Example Corp//Calendar Demo//EN",
    events: [
        ICalEventBuilder(
            uid: "event-123",
            start: try ICalDateTime.parse("20260519T120000Z"),
            stamp: try ICalDateTime.parse("20260501T090000Z"),
            summary: "Team sync",
            description: "Weekly planning and blockers"
        )
    ]
).document()

let ics = try document.serialized()
```

You can also hand the builder native Swift `Date` values and choose how they
should be encoded in iCalendar:

```swift
let start = ISO8601DateFormatter().date(from: "2026-05-19T12:00:00Z")!

let document = try ICalendarBuilder(
    events: [
        ICalEventBuilder(
            uid: "event-456",
            startDate: start,
            dateTimeEncoding: .utc,
            summary: "Date-backed event"
        )
    ]
).document()
```

All-day events can be built with date-only values:

```swift
let document = try ICalendarBuilder(
    events: [
        ICalEventBuilder(
            uid: "anniversary-1",
            allDayDate: ICalDate(year: 2026, month: 5, day: 21),
            summary: "Anniversary"
        )
    ]
).document()
```

Common `VEVENT` fields also have typed builder support:

```swift
let event = ICalEventBuilder(
    uid: "event-789",
    startDate: start,
    summary: "Planning",
    url: "https://example.com/events/planning",
    status: .confirmed,
    transparency: .opaque,
    classification: .privateEvent,
    organizer: .mailto("owner@example.com", commonName: "Calendar Owner"),
    attendees: [
        .mailto("ada@example.com", commonName: "Ada Lovelace")
    ]
)
```

## Validation

Parsing is intentionally lossless and permissive: unknown properties, custom
components, and extensions are preserved. Use `validate()` when you want
non-blocking structural checks for common RFC 5545 constraints:

```swift
let issues = document.validate()

for issue in issues {
    print("\(issue.severity.rawValue): \(issue.message)")
}
```

## Recurrence

```swift
let event = document.events[0]
let occurrences = try event.occurrences(
    between: rangeStart,
    and: rangeEnd
)
```

The recurrence engine currently supports `FREQ`, `UNTIL`, `COUNT`, `INTERVAL`, `BYDAY`, `BYMONTH`, `BYMONTHDAY`, `BYYEARDAY`, `BYWEEKNO`, `BYHOUR`, `BYMINUTE`, `BYSECOND`, `BYSETPOS`, `WKST`, plus event-level `RDATE` and `EXDATE`.

## Fixture Status

Tests vendor a starter set of upstream `libical` fixtures:

- Valid `.ics` files are parsed, serialized, reparsed, and compared for lossless tree equality.
- One malformed/fuzz-style `.ics` fixture is tracked as an expected parser failure.
- The upstream `icalrecur_test.txt` file is vendored. All recurrence cases with upstream expected instances currently pass. The single upstream `*** UNIMPLEMENTED` case is tracked separately, and `swift-ical` has its own regression test for that rule.
- RFC 5545 example fixtures cover representative `VEVENT`, `VTODO`, `VJOURNAL`, `VFREEBUSY`, `VTIMEZONE`, and recurrence examples with parse/serialize/validate checks.

The vendored fixture suites are third-party test data and are not covered by
this project's Apache-2.0 license. See `THIRD_PARTY_NOTICES.md`.

## Development

```sh
swift test
```

CI runs `swift build` and `swift test` on macOS and Ubuntu.

## License

`swift-ical` runtime source code is licensed under the Apache License, Version
2.0. See `LICENSE`.

Third-party `libical` test fixtures under
`Tests/ICalendarTests/Fixtures/libical/` remain under the upstream `libical`
license terms and are not relicensed as Apache-2.0 by this project. They are
used only for tests and are not part of the public `ICalendar` runtime library.
See `THIRD_PARTY_NOTICES.md` and
`Tests/ICalendarTests/Fixtures/libical/LICENSE.md`.
