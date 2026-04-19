//
//  MarkdownSerializerTypes.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - InlineStyle

struct MarkdownInlineStyle {
    var isBold = false
    var isItalic = false
    var isUnderlined = false
    var isStruck = false
    var isMonospaced = false
    var isBlockquote = false
    var highlightColor: UIColor?
    var linkURL: URL?
    var fontSize: CGFloat?
    var paragraphStyle: NSParagraphStyle?
}

// MARK: - InlineTokenKind

enum MarkdownInlineTokenKind {
    case code
    case link
    case underline
    case strikethrough
    case highlight
    case boldItalicMixed
    case boldItalicStars
    case bold
    case italicAsterisk
    case italicUnderscore
}

// MARK: - InlineToken

struct MarkdownInlineToken {
    let kind: MarkdownInlineTokenKind
    let match: NSTextCheckingResult
}

// MARK: - BlockContext

struct MarkdownBlockContext {
    let markdownPrefix: String
    let inlineRange: NSRange
    let blockImpliedBold: Bool
}

// MARK: - DeserializedBlock

struct MarkdownDeserializedBlock {
    let content: NSAttributedString
    let newlineAttributes: [NSAttributedString.Key: Any]
}
