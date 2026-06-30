//
//  MarkdownHTMLDetector.swift
//  NoticeData
//
//  Created by 이예지 on 7/1/26.
//

import Foundation
import UIKit

// MARK: - MarkdownHTMLDetector

/// 서버/다른 클라이언트에서 넘어온 콘텐츠가 마크다운인지 HTML 인지 구분하고,
/// HTML 일 경우 순수 텍스트로 변환하는 유틸리티.
///
/// 공지사항 본문은 일반적으로 마크다운이지만, 과거 데이터 또는 외부 경로로 HTML 이 섞여
/// 들어올 수 있습니다. 이 경우 마크다운 파서에 그대로 통과시키면 깨진 서식이 화면에
/// 노출되므로, 휴리스틱으로 포맷을 감지한 뒤 분기합니다.
public enum MarkdownHTMLDetector {

    // MARK: - Function

    /// 문자열이 마크다운이 아닌 HTML 형식인지 휴리스틱으로 판별합니다.
    ///
    /// 대표적인 HTML 블록/인라인 태그가 여는 형태(`<tag>`, `<tag ...>`, `<tag/>`)로
    /// 등장하는지를 정규식으로 확인합니다.
    ///
    /// - Parameter content: 판별 대상 콘텐츠.
    /// - Returns: HTML 로 보이면 `true`, 그 외(마크다운 포함)는 `false`.
    ///
    /// - Note: `<u>`, `<mark>` 는 iOS 에디터의 마크다운 인라인 토큰이므로 판별 집합에서
    ///   제외합니다. 이 태그만 포함된 콘텐츠는 계속 마크다운으로 간주됩니다.
    public static func looksLikeHTML(_ content: String) -> Bool {
        let pattern = "<(p|div|br|span|b|i|strong|em|ul|ol|li|h[1-6]|blockquote|a|table|tr|td)[\\s>/]"
        return content.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// 마크다운 또는 HTML 문자열에서 모든 서식을 제거하고 plain text 를 반환합니다.
    ///
    /// 검색 인덱싱, 미리보기 snippet, 알림 본문 등 서식 없는 텍스트가 필요한 곳에서 사용합니다.
    ///
    /// 2-패스로 해석합니다. 에디터에 문법을 직접 타이핑해 이스케이프되어 저장된 콘텐츠
    /// (`\*\*굿\*\*`)는 1차 패스에서 리터럴 `**굿**` 로 풀리는데, 미리보기에는 마커가
    /// 보이면 안 되므로 그 결과를 한 번 더 마크다운으로 해석해 마커를 제거합니다.
    /// 파서의 페어링 규칙을 그대로 따르므로 `2 * 3`, `user_name` 같은 일반 텍스트는
    /// 2차 패스에서도 변형되지 않습니다.
    ///
    /// - Parameter markdown: 마크다운 또는 HTML 문자열.
    /// - Returns: 서식이 모두 제거된 plain text.
    public static func plainText(from markdown: String) -> String {
        if looksLikeHTML(markdown) {
            return plainTextFromHTML(markdown)
        }
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let firstPass = MarkdownBlockParser.deserialize(markdown, baseFont: baseFont).string
        return MarkdownBlockParser.deserialize(firstPass, baseFont: baseFont).string
    }

    // MARK: - Private

    /// HTML 문자열에서 태그를 제거하고 순수 텍스트를 추출합니다.
    ///
    /// `NSAttributedString(data:options:documentAttributes:)` 의 HTML 파서를 활용하여
    /// 태그 제거 + 엔티티 디코딩 + 기본 줄바꿈 보정까지 한 번에 처리합니다.
    /// 파서가 실패할 경우(잘못된 UTF-8, 파싱 불가 등)에는 안전하게 원문을 반환합니다.
    ///
    /// - Parameter html: HTML 콘텐츠.
    /// - Returns: 태그를 제거하고 trim 한 plain text.
    private static func plainTextFromHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8) else { return html }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            return html
        }
        return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
