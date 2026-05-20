# swift-ical

`swift-ical` is a pure Swift iCalendar package. The runtime has no C dependency and is intended to work anywhere SwiftPM and Foundation are available.

The current implementation focuses on RFC 5545 iCalendar parsing, lossless component preservation, serialization, typed event access, and recurrence expansion.

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

The vendored `libical` fixtures are third-party test data and are not covered by
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
