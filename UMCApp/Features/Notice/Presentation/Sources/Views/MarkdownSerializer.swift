//
//  MarkdownSerializer.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import UIKit

// TODO: 교체 - MarkdownSerializer 본체로 대체 예정
public enum MarkdownSerializer {
    
    static func serialize(_ attributedString: NSAttributedString) -> String {
        var markdown = ""
        return markdown
    }
    
    public static func plainText(from markdown: String) -> String { markdown }
    
    public static func looksLikeHTML(_ content: String) -> Bool {
        let pattern = "<(p|div|br|span|b|i|strong|em|ul|ol|li|h[1-6]|blockquote|a|table|tr|td)[\\s>/]"
        return content.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    public static func deserializeForDisplay(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        return attributedString
    }
    
    public static func unescapeForDisplay(_ markdown: String) -> String {
        var unescaped = ""
        return unescaped
    }
    
    public static func deserialize(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        return attributedString
    }
}
