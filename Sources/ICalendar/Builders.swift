import Foundation

public enum ICalendarBuilderError: Error, Sendable, Equatable, CustomStringConvertible {
    case mutuallyExclusiveEventEndAndDuration
    case invalidAllDayDateRange(start: ICalDate, end: ICalDate)

    public var description: String {
        switch self {
        case .mutuallyExclusiveEventEndAndDuration:
            "VEVENT builder cannot set both DTEND and DURATION"
        case .invalidAllDayDateRange(let start, let end):
            "All-day VEVENT DTEND must be later than DTSTART; got \(start.rawValue) and \(end.rawValue)"
        }
    }
}

public struct ICalendarBuilder: Sendable, Equatable {
    public var prodID: String
    public var version: String
    public var calendarProperties: [ICalProperty]
    public var events: [ICalEventBuilder]
    public var additionalComponents: [ICalComponent]

    public init(
        prodID: String = "-//swift-ical//EN",
        version: String = "2.0",
        calendarProperties: [ICalProperty] = [],
        events: [ICalEventBuilder] = [],
        additionalComponents: [ICalComponent] = []
    ) {
        self.prodID = prodID
        self.version = version
        self.calendarProperties = calendarProperties
        self.events = events
        self.additionalComponents = additionalComponents
    }

    public func document() throws -> ICalendarDocument {
        let properties = [
            ICalProperty(name: .known(.version), rawValue: version),
            ICalProperty(name: .known(.prodid), rawValue: prodID)
        ] + calendarProperties

        let children = try events.map { try $0.component() } + additionalComponents
        return ICalendarDocument(
            components: [
                ICalComponent(name: .vcalendar, properties: properties, children: children)
            ]
        )
    }
}

public enum ICalDateTimeEncoding: Sendable, Equatable {
    case utc
    case floating(TimeZone)
    case timeZone(String)

    public func dateTime(from date: Date) -> ICalDateTime {
        switch self {
        case .utc:
            return .utc(date)
        case .floating(let timeZone):
            return .floating(date, timeZone: timeZone)
        case .timeZone(let identifier):
            return .timeZone(identifier, date: date)
        }
    }
}

public struct ICalEventBuilder: Sendable, Equatable {
    public var uid: String
    public var start: ICalDateTime
    public var stamp: ICalDateTime
    public var end: ICalDateTime?
    public var duration: ICalDuration?
    public var summary: String?
    public var description: String?
    public var location: String?
    public var categories: [String]
    public var recurrenceRules: [ICalRecurrenceRule]
    public var recurrenceDates: [ICalDateTime]
    public var exceptionDates: [ICalDateTime]
    public var additionalProperties: [ICalProperty]

    public init(
        uid: String,
        start: ICalDateTime,
        stamp: ICalDateTime = .utc(Date()),
        end: ICalDateTime? = nil,
        duration: ICalDuration? = nil,
        summary: String? = nil,
        description: String? = nil,
        location: String? = nil,
        categories: [String] = [],
        recurrenceRules: [ICalRecurrenceRule] = [],
        recurrenceDates: [ICalDateTime] = [],
        exceptionDates: [ICalDateTime] = [],
        additionalProperties: [ICalProperty] = []
    ) {
        self.uid = uid
        self.start = start
        self.stamp = stamp
        self.end = end
        self.duration = duration
        self.summary = summary
        self.description = description
        self.location = location
        self.categories = categories
        self.recurrenceRules = recurrenceRules
        self.recurrenceDates = recurrenceDates
        self.exceptionDates = exceptionDates
        self.additionalProperties = additionalProperties
    }

    public init(
        uid: String,
        startDate: Date,
        stampDate: Date = Date(),
        endDate: Date? = nil,
        dateTimeEncoding: ICalDateTimeEncoding = .utc,
        duration: ICalDuration? = nil,
        summary: String? = nil,
        description: String? = nil,
        location: String? = nil,
        categories: [String] = [],
        recurrenceRules: [ICalRecurrenceRule] = [],
        recurrenceDates: [Date] = [],
        exceptionDates: [Date] = [],
        additionalProperties: [ICalProperty] = []
    ) {
        let encode = { dateTimeEncoding.dateTime(from: $0) }
        self.init(
            uid: uid,
            start: encode(startDate),
            stamp: .utc(stampDate),
            end: endDate.map(encode),
            duration: duration,
            summary: summary,
            description: description,
            location: location,
            categories: categories,
            recurrenceRules: recurrenceRules,
            recurrenceDates: recurrenceDates.map(encode),
            exceptionDates: exceptionDates.map(encode),
            additionalProperties: additionalProperties
        )
    }

    public init(
        uid: String,
        allDayDate: ICalDate,
        stampDate: Date = Date(),
        summary: String? = nil,
        description: String? = nil,
        location: String? = nil,
        categories: [String] = [],
        recurrenceRules: [ICalRecurrenceRule] = [],
        recurrenceDates: [ICalDate] = [],
        exceptionDates: [ICalDate] = [],
        additionalProperties: [ICalProperty] = []
    ) {
        self.init(
            uid: uid,
            allDayStart: allDayDate,
            allDayEnd: nil,
            stampDate: stampDate,
            summary: summary,
            description: description,
            location: location,
            categories: categories,
            recurrenceRules: recurrenceRules,
            recurrenceDates: recurrenceDates,
            exceptionDates: exceptionDates,
            additionalProperties: additionalProperties
        )
    }

    public init(
        uid: String,
        allDayStart: ICalDate,
        allDayEnd: ICalDate? = nil,
        stampDate: Date = Date(),
        duration: ICalDuration? = nil,
        summary: String? = nil,
        description: String? = nil,
        location: String? = nil,
        categories: [String] = [],
        recurrenceRules: [ICalRecurrenceRule] = [],
        recurrenceDates: [ICalDate] = [],
        exceptionDates: [ICalDate] = [],
        additionalProperties: [ICalProperty] = []
    ) {
        self.init(
            uid: uid,
            start: .allDay(allDayStart),
            stamp: .utc(stampDate),
            end: allDayEnd.map(ICalDateTime.allDay),
            duration: duration,
            summary: summary,
            description: description,
            location: location,
            categories: categories,
            recurrenceRules: recurrenceRules,
            recurrenceDates: recurrenceDates.map(ICalDateTime.allDay),
            exceptionDates: exceptionDates.map(ICalDateTime.allDay),
            additionalProperties: additionalProperties
        )
    }

    public func component() throws -> ICalComponent {
        if end != nil && duration != nil {
            throw ICalendarBuilderError.mutuallyExclusiveEventEndAndDuration
        }
        if let end, start.kind == .date, end.kind == .date, end.date <= start.date {
            throw ICalendarBuilderError.invalidAllDayDateRange(start: start.date, end: end.date)
        }

        var properties: [ICalProperty] = [
            textProperty(.uid, value: uid),
            dateOrDateTimeProperty(.dtstamp, value: stamp),
            dateOrDateTimeProperty(.dtstart, value: start)
        ]

        if let end {
            properties.append(dateOrDateTimeProperty(.dtend, value: end))
        }
        if let duration {
            properties.append(ICalProperty(name: .known(.duration), rawValue: duration.rawValue))
        }
        if let summary {
            properties.append(textProperty(.summary, value: summary))
        }
        if let description {
            properties.append(textProperty(.description, value: description))
        }
        if let location {
            properties.append(textProperty(.location, value: location))
        }
        if !categories.isEmpty {
            properties.append(
                ICalProperty(
                    name: .known(.categories),
                    rawValue: categories.map(ICalValue.encodeText).joined(separator: ",")
                )
            )
        }
        properties.append(contentsOf: recurrenceRules.map {
            ICalProperty(name: .known(.rrule), rawValue: $0.rawValue)
        })
        properties.append(contentsOf: dateCollectionProperties(.rdate, values: recurrenceDates))
        properties.append(contentsOf: dateCollectionProperties(.exdate, values: exceptionDates))
        properties.append(contentsOf: additionalProperties)

        return ICalComponent(name: .vevent, properties: properties)
    }
}

public extension ICalDateTime {
    static func allDay(_ date: ICalDate) -> ICalDateTime {
        ICalDateTime(date: date, hour: 0, minute: 0, second: 0, kind: .date)
    }

    static func utc(_ date: Date) -> ICalDateTime {
        dateTime(from: date, timeZone: TimeZone(secondsFromGMT: 0)!, kind: .utc)
    }

    static func floating(_ date: Date, timeZone: TimeZone = .current) -> ICalDateTime {
        dateTime(from: date, timeZone: timeZone, kind: .floating)
    }

    static func timeZone(_ identifier: String, date: Date) -> ICalDateTime {
        let timeZone = TimeZone(identifier: identifier) ?? .current
        return dateTime(from: date, timeZone: timeZone, kind: .timeZone(identifier))
    }

    private static func dateTime(from date: Date, timeZone: TimeZone, kind: Kind) -> ICalDateTime {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return ICalDateTime(
            date: ICalDate(
                year: components.year ?? 1970,
                month: components.month ?? 1,
                day: components.day ?? 1
            ),
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            kind: kind
        )
    }
}

public extension ICalDuration {
    var rawValue: String {
        if seconds == 0 {
            return "PT0S"
        }

        var remainder = abs(seconds)
        let days = remainder / 86_400
        remainder %= 86_400
        let hours = remainder / 3_600
        remainder %= 3_600
        let minutes = remainder / 60
        let secs = remainder % 60

        var result = seconds < 0 ? "-P" : "P"
        if days > 0 {
            result += "\(days)D"
        }
        if hours > 0 || minutes > 0 || secs > 0 {
            result += "T"
            if hours > 0 {
                result += "\(hours)H"
            }
            if minutes > 0 {
                result += "\(minutes)M"
            }
            if secs > 0 {
                result += "\(secs)S"
            }
        }
        return result
    }
}

public extension ICalRecurrenceRule {
    var rawValue: String {
        var fields = ["FREQ=\(frequency.rawValue)"]
        if let until {
            fields.append("UNTIL=\(until.rawValue)")
        }
        if let count {
            fields.append("COUNT=\(count)")
        }
        if interval != 1 {
            fields.append("INTERVAL=\(interval)")
        }
        if !bySecond.isEmpty {
            fields.append("BYSECOND=\(bySecond.map(String.init).joined(separator: ","))")
        }
        if !byMinute.isEmpty {
            fields.append("BYMINUTE=\(byMinute.map(String.init).joined(separator: ","))")
        }
        if !byHour.isEmpty {
            fields.append("BYHOUR=\(byHour.map(String.init).joined(separator: ","))")
        }
        if !byDay.isEmpty {
            fields.append("BYDAY=\(byDay.map(\.rawValue).joined(separator: ","))")
        }
        if !byMonthDay.isEmpty {
            fields.append("BYMONTHDAY=\(byMonthDay.map(String.init).joined(separator: ","))")
        }
        if !byYearDay.isEmpty {
            fields.append("BYYEARDAY=\(byYearDay.map(String.init).joined(separator: ","))")
        }
        if !byWeekNo.isEmpty {
            fields.append("BYWEEKNO=\(byWeekNo.map(String.init).joined(separator: ","))")
        }
        if !byMonth.isEmpty {
            fields.append("BYMONTH=\(byMonth.map(String.init).joined(separator: ","))")
        }
        if !bySetPos.isEmpty {
            fields.append("BYSETPOS=\(bySetPos.map(String.init).joined(separator: ","))")
        }
        if weekStart != .monday {
            fields.append("WKST=\(weekStart.rawValue)")
        }
        return fields.joined(separator: ";")
    }
}

public extension ICalRecurrenceRule.Weekday {
    var rawValue: String {
        if let ordinal {
            return "\(ordinal)\(symbol.rawValue)"
        }
        return symbol.rawValue
    }
}

private func textProperty(_ name: KnownICalProperty, value: String) -> ICalProperty {
    ICalProperty(name: .known(name), rawValue: ICalValue.encodeText(value))
}

private func dateOrDateTimeProperty(_ name: KnownICalProperty, value: ICalDateTime) -> ICalProperty {
    ICalProperty(
        name: .known(name),
        parameters: dateOrDateTimeParameters(for: value),
        rawValue: value.rawValue
    )
}

private func dateCollectionProperties(_ name: KnownICalProperty, values: [ICalDateTime]) -> [ICalProperty] {
    let grouped = Dictionary(grouping: values, by: DateCollectionKey.init)
    return grouped.keys.sorted().map { key in
        let groupedValues = grouped[key, default: []]
        return ICalProperty(
            name: .known(name),
            parameters: key.parameters,
            rawValue: groupedValues.map(\.rawValue).joined(separator: ",")
        )
    }
}

private func dateOrDateTimeParameters(for value: ICalDateTime) -> [ICalParameter] {
    switch value.kind {
    case .date:
        return [ICalParameter(name: "VALUE", values: ["DATE"])]
    case .timeZone(let identifier):
        return [ICalParameter(name: "TZID", values: [identifier])]
    case .floating, .utc:
        return []
    }
}

private struct DateCollectionKey: Hashable, Comparable {
    var sortRank: Int
    var timeZoneID: String?
    var parameters: [ICalParameter]

    init(_ value: ICalDateTime) {
        switch value.kind {
        case .date:
            sortRank = 0
            timeZoneID = nil
            parameters = [ICalParameter(name: "VALUE", values: ["DATE"])]
        case .floating:
            sortRank = 1
            timeZoneID = nil
            parameters = []
        case .utc:
            sortRank = 2
            timeZoneID = nil
            parameters = []
        case .timeZone(let identifier):
            sortRank = 3
            timeZoneID = identifier
            parameters = [ICalParameter(name: "TZID", values: [identifier])]
        }
    }

    static func < (lhs: DateCollectionKey, rhs: DateCollectionKey) -> Bool {
        (lhs.sortRank, lhs.timeZoneID ?? "") < (rhs.sortRank, rhs.timeZoneID ?? "")
    }
}
