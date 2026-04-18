//
//  MarkdownHTMLDetector.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import UIKit

// MARK: - MarkdownHTMLDetector

enum MarkdownHTMLDetector {

    // MARK: - Function

    /// 문자열이 마크다운이 아닌 HTML 형식인지 휴리스틱으로 판별합니다.
    /// `<u>`, `<mark>`는 iOS 에디터의 마크다운 인라인 토큰이므로 제외합니다.
    static func looksLikeHTML(_ content: String) -> Bool {
        let pattern = "<(p|div|br|span|b|i|strong|em|ul|ol|li|h[1-6]|blockquote|a|table|tr|td)[\\s>/]"
        return content.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// 마크다운 또는 HTML 문자열에서 모든 서식을 제거하고 plain text를 반환합니다.
    static func plainText(from markdown: String) -> String {
        if looksLikeHTML(markdown) {
            return plainTextFromHTML(markdown)
        }
        return MarkdownBlockParser.deserialize(markdown, baseFont: UIFont.preferredFont(forTextStyle: .body)).string
    }

    // MARK: - Private

    /// HTML 문자열에서 태그를 제거하고 순수 텍스트를 추출합니다.
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
