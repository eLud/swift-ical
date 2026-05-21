# Changelog

All notable changes to `swift-ical` will be documented in this file.

The format is based on Keep a Changelog, and this project uses Semantic
Versioning.

## 0.1.0 - 2026-05-21

Initial alpha release candidate.

### Added

- Pure Swift 6 SwiftPM package with the public `ICalendar` library product.
- Lossless RFC 5545-style iCalendar parser with folded-line support, CRLF normalization, quoted parameters, unknown property/component preservation, and structured parse diagnostics.
- Canonical serializer with CRLF output, 75-octet folding, parameter quoting, text escaping helpers, and content-line injection hardening.
- Low-level model types for documents, components, properties, parameters, typed names, dates, date-times, durations, periods, recurrence rules, and values.
- Typed `VCALENDAR` and `VEVENT` convenience accessors.
- Recurrence expansion for common RFC 5545 rules including `FREQ`, `UNTIL`, `COUNT`, `INTERVAL`, `BYDAY`, `BYMONTH`, `BYMONTHDAY`, `BYYEARDAY`, `BYWEEKNO`, `BYHOUR`, `BYMINUTE`, `BYSECOND`, `BYSETPOS`, `WKST`, plus event-level `RDATE` and `EXDATE`.
- Recurrence expansion guardrails for occurrence limits, iteration limits, and requested expansion duration.
- Non-blocking structural validation via `ICalendarDocument.validate()`.
- Builder APIs for timed events, native Swift `Date` inputs, all-day events, durations, recurrence dates, exception dates, organizer, attendees, URL, status, transparency, classification, categories, and common text fields.
- Fixture suites based on RFC 5545 examples and vendored libical parser/recurrence data.
- Third-party fixture license notices for vendored libical and RFC-derived test data.

### Known Limitations

- `VTIMEZONE` components are preserved, but custom transition expansion is not yet complete; Foundation-backed IANA timezone resolution is the supported path for now.
- Typed convenience APIs are currently strongest for `VCALENDAR` and `VEVENT`.
- Validation is intentionally structural and lightweight, not a full semantic scheduler validator.
- More real-world interop fixtures are planned before calling the API stable.
