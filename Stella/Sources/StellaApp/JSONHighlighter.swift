import SwiftUI

enum JSONHighlighter {
    static func prettyPrinted(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let pretty = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .withoutEscapingSlashes]
              ),
              let string = String(data: pretty, encoding: .utf8)
        else { return nil }
        return string
    }

    /// Tokenizes a JSON-ish string and returns an AttributedString with colored
    /// keys / values / numbers / keywords. Plain text outside the JSON body
    /// (e.g. an "HTTP 200" prefix line) is preserved as-is.
    static func attributed(_ raw: String) -> AttributedString {
        var output = AttributedString()
        let chars = Array(raw)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if c == "\"" {
                let (string, next) = readString(chars, from: i)
                let isKey = lookaheadIsColon(chars, from: next)
                output.append(styled(string, color: isKey ? .keyColor : .stringColor))
                i = next
                continue
            }

            if c.isNumber || (c == "-" && i + 1 < chars.count && (chars[i + 1].isNumber || chars[i + 1] == ".")) {
                let (number, next) = readNumber(chars, from: i)
                output.append(styled(number, color: .numberColor))
                i = next
                continue
            }

            if c.isLetter {
                let (word, next) = readWord(chars, from: i)
                if word == "true" || word == "false" || word == "null" {
                    output.append(styled(word, color: .keywordColor))
                } else {
                    output.append(styled(word, color: .punctColor))
                }
                i = next
                continue
            }

            switch c {
            case "{", "}", "[", "]", ",", ":":
                output.append(styled(String(c), color: .punctColor))
            default:
                output.append(AttributedString(String(c)))
            }
            i += 1
        }

        return output
    }

    private static func styled(_ text: String, color: Color) -> AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = color
        return attr
    }

    private static func readString(_ chars: [Character], from start: Int) -> (String, Int) {
        var i = start + 1
        var escape = false
        while i < chars.count {
            let c = chars[i]
            if escape {
                escape = false
            } else if c == "\\" {
                escape = true
            } else if c == "\"" {
                i += 1
                break
            }
            i += 1
        }
        return (String(chars[start..<i]), i)
    }

    private static func readNumber(_ chars: [Character], from start: Int) -> (String, Int) {
        var i = start
        while i < chars.count {
            let c = chars[i]
            if c.isNumber || c == "." || c == "-" || c == "+" || c == "e" || c == "E" {
                i += 1
            } else {
                break
            }
        }
        return (String(chars[start..<i]), i)
    }

    private static func readWord(_ chars: [Character], from start: Int) -> (String, Int) {
        var i = start
        while i < chars.count, chars[i].isLetter {
            i += 1
        }
        return (String(chars[start..<i]), i)
    }

    private static func lookaheadIsColon(_ chars: [Character], from start: Int) -> Bool {
        var i = start
        while i < chars.count, chars[i].isWhitespace {
            i += 1
        }
        return i < chars.count && chars[i] == ":"
    }
}

private extension Color {
    static let keyColor     = Color(red: 0.42, green: 0.55, blue: 0.96) // soft blue
    static let stringColor  = Color(red: 0.84, green: 0.45, blue: 0.45) // warm red
    static let numberColor  = Color(red: 0.62, green: 0.45, blue: 0.86) // purple
    static let keywordColor = Color(red: 0.94, green: 0.62, blue: 0.30) // orange
    static let punctColor   = Color.secondary
}
