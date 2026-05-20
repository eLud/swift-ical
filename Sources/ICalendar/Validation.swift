import Foundation

public struct ICalendarValidationIssue: Sendable, Equatable {
    public enum Severity: String, Sendable, Equatable {
        case warning
        case error
    }

    public enum Code: String, Sendable, Equatable {
        case topLevelComponentMustBeVCalendar
        case nestedVCalendar
        case invalidChildComponent
        case unknownComponent
        case missingRequiredProperty
        case duplicateSingletonProperty
        case mutuallyExclusiveProperties
    }

    public var severity: Severity
    public var code: Code
    public var componentPath: [ICalComponentName]
    public var message: String

    public init(severity: Severity, code: Code, componentPath: [ICalComponentName], message: String) {
        self.severity = severity
        self.code = code
        self.componentPath = componentPath
        self.message = message
    }
}

public extension ICalendarDocument {
    func validate() -> [ICalendarValidationIssue] {
        var issues: [ICalendarValidationIssue] = []
        for component in components {
            let path = [component.name]
            if component.name != .vcalendar {
                issues.append(
                    ICalendarValidationIssue(
                        severity: .error,
                        code: .topLevelComponentMustBeVCalendar,
                        componentPath: path,
                        message: "Top-level component must be VCALENDAR, found \(component.name.rawName)"
                    )
                )
            }
            validateComponent(component, parent: nil, path: path, issues: &issues)
        }
        return issues
    }
}

private func validateComponent(
    _ component: ICalComponent,
    parent: ICalComponentName?,
    path: [ICalComponentName],
    issues: inout [ICalendarValidationIssue]
) {
    validateKnownComponent(component, parent: parent, path: path, issues: &issues)
    validateRequiredProperties(component, path: path, issues: &issues)
    validateSingletonProperties(component, path: path, issues: &issues)
    validateMutuallyExclusiveProperties(component, path: path, issues: &issues)

    for child in component.children {
        validateComponent(child, parent: component.name, path: path + [child.name], issues: &issues)
    }
}

private func validateKnownComponent(
    _ component: ICalComponent,
    parent: ICalComponentName?,
    path: [ICalComponentName],
    issues: inout [ICalendarValidationIssue]
) {
    if component.name == .vcalendar, parent != nil {
        issues.append(
            ICalendarValidationIssue(
                severity: .error,
                code: .nestedVCalendar,
                componentPath: path,
                message: "VCALENDAR must not be nested inside another component"
            )
        )
    }

    if case .custom = component.name {
        issues.append(
            ICalendarValidationIssue(
                severity: .warning,
                code: .unknownComponent,
                componentPath: path,
                message: "Unknown component \(component.name.rawName) is preserved but not structurally validated"
            )
        )
        return
    }

    guard let parent else {
        return
    }

    if case .custom = parent {
        return
    }

    let allowedChildren = allowedChildComponents(for: parent)
    if !allowedChildren.contains(component.name) {
        issues.append(
            ICalendarValidationIssue(
                severity: .error,
                code: .invalidChildComponent,
                componentPath: path,
                message: "\(component.name.rawName) is not a valid child of \(parent.rawName)"
            )
        )
    }
}

private func validateRequiredProperties(
    _ component: ICalComponent,
    path: [ICalComponentName],
    issues: inout [ICalendarValidationIssue]
) {
    for property in requiredProperties(for: component.name) where component.firstProperty(property) == nil {
        issues.append(
            ICalendarValidationIssue(
                severity: .error,
                code: .missingRequiredProperty,
                componentPath: path,
                message: "\(component.name.rawName) is missing required property \(property.rawValue)"
            )
        )
    }
}

private func validateSingletonProperties(
    _ component: ICalComponent,
    path: [ICalComponentName],
    issues: inout [ICalendarValidationIssue]
) {
    for property in singletonProperties(for: component.name) where component.properties(property).count > 1 {
        issues.append(
            ICalendarValidationIssue(
                severity: .error,
                code: .duplicateSingletonProperty,
                componentPath: path,
                message: "\(component.name.rawName) contains multiple \(property.rawValue) properties"
            )
        )
    }
}

private func validateMutuallyExclusiveProperties(
    _ component: ICalComponent,
    path: [ICalComponentName],
    issues: inout [ICalendarValidationIssue]
) {
    for pair in mutuallyExclusiveProperties(for: component.name)
    where component.firstProperty(pair.0) != nil && component.firstProperty(pair.1) != nil {
        issues.append(
            ICalendarValidationIssue(
                severity: .error,
                code: .mutuallyExclusiveProperties,
                componentPath: path,
                message: "\(component.name.rawName) must not contain both \(pair.0.rawValue) and \(pair.1.rawValue)"
            )
        )
    }
}

private func allowedChildComponents(for component: ICalComponentName) -> Set<ICalComponentName> {
    switch component {
    case .vcalendar:
        [.vevent, .vtodo, .vjournal, .vfreebusy, .vtimezone]
    case .vevent, .vtodo:
        [.valarm]
    case .vtimezone:
        [.standard, .daylight]
    case .vjournal, .vfreebusy, .valarm, .standard, .daylight:
        []
    case .custom:
        []
    }
}

private func requiredProperties(for component: ICalComponentName) -> Set<KnownICalProperty> {
    switch component {
    case .vcalendar:
        [.prodid, .version]
    case .vevent:
        [.dtstamp, .dtstart, .uid]
    case .vtodo, .vjournal, .vfreebusy:
        [.dtstamp, .uid]
    case .vtimezone:
        [.tzid]
    case .standard, .daylight:
        [.dtstart, .tzoffsetfrom, .tzoffsetto]
    case .valarm:
        [.action, .trigger]
    case .custom:
        []
    }
}

private func singletonProperties(for component: ICalComponentName) -> Set<KnownICalProperty> {
    switch component {
    case .vcalendar:
        [.calscale, .method, .prodid, .version]
    case .vevent:
        [.dtend, .dtstamp, .dtstart, .duration, .uid]
    case .vtodo:
        [.completed, .dtstamp, .dtstart, .due, .duration, .uid]
    case .vjournal, .vfreebusy:
        [.dtstamp, .dtstart, .uid]
    case .vtimezone:
        [.tzid]
    case .standard, .daylight:
        [.dtstart, .tzoffsetfrom, .tzoffsetto]
    case .valarm:
        [.action, .duration, .repeatCount, .trigger]
    case .custom:
        []
    }
}

private func mutuallyExclusiveProperties(for component: ICalComponentName) -> [(KnownICalProperty, KnownICalProperty)] {
    switch component {
    case .vevent:
        [(.dtend, .duration)]
    case .vtodo:
        [(.due, .duration)]
    default:
        []
    }
}
