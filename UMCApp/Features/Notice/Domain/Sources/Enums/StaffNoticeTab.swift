//
//  StaffNoticeTab.swift
//  NoticeDomain
//
//  Created by 이예지 on 6/2/26.
//

import Foundation
import UMCFoundation

// MARK: - StaffNoticeTab
/// 운영진 공지 탭 종류
///
/// 서버 API `noticeTab` 파라미터 값과 1:1 매핑됩니다.
/// 각 탭은 접근 가능한 최소 역할(`ManagementTeam.level`)을 갖습니다.
public enum StaffNoticeTab: String, CaseIterable, Identifiable, Equatable, Hashable {
    case centralMember = "CENTRAL_MEMBER"
    case schoolCore = "SCHOOL_CORE"
    case schoolPartLeader = "SCHOOL_PART_LEADER"

    public var id: String { rawValue }

    public var labelText: String {
        switch self {
        case .centralMember: return "중앙 운영진 공지"
        case .schoolCore: return "학교 회장단 공지"
        case .schoolPartLeader: return "학교 파트장 공지"
        }
    }

    public var labelIcon: String {
        switch self {
        case .centralMember: return "building.columns.fill"
        case .schoolCore: return "graduationcap.fill"
        case .schoolPartLeader: return "person.3.fill"
        }
    }

    /// 이 탭에 접근하기 위한 최소 역할 레벨
    public var minimumLevel: Int {
        switch self {
        case .centralMember: return ManagementTeam.centralEducationTeamMember.level
        case .schoolCore: return ManagementTeam.schoolPresident.level
        case .schoolPartLeader: return ManagementTeam.schoolPartLeader.level
        }
    }

    /// 이 탭 요청 시 schoolId를 포함해야 하는지 여부
    public var requiresSchoolId: Bool {
        switch self {
        case .centralMember: return false
        case .schoolCore, .schoolPartLeader: return true
        }
    }

    /// 특정 역할이 접근 가능한 탭 목록을 반환합니다.
    ///
    /// 서버 스펙: 지부장은 SCHOOL_CORE viewerRole로 매핑되어
    /// SCHOOL_CORE / SCHOOL_PART_LEADER 만 열람 가능 (CENTRAL_MEMBER는 비노출).
    public static func accessibleTabs(for role: ManagementTeam?) -> [StaffNoticeTab] {
        guard let role else { return [] }

        if role == .chapterPresident {
            return [.schoolCore, .schoolPartLeader]
        }

        return allCases.filter { role.level >= $0.minimumLevel }
    }
}
