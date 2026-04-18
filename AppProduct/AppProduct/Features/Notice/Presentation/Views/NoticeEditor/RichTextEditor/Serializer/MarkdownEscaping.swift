//
//  MarkdownEscaping.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation

// MARK: - MarkdownEscaping

enum MarkdownEscaping {

    // MARK: - Property

    /// 이 파서가 escape하는 문자 집합입니다. `unescapeMarkdownText`는 이 집합 앞에 붙은 `\`만 제거합니다.
    ///
    /// `.`: `escapeLeadingBlockSyntax`가 `1\. text` 형태로 escape하므로 역직렬화 시 `.`를 unescape해야 합니다.
    /// `–`: `escapeLeadingBlockSyntax`가 `\– text` 형태로 escape하므로 역직렬화 시 `–`를 unescape해야 합니다.
    static let escapedMarkdownCharacters: Set<Character> = [
        "\\", "*", "_", "[", "]", "(", ")", "~", "`", "<", ">", "#", "-", ".", "–"
    ]

    // MARK: - Function

    static func escapeMarkdownText(_ text: String) -> String {
        var escaped = ""

        for character in text {
            // '<', '>' 포함: 사용자가 입력한 </u>, </mark> 등이 deserialize 시 닫는 태그로 오파싱되는 것을 방지
            if "\\*_[]()~`<>".contains(character) {
                escaped.append("\\")
            }

            escaped.append(character)
        }

        return escaped
    }

    static func escapeMarkdownCodeText(_ text: String) -> String {
        var escaped = ""

        for character in text {
            if character == "\\" || character == "`" {
                escaped.append("\\")
            }

            escaped.append(character)
        }

        return escaped
    }

    /// 링크 URL destination에서 `)`, `\`를 escape합니다.
    static func escapeMarkdownLinkDestination(_ url: String) -> String {
        var escaped = ""
        for character in url {
            if character == ")" || character == "\\" {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        return escaped
    }

    static func escapeLeadingBlockSyntax(in line: String) -> String {
        if line.hasPrefix("### ") || line.hasPrefix("## ") || line.hasPrefix("# ") {
            return "\\\(line)"
        }

        if line.hasPrefix("> ") || line.hasPrefix("- ") || line.hasPrefix("– ") {
            return "\\\(line)"
        }

        guard let match = MarkdownRegex.leadingNumber
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
            return line
        }

        let nsLine = line as NSString
        let marker = nsLine.substring(with: match.range(at: 1))
        let remainder = nsLine.substring(from: match.range.length)
        return "\(marker)\\. \(remainder)"
    }

    static func unescapeMarkdownText(_ text: String) -> String {
        var unescaped = ""
        var isEscaping = false

        for character in text {
            if isEscaping {
                // escape 대상 문자: backslash 제거 후 문자만 추가
                // 비대상 문자: backslash도 유지 (e.g. C:\Users → C:\Users)
                if !escapedMarkdownCharacters.contains(character) {
                    unescaped.append("\\")
                }
                unescaped.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            unescaped.append(character)
        }

        if isEscaping {
            unescaped.append("\\")
        }

        return unescaped
    }

    /// 코드 스팬 내부의 백슬래시 이스케이프를 제거합니다. `\`` → `` ` ``, `\\` → `\`.
    static func unescapeCodeText(_ text: String) -> String {
        var unescaped = ""
        var isEscaping = false

        for character in text {
            if isEscaping {
                unescaped.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            unescaped.append(character)
        }

        if isEscaping {
            unescaped.append("\\")
        }

        return unescaped
    }
}
