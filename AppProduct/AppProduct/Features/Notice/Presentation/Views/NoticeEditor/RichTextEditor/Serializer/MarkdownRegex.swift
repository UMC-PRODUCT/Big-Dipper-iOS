//
//  MarkdownRegex.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation

// MARK: - MarkdownRegex

enum MarkdownRegex {

    // MARK: - Block Serialization Regex

    static let bulletPrefix = try! NSRegularExpression(pattern: "^•\\s+")
    static let dashPrefix = try! NSRegularExpression(pattern: "^–\\s+")
    static let numberPrefix = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // MARK: - Block Deserialization Regex

    static let h3 = try! NSRegularExpression(pattern: "^###\\s+")
    static let h2 = try! NSRegularExpression(pattern: "^##\\s+")
    static let h1 = try! NSRegularExpression(pattern: "^#\\s+")
    static let blockquote = try! NSRegularExpression(pattern: "^>\\s+")
    static let bulletList = try! NSRegularExpression(pattern: "^-\\s+")
    static let dashList = try! NSRegularExpression(pattern: "^–\\s+")
    static let numberList = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // MARK: - Leading Block Escape Regex

    static let leadingNumber = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // MARK: - Inline Patterns

    static let inlinePatterns: [(MarkdownInlineTokenKind, NSRegularExpression)] = {
        let patterns: [(MarkdownInlineTokenKind, String)] = [
            (.code, "(?<!\\\\)`((?:\\\\.|[^`\\n])+?)`"),
            (.link, "(?<!\\\\)\\[((?:\\\\.|[^\\]\\n])+?)\\]\\(((?:\\\\.|[^)\\n])+?)\\)"),
            (.underline, "(?<!\\\\)<u>(.+?)</u>"),
            (.strikethrough, "(?<!\\\\)~~(?=\\S)(.+?)(?<=\\S)~~"),
            (.highlight, "(?<!\\\\)<mark(?:\\s+color=\"([^\"]*)\")?>(.+?)</mark>"),
            (.boldItalicMixed, "(?<!\\\\)\\*\\*_(.+?)_\\*\\*"),
            (.boldItalicStars, "(?<!\\\\)\\*\\*\\*(.+?)\\*\\*\\*"),
            (.bold, "(?<!\\\\)\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*"),
            (.italicAsterisk, "(?<!\\\\)(?<!\\*)\\*(?=\\S)(.+?)(?<=\\S)\\*(?!\\*)"),
            (.italicUnderscore, "(?<!\\\\)(?<!_)_(?=\\S)(.+?)(?<=\\S)_(?!_)"),
        ]
        return patterns.compactMap { kind, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
                return nil
            }
            return (kind, regex)
        }
    }()
}
