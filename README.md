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
- The upstream `icalrecur_test.txt` file is vendored, with a curated set of currently supported recurrence cases asserted against golden instances.

The next compatibility milestone is to classify the full recurrence fixture file into supported cases and known gaps, then turn those gaps into passing cases incrementally.

## Development

```sh
swift test
```

CI runs `swift build` and `swift test` on macOS and Ubuntu.
