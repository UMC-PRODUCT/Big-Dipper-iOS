//
//  MarkdownBlockSerializer.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - MarkdownBlockSerializer

/// `NSAttributedString` 을 **블록 단위**로 마크다운 문자열로 직렬화하는 엔진.
///
/// 단락(paragraph) 경계를 따라가며 각 단락에 적절한 블록 prefix
/// (`#`, `>`, `- `, `1. ` 등) 를 결정하고, 인라인 직렬화는 `MarkdownInlineSerializer` 에
/// 위임합니다. 단락 경계를 넘어서는 줄바꿈 문자(trailing newlines)는 내용과 분리하여
/// 손실 없이 보존합니다.
enum MarkdownBlockSerializer {

    // MARK: - Function

    /// attributed string 전체를 마크다운 문자열로 변환합니다.
    ///
    /// ### 처리 흐름
    /// 1. 빈 문자열 가드 → `""` 반환.
    /// 2. `paragraphRange(for:)` 로 단락 단위 전진.
    /// 3. 단락의 trailing newline 을 분리해 순서 유지.
    /// 4. `blockContext` 로 prefix/인라인 범위 판별 → 인라인 직렬화기 호출.
    /// 5. prefix 가 비어있는 일반 단락은 `escapeLeadingBlockSyntax` 로 보정(충돌 방지).
    ///
    /// - Parameter attributedString: 에디터의 현재 입력 상태.
    /// - Returns: 저장/전송에 사용할 마크다운 문자열.
    static func serialize(_ attributedString: NSAttributedString) -> String {
        let nsString = attributedString.string as NSString

        guard nsString.length > 0 else {
            return ""
        }

        var markdown = ""
        var location = 0

        while location < nsString.length {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            let paragraphText = nsString.substring(with: paragraphRange) as NSString
            let contentLength = contentLengthExcludingTrailingNewlines(in: paragraphText)
            let contentRange = NSRange(location: paragraphRange.location, length: contentLength)
            let trailingRange = NSRange(
                location: paragraphRange.location + contentLength,
                length: paragraphRange.length - contentLength
            )

            if contentRange.length == 0 {
                markdown.append(nsString.substring(with: trailingRange))
                location = NSMaxRange(paragraphRange)
                continue
            }

            let blockContext = blockContext(for: attributedString, contentRange: contentRange)
            var line = blockContext.markdownPrefix
            line.append(MarkdownInlineSerializer.serializeInline(
                attributedString,
                range: blockContext.inlineRange,
                blockImpliedBold: blockContext.blockImpliedBold
            ))

            if blockContext.markdownPrefix.isEmpty {
                line = MarkdownEscaping.escapeLeadingBlockSyntax(in: line)
            }

            markdown.append(line)
            markdown.append(nsString.substring(with: trailingRange))
            location = NSMaxRange(paragraphRange)
        }

        return markdown
    }

    // MARK: - Private

    /// 주어진 단락 범위에 어울리는 블록 prefix 를 결정합니다.
    ///
    /// ### 판별 우선순위
    /// 1. **속성 기반**: 인용구 attribute → 헤딩 폰트 크기(28/22/17pt).
    /// 2. **텍스트 prefix 기반**: `•`, `–`, `1.` 시작 여부.
    ///
    /// 속성 기반을 먼저 보는 이유: 제목/인용구가 우연히 목록처럼 보이는 문자열
    /// (예: 제목이 `• 중요 공지` 로 시작) 을 오해석하지 않도록 하기 위함입니다.
    ///
    /// - Parameters:
    ///   - attributedString: 전체 에디터 텍스트.
    ///   - contentRange: 개행을 제외한 단락 본문 범위.
    /// - Returns: prefix / 인라인 범위 / 블록 레벨 bold 여부가 담긴 `MarkdownBlockContext`.
    private static func blockContext(for attributedString: NSAttributedString, contentRange: NSRange) -> MarkdownBlockContext {
        let paragraphString = attributedString.attributedSubstring(from: contentRange).string as NSString
        let fullLength = paragraphString.length

        guard let firstContentOffset = firstNonWhitespaceOffset(in: paragraphString as String) else {
            return MarkdownBlockContext(markdownPrefix: "", inlineRange: contentRange, blockImpliedBold: false)
        }

        let firstContentLocation = contentRange.location + firstContentOffset
        let font = attributedString.attribute(.font, at: firstContentLocation, effectiveRange: nil) as? UIFont

        let isBlockquote = (attributedString.attribute(.editorBlockquote, at: firstContentLocation, effectiveRange: nil) as? Bool) == true
        if isBlockquote {
            return MarkdownBlockContext(markdownPrefix: "> ", inlineRange: contentRange, blockImpliedBold: false)
        }

        if let font, abs(font.pointSize - 28) < 0.5 {
            return MarkdownBlockContext(markdownPrefix: "# ", inlineRange: contentRange, blockImpliedBold: true)
        }

        if let font, abs(font.pointSize - 22) < 0.5 {
            return MarkdownBlockContext(markdownPrefix: "## ", inlineRange: contentRange, blockImpliedBold: true)
        }

        if let font,
           abs(font.pointSize - 17) < 0.5,
           font.fontDescriptor.symbolicTraits.contains(.traitBold),
           isParagraphDominantlySubheading(in: attributedString, range: contentRange) {
            return MarkdownBlockContext(markdownPrefix: "### ", inlineRange: contentRange, blockImpliedBold: true)
        }

        if let match = MarkdownRegex.bulletPrefix
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            return MarkdownBlockContext(
                markdownPrefix: "- ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        if let match = MarkdownRegex.dashPrefix
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            return MarkdownBlockContext(
                markdownPrefix: "– ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        if let match = MarkdownRegex.numberPrefix
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            let marker = paragraphString.substring(with: match.range(at: 1))
            return MarkdownBlockContext(
                markdownPrefix: "\(marker). ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        return MarkdownBlockContext(markdownPrefix: "", inlineRange: contentRange, blockImpliedBold: false)
    }

    /// 단락 문자열의 끝에서 연속된 `\n`/`\r` 개수를 제외한 "내용 길이" 를 계산합니다.
    ///
    /// 단락을 `content + trailing` 으로 쪼개 직렬화 결과와 원본의 줄바꿈 수가 동일하도록
    /// 보존하는 데 사용됩니다.
    ///
    /// - Parameter paragraph: `paragraphRange` 로 얻은 단락 문자열.
    /// - Returns: trailing 개행을 제외한 문자열 길이.
    private static func contentLengthExcludingTrailingNewlines(in paragraph: NSString) -> Int {
        var length = paragraph.length

        while length > 0 {
            let character = paragraph.substring(with: NSRange(location: length - 1, length: 1))

            if character == "\n" || character == "\r" {
                length -= 1
                continue
            }

            break
        }

        return length
    }

    /// 문자열에서 공백이 아닌 첫 글자의 offset 을 반환합니다.
    ///
    /// 전체가 공백이면 `nil` 을 반환하며, 호출부는 이 경우 "빈 단락" 으로 처리합니다.
    ///
    /// - Parameter text: 검색 대상 문자열.
    /// - Returns: 공백 아닌 첫 문자의 위치 또는 `nil`.
    private static func firstNonWhitespaceOffset(in text: String) -> Int? {
        let nsText = text as NSString
        let range = nsText.rangeOfCharacter(from: CharacterSet.whitespaces.inverted)

        guard range.location != NSNotFound else {
            return nil
        }

        return range.location
    }

    /// 단락 내 비공백 문자 전체가 17pt bold 폰트인지 확인합니다.
    ///
    /// 링크, 밑줄, bold-italic 복합 등 인라인 서식이 포함되어도 폰트 크기와 굵기가
    /// subheading 조건을 만족하면 `###` 접두사를 붙일 수 있도록 합니다.
    ///
    /// - Parameters:
    ///   - attributedString: 전체 에디터 텍스트.
    ///   - range: 검사 대상 단락 범위.
    /// - Returns: 모든 비공백 run 이 17pt bold 이면 `true`.
    private static func isParagraphDominantlySubheading(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        var hasNonWhitespace = false
        var allSubheading = true

        attributedString.enumerateAttribute(.font, in: range) { value, effectiveRange, stop in
            let content = attributedString.attributedSubstring(from: effectiveRange).string
            guard content.contains(where: { !$0.isWhitespace }) else { return }
            hasNonWhitespace = true

            if let font = value as? UIFont,
               abs(font.pointSize - 17) < 0.5,
               font.fontDescriptor.symbolicTraits.contains(.traitBold) {
            } else {
                allSubheading = false
                stop.pointee = true
            }
        }

        return hasNonWhitespace && allSubheading
    }
}
