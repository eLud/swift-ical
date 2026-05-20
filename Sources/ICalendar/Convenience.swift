import Foundation

public struct ICalendarComponent: Sendable, Equatable {
    public var component: ICalComponent

    public init(component: ICalComponent) {
        self.component = component
    }

    public var events: [ICalEvent] {
        component.children(.vevent).map(ICalEvent.init(component:))
    }
}

public struct ICalEvent: Sendable, Equatable {
    public var component: ICalComponent

    public init(component: ICalComponent) {
        self.component = component
    }

    public var uid: String? {
        component.firstProperty(.uid)?.textValue
    }

    public var summary: String? {
        component.firstProperty(.summary)?.textValue
    }

    public var start: ICalDateTime? {
        try? component.firstProperty(.dtstart)?.dateOrDateTimeValue()
    }

    public var end: ICalDateTime? {
        try? component.firstProperty(.dtend)?.dateOrDateTimeValue()
    }

    public var recurrenceRules: [ICalRecurrenceRule] {
        component.properties(.rrule).compactMap { try? ICalRecurrenceRule.parse($0.rawValue) }
    }

    public func occurrences(
        between start: Date,
        and end: Date,
        timeZoneResolver: any ICalTimeZoneResolving = FoundationTimeZoneResolver()
    ) throws -> [ICalOccurrence] {
        guard let eventStart = self.start else {
            return []
        }

        let eventDuration = try occurrenceDuration(timeZoneResolver: timeZoneResolver)
        var occurrenceStarts = Set<Date>()

        if recurrenceRules.isEmpty {
            let date = try eventStart.dateValue(timeZoneResolver: timeZoneResolver)
            if date >= start && date < end {
                occurrenceStarts.insert(date)
            }
        } else {
            for rule in recurrenceRules {
                let dates = try rule.occurrences(
                    startingAt: eventStart,
                    between: start,
                    and: end,
                    timeZoneResolver: timeZoneResolver
                )
                occurrenceStarts.formUnion(dates)
            }
        }

        for property in component.properties(.rdate) {
            let values = property.rawValue.split(separator: ",").map(String.init)
            for value in values {
                let dateTime = try property.dateOrDateTimeValue(value)
                let date = try dateTime.dateValue(timeZoneResolver: timeZoneResolver)
                if date >= start && date < end {
                    occurrenceStarts.insert(date)
                }
            }
        }

        for property in component.properties(.exdate) {
            let values = property.rawValue.split(separator: ",").map(String.init)
            for value in values {
                let dateTime = try property.dateOrDateTimeValue(value)
                let date = try dateTime.dateValue(timeZoneResolver: timeZoneResolver)
                occurrenceStarts.remove(date)
            }
        }

        return occurrenceStarts.sorted().map { occurrenceStart in
            ICalOccurrence(
                start: occurrenceStart,
                end: occurrenceStart.addingTimeInterval(TimeInterval(eventDuration))
            )
        }
    }

    private func occurrenceDuration(timeZoneResolver: any ICalTimeZoneResolving) throws -> Int {
        if let explicitEnd = end, let explicitStart = start {
            let startDate = try explicitStart.dateValue(timeZoneResolver: timeZoneResolver)
            let endDate = try explicitEnd.dateValue(timeZoneResolver: timeZoneResolver)
            return max(0, Int(endDate.timeIntervalSince(startDate)))
        }
        if let duration = try component.firstProperty(.duration)?.durationValue() {
            return max(0, duration.seconds)
        }
        return 0
    }
}

public struct ICalOccurrence: Sendable, Equatable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public extension ICalendarDocument {
    var calendars: [ICalendarComponent] {
        components.filter { $0.name == .vcalendar }.map(ICalendarComponent.init(component:))
    }

    var events: [ICalEvent] {
        calendars.flatMap(\.events)
    }
}

private extension ICalProperty {
    func dateOrDateTimeValue() throws -> ICalDateTime {
        try dateOrDateTimeValue(rawValue)
    }

    func dateOrDateTimeValue(_ rawValue: String) throws -> ICalDateTime {
        if rawValue.contains("T") {
            return try ICalDateTime.parse(rawValue, timeZoneID: timeZoneID)
        }
        let date = try ICalDate.parse(rawValue)
        return ICalDateTime(date: date, hour: 0, minute: 0, second: 0, kind: .date)
    }
}
