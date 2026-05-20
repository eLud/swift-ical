import Foundation

public struct ICalendarDocument: Sendable, Equatable {
    public var components: [ICalComponent]

    public init(components: [ICalComponent] = []) {
        self.components = components
    }

    public static func parse(_ source: String, options: ParseOptions = .default) throws -> ICalendarDocument {
        try ICalendarParser(options: options).parse(source)
    }

    public func serialized(options: SerializationOptions = .default) throws -> String {
        try components.map { try $0.serialized(options: options) }.joined()
    }
}

public struct ICalComponent: Sendable, Equatable {
    public var name: ICalComponentName
    public var properties: [ICalProperty]
    public var children: [ICalComponent]

    public init(
        name: ICalComponentName,
        properties: [ICalProperty] = [],
        children: [ICalComponent] = []
    ) {
        self.name = name
        self.properties = properties
        self.children = children
    }

    public func firstProperty(_ name: KnownICalProperty) -> ICalProperty? {
        properties.first { $0.name == .known(name) }
    }

    public func properties(_ name: KnownICalProperty) -> [ICalProperty] {
        properties.filter { $0.name == .known(name) }
    }

    public func children(_ name: ICalComponentName) -> [ICalComponent] {
        children.filter { $0.name == name }
    }
}

public struct ICalProperty: Sendable, Equatable {
    public var name: ICalPropertyName
    public var parameters: [ICalParameter]
    public var rawValue: String

    public init(
        name: ICalPropertyName,
        parameters: [ICalParameter] = [],
        rawValue: String
    ) {
        self.name = name
        self.parameters = parameters
        self.rawValue = rawValue
    }

    public func firstParameter(_ name: String) -> ICalParameter? {
        let normalized = name.uppercased()
        return parameters.first { $0.name == normalized }
    }

    public var textValue: String {
        ICalValue.decodeText(rawValue)
    }
}

public struct ICalParameter: Sendable, Equatable, Hashable {
    public var name: String
    public var values: [String]

    public init(name: String, values: [String]) {
        self.name = name.uppercased()
        self.values = values
    }
}

public enum ICalValue: Sendable, Equatable {
    case raw(String)
    case text(String)
    case date(ICalDate)
    case dateTime(ICalDateTime)
    case duration(ICalDuration)
    case period(ICalPeriod)
    case utcOffset(seconds: Int)
    case integer(Int)
    case boolean(Bool)
    case uri(String)
    case list([ICalValue])
    case structured([[String]])
}
