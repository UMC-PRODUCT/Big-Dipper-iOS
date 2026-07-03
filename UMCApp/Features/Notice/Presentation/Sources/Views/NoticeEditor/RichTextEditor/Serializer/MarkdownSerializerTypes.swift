//
//  MarkdownSerializerTypes.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/1/26.
//

import Foundation
import UIKit

// MARK: - InlineStyle

/// 인라인(문자 단위) 마크다운 서식 상태를 한 곳에 모아두는 값 타입.
///
/// 파서가 재귀적으로 인라인 토큰을 해석하면서 현재까지 적용된 스타일을
/// 누적하고, 직렬화 시에는 `NSAttributedString`의 속성을 이 구조체로 투영하여
/// 마크다운 토큰(`**`, `*`, `<u>` 등)을 결정하는 데 사용합니다.
///
/// 모든 프로퍼티가 `var`인 이유: 파서가 기존 스타일을 복사한 뒤 한두 가지 플래그만
/// 덧씌워 자식 토큰으로 전달하는 패턴을 빈번하게 쓰기 때문입니다.
public struct MarkdownInlineStyle {
    /// `**텍스트**` / `***텍스트***` 등으로 굵게 표시되는지 여부.
    public var isBold = false

    /// `*텍스트*` / `_텍스트_` 등 기울임 적용 여부.
    ///
    /// Pretendard처럼 italic 변형이 없는 커스텀 폰트는 `MarkdownAttributeBuilder`가
    /// oblique matrix로 기울임을 시뮬레이션합니다.
    public var isItalic = false

    /// `<u>텍스트</u>` 로 밑줄이 적용되는지 여부.
    public var isUnderlined = false

    /// `~~텍스트~~` 로 취소선이 적용되는지 여부.
    public var isStruck = false

    /// `` `텍스트` `` 코드 스팬 여부. 모노스페이스 폰트로 렌더링됩니다.
    public var isMonospaced = false

    /// `> 텍스트` 인용구 블록인지 여부. 단락 스타일과 함께 커스텀 attribute 키를 부여합니다.
    public var isBlockquote = false

    /// `<mark color="R,G,B,A">` 로 지정된 하이라이트 배경색.
    ///
    /// `nil`이면 하이라이트가 적용되지 않습니다. `MarkdownAttributeBuilder`는
    /// RGBA 문자열을 `UIColor`로 변환한 값을 그대로 보존하여 역직렬화-재직렬화
    /// 왕복에서 색상이 변형되지 않도록 합니다.
    public var highlightColor: UIColor?

    /// `[텍스트](url)` 형식의 링크 URL. scheme이 허용 목록에 없으면 파서 단계에서 `nil`로 유지됩니다.
    public var linkURL: URL?

    /// 헤딩 크기(17/22/28pt 등) 오버라이드. `nil`이면 `baseFont.pointSize`를 따릅니다.
    public var fontSize: CGFloat?

    /// 인용구의 들여쓰기 등 단락 단위 스타일. `.paragraphStyle` attribute로 주입됩니다.
    public var paragraphStyle: NSParagraphStyle?
}

// MARK: - InlineTokenKind

/// 파서가 인식하는 인라인 마크다운 토큰의 종류.
///
/// `MarkdownRegex.inlinePatterns` 배열이 정의하는 **우선순위 순서**와 케이스 선언 순서를
/// 맞춰두었습니다. 한 구간에 여러 토큰이 모두 매칭될 경우(예: `**_굵은 이탤릭_**` 내부는
/// `bold` 와 `italic` 이 모두 매칭) 배열 앞쪽 규칙이 먼저 적용됩니다.
public enum MarkdownInlineTokenKind {
    /// 인라인 코드 스팬: `` `code` ``
    case code

    /// 링크: `[label](url)`
    case link

    /// 밑줄: `<u>text</u>` (HTML 스타일 태그지만 마크다운 토큰으로 처리)
    case underline

    /// 취소선: `~~text~~`
    case strikethrough

    /// 형광펜/하이라이트: `<mark color="R,G,B,A">text</mark>`
    case highlight

    /// 굵은 이탤릭(혼합형): `**_text_**`
    case boldItalicMixed

    /// 굵은 이탤릭(별 세 개): `***text***`
    case boldItalicStars

    /// 굵게: `**text**`
    case bold

    /// 이탤릭(별): `*text*`
    case italicAsterisk

    /// 이탤릭(언더스코어): `_text_`
    case italicUnderscore
}

// MARK: - InlineToken

/// 인라인 파서가 "가장 먼저 등장하는 토큰"을 선택할 때 사용하는 후보 구조체.
///
/// - Parameters:
///   - kind: 어떤 종류의 인라인 토큰인지.
///   - match: 해당 토큰에 대한 정규식 매칭 결과. capture group 범위도 보존되어
///            본문 텍스트와 메타데이터(링크 URL, 색상 코드 등)를 추출할 수 있습니다.
public struct MarkdownInlineToken {
    /// 토큰 종류. `switch`를 통해 해당 토큰에 맞는 스타일 변형을 적용합니다.
    public let kind: MarkdownInlineTokenKind

    /// 원본 문자열에서 해당 토큰이 매칭된 결과. 위치/길이 및 capture group 범위 포함.
    public let match: NSTextCheckingResult
}

// MARK: - BlockContext

/// 블록(단락) 레벨 직렬화 시 앞부분에 붙일 마크다운 prefix와 인라인 본문 범위를 캡슐화한 구조체.
///
/// 단락이 헤딩/인용구/목록인지 판별한 결과를 `MarkdownBlockSerializer` 내부에서
/// 인라인 직렬화 함수로 전달하기 위해 사용합니다.
public struct MarkdownBlockContext {
    /// 단락 앞에 붙여야 할 마크다운 접두어. 예: `"# "`, `"> "`, `"- "`, `"1. "`.
    ///
    /// 일반 단락은 빈 문자열입니다.
    public let markdownPrefix: String

    /// 접두어를 제외한 **인라인 파트만**의 범위. `prefix` 길이만큼 잘라낸 위치부터 시작합니다.
    public let inlineRange: NSRange

    /// 블록 prefix 자체가 이미 굵게 표현되는 경우(헤딩 계열) `true`.
    ///
    /// 이 값이 `true`이면 인라인 직렬화기는 굵은 텍스트를 `**` 래핑하지 **않습니다**
    /// (중복 래핑 방지).
    public let blockImpliedBold: Bool
}

// MARK: - DeserializedBlock

/// 블록 역직렬화(마크다운 → AttributedString) 결과.
///
/// 줄바꿈 문자에도 해당 블록의 단락 속성이 함께 전파되어야 커서를 개행 위치에 뒀을 때
/// 이전 단락 스타일이 이어지기 때문에 줄바꿈 전용 속성을 별도로 보존합니다.
public struct MarkdownDeserializedBlock {
    /// 한 줄(블록)을 렌더링한 최종 `NSAttributedString`.
    public let content: NSAttributedString

    /// 블록 뒤에 붙이는 `"\n"` 문자에 적용할 속성. 단락 스타일 일관성 유지용.
    public let newlineAttributes: [NSAttributedString.Key: Any]
}
