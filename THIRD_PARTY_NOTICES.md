# Third-Party Notices

Unless otherwise noted, `swift-ical` source code is licensed under the Apache
License, Version 2.0. See `LICENSE`.

## libical test fixtures

The files under `Tests/ICalendarTests/Fixtures/libical/` are third-party test
fixtures vendored from the upstream `libical/libical` project:

- `Tests/ICalendarTests/Fixtures/libical/ics/*.ics`
- `Tests/ICalendarTests/Fixtures/libical/recurrence/icalrecur_test.txt`

These files are used only by the test suite as compatibility fixtures. They are
not part of the public `ICalendar` runtime library target, and `swift-ical` does
not link against or redistribute the `libical` C runtime.

These vendored fixture files are not relicensed under `swift-ical`'s Apache-2.0
license. They remain available under the upstream `libical` license terms. The
upstream `libical` project states that it is distributed under either:

- Mozilla Public License 2.0 (`MPL-2.0`), or
- GNU Lesser General Public License 2.1 (`LGPL-2.1`).

Upstream source and license:

- https://github.com/libical/libical
- https://github.com/libical/libical/blob/master/LICENSE.txt
- https://github.com/libical/libical/blob/master/LICENSES/MPL-2.0.txt
- https://github.com/libical/libical/blob/master/LICENSES/LGPL-2.1-only.txt

Local copies of these license texts are included under
`Tests/ICalendarTests/Fixtures/libical/LICENSES/`.

## RFC 5545 example fixtures

The files under `Tests/ICalendarTests/Fixtures/rfc5545/` are test fixtures
based on examples from RFC 5545, "Internet Calendaring and Scheduling Core
Object Specification (iCalendar)".

These files are used only by the test suite and are not part of the public
`ICalendar` runtime library target. RFC 5545 is copyright (c) 2009 IETF Trust
and the persons identified as the document authors, and is subject to BCP 78 and
the IETF Trust's Legal Provisions Relating to IETF Documents.

These fixture files are not relicensed under `swift-ical`'s Apache-2.0 license.

RFC source and license information:

- https://www.rfc-editor.org/rfc/rfc5545
- https://trustee.ietf.org/license-info
