//
//  MarkdownEscaping.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation

// MARK: - MarkdownEscaping

/// 마크다운 문자열의 escape / unescape 처리를 담당하는 유틸리티.
///
/// 에디터는 WYSIWYG 편집 결과를 마크다운 문자열로 저장한 뒤 다시 파싱해 렌더링합니다.
/// 이 왕복 과정에서 사용자가 "문자 그대로" 입력한 마크다운 기호(`*`, `_`, `` ` `` 등)가
/// 서식으로 오해석되지 않도록 직렬화 시 백슬래시로 escape하고, 역직렬화 시 다시 벗겨냅니다.
enum MarkdownEscaping {

    // MARK: - Property

    /// 이 파서가 escape 하는 문자 집합입니다. `unescapeMarkdownText` 는 이 집합 앞에 붙은 `\` 만 제거합니다.
    ///
    /// ### 각 문자가 포함된 이유
    /// - `\\`, `*`, `_`, `[`, `]`, `(`, `)`, `~`, `` ` ``, `<`, `>`: 인라인 토큰 기호.
    /// - `#`, `-`: 헤딩/목록 등 블록 레벨 토큰 기호.
    /// - `.`: `escapeLeadingBlockSyntax` 가 `"1\. text"` 형태로 escape하므로 역직렬화 시 `.` 를 unescape 해야 합니다.
    /// - `–`: `escapeLeadingBlockSyntax` 가 `"\– text"` 형태로 escape 하므로 역직렬화 시 `–` 를 unescape 해야 합니다.
    static let escapedMarkdownCharacters: Set<Character> = [
        "\\", "*", "_", "[", "]", "(", ")", "~", "`", "<", ">", "#", "-", ".", "–"
    ]

    // MARK: - Function

    /// 일반 텍스트 구간을 마크다운으로 직렬화할 때 사용합니다.
    ///
    /// 인라인 토큰 기호(`*`, `_`, `[` 등)와 `<`, `>` 앞에 백슬래시를 붙여, 사용자가 입력한
    /// 문자 그대로가 다시 파싱될 때 서식으로 해석되지 않도록 합니다.
    ///
    /// - Parameter text: 이미 NSAttributedString에서 뽑아낸 원본 텍스트.
    /// - Returns: escape 가 적용된 마크다운-안전 문자열.
    ///
    /// - Note: `<`, `>` 포함의 근거: 사용자가 입력한 `</u>`, `</mark>` 등이 deserialize 시
    ///   닫는 태그로 오파싱되는 것을 방지합니다.
    static func escapeMarkdownText(_ text: String) -> String {
        var escaped = ""

        for character in text {
            if "\\*_[]()~`<>".contains(character) {
                escaped.append("\\")
            }

            escaped.append(character)
        }

        return escaped
    }

    /// 코드 스팬 내부에서 사용하는 escape 함수.
    ///
    /// `` ` `` 자체와 `\` 만 escape 하면 충분합니다. 코드 스팬 안에서는 다른 인라인 토큰이
    /// 활성화되지 않으므로 `*`, `_` 등은 그대로 둡니다.
    ///
    /// - Parameter text: 코드 스팬 내부 원본.
    /// - Returns: 백틱 스팬으로 안전하게 감쌀 수 있는 문자열.
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

    /// 링크 URL destination 에서 `)`, `\` 를 escape 합니다.
    ///
    /// `[label](url)` 형식에서 URL 에 `)` 가 포함되면 파서가 조기 종료되므로
    /// 반드시 escape 되어야 합니다. `\` 는 escape 문자 자체이기에 동일하게 보존합니다.
    ///
    /// - Parameter url: 링크 URL 의 raw 문자열.
    /// - Returns: destination 영역에 안전하게 삽입 가능한 문자열.
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

    /// 블록 prefix(헤딩/인용/목록) 와 동일한 문자열이 사용자의 일반 단락 첫머리에
    /// 나타난 경우, 해당 prefix 를 "문자 그대로" 보존하기 위해 escape 합니다.
    ///
    /// - `"# "`, `"## "`, `"### "`, `"> "`, `"- "`, `"– "` → 맨 앞에 `\` 를 추가.
    /// - `"1. "` 처럼 숫자 목록 형태 → `"1\. "` 로 점 앞에 `\` 를 삽입.
    ///
    /// - Parameter line: 아직 블록 처리가 안 된 한 줄.
    /// - Returns: 해당 prefix 가 서식으로 재해석되지 않도록 보정된 문자열.
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

    /// 마크다운 문자열의 백슬래시 이스케이프를 제거합니다. 파서의 plain text 구간에서만 호출됩니다.
    ///
    /// ### 동작 규칙
    /// - `escapedMarkdownCharacters` 에 속한 문자 앞의 `\` 는 제거하고 그 문자만 남김.
    /// - 집합에 **속하지 않은** 문자 앞의 `\` 는 그대로 유지 (예: 윈도우 경로 `"C:\\Users"` 보존).
    /// - 문자열이 `\` 로 끝나면 단독 `\` 로 출력.
    ///
    /// - Parameter text: escape 된 마크다운 텍스트.
    /// - Returns: 화면 표시 또는 추가 처리용 원본 텍스트.
    static func unescapeMarkdownText(_ text: String) -> String {
        var unescaped = ""
        var isEscaping = false

        for character in text {
            if isEscaping {
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
    ///
    /// 코드 스팬 내부에서는 모든 escape 가 "바로 앞 문자를 문자 그대로 유지" 의미이므로
    /// 집합 체크 없이 `\` 를 제거합니다.
    ///
    /// - Parameter text: 코드 스팬 안의 raw 문자열.
    /// - Returns: 사용자가 입력한 그대로의 코드 본문.
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
