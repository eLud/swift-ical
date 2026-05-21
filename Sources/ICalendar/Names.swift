import Foundation

public enum KnownICalProperty: String, CaseIterable, Sendable, Hashable {
    case action = "ACTION"
    case attendee = "ATTENDEE"
    case categories = "CATEGORIES"
    case calscale = "CALSCALE"
    case classification = "CLASS"
    case completed = "COMPLETED"
    case created = "CREATED"
    case description = "DESCRIPTION"
    case dtend = "DTEND"
    case dtstamp = "DTSTAMP"
    case dtstart = "DTSTART"
    case due = "DUE"
    case duration = "DURATION"
    case exdate = "EXDATE"
    case freebusy = "FREEBUSY"
    case geo = "GEO"
    case lastModified = "LAST-MODIFIED"
    case location = "LOCATION"
    case method = "METHOD"
    case organizer = "ORGANIZER"
    case priority = "PRIORITY"
    case prodid = "PRODID"
    case rdate = "RDATE"
    case recurrenceID = "RECURRENCE-ID"
    case relatedTo = "RELATED-TO"
    case repeatCount = "REPEAT"
    case resources = "RESOURCES"
    case rrule = "RRULE"
    case sequence = "SEQUENCE"
    case status = "STATUS"
    case summary = "SUMMARY"
    case transp = "TRANSP"
    case trigger = "TRIGGER"
    case tzid = "TZID"
    case tzname = "TZNAME"
    case tzoffsetfrom = "TZOFFSETFROM"
    case tzoffsetto = "TZOFFSETTO"
    case uid = "UID"
    case url = "URL"
    case version = "VERSION"
}

public enum ICalPropertyName: Sendable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    case known(KnownICalProperty)
    case xName(String)
    case ianaToken(String)

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(_ value: String) {
        let normalized = value.uppercased()
        if let known = KnownICalProperty(rawValue: normalized) {
            self = .known(known)
        } else if normalized.hasPrefix("X-") {
            self = .xName(normalized)
        } else {
            self = .ianaToken(normalized)
        }
    }

    public var rawName: String {
        switch self {
        case .known(let known):
            known.rawValue
        case .xName(let value), .ianaToken(let value):
            value
        }
    }

    public var description: String { rawName }
}

public enum ICalComponentName: Sendable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    case vcalendar
    case vevent
    case vtodo
    case vjournal
    case vfreebusy
    case vtimezone
    case valarm
    case standard
    case daylight
    case custom(String)

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(_ value: String) {
        switch value.uppercased() {
        case "VCALENDAR": self = .vcalendar
        case "VEVENT": self = .vevent
        case "VTODO": self = .vtodo
        case "VJOURNAL": self = .vjournal
        case "VFREEBUSY": self = .vfreebusy
        case "VTIMEZONE": self = .vtimezone
        case "VALARM": self = .valarm
        case "STANDARD": self = .standard
        case "DAYLIGHT": self = .daylight
        default: self = .custom(value.uppercased())
        }
    }

    public var rawName: String {
        switch self {
        case .vcalendar: "VCALENDAR"
        case .vevent: "VEVENT"
        case .vtodo: "VTODO"
        case .vjournal: "VJOURNAL"
        case .vfreebusy: "VFREEBUSY"
        case .vtimezone: "VTIMEZONE"
        case .valarm: "VALARM"
        case .standard: "STANDARD"
        case .daylight: "DAYLIGHT"
        case .custom(let value): value
        }
    }

    public var description: String { rawName }
}
