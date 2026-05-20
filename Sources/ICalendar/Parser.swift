import Foundation

struct ICalendarParser {
    var options: ParseOptions

    func parse(_ source: String) throws -> ICalendarDocument {
        let parsedLines = try ContentLine.unfold(source, options: options)
            .map { try ContentLine.parse($0.line, sourceLine: $0.sourceLine) }
        var index = 0
        var components: [ICalComponent] = []

        while index < parsedLines.count {
            let line = parsedLines[index]
            if line.name == "BEGIN" {
                index += 1
                components.append(try parseComponent(named: ICalComponentName(line.value), lines: parsedLines, index: &index))
            } else if line.name == "END" {
                throw ICalendarParseError.unexpectedEnd(line: line.sourceLine, name: ICalComponentName(line.value))
            } else {
                throw ICalendarParseError.propertyOutsideComponent(line: line.sourceLine, name: line.name)
            }
        }

        return ICalendarDocument(components: components)
    }

    private func parseComponent(
        named name: ICalComponentName,
        lines: [ParsedContentLine],
        index: inout Int
    ) throws -> ICalComponent {
        var properties: [ICalProperty] = []
        var children: [ICalComponent] = []

        while index < lines.count {
            let line = lines[index]
            index += 1

            if line.name == "BEGIN" {
                children.append(try parseComponent(named: ICalComponentName(line.value), lines: lines, index: &index))
            } else if line.name == "END" {
                let found = ICalComponentName(line.value)
                guard found == name else {
                    throw ICalendarParseError.mismatchedEnd(line: line.sourceLine, expected: name, found: found)
                }
                return ICalComponent(name: name, properties: properties, children: children)
            } else {
                properties.append(
                    ICalProperty(
                        name: ICalPropertyName(line.name),
                        parameters: line.parameters,
                        rawValue: line.value
                    )
                )
            }
        }

        throw ICalendarParseError.missingEnd(name: name)
    }
}

extension ICalComponent {
    func serialized(options: SerializationOptions) throws -> String {
        var output = try ContentLine.serialize(name: "BEGIN", parameters: [], value: name.rawName, options: options)
        for property in properties {
            output += try property.serialized(options: options)
        }
        for child in children {
            output += try child.serialized(options: options)
        }
        output += try ContentLine.serialize(name: "END", parameters: [], value: name.rawName, options: options)
        return output
    }
}

extension ICalProperty {
    func serialized(options: SerializationOptions) throws -> String {
        try ContentLine.serialize(name: name.rawName, parameters: parameters, value: rawValue, options: options)
    }
}
