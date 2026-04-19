//
//  MarkdownSerializer.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - MarkdownSerializer (Facade)

enum MarkdownSerializer {

    // MARK: - Serialize

    static func serialize(_ attributedString: NSAttributedString) -> String {
        MarkdownBlockSerializer.serialize(attributedString)
    }

    // MARK: - HTML Detection

    static func looksLikeHTML(_ content: String) -> Bool {
        MarkdownHTMLDetector.looksLikeHTML(content)
    }

    // MARK: - Plain Text

    static func plainText(from markdown: String) -> String {
        MarkdownHTMLDetector.plainText(from: markdown)
    }

    // MARK: - Display Rendering

    /// 서버에서 받은 마크다운 문자열을 화면 표시용 NSAttributedString으로 변환합니다.
    ///
    /// `deserialize`와 동일하게 동작합니다. 백슬래시 이스케이프는 파서 내부의
    /// `unescapeMarkdownText`가 plain text 구간에서만 제거하므로
    /// `\*\*not bold\*\*`는 서식 없이 `**not bold**`로 표시되고,
    /// `**bold**`는 볼드로 올바르게 렌더링됩니다.
    static func deserializeForDisplay(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        MarkdownBlockParser.deserialize(markdown, baseFont: baseFont)
    }

    /// 서버에서 수신한 마크다운의 백슬래시 이스케이프를 제거합니다.
    /// 디스플레이 전처리 전용 — 에디터 로드 경로에는 사용하지 마십시오.
    static func unescapeForDisplay(_ markdown: String) -> String {
        MarkdownEscaping.unescapeMarkdownText(markdown)
    }

    // MARK: - Deserialize

    static func deserialize(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        MarkdownBlockParser.deserialize(markdown, baseFont: baseFont)
    }
}
