//
//  MarkdownAttributeBuilder.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/30/26.
//

import Foundation
import UIKit

// MARK: - MarkdownAttributeBuilder

/// `MarkdownInlineStyle` 을 `NSAttributedString` 의 속성 dictionary 와 실제 `UIFont` 로
/// 변환하는 책임을 가진 빌더.
///
/// 파서(역직렬화)와 직렬화 공통 코드 경로에서 재사용되며, Pretendard 커스텀 폰트의
/// 굵기/기울임 처리 같은 플랫폼 세부사항을 한곳에 격리합니다.
public enum MarkdownAttributeBuilder {

    // MARK: - Function

    /// 인라인 스타일 상태로부터 `NSAttributedString` 속성 dictionary 를 구성합니다.
    ///
    /// - Parameters:
    ///   - style: 적용할 인라인 스타일 스냅샷.
    ///   - baseFont: 스타일 별도 지정이 없을 때 기반이 되는 폰트(본문 폰트).
    /// - Returns: `addAttributes(_:range:)` 에 그대로 전달 가능한 속성 dictionary.
    ///
    /// - Note: 인용구 전용 커스텀 키(`editorBlockquote` 등)는 에디터 내부의 장식
    ///   레이어(왼쪽 테두리 라인 등)에서 사용되며, 직렬화 시에도 블록 prefix 판별 근거가 됩니다.
    static func attributes(for style: MarkdownInlineStyle, baseFont: UIFont) -> [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [
            .font: font(for: style, baseFont: baseFont),
        ]

        if style.isUnderlined {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if style.isStruck {
            result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        if let highlightColor = style.highlightColor {
            result[.backgroundColor] = highlightColor
        }

        if let paragraphStyle = style.paragraphStyle {
            result[.paragraphStyle] = paragraphStyle
        }

        if style.isBlockquote {
            result[.editorBlockquote] = true
            result[.editorBlockquoteBorderColor] = UIColor.systemGray3
            result[.editorBlockquoteBaseHeadIndent] = NSNumber(value: 0.0)
            result[.editorBlockquoteBaseFirstLineHeadIndent] = NSNumber(value: 0.0)
        }

        if let linkURL = style.linkURL {
            result[.link] = linkURL
        }

        return result
    }

    /// 인라인 스타일과 기반 폰트를 조합해 최종 `UIFont` 를 계산합니다.
    ///
    /// ### 분기 순서
    /// 1. `isMonospaced` → 시스템 monospaced 폰트로 강제 전환 (bold/italic 유지).
    /// 2. Pretendard 커스텀 폰트 → 폰트명 직접 지정 + oblique matrix 로 italic 시뮬레이션.
    /// 3. 기타 폰트 → symbolic traits (bold/italic) 조합.
    /// 4. traits 적용 실패 시 system bold/italic 폰트로 폴백.
    ///
    /// - Parameters:
    ///   - style: 굵기/기울임/크기 등을 담은 스타일.
    ///   - baseFont: 기반이 되는 폰트.
    /// - Returns: 스타일이 반영된 최종 폰트.
    static func font(for style: MarkdownInlineStyle, baseFont: UIFont) -> UIFont {
        let pointSize = style.fontSize ?? baseFont.pointSize

        if style.isMonospaced {
            var monospacedFont = UIFont.monospacedSystemFont(
                ofSize: pointSize,
                weight: style.isBold ? .bold : fontWeight(from: baseFont)
            )

            if style.isItalic {
                var traits = monospacedFont.fontDescriptor.symbolicTraits
                traits.insert(.traitItalic)

                if let descriptor = monospacedFont.fontDescriptor.withSymbolicTraits(traits) {
                    monospacedFont = UIFont(descriptor: descriptor, size: pointSize)
                }
            }

            return monospacedFont
        }

        // Pretendard 커스텀 폰트는 symbolic traits 방식이 아닌 폰트명 직접 지정으로 처리
        // Pretendard에 italic 변형이 없으므로 oblique matrix로 기울임 표현
        if baseFont.fontName.hasPrefix("Pretendard") {
            let fontName = style.isBold ? "Pretendard-SemiBold" : "Pretendard-Regular"
            var font = UIFont(name: fontName, size: pointSize) ?? baseFont.withSize(pointSize)

            if style.isItalic {
                let oblique = CGAffineTransform(a: 1, b: 0, c: CGFloat(tanf(12.0 * Float.pi / 180.0)), d: 1, tx: 0, ty: 0)
                let descriptor = font.fontDescriptor.withMatrix(oblique)
                font = UIFont(descriptor: descriptor, size: pointSize)
            }

            return font
        }

        var traits = UIFontDescriptor.SymbolicTraits()

        if style.isBold {
            traits.insert(.traitBold)
        }

        if style.isItalic {
            traits.insert(.traitItalic)
        }

        let descriptor = baseFont.fontDescriptor.withSize(pointSize)

        if let styledDescriptor = descriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: styledDescriptor, size: pointSize)
        }

        if style.isBold && style.isItalic {
            let fallbackDescriptor = UIFont.systemFont(ofSize: pointSize, weight: .bold).fontDescriptor
            let italicTraits = fallbackDescriptor.symbolicTraits.union(.traitItalic)

            if let italicDescriptor = fallbackDescriptor.withSymbolicTraits(italicTraits) {
                return UIFont(descriptor: italicDescriptor, size: pointSize)
            }
        }

        if style.isBold {
            return UIFont.systemFont(ofSize: pointSize, weight: .bold)
        }

        if style.isItalic {
            return UIFont.italicSystemFont(ofSize: pointSize)
        }

        return baseFont.withSize(pointSize)
    }

    /// 폰트 descriptor 의 traits dictionary 에서 weight 수치를 꺼내 `UIFont.Weight` 로 변환합니다.
    ///
    /// monospaced 폰트 생성 시 기반 폰트 굵기를 이어받기 위해 사용합니다.
    ///
    /// - Parameter font: 굵기를 읽어올 대상 폰트.
    /// - Returns: `UIFont.Weight` (읽기 실패 시 `.regular`).
    public static func fontWeight(from font: UIFont) -> UIFont.Weight {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        let rawWeight = traits?[.weight] as? CGFloat ?? UIFont.Weight.regular.rawValue
        return UIFont.Weight(rawValue: rawWeight)
    }

    /// 인용구 블록에 적용할 단락 스타일을 생성합니다.
    ///
    /// 첫 줄과 이어지는 줄 모두 동일한 들여쓰기를 갖도록 설정해, 여러 줄 인용구에서도
    /// 왼쪽 테두리 라인과 본문 간격이 일정하게 유지됩니다.
    ///
    /// - Returns: 인용구용 `NSParagraphStyle`.
    public static func quoteParagraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = EditorConstants.blockquoteIndent
        paragraphStyle.headIndent = EditorConstants.blockquoteIndent
        return paragraphStyle
    }

    /// `"R,G,B,A"` 형태의 RGBA 문자열을 `UIColor` 로 파싱합니다.
    ///
    /// `<mark color="0.1,0.2,0.3,0.4">` 형식의 컬러 코드를 역직렬화할 때 사용합니다.
    /// 잘못된 포맷(토큰 개수 불일치, NaN, 무한대)이거나 변환에 실패하면 `nil` 을 반환합니다.
    /// 값은 `[0, 1]` 범위로 clamping 되어 안전하게 `UIColor` 로 전달됩니다.
    ///
    /// - Parameter code: 소수점 구분자를 쉼표로 사용하는 RGBA 문자열.
    /// - Returns: 변환된 `UIColor` 또는 `nil`.
    public static func uiColor(fromCode code: String) -> UIColor? {
        let parts = code.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4, parts.allSatisfy(\.isFinite) else { return nil }
        let clamped = parts.map { max(0.0, min(1.0, $0)) }
        return UIColor(red: CGFloat(clamped[0]), green: CGFloat(clamped[1]), blue: CGFloat(clamped[2]), alpha: CGFloat(clamped[3]))
    }
}
