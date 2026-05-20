import Foundation

struct ParsedContentLine: Sendable, Equatable {
    var name: String
    var parameters: [ICalParameter]
    var value: String
    var sourceLine: Int
}

enum ContentLine {
    static func unfold(_ source: String, options: ParseOptions) throws -> [(line: String, sourceLine: Int)] {
        if !options.allowsBareLF {
            try validateStrictCRLF(source)
        }
        var normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        var unfolded: [(line: String, sourceLine: Int)] = []

        for (offset, rawLine) in rawLines.enumerated() {
            let lineNumber = offset + 1
            let line = String(rawLine)
            if line.isEmpty {
                continue
            }

            if line.first == " " || line.first == "\t" {
                guard !unfolded.isEmpty else {
                    throw ICalendarParseError.invalidContentLine(
                        line: lineNumber,
                        reason: "Continuation line without a previous content line"
                    )
                }
                unfolded[unfolded.count - 1].line += String(line.dropFirst())
            } else {
                unfolded.append((line, lineNumber))
            }
        }

        return try unfolded.map { item in
            switch options.controlCharacterPolicy {
            case .keep:
                return item
            case .omit:
                return (String(item.line.unicodeScalars.filter { !$0.isDisallowedControlCharacter }), item.sourceLine)
            case .error:
                if item.line.unicodeScalars.contains(where: \.isDisallowedControlCharacter) {
                    throw ICalendarParseError.controlCharacter(line: item.sourceLine)
                }
                return item
            }
        }
    }

    static func parse(_ line: String, sourceLine: Int) throws -> ParsedContentLine {
        guard !line.isEmpty else {
            throw ICalendarParseError.emptyContentLine(line: sourceLine)
        }
        guard let colonIndex = firstUnquotedColon(in: line) else {
            throw ICalendarParseError.invalidContentLine(line: sourceLine, reason: "Missing ':' separator")
        }

        let head = String(line[..<colonIndex])
        let value = String(line[line.index(after: colonIndex)...])
        let parts = splitUnquoted(head, separator: ";")
        guard let rawName = parts.first, !rawName.isEmpty else {
            throw ICalendarParseError.invalidContentLine(line: sourceLine, reason: "Missing property name")
        }
        guard rawName.allSatisfy({ $0.isValidNameCharacter }) else {
            throw ICalendarParseError.invalidContentLine(line: sourceLine, reason: "Invalid property name")
        }

        let parameters = try parts.dropFirst().map { try parseParameter($0, sourceLine: sourceLine) }
        return ParsedContentLine(
            name: rawName.uppercased(),
            parameters: parameters,
            value: value,
            sourceLine: sourceLine
        )
    }

    static func serialize(name: String, parameters: [ICalParameter], value: String, options: SerializationOptions) throws -> String {
        try validateSafeContentLineText(name, field: "name")
        try validateSafeContentLineText(value, field: "value")
        var line = name.uppercased()
        for parameter in parameters {
            try validateSafeContentLineText(parameter.name, field: "parameter name")
            line += ";\(parameter.name)="
            line += try parameter.values.map {
                try validateSafeContentLineText($0, field: "parameter value")
                return serializeParameterValue($0)
            }.joined(separator: ",")
        }
        line += ":\(value)"
        guard options.foldsLines else {
            return line + "\r\n"
        }
        return fold(line, maximumOctets: options.maximumLineOctets)
    }

    static func fold(_ line: String, maximumOctets: Int = 75) -> String {
        guard line.utf8.count > maximumOctets else {
            return line + "\r\n"
        }

        var result = ""
        var current = ""
        var currentLimit = maximumOctets

        for character in line {
            let characterOctets = String(character).utf8.count
            if !current.isEmpty && current.utf8.count + characterOctets > currentLimit {
                result += current + "\r\n"
                current = " " + String(character)
                currentLimit = max(1, maximumOctets)
            } else {
                current.append(character)
            }
        }

        result += current + "\r\n"
        return result
    }

    private static func firstUnquotedColon(in line: String) -> String.Index? {
        var isQuoted = false
        var previousWasEscape = false
        for index in line.indices {
            let character = line[index]
            if character == "\\" && isQuoted {
                previousWasEscape.toggle()
                continue
            }
            if character == "\"" && !previousWasEscape {
                isQuoted.toggle()
            } else if character == ":" && !isQuoted {
                return index
            }
            previousWasEscape = false
        }
        return nil
    }

    private static func parseParameter(_ raw: String, sourceLine: Int) throws -> ICalParameter {
        guard let equals = raw.firstIndex(of: "=") else {
            throw ICalendarParseError.invalidContentLine(line: sourceLine, reason: "Parameter missing '='")
        }
        let name = String(raw[..<equals]).uppercased()
        guard !name.isEmpty, name.allSatisfy({ $0.isValidNameCharacter }) else {
            throw ICalendarParseError.invalidContentLine(line: sourceLine, reason: "Invalid parameter name")
        }
        let values = splitUnquoted(String(raw[raw.index(after: equals)...]), separator: ",")
            .map(unquoteParameterValue)
        return ICalParameter(name: name, values: values)
    }

    private static func splitUnquoted(_ value: String, separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var isQuoted = false
        var previousWasEscape = false

        for character in value {
            if character == "\\" && isQuoted {
                previousWasEscape.toggle()
                current.append(character)
                continue
            }
            if character == "\"" && !previousWasEscape {
                isQuoted.toggle()
                current.append(character)
            } else if character == separator && !isQuoted {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
            previousWasEscape = false
        }
        parts.append(current)
        return parts
    }

    private static func unquoteParameterValue(_ raw: String) -> String {
        guard raw.count >= 2, raw.first == "\"", raw.last == "\"" else {
            return raw
        }
        var result = ""
        var isEscaped = false
        for character in raw.dropFirst().dropLast() {
            if isEscaped {
                result.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    private static func serializeParameterValue(_ value: String) -> String {
        let requiresQuoting = value.isEmpty || value.contains { character in
            character == ":" || character == ";" || character == "," || character == "\""
        }
        guard requiresQuoting else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private static func validateSafeContentLineText(_ value: String, field: String) throws {
        if value.unicodeScalars.contains(where: { $0.value == 0x0A || $0.value == 0x0D }) {
            throw ICalendarSerializationError.unsafeContentLineText(field: field)
        }
    }

    private static func validateStrictCRLF(_ source: String) throws {
        var line = 1
        var previousWasCR = false

        for scalar in source.unicodeScalars {
            if previousWasCR {
                guard scalar.value == 0x0A else {
                    throw ICalendarParseError.invalidContentLine(line: line, reason: "Bare CR line break")
                }
                previousWasCR = false
                line += 1
                continue
            }

            switch scalar.value {
            case 0x0D:
                previousWasCR = true
            case 0x0A:
                throw ICalendarParseError.invalidContentLine(line: line, reason: "Bare LF line break")
            default:
                continue
            }
        }

        if previousWasCR {
            throw ICalendarParseError.invalidContentLine(line: line, reason: "Bare CR line break")
        }
    }
}

private extension Unicode.Scalar {
    var isDisallowedControlCharacter: Bool {
        (value < 0x20 && self != "\t") || value == 0x7F
    }
}

private extension Character {
    var isValidNameCharacter: Bool {
        isLetter || isNumber || self == "-"
    }
}
