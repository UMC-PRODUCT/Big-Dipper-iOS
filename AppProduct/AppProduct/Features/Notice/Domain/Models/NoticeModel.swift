//
//  NoticeModel.swift
//  AppProduct
//
//  Created by 이예지 on 1/14/26.
//

import Foundation
import SwiftUI

// MARK: - Generation
/// 기수 모델
struct Generation: Identifiable, Equatable, Hashable {
    let value: Int
    var id: Int { value }
    var title: String { "\(value)기" }
}

// MARK: - NoticeScope
/// 공지 출처 (어디서 온 공지인지)
enum NoticeScope: Equatable, Hashable {
    // 중앙
    case central
    // 지부
    case branch
    // 교내
    case campus
}

// MARK: - NoticeCategory
/// 공지 카테고리 (일반/파트별)
enum NoticeCategory: Equatable, Hashable {
    // 일반 공지
    case general
    // 파트별 공지
    case part(UMCPartType)
}

// MARK: - NoticeSubFilterType
/// 서브필터 타입 (전체, 파트)
///
/// 운영진 공지는 `StaffNoticeTab` enum + `StaffNoticeView`로 분리되었습니다. (#723)
enum NoticeSubFilterType: Identifiable, Equatable, Hashable {
    case all
    case part

    var id: String {
        switch self {
        case .all: return "all"
        case .part: return "part"
        }
    }

    var labelText: String {
        switch self {
        case .all: return "전체"
        case .part: return "파트"
        }
    }
}

// MARK: - NoticeMainFilterType
/// 메인필터 타입 (전체, 중앙, 지부, 학교, 파트)
enum NoticeMainFilterType: Identifiable, Equatable, Hashable {
    // 전체
    case all
    // 중앙운영사무국
    case central
    // 지부
    case branch(String)
    // 학교
    case school(String)
    // 파트
    case part(NoticePart)

    var id: String {
        switch self {
        case .all: return "all"
        case .central: return "central"
        case .branch(let name): return "\(name)"
        case .school(let name): return "\(name)"
        case .part(let part): return part.id
        }
    }

    /// 필터 라벨 텍스트
    var labelText: String {
        switch self {
        case .all: return "전체"
        case .central: return "UMC 공지"
        case .branch(let name): return name
        case .school(let name): return name
        case .part(let part): return part.displayName
        }
    }

    /// 필터 아이콘 (SF Symbol)
    var labelIcon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .central: return "building.columns"
        case .branch: return "mappin.and.ellipse"
        case .school: return "graduationcap"
        case .part: return "person.3.fill"
        }
    }

    static func == (lhs: NoticeMainFilterType, rhs: NoticeMainFilterType) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.central, .central):
            return true
        case let (.branch(l), .branch(r)):
            return l == r
        case let (.school(l), .school(r)):
            return l == r
        case let (.part(l), .part(r)):
            return l == r
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .all:
            hasher.combine("all")
        case .central:
            hasher.combine("central")
        case .branch(let name):
            hasher.combine("branch")
            hasher.combine(name)
        case .school(let name):
            hasher.combine("school")
            hasher.combine(name)
        case .part(let part):
            hasher.combine("part")
            hasher.combine(part)
        }
    }
}


// MARK: - MainFilterKey
/// 메인필터 키 (Dictionary key용, associated value 없음)
enum MainFilterKey: Hashable {
    case all
    case central
    case branch
    case school
    case part

    init(from filter: NoticeMainFilterType) {
        switch filter {
        case .all: self = .all
        case .central: self = .central
        case .branch: self = .branch
        case .school: self = .school
        case .part: self = .part
        }
    }
}

// MARK: - MainFilterState
/// 메인필터별 서브필터 상태
struct MainFilterState: Equatable {
    var subFilter: NoticeSubFilterType = .all
    var selectedPart: NoticePart?
}

// MARK: - GenerationFilterState
/// 기수별 필터 상태
struct GenerationFilterState: Equatable {
    var mainFilter: NoticeMainFilterType = .all
    var mainFilterStates: [MainFilterKey: MainFilterState] = [:]

    /// 특정 메인필터의 서브필터 상태 조회
    func state(for key: MainFilterKey) -> MainFilterState {
        mainFilterStates[key] ?? MainFilterState()
    }

    /// 특정 메인필터의 서브필터 상태 업데이트
    mutating func updateState(for key: MainFilterKey, state: MainFilterState) {
        mainFilterStates[key] = state
    }
}

// MARK: - NoticeListSubFilterChip
/// 공지 리스트 하단 칩 구성 타입
enum NoticeListSubFilterChip: Identifiable, Equatable {
    case all
    case branch
    case school
    case part

    var id: String {
        switch self {
        case .all: return "all"
        case .branch: return "branch"
        case .school: return "school"
        case .part: return "part"
        }
    }

    var labelText: String {
        switch self {
        case .all: return "전체"
        case .branch: return "지부"
        case .school: return "학교"
        case .part: return "파트"
        }
    }
}
