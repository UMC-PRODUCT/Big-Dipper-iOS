//
//  ManagementTeam.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/25/26.
//

import Foundation
import SwiftUI

/// 멤버 역할/권한 구분
///
/// 서버 API `roleType` 값과 1:1 매핑됩니다.
///
/// 계층 구조 (높은 → 낮은)
/// 1. superAdmin (시스템 관리자)
/// 2. centralPresident / centralVicePresident (총괄/부총괄)
/// 3. centralOperatingTeamMember / centralEducationTeamMember (중앙 운영진)
/// 4. chapterPresident (지부장)
/// 5. schoolPresident / schoolVicePresident (교내 회장단)
/// 6. schoolPartLeader (교내 파트장)
/// 7. schoolEtcAdmin (교내 기타 운영진)
/// 8. challenger (챌린저)
enum ManagementTeam: String, CaseIterable, Codable, Comparable {

    // MARK: - Cases

    case superAdmin = "SUPER_ADMIN"
    case centralPresident = "CENTRAL_PRESIDENT"
    case centralVicePresident = "CENTRAL_VICE_PRESIDENT"
    case centralOperatingTeamMember = "CENTRAL_OPERATING_TEAM_MEMBER"
    case centralEducationTeamMember = "CENTRAL_EDUCATION_TEAM_MEMBER"
    case chapterPresident = "CHAPTER_PRESIDENT"
    case schoolPresident = "SCHOOL_PRESIDENT"
    case schoolVicePresident = "SCHOOL_VICE_PRESIDENT"
    case schoolPartLeader = "SCHOOL_PART_LEADER"
    case schoolEtcAdmin = "SCHOOL_ETC_ADMIN"
    case challenger = "CHALLENGER"

    // MARK: - Level

    /// 권한 레벨 (높을수록 상위 권한)
    ///
    /// 이슈 #399 기준으로 복수 역할 보유 시 아래 순서를 우선 적용합니다.
    /// superAdmin은 시스템 역할이므로 별도로 최상위에 둡니다.
    var level: Int {
        switch self {
        case .superAdmin:                   return 110
        case .centralPresident:             return 100
        case .centralVicePresident:         return 90
        case .centralOperatingTeamMember:   return 80
        case .centralEducationTeamMember:   return 70
        case .chapterPresident:             return 60
        case .schoolPresident:              return 50
        case .schoolVicePresident:          return 40
        case .schoolPartLeader:             return 30
        case .schoolEtcAdmin:               return 20
        case .challenger:                   return 0
        }
    }

    /// Admin 모드 접근 가능 여부
    var canAccessAdminMode: Bool {
        level >= Self.schoolEtcAdmin.level
    }

    /// 스터디 그룹 생성 가능 여부 (교내 회장/부회장만 가능)
    var canCreateStudyGroup: Bool {
        self == .schoolPresident || self == .schoolVicePresident
    }

    /// 운영진 공지 탭 접근 가능 여부 (교내 파트장 이상)
    var canAccessStaffNotice: Bool {
        level >= Self.schoolPartLeader.level
    }

    // MARK: - Comparable

    static func < (lhs: ManagementTeam, rhs: ManagementTeam) -> Bool {
        lhs.level < rhs.level
    }

    static func highestPriority<S: Sequence>(in roles: S) -> ManagementTeam? where S.Element == ManagementTeam {
        roles.max()
    }

    // MARK: - Notice Write Permissions

    /// 중앙운영진 전체(`CENTRAL_MEMBER`) 공지 작성 가능 여부
    ///
    /// 서버 스펙: `STAFF_SPECIFIC_GISU` + `targetNoticeTab=CENTRAL_MEMBER` → CENTRAL_CORE
    var canWriteCentralAllNotice: Bool {
        self == .superAdmin
            || self == .centralPresident
            || self == .centralVicePresident
    }

    /// 학교 회장단(`SCHOOL_CORE`) 공지 작성 가능 여부
    ///
    /// 서버 스펙:
    /// - 학교 미지정: CENTRAL_MEMBER(교육/운영팀원) 이상
    /// - 학교 지정: SCHOOL_CORE(학교 회장/부회장) 이상
    var canWriteSchoolCoreNotice: Bool {
        self == .superAdmin
            || level >= ManagementTeam.centralEducationTeamMember.level
            || self == .schoolPresident
            || self == .schoolVicePresident
    }

    /// 학교 파트장(`SCHOOL_PART_LEADER`) 공지 작성 가능 여부
    ///
    /// 서버 스펙:
    /// - 학교 미지정: CENTRAL_MEMBER(교육/운영팀원) 이상
    /// - 학교 지정: SCHOOL_CORE(학교 회장/부회장) 이상
    /// - 파트 지정: CENTRAL_MEMBER 이상
    ///
    /// 학교 파트장(`SCHOOL_PART_LEADER`) 본인은 작성 권한이 없습니다.
    var canWriteSchoolPartLeaderNotice: Bool {
        self == .superAdmin
            || level >= ManagementTeam.centralEducationTeamMember.level
            || self == .schoolPresident
            || self == .schoolVicePresident
    }

    /// 학교 파트장 공지 작성 시, 본인 학교로 자동 바인딩되는 역할
    var bindsOwnSchoolForPartLeaderNotice: Bool {
        self == .schoolPresident
            || self == .schoolVicePresident
    }

    /// 학교 회장단 공지 작성 시, 본인 학교로 자동 바인딩되는 역할
    var bindsOwnSchoolForSchoolCoreNotice: Bool {
        self == .schoolPresident || self == .schoolVicePresident
    }

    /// 챌린저 공지 — 지부 범위 작성 가능 여부
    ///
    /// 서버 스펙: `SPECIFIC_GISU_SPECIFIC_CHAPTER` / `_WITH_PART` → CHAPTER_PRESIDENT
    var canWriteChallengerChapterNotice: Bool {
        self == .superAdmin || self == .chapterPresident
    }

    /// 운영진 카테고리 중 하나라도 작성 가능한가
    var canWriteAnyManagementNotice: Bool {
        canWriteCentralAllNotice
            || canWriteSchoolCoreNotice
            || canWriteSchoolPartLeaderNotice
    }

    // MARK: - Display

    /// 한글 표시명
    var korean: String {
        switch self {
        case .superAdmin:                   return "시스템 관리자"
        case .centralPresident:             return "총괄"
        case .centralVicePresident:         return "부총괄"
        case .centralOperatingTeamMember:   return "중앙 운영 운영국"
        case .centralEducationTeamMember:   return "중앙 운영 교육국"
        case .chapterPresident:             return "지부장"
        case .schoolPresident:              return "교내 회장"
        case .schoolVicePresident:          return "교내 부회장"
        case .schoolPartLeader:             return "교내 파트장"
        case .schoolEtcAdmin:              return "교내 운영진"
        case .challenger:                   return "챌린저"
        }
    }

    // MARK: - UI Styling

    /// 배지 아이콘
    var icon: String {
        switch self {
        case .superAdmin:                                           return "👑"
        case .centralPresident, .centralVicePresident:               return "⭐️"
        case .centralOperatingTeamMember, .centralEducationTeamMember: return "⭐️"
        case .chapterPresident:                                     return "🏛️"
        case .schoolPresident, .schoolVicePresident:                 return "🏫"
        case .schoolPartLeader, .schoolEtcAdmin:                    return "🚩"
        case .challenger:                                           return ""
        }
    }

    /// 아이콘 포함 표시명
    var displayName: String {
        icon.isEmpty ? korean : "\(icon) \(korean)"
    }

    var textColor: Color {
        switch self {
        case .superAdmin:
            return .red100
        case .centralPresident, .centralVicePresident,
             .centralOperatingTeamMember, .centralEducationTeamMember:
            return .indigo100
        case .chapterPresident, .schoolPresident, .schoolVicePresident:
            return .orange500
        case .schoolPartLeader, .schoolEtcAdmin:
            return .green500
        case .challenger:
            return .clear
        }
    }

    var backgroundColor: Color {
        switch self {
        case .superAdmin:
            return .red300
        case .centralPresident, .centralVicePresident,
             .centralOperatingTeamMember, .centralEducationTeamMember:
            return .indigo400
        case .chapterPresident, .schoolPresident, .schoolVicePresident:
            return .orange100
        case .schoolPartLeader, .schoolEtcAdmin:
            return .green100
        case .challenger:
            return .clear
        }
    }

    var borderColor: Color {
        switch self {
        case .superAdmin:
            return .red500
        case .centralPresident, .centralVicePresident,
             .centralOperatingTeamMember, .centralEducationTeamMember:
            return .indigo700
        case .chapterPresident, .schoolPresident, .schoolVicePresident:
            return .orange300
        case .schoolPartLeader, .schoolEtcAdmin:
            return .green300
        case .challenger:
            return .clear
        }
    }
}
