//
//  StaffNoticeTab.swift
//  AppProduct
//
//  Created by euijjang97 on 5/15/26.
//

import Foundation

// MARK: - StaffNoticeTab
/// 운영진 공지 탭 종류
///
/// 서버 API `noticeTab` 파라미터 값과 1:1 매핑됩니다.
/// 각 탭은 접근 가능한 최소 역할(`ManagementTeam.level`)을 갖습니다.
enum StaffNoticeTab: String, CaseIterable, Identifiable, Equatable, Hashable {
    case centralMember = "CENTRAL_MEMBER"
    case schoolCore = "SCHOOL_CORE"
    case schoolPartLeader = "SCHOOL_PART_LEADER"

    /// 챌린저(일반) 공지 작성 시 서버에 전달하는 `targetNoticeTab` 값.
    ///
    /// 서버 `NoticeTab` enum 의 `CHALLENGER` 와 1:1. 매직 스트링을 새로 만들지 않고
    /// `ManagementTeam.challenger.rawValue` 를 단일 출처로 참조합니다.
    static let challengerServerValue = ManagementTeam.challenger.rawValue

    var id: String { rawValue }

    var labelText: String {
        switch self {
        case .centralMember: return "중앙 운영진 공지"
        case .schoolCore: return "학교 회장단 공지"
        case .schoolPartLeader: return "학교 파트장 공지"
        }
    }

    var labelIcon: String {
        switch self {
        case .centralMember: return "building.columns.fill"
        case .schoolCore: return "graduationcap.fill"
        case .schoolPartLeader: return "person.3.fill"
        }
    }

    /// 이 탭에 접근하기 위한 최소 역할 레벨
    var minimumLevel: Int {
        switch self {
        case .centralMember: return ManagementTeam.centralEducationTeamMember.level
        case .schoolCore: return ManagementTeam.schoolPresident.level
        case .schoolPartLeader: return ManagementTeam.schoolPartLeader.level
        }
    }

    /// 이 탭 요청 시 schoolId를 포함해야 하는지 여부
    var requiresSchoolId: Bool {
        switch self {
        case .centralMember: return false
        case .schoolCore, .schoolPartLeader: return true
        }
    }

    /// 특정 역할이 접근 가능한 탭 목록을 반환합니다.
    ///
    /// 서버 스펙: 지부장은 SCHOOL_CORE viewerRole로 매핑되어
    /// SCHOOL_CORE / SCHOOL_PART_LEADER 만 열람 가능 (CENTRAL_MEMBER는 비노출).
    static func accessibleTabs(for role: ManagementTeam?) -> [StaffNoticeTab] {
        guard let role else { return [] }

        if role == .chapterPresident {
            return [.schoolCore, .schoolPartLeader]
        }

        return allCases.filter { role.level >= $0.minimumLevel }
    }
}
