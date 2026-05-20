import Foundation

public struct ICalDate: Sendable, Equatable, Hashable, Comparable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func parse(_ raw: String) throws -> ICalDate {
        guard raw.count == 8,
              let year = Int(raw.prefix(4)),
              let month = Int(raw.dropFirst(4).prefix(2)),
              let day = Int(raw.suffix(2)),
              (1...12).contains(month),
              (1...31).contains(day)
        else {
            throw ICalendarValueError.invalidDate(raw)
        }
        return ICalDate(year: year, month: month, day: day)
    }

    public var rawValue: String {
        String(format: "%04d%02d%02d", year, month, day)
    }

    public static func < (lhs: ICalDate, rhs: ICalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public struct ICalDateTime: Sendable, Equatable, Hashable, Comparable {
    public enum Kind: Sendable, Equatable, Hashable {
        case floating
        case utc
        case timeZone(String)
    }

    public var date: ICalDate
    public var hour: Int
    public var minute: Int
    public var second: Int
    public var kind: Kind

    public init(date: ICalDate, hour: Int, minute: Int, second: Int, kind: Kind = .floating) {
        self.date = date
        self.hour = hour
        self.minute = minute
        self.second = second
        self.kind = kind
    }

    public static func parse(_ raw: String, timeZoneID: String? = nil) throws -> ICalDateTime {
        let isUTC = raw.hasSuffix("Z")
        let value = isUTC ? String(raw.dropLast()) : raw
        guard value.count == 15,
              value[value.index(value.startIndex, offsetBy: 8)] == "T"
        else {
            throw ICalendarValueError.invalidDateTime(raw)
        }
        let date = try ICalDate.parse(String(value.prefix(8)))
        guard let hour = Int(value.dropFirst(9).prefix(2)),
              let minute = Int(value.dropFirst(11).prefix(2)),
              let second = Int(value.dropFirst(13).prefix(2)),
              (0...23).contains(hour),
              (0...59).contains(minute),
              (0...60).contains(second)
        else {
            throw ICalendarValueError.invalidDateTime(raw)
        }
        let kind: Kind
        if isUTC {
            kind = .utc
        } else if let timeZoneID {
            kind = .timeZone(timeZoneID)
        } else {
            kind = .floating
        }
        return ICalDateTime(date: date, hour: hour, minute: minute, second: second, kind: kind)
    }

    public var rawValue: String {
        let base = "\(date.rawValue)T" + String(format: "%02d%02d%02d", hour, minute, second)
        if kind == .utc {
            return base + "Z"
        }
        return base
    }

    public func dateValue(timeZoneResolver: ICalTimeZoneResolving = .foundation) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZoneResolver.timeZone(for: kind)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = date.year
        components.month = date.month
        components.day = date.day
        components.hour = hour
        components.minute = minute
        components.second = min(second, 59)
        guard let value = calendar.date(from: components) else {
            throw ICalendarValueError.invalidDateTime(rawValue)
        }
        return value
    }

    public static func < (lhs: ICalDateTime, rhs: ICalDateTime) -> Bool {
        (lhs.date, lhs.hour, lhs.minute, lhs.second, lhs.rawValue) <
            (rhs.date, rhs.hour, rhs.minute, rhs.second, rhs.rawValue)
    }
}

public struct ICalDuration: Sendable, Equatable, Hashable {
    public var seconds: Int

    public init(seconds: Int) {
        self.seconds = seconds
    }

    public static func parse(_ raw: String) throws -> ICalDuration {
        var input = raw
        var sign = 1
        if input.first == "-" {
            sign = -1
            input.removeFirst()
        } else if input.first == "+" {
            input.removeFirst()
        }
        guard input.first == "P" else {
            throw ICalendarValueError.invalidDuration(raw)
        }
        input.removeFirst()

        var total = 0
        var number = ""
        var inTime = false
        for character in input {
            if character == "T" {
                inTime = true
                continue
            }
            if character.isNumber {
                number.append(character)
                continue
            }
            guard let value = Int(number) else {
                throw ICalendarValueError.invalidDuration(raw)
            }
            number = ""
            switch character {
            case "W": total += value * 7 * 24 * 60 * 60
            case "D": total += value * 24 * 60 * 60
            case "H" where inTime: total += value * 60 * 60
            case "M" where inTime: total += value * 60
            case "S" where inTime: total += value
            default: throw ICalendarValueError.invalidDuration(raw)
            }
        }
        guard number.isEmpty else {
            throw ICalendarValueError.invalidDuration(raw)
        }
        return ICalDuration(seconds: total * sign)
    }
}

public enum ICalPeriodEnd: Sendable, Equatable, Hashable {
    case end(ICalDateTime)
    case duration(ICalDuration)
}

public struct ICalPeriod: Sendable, Equatable, Hashable {
    public var start: ICalDateTime
    public var end: ICalPeriodEnd

    public init(start: ICalDateTime, end: ICalPeriodEnd) {
        self.start = start
        self.end = end
    }

    public static func parse(_ raw: String, timeZoneID: String? = nil) throws -> ICalPeriod {
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            throw ICalendarValueError.invalidPeriod(raw)
        }
        let start = try ICalDateTime.parse(String(parts[0]), timeZoneID: timeZoneID)
        if parts[1].first == "P" || parts[1].first == "+" || parts[1].first == "-" {
            return ICalPeriod(start: start, end: .duration(try ICalDuration.parse(String(parts[1]))))
        }
        return ICalPeriod(start: start, end: .end(try ICalDateTime.parse(String(parts[1]), timeZoneID: timeZoneID)))
    }
}

public protocol ICalTimeZoneResolving: Sendable {
    func timeZone(for kind: ICalDateTime.Kind) -> TimeZone
}

public struct FoundationTimeZoneResolver: ICalTimeZoneResolving {
    public init() {}

    public func timeZone(for kind: ICalDateTime.Kind) -> TimeZone {
        switch kind {
        case .utc:
            TimeZone(secondsFromGMT: 0)!
        case .floating:
            TimeZone.current
        case .timeZone(let identifier):
            TimeZone(identifier: identifier) ?? TimeZone.current
        }
    }
}

public extension ICalTimeZoneResolving where Self == FoundationTimeZoneResolver {
    static var foundation: FoundationTimeZoneResolver { FoundationTimeZoneResolver() }
}

public extension ICalValue {
    static func decodeText(_ raw: String) -> String {
        var result = ""
        var isEscaped = false
        for character in raw {
            if isEscaped {
                switch character {
                case "n", "N": result.append("\n")
                case "\\": result.append("\\")
                case ",": result.append(",")
                case ";": result.append(";")
                default: result.append(character)
                }
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }
        if isEscaped {
            result.append("\\")
        }
        return result
    }

    static func parseUTCOffset(_ raw: String) throws -> Int {
        guard raw.count == 5 || raw.count == 7,
              raw.first == "+" || raw.first == "-"
        else {
            throw ICalendarValueError.invalidUTCOffset(raw)
        }
        let sign = raw.first == "-" ? -1 : 1
        guard let hours = Int(raw.dropFirst().prefix(2)),
              let minutes = Int(raw.dropFirst(3).prefix(2))
        else {
            throw ICalendarValueError.invalidUTCOffset(raw)
        }
        let seconds = raw.count == 7 ? Int(raw.suffix(2)) ?? -1 : 0
        guard (0...23).contains(hours), (0...59).contains(minutes), (0...59).contains(seconds) else {
            throw ICalendarValueError.invalidUTCOffset(raw)
        }
        return sign * (hours * 3600 + minutes * 60 + seconds)
    }
}

public extension ICalProperty {
    var timeZoneID: String? {
        firstParameter("TZID")?.values.first
    }

    func dateValue() throws -> ICalDate {
        try ICalDate.parse(rawValue)
    }

    func dateTimeValue() throws -> ICalDateTime {
        try ICalDateTime.parse(rawValue, timeZoneID: timeZoneID)
    }

    func durationValue() throws -> ICalDuration {
        try ICalDuration.parse(rawValue)
    }

    func periodValue() throws -> ICalPeriod {
        try ICalPeriod.parse(rawValue, timeZoneID: timeZoneID)
    }

    func utcOffsetValue() throws -> Int {
        try ICalValue.parseUTCOffset(rawValue)
    }

    func integerValue() throws -> Int {
        guard let value = Int(rawValue) else {
            throw ICalendarValueError.invalidRecurrenceRule(rawValue)
        }
        return value
    }

    func booleanValue() throws -> Bool {
        switch rawValue.uppercased() {
        case "TRUE": true
        case "FALSE": false
        default: throw ICalendarValueError.invalidRecurrenceRule(rawValue)
        }
    }
}
