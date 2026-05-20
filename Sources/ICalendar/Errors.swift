import Foundation

public struct ParseOptions: Sendable, Equatable {
    public enum ControlCharacterPolicy: Sendable, Equatable {
        case keep
        case omit
        case error
    }

    public var controlCharacterPolicy: ControlCharacterPolicy
    public var allowsBareLF: Bool

    public static let `default` = ParseOptions()

    public init(controlCharacterPolicy: ControlCharacterPolicy = .keep, allowsBareLF: Bool = true) {
        self.controlCharacterPolicy = controlCharacterPolicy
        self.allowsBareLF = allowsBareLF
    }
}

public struct SerializationOptions: Sendable, Equatable {
    public var foldsLines: Bool
    public var maximumLineOctets: Int

    public static let `default` = SerializationOptions()

    public init(foldsLines: Bool = true, maximumLineOctets: Int = 75) {
        self.foldsLines = foldsLines
        self.maximumLineOctets = maximumLineOctets
    }
}

public enum ICalendarParseError: Error, Sendable, Equatable, CustomStringConvertible {
    case emptyContentLine(line: Int)
    case invalidContentLine(line: Int, reason: String)
    case controlCharacter(line: Int)
    case propertyOutsideComponent(line: Int, name: String)
    case mismatchedEnd(line: Int, expected: ICalComponentName, found: ICalComponentName)
    case unexpectedEnd(line: Int, name: ICalComponentName)
    case missingEnd(name: ICalComponentName)

    public var description: String {
        switch self {
        case .emptyContentLine(let line):
            "Empty content line at line \(line)"
        case .invalidContentLine(let line, let reason):
            "Invalid content line at line \(line): \(reason)"
        case .controlCharacter(let line):
            "Control character in content line at line \(line)"
        case .propertyOutsideComponent(let line, let name):
            "Property \(name) outside component at line \(line)"
        case .mismatchedEnd(let line, let expected, let found):
            "Mismatched END at line \(line): expected \(expected.rawName), found \(found.rawName)"
        case .unexpectedEnd(let line, let name):
            "Unexpected END:\(name.rawName) at line \(line)"
        case .missingEnd(let name):
            "Missing END:\(name.rawName)"
        }
    }
}

public enum ICalendarValueError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidDate(String)
    case invalidDateTime(String)
    case invalidDuration(String)
    case invalidPeriod(String)
    case invalidUTCOffset(String)
    case invalidRecurrenceRule(String)
    case unsupportedRecurrence(String)

    public var description: String {
        switch self {
        case .invalidDate(let value):
            "Invalid DATE value: \(value)"
        case .invalidDateTime(let value):
            "Invalid DATE-TIME value: \(value)"
        case .invalidDuration(let value):
            "Invalid DURATION value: \(value)"
        case .invalidPeriod(let value):
            "Invalid PERIOD value: \(value)"
        case .invalidUTCOffset(let value):
            "Invalid UTC-OFFSET value: \(value)"
        case .invalidRecurrenceRule(let value):
            "Invalid RECUR value: \(value)"
        case .unsupportedRecurrence(let value):
            "Unsupported recurrence rule: \(value)"
        }
    }
}

public enum ICalendarRecurrenceError: Error, Sendable, Equatable, CustomStringConvertible {
    case occurrenceLimitExceeded(limit: Int)
    case iterationLimitExceeded(limit: Int)
    case expansionDurationExceeded(maximum: TimeInterval)

    public var description: String {
        switch self {
        case .occurrenceLimitExceeded(let limit):
            "Recurrence expansion exceeded occurrence limit of \(limit)"
        case .iterationLimitExceeded(let limit):
            "Recurrence expansion exceeded iteration limit of \(limit)"
        case .expansionDurationExceeded(let maximum):
            "Recurrence expansion exceeded duration limit of \(maximum) seconds"
        }
    }
}
