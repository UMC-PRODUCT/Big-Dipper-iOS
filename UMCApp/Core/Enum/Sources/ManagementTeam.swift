//
//  ManagementTeam.swift
//  CoreEnum
//
//  Created by jaewon Lee on 5/10/26.
//

import Foundation

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
///
/// UI 프로퍼티(textColor/backgroundColor/borderColor/icon/displayName)는
/// 사용처 Presentation 모듈의 extension으로 제공합니다.
public enum ManagementTeam: String, CaseIterable, Codable, Comparable {

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
    /// 복수 역할 보유 시 아래 순서를 우선 적용합니다.
    /// superAdmin은 시스템 역할이므로 별도로 최상위에 둡니다.
    public var level: Int {
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
    public var canAccessAdminMode: Bool {
        level >= Self.schoolEtcAdmin.level
    }

    /// 스터디 그룹 생성 가능 여부 (교내 회장/부회장만 가능)
    public var canCreateStudyGroup: Bool {
        self == .schoolPresident || self == .schoolVicePresident
    }

    // MARK: - Comparable

    public static func < (lhs: ManagementTeam, rhs: ManagementTeam) -> Bool {
        lhs.level < rhs.level
    }

    public static func highestPriority<S: Sequence>(in roles: S) -> ManagementTeam? where S.Element == ManagementTeam {
        roles.max()
    }

    // MARK: - Display

    /// 한글 표시명
    public var korean: String {
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
        case .schoolEtcAdmin:               return "교내 운영진"
        case .challenger:                   return "챌린저"
        }
    }
}
