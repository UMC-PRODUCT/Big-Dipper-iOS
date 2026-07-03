//
//  MarkdownSerializer.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/1/26.
//

import Foundation
import UIKit

// MARK: - MarkdownSerializer (Facade)

/// 리치 텍스트 에디터의 마크다운 변환 진입점.
///
/// 내부 구현은 `MarkdownBlockSerializer`, `MarkdownBlockParser`, `MarkdownHTMLDetector`,
/// `MarkdownEscaping` 으로 책임이 분리되어 있으며, 이 타입은 호출자가 한 곳만 바라볼 수
/// 있도록 Facade 역할을 수행합니다.
///
/// ### 왜 Facade 가 필요한가
/// - 호출자(ViewModel, View)가 직렬화/역직렬화/plain text/HTML 감지를 각각 다른 타입에서
///   꺼내 쓰지 않아도 됩니다.
/// - 내부 파일을 SOLID 원칙에 따라 분리한 뒤에도 공용 API 표면은 불변이라 리팩터링 영향이
///   국소화됩니다.
public enum MarkdownSerializer {

    // MARK: - Serialize

    /// 에디터의 attributed string 을 마크다운 문자열로 변환합니다.
    ///
    /// - Parameter attributedString: 에디터 현재 상태.
    /// - Returns: 저장/전송에 사용할 마크다운 원문.
    public static func serialize(_ attributedString: NSAttributedString) -> String {
        MarkdownBlockSerializer.serialize(attributedString)
    }

    // MARK: - HTML Detection

    /// 문자열이 HTML 형식인지 휴리스틱으로 판별합니다.
    ///
    /// - Parameter content: 검사 대상.
    /// - Returns: HTML 로 보이면 `true`.
    public static func looksLikeHTML(_ content: String) -> Bool {
        MarkdownHTMLDetector.looksLikeHTML(content)
    }

    // MARK: - Plain Text

    /// 마크다운/HTML 에 관계없이 plain text 만 추출합니다.
    ///
    /// 검색 인덱싱, 미리보기, 알림 본문 등에 사용합니다.
    ///
    /// - Parameter markdown: 마크다운 또는 HTML 원본.
    /// - Returns: 서식이 제거된 plain text.
    public static func plainText(from markdown: String) -> String {
        MarkdownHTMLDetector.plainText(from: markdown)
    }

    // MARK: - Display Rendering

    /// 서버에서 받은 마크다운 문자열을 화면 표시용 NSAttributedString으로 변환합니다.
    ///
    /// `deserialize`와 동일하게 동작합니다. 백슬래시 이스케이프는 파서 내부의
    /// `unescapeMarkdownText`가 plain text 구간에서만 제거하므로
    /// `\*\*not bold\*\*`는 서식 없이 `**not bold**`로 표시되고,
    /// `**bold**`는 볼드로 올바르게 렌더링됩니다.
    ///
    /// - Parameters:
    ///   - markdown: 표시할 마크다운.
    ///   - baseFont: 본문 기본 폰트.
    /// - Returns: 렌더링 가능한 attributed string.
    public static func deserializeForDisplay(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        MarkdownBlockParser.deserialize(markdown, baseFont: baseFont)
    }

    /// 서버에서 수신한 마크다운의 백슬래시 이스케이프를 제거합니다.
    /// 디스플레이 전처리 전용 — 에디터 로드 경로에는 사용하지 마십시오.
    ///
    /// 에디터 로드 시에는 파서가 내부적으로 plain text 구간만 선택적으로 unescape 하므로,
    /// 사전에 전체 문자열을 unescape 해 버리면 `\*not bold\*` 같은 입력이 원래 서식으로
    /// 잘못 해석될 수 있습니다. 따라서 화면에 단순 출력할 때만 사용하세요.
    ///
    /// - Parameter markdown: escape 가 포함된 마크다운 문자열.
    /// - Returns: escape 가 제거된 문자열.
    public static func unescapeForDisplay(_ markdown: String) -> String {
        MarkdownEscaping.unescapeMarkdownText(markdown)
    }

    // MARK: - Deserialize

    /// 마크다운 문자열을 에디터 로드용 attributed string 으로 변환합니다.
    ///
    /// `deserializeForDisplay` 와 동일한 내부 파서를 호출하지만, 의미론적으로 에디터 로드
    /// 경로에서 사용됨을 나타냅니다.
    ///
    /// - Parameters:
    ///   - markdown: 로드할 마크다운.
    ///   - baseFont: 본문 기본 폰트.
    /// - Returns: 에디터에 주입 가능한 attributed string.
    public static func deserialize(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        MarkdownBlockParser.deserialize(markdown, baseFont: baseFont)
    }
}
