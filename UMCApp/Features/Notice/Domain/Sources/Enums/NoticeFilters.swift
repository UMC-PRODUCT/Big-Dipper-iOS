//
//  NoticeFilters.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/8/26.
//

import Foundation

// MARK: - NoticeSubFilterType
/// 서브필터 타입 (전체, 운영진 공지, 파트)
public enum NoticeSubFilterType: Identifiable, Equatable, Hashable {
    // 전체
    case all
    /// !!!: 추후 운영진 필터 가리기 해제할 것
    // 운영진 공지
    // case staff
    // 파트
    case part

    public var id: String {
        switch self {
        case .all: return "all"
        //case .staff: return "management"
        case .part: return "part"
        }
    }

    public var labelText: String {
        switch self {
        case .all: return "전체"
        //case .staff: return "운영진 공지"
        case .part: return "파트"
        }
    }
}

// MARK: - NoticeMainFilterType
/// 메인필터 타입 (전체, 중앙, 지부, 학교, 파트)
public enum NoticeMainFilterType: Identifiable, Equatable, Hashable {
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

    public var id: String {
        switch self {
        case .all: return "all"
        case .central: return "central"
        case .branch(let name): return "branch_\(name)"
        case .school(let name): return "school_\(name)"
        case .part(let part): return part.id
        }
    }

    /// 필터 라벨 텍스트
    public var labelText: String {
        switch self {
        case .all: return "전체"
        case .central: return "UMC 공지"
        case .branch(let name): return name
        case .school(let name): return name
        case .part(let part): return part.displayName
        }
    }

    /// 필터 아이콘 (SF Symbol)
    public var labelIcon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .central: return "building.columns"
        case .branch: return "mappin.and.ellipse"
        case .school: return "graduationcap"
        case .part: return "person.3.fill"
        }
    }

    public static func == (lhs: NoticeMainFilterType, rhs: NoticeMainFilterType) -> Bool {
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

    public func hash(into hasher: inout Hasher) {
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
public enum MainFilterKey: Hashable {
    case all
    case central
    case branch
    case school
    case part

    public init(from filter: NoticeMainFilterType) {
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
public struct MainFilterState: Equatable {
    public var subFilter: NoticeSubFilterType = .all
    public var selectedPart: NoticePart?
}

// MARK: - GenerationFilterState
/// 기수별 필터 상태
public struct GenerationFilterState: Equatable {
    public var mainFilter: NoticeMainFilterType = .all
    public var mainFilterStates: [MainFilterKey: MainFilterState] = [:]
    
    public init(
          mainFilter: NoticeMainFilterType = .all,
          mainFilterStates: [MainFilterKey: MainFilterState] = [:]
    ) {
        self.mainFilter = mainFilter
        self.mainFilterStates = mainFilterStates
    }

    /// 특정 메인필터의 서브필터 상태 조회
    public func state(for key: MainFilterKey) -> MainFilterState {
        mainFilterStates[key] ?? MainFilterState()
    }

    /// 특정 메인필터의 서브필터 상태 업데이트
    public mutating func updateState(for key: MainFilterKey, state: MainFilterState) {
        mainFilterStates[key] = state
    }
}

// MARK: - NoticeListSubFilterChip
/// 공지 리스트 하단 칩 구성 타입
public enum NoticeListSubFilterChip: Identifiable, Equatable {
    case all
    case branch
    case school
    case part

    public var id: String {
        switch self {
        case .all: return "all"
        case .branch: return "branch"
        case .school: return "school"
        case .part: return "part"
        }
    }

    public var labelText: String {
        switch self {
        case .all: return "전체"
        case .branch: return "지부"
        case .school: return "학교"
        case .part: return "파트"
        }
    }
}
