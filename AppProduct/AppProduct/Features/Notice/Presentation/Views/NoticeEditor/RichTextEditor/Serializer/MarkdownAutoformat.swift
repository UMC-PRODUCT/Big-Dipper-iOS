//
//  MarkdownAutoformat.swift
//  AppProduct
//
//  Created by euijjang97 on 6/10/26.
//

import Foundation

// MARK: - MarkdownAutoformat

/// 에디터에 **텍스트로 입력된 마크다운 문법**을 실제 서식으로 변환하기 위한 감지 로직.
///
/// 리치 에디터는 WYSIWYG 원칙에 따라 타이핑된 기호를 문자 그대로 보존(이스케이프)하지만,
/// 디스코드 습관으로 `**굿**` 같은 문법을 직접 입력하는 사용자가 많아 리터럴 마커가
/// 모든 화면에 노출되는 문제가 있었습니다. 이 타입은 두 가지 진입점을 제공합니다.
///
/// 1. `containsMarkdownSyntax`: 붙여넣은 텍스트가 마크다운인지 판별 (붙여넣기 자동 변환)
/// 2. `completedInlineToken`: 커서 직전에 막 완성된 인라인 토큰 검출 (타이핑 라이브 변환)
///
/// 변환 동작 자체(NSAttributedString 치환)는 `RichTextCoordinator+MarkdownAutoformat` 이
/// 담당하며, 이 타입은 UIKit 의존이 없는 순수 판별 로직만 가집니다.
enum MarkdownAutoformat {

    // MARK: - Types

    /// 타이핑으로 막 완성된 인라인 토큰의 종류.
    enum InlineTokenKind {
        /// `**텍스트**`
        case bold
        /// `***텍스트***`
        case boldItalic
        /// `*텍스트*`
        case italic
        /// `~~텍스트~~`
        case strikethrough
        /// `` `텍스트` ``
        case code
        /// `[라벨](url)`
        case link
    }

    /// `completedInlineToken` 의 검출 결과.
    struct CompletedToken {
        /// 토큰 종류.
        let kind: InlineTokenKind
        /// 검사 구간(segment) 내에서 마커를 포함한 토큰 전체 범위 (UTF-16).
        let range: NSRange
        /// 마커를 제거하고 백슬래시 이스케이프까지 푼 본문 텍스트.
        let body: String
        /// 링크 토큰일 때의 목적지 URL. 허용 scheme(https/http/mailto/tel)이 아니면 검출 자체가 실패합니다.
        let linkURL: URL?
    }

    // MARK: - Paste Detection

    /// 텍스트가 마크다운 문법을 포함하는지 판별합니다. (붙여넣기 자동 변환 트리거)
    ///
    /// **강한 신호만** 사용합니다 — 단독 `*텍스트*` / `_텍스트_` (이탤릭) 는 `user_name`,
    /// `3*4*5` 같은 일반 텍스트와 구분이 어려워 신호에서 제외합니다. 강한 신호로 변환이
    /// 결정되면 이후 파싱(`MarkdownSerializer.deserialize`)은 이탤릭까지 포함해 전체
    /// 문법을 해석합니다.
    ///
    /// - Parameter text: 붙여넣기로 삽입될 원본 텍스트.
    /// - Returns: 마크다운으로 해석해야 하면 `true`.
    static func containsMarkdownSyntax(_ text: String) -> Bool {
        // 블록 prefix: 라인 시작의 헤딩/인용구/불릿/번호 목록
        for line in text.components(separatedBy: .newlines) {
            let lineRange = NSRange(location: 0, length: (line as NSString).length)
            let blockPatterns: [NSRegularExpression] = [
                MarkdownRegex.h3, MarkdownRegex.h2, MarkdownRegex.h1,
                MarkdownRegex.blockquote, MarkdownRegex.bulletList, MarkdownRegex.numberList,
            ]
            if blockPatterns.contains(where: { $0.firstMatch(in: line, range: lineRange) != nil }) {
                return true
            }
        }

        // 인라인 토큰: 파서 dialect 의 정규식을 재사용하되 이탤릭 계열은 제외
        let weakKinds: Set<MarkdownInlineTokenKind> = [.italicAsterisk, .italicUnderscore]
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        for (kind, regex) in MarkdownRegex.inlinePatterns where !weakKinds.contains(kind) {
            if regex.firstMatch(in: text, range: fullRange) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - Typing Detection

    /// 검사 구간(단락 시작 ~ 커서)의 **끝에서 막 완성된** 인라인 토큰을 찾습니다.
    ///
    /// 마지막 키 입력으로 닫는 마커가 완성된 순간만 잡도록 모든 패턴이 `$` 로 끝납니다.
    /// 이미 변환된 서식 텍스트에는 마커 문자가 없으므로 재변환되지 않고,
    /// `\*\*텍스트\*\*` 처럼 백슬래시 이스케이프된 입력은 lookbehind 가드로 보존됩니다.
    ///
    /// - Parameter segment: 단락 시작부터 커서까지의 plain 문자열.
    /// - Returns: 완성된 토큰 정보. 없으면 `nil`.
    static func completedInlineToken(in segment: String) -> CompletedToken? {
        let nsSegment = segment as NSString
        let fullRange = NSRange(location: 0, length: nsSegment.length)

        for (kind, regex) in typedTokenPatterns {
            guard let match = regex.firstMatch(in: segment, range: fullRange) else { continue }

            if kind == .link {
                let label = nsSegment.substring(with: match.range(at: 1))
                let rawURL = nsSegment.substring(with: match.range(at: 2))
                guard let url = URL(string: MarkdownEscaping.unescapeMarkdownText(rawURL)),
                      let scheme = url.scheme?.lowercased(),
                      ["https", "http", "mailto", "tel"].contains(scheme) else {
                    continue
                }
                return CompletedToken(
                    kind: kind,
                    range: match.range,
                    body: MarkdownEscaping.unescapeMarkdownText(label),
                    linkURL: url
                )
            }

            let rawBody = nsSegment.substring(with: match.range(at: 1))
            let body = kind == .code
                ? MarkdownEscaping.unescapeCodeText(rawBody)
                : MarkdownEscaping.unescapeMarkdownText(rawBody)
            return CompletedToken(kind: kind, range: match.range, body: body, linkURL: nil)
        }

        return nil
    }

    // MARK: - Private

    /// 타이핑 완성 검출용 정규식. 선언 순서가 우선순위입니다 (구체적 패턴 우선).
    ///
    /// 파서(`MarkdownRegex.inlinePatterns`)와 동일한 가드를 사용하되, 토큰이 검사 구간의
    /// 끝(`$` == 커서 위치)에서 끝나는 매칭만 허용합니다.
    private static let typedTokenPatterns: [(InlineTokenKind, NSRegularExpression)] = {
        let patterns: [(InlineTokenKind, String)] = [
            (.code, "(?<!\\\\)`((?:\\\\.|[^`\\n])+?)`$"),
            (.link, "(?<!\\\\)\\[((?:\\\\.|[^\\]\\n])+?)\\]\\(((?:\\\\.|[^)\\n])+?)\\)$"),
            (.boldItalic, "(?<!\\\\)\\*\\*\\*(?=\\S)((?:\\\\.|[^*\\n])+?)(?<=\\S)\\*\\*\\*$"),
            (.bold, "(?<!\\\\)(?<!\\*)\\*\\*(?=\\S)((?:\\\\.|[^*\\n])+?)(?<=\\S)\\*\\*$"),
            (.strikethrough, "(?<!\\\\)~~(?=\\S)((?:\\\\.|[^~\\n])+?)(?<=\\S)~~$"),
            (.italic, "(?<!\\\\)(?<!\\*)\\*(?=\\S)((?:\\\\.|[^*\\n])+?)(?<=\\S)\\*$"),
        ]
        return patterns.compactMap { kind, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (kind, regex)
        }
    }()
}
