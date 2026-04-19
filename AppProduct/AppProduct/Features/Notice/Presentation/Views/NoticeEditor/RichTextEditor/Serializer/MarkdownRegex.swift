//
//  MarkdownRegex.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation

// MARK: - MarkdownRegex

/// 마크다운 파서/직렬화기 전체가 공유하는 정규식 저장소.
///
/// 정규식 컴파일 비용을 매번 치르지 않도록 `static let`으로 한 번만 만들어둡니다.
/// 패턴이 고정 리터럴이므로 `try!`가 안전하며, 컴파일에 실패하면 곧 개발자 에러로 crash하여
/// 빠르게 드러납니다.
enum MarkdownRegex {

    // MARK: - Block Serialization Regex

    /// `"• text"` 처럼 bullet 기호와 뒤따르는 공백을 매칭. 직렬화 시 `"- "`로 치환됩니다.
    static let bulletPrefix = try! NSRegularExpression(pattern: "^•\\s+")

    /// `"– text"` (EN DASH)를 매칭. 직렬화 시 그대로 `"– "`로 유지합니다.
    static let dashPrefix = try! NSRegularExpression(pattern: "^–\\s+")

    /// `"1. text"` 처럼 번호 + 점 + 공백으로 시작하는 항목. capture group 1 = 숫자 marker.
    static let numberPrefix = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // MARK: - Block Deserialization Regex

    /// `"### "` subheading 접두어.
    static let h3 = try! NSRegularExpression(pattern: "^###\\s+")

    /// `"## "` heading 접두어.
    static let h2 = try! NSRegularExpression(pattern: "^##\\s+")

    /// `"# "` title 접두어.
    static let h1 = try! NSRegularExpression(pattern: "^#\\s+")

    /// `"> "` 인용구 접두어.
    static let blockquote = try! NSRegularExpression(pattern: "^>\\s+")

    /// `"- "` bullet 목록 접두어(입력용). 렌더링 시 `"•"`로 변환됩니다.
    static let bulletList = try! NSRegularExpression(pattern: "^-\\s+")

    /// `"– "` dash 목록 접두어(EN DASH).
    static let dashList = try! NSRegularExpression(pattern: "^–\\s+")

    /// `"1. "` numbered 목록 접두어. capture group 1 = 숫자.
    static let numberList = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // MARK: - Leading Block Escape Regex

    /// 의도치 않게 목록으로 해석될 수 있는 선행 숫자 패턴을 찾기 위한 정규식.
    ///
    /// 예: 사용자가 일반 단락에 `"1. Hello"`를 입력한 경우 `"1\\. Hello"`로 escape하여
    /// 직렬화-역직렬화 왕복에서 의미가 변하지 않도록 합니다.
    static let leadingNumber = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // MARK: - Inline Patterns

    /// 인라인 토큰 정규식 리스트. `MarkdownInlineParser.earliestInlineToken`이
    /// 이 배열을 순회하며 가장 먼저 등장하는 매칭을 선택합니다.
    ///
    /// ### 순서가 중요합니다
    /// - 길고 구체적인 패턴이 먼저: `boldItalicMixed`/`boldItalicStars` 가 `bold`보다 앞.
    /// - `code`, `link` 는 다른 인라인 토큰보다 우선하여 경쟁 매칭을 방지.
    ///
    /// ### 공통 규칙
    /// - `(?<!\\\\)` negative lookbehind: 바로 앞에 백슬래시(`\`)가 있으면 매칭 실패.
    ///   사용자가 `\*not bold\*` 로 입력한 경우를 문자 그대로 보존하기 위함.
    /// - `bold`/`italic` 계열은 `(?=\S) ... (?<=\S)` 로 양끝 공백 래핑을 배제하여
    ///   `** text **` 같은 실수 입력을 서식으로 해석하지 않게 합니다.
    /// - `.dotMatchesLineSeparators` 옵션으로 `.`가 `\n`까지 포함하여 여러 줄 인라인도 허용합니다.
    static let inlinePatterns: [(MarkdownInlineTokenKind, NSRegularExpression)] = {
        let patterns: [(MarkdownInlineTokenKind, String)] = [
            (.code, "(?<!\\\\)`((?:\\\\.|[^`\\n])+?)`"),
            (.link, "(?<!\\\\)\\[((?:\\\\.|[^\\]\\n])+?)\\]\\(((?:\\\\.|[^)\\n])+?)\\)"),
            (.underline, "(?<!\\\\)<u>(.+?)</u>"),
            (.strikethrough, "(?<!\\\\)~~(?=\\S)(.+?)(?<=\\S)~~"),
            (.highlight, "(?<!\\\\)<mark(?:\\s+color=\"([^\"]*)\")?>(.+?)</mark>"),
            (.boldItalicMixed, "(?<!\\\\)\\*\\*_(.+?)_\\*\\*"),
            (.boldItalicStars, "(?<!\\\\)\\*\\*\\*(.+?)\\*\\*\\*"),
            (.bold, "(?<!\\\\)\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*"),
            (.italicAsterisk, "(?<!\\\\)(?<!\\*)\\*(?=\\S)(.+?)(?<=\\S)\\*(?!\\*)"),
            (.italicUnderscore, "(?<!\\\\)(?<!_)_(?=\\S)(.+?)(?<=\\S)_(?!_)"),
        ]
        return patterns.compactMap { kind, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
                return nil
            }
            return (kind, regex)
        }
    }()
}
