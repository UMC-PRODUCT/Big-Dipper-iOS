//
//  ScheduleIconCategory.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation

/// 일정 카테고리 분류
///
/// 일정의 종류(스터디, 회의, 해커톤 등)를 정의합니다.
/// 시각 매핑(SF Symbol, Color)은 `CoreDesignSystem`의 extension에서 제공합니다.
public enum ScheduleIconCategory: String, Codable, CaseIterable, Sendable {
    /// 리더십 관련 활동
    case leadership = "LEADERSHIP"
    /// 스터디 활동
    case study = "STUDY"
    /// 회비 관련
    case fee = "DUES"
    /// 회의 (운영진 회의 등)
    case meeting = "MEETING"
    /// 네트워킹 행사
    case networking = "NETWORKING"
    /// 해커톤 행사
    case hackathon = "HACKATHON"
    /// 프로젝트 활동
    case project = "PROJECT"
    /// 발표 관련 (데모데이 등)
    case presentation = "PRESENTATION"
    /// 워크샵 행사
    case workshop = "WORKSHOP"
    /// 회고 활동
    case review = "RETROSPECTIVE"
    /// 뒷풀이/축하 행사
    case celebration = "AFTER_PARTY"
    /// 오리엔테이션 (OT)
    case orientation = "ORIENTATION"
    /// 테스트/검증 일정
    case testing = "TESTING"
    /// 일반 일정
    case general = "GENERAL"

    /// 일정 등록 화면에서 노출할 카테고리 목록
    public static var selectableCases: [ScheduleIconCategory] {
        allCases.filter { $0 != .testing }
    }

    /// 더 이상 신규 입력에 사용하지 않는 레거시 카테고리 여부
    public var isDeprecated: Bool {
        self == .testing
    }

    /// 카테고리별 한글 명칭
    public var korean: String {
        switch self {
        case .leadership:   return "리더십"
        case .study:        return "스터디"
        case .fee:          return "회비"
        case .meeting:      return "회의"
        case .networking:   return "네트워킹"
        case .hackathon:    return "해커톤"
        case .project:      return "프로젝트"
        case .presentation: return "발표"
        case .workshop:     return "워크샵"
        case .review:       return "회고"
        case .celebration:  return "뒷풀이"
        case .orientation:  return "오리엔테이션"
        case .testing:      return "테스트"
        case .general:      return "일반"
        }
    }
}
