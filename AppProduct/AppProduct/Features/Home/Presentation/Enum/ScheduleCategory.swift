//
//  ScheduleCategory.swift
//  AppProduct
//
//  Created by euijjang97 on 1/18/26.
//

import SwiftUI
import FoundationModels

/// 일정 카테고리 아이콘 타입
///
/// 일정의 종류(스터디, 회의, 해커톤 등)를 정의하고,
/// 각 종류에 따른 심볼 아이콘, 테마 색상, 한글 명칭을 제공합니다.
enum ScheduleIconCategory: String, Codable, CaseIterable {
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
    ///
    /// `.study` 는 스터디 관리 화면에서 별도 등록하므로 신규 입력 목록에서 제외합니다.
    /// 기존 STUDY 일정의 icon/color/korean 표현은 enum case 가 유지되므로 그대로 동작합니다.
    static var selectableCases: [ScheduleIconCategory] {
        allCases.filter { !$0.isDeprecated }
    }

    /// 더 이상 신규 입력에 사용하지 않는 레거시 카테고리 여부
    ///
    /// - `.testing`: 내부 테스트 전용
    /// - `.study`: 스터디 회차 일정은 스터디 관리 화면에서 별도 등록
    var isDeprecated: Bool {
        self == .testing || self == .study
    }

    /// 카테고리별 시스템 심볼 이미지 이름
    var symbol: String {
        switch self {
        case .leadership:     return "person.3.sequence.fill"
        case .study:          return "book.closed.fill"
        case .fee:           return "wonsign.circle.fill"
        case .meeting:        return "person.2.fill"
        case .networking:     return "bubble.left.and.bubble.right.fill"
        case .hackathon:      return "laptopcomputer"
        case .project:        return "hammer.fill"
        case .presentation:   return "mic.fill"
        case .workshop:       return "tent.fill"
        case .review:  return "lightbulb.fill"
        case .celebration:     return "sparkles"
        case .orientation:    return "megaphone.fill"
        case .testing:        return "chevron.left.forwardslash.chevron.right"
        case .general:        return "calendar.badge"
        }
    }

    /// 카테고리별 테마 색상
    var color: Color {
        switch self {
        case .leadership:     return .indigo
        case .study:          return .blue
        case .fee:           return .green
        case .meeting:        return .cyan
        case .networking:     return .teal
        case .hackathon:      return .purple
        case .project:        return .orange
        case .presentation:   return .red
        case .workshop:       return .mint
        case .review:  return .yellow
        case .celebration:     return .accentColor
        case .orientation:    return .orange
        case .testing:        return .gray
        case .general:        return .indigo500
        }
    }

    /// 카테고리별 한글 명칭
    var korean: String {
        switch self {
        case .leadership:     return "리더십"
        case .study:          return "스터디"
        case .fee:           return "회비"
        case .meeting:        return "회의"
        case .networking:     return "네트워킹"
        case .hackathon:      return "해커톤"
        case .project:        return "프로젝트"
        case .presentation:   return "발표"
        case .workshop:       return "워크샵"
        case .review:  return "회고"
        case .celebration:     return "뒷풀이"
        case .orientation:    return "오리엔테이션"
        case .testing:        return "테스트"
        case .general:        return "일반"
        }
    }
}
