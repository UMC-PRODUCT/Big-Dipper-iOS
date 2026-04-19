//
//  EditorToolbarTypes.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation

enum EditorToolbarMode {
    case `default`
    case textSelected
    case tableCell
}

enum EditorParagraphStyle: String, CaseIterable {
    case title
    case heading
    case subheading
    case body
    case mono
}

enum EditorListStyle {
    case bullet
    case dash
    case number
}

enum EditorConstants {
    static let blockquoteIndent: CGFloat = 14
}

extension NSAttributedString.Key {
    static let editorBlockquote = NSAttributedString.Key("EditorToolbarBlockquote")
    static let editorBlockquoteBorderColor = NSAttributedString.Key("EditorToolbarBlockquoteBorderColor")
    static let editorBlockquoteBaseHeadIndent = NSAttributedString.Key("EditorToolbarBlockquoteBaseHeadIndent")
    static let editorBlockquoteBaseFirstLineHeadIndent = NSAttributedString.Key("EditorToolbarBlockquoteBaseFirstLineHeadIndent")
    static let editorListStyle = NSAttributedString.Key("EditorToolbarListStyle")
    /// UIKit이 커서 이동 시 typingAttributes의 oblique matrix를 버리므로 italic 활성 상태를 별도 추적합니다.
    static let editorItalic = NSAttributedString.Key("EditorToolbarItalic")
}
