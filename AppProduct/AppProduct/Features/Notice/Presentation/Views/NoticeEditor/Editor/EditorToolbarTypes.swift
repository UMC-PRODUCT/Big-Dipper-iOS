//
//  EditorToolbarTypes.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation

/// 공지 에디터 툴바의 표시 상태를 정의합니다.
enum EditorToolbarMode {
    case `default`
    case textSelected
    case tableCell
}

/// 공지 에디터 단락 스타일 프리셋을 정의합니다.
enum EditorParagraphStyle: String, CaseIterable {
    case title
    case heading
    case subheading
    case body
    case mono
}

/// 공지 에디터 목록 스타일을 정의합니다.
enum EditorListStyle {
    case bullet
    case dash
    case number
}

/// 공지 에디터 전역 상수입니다.
enum EditorConstants {
    /// 블록 인용문에 적용되는 들여쓰기(pt) 값입니다. 에디터와 역직렬화에서 공통 사용합니다.
    static let blockquoteIndent: CGFloat = 14
}

extension NSAttributedString.Key {

    /// 블록 인용문 적용 여부를 저장하는 키입니다.
    static let editorBlockquote = NSAttributedString.Key("EditorToolbarBlockquote")

    /// 블록 인용문 테두리 색상을 저장하는 키입니다.
    static let editorBlockquoteBorderColor = NSAttributedString.Key("EditorToolbarBlockquoteBorderColor")

    /// 블록 인용문 이전의 headIndent 값을 저장하는 키입니다.
    static let editorBlockquoteBaseHeadIndent = NSAttributedString.Key("EditorToolbarBlockquoteBaseHeadIndent")

    /// 블록 인용문 이전의 firstLineHeadIndent 값을 저장하는 키입니다.
    static let editorBlockquoteBaseFirstLineHeadIndent = NSAttributedString.Key("EditorToolbarBlockquoteBaseFirstLineHeadIndent")

    /// 현재 목록 스타일 식별자를 저장하는 키입니다.
    static let editorListStyle = NSAttributedString.Key("EditorToolbarListStyle")
}
