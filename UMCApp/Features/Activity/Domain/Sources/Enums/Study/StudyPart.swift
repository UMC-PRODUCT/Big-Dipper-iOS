//
//  StudyPart.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import UMCFoundation

/// 스터디 파트
///
/// 서버에서 내려오는 part 라벨 단위로, `UMCPartType` 으로의 변환을 담당합니다.
/// UI 색상 매핑은 Presentation 레이어 extension으로 제공됩니다.
public enum StudyPart: String, CaseIterable, Codable, Hashable {
    case ios = "iOS"
    case android = "Android"
    case web = "Web"
    case spring = "Spring"
    case nodejs = "Node.js"
    case design = "Design"
    case pm = "PM"

    /// `UMCPartType` 변환
    public var partType: UMCPartType {
        switch self {
        case .ios:     return .front(type: .ios)
        case .android: return .front(type: .android)
        case .web:     return .front(type: .web)
        case .spring:  return .server(type: .spring)
        case .nodejs:  return .server(type: .node)
        case .design:  return .design
        case .pm:      return .pm
        }
    }
}
