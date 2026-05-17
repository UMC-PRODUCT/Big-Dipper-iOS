//
//  CommunityItemCategory.swift
//  CoreDomain
//
//  Created by 김미주 on 5/10/26.
//

import Foundation

/// 커뮤니티 게시글 카테고리
///
/// UI 프로퍼티(color)는 사용처 Presentation 모듈의 extension으로 제공합니다.
public enum CommunityItemCategory: String, Hashable, CaseIterable, Codable {
    case lighting = "LIGHTNING"
    case question = "QUESTION"
    case free = "FREE"
    case information = "INFORMATION"
    case habit = "HABIT"

    /// 카테고리 표시 텍스트 (이모지 + 한글)
    public var text: String {
        switch self {
        case .lighting:     return "⚡️ 번개"
        case .question:     return "🔥 질문"
        case .free:         return "💌 자유"
        case .information:  return "📚 정보"
        case .habit:        return "📝 습관"
        }
    }

    /// 서버 API 문자열로부터 생성
    public init?(apiValue: String) {
        switch apiValue {
        case "LIGHTNING":     self = .lighting
        case "QUESTION":      self = .question
        case "FREE":          self = .free
        case "INFORMATION":   self = .information
        case "HABIT":         self = .habit
        default:              return nil
        }
    }
}
