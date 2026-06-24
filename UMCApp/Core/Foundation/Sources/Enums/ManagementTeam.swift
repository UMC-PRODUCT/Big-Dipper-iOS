//
//  ManagementTeam.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 6/17/26.
//

import Foundation

/// 멤버 역할/권한 구분
///
/// 서버 API `roleType` 값과 1:1 매핑됩니다.
/// 역할 배지의 시각 매핑(Color)은 Presentation 레이어의 extension 에서 제공합니다.
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
public enum ManagementTeam: String, CaseIterable, Codable, Sendable, Comparable {

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
    /// 복수 역할 보유 시 레벨이 높은 역할을 우선 적용합니다.
    /// superAdmin 은 시스템 역할이므로 별도로 최상위에 둡니다.
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

    // MARK: - Comparable

    public static func < (lhs: ManagementTeam, rhs: ManagementTeam) -> Bool {
        lhs.level < rhs.level
    }

    /// 역할 목록에서 가장 상위 권한을 반환합니다.
    public static func highestPriority<S: Sequence>(
        in roles: S
    ) -> ManagementTeam? where S.Element == ManagementTeam {
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

    /// 배지 아이콘 (이모지)
    public var icon: String {
        switch self {
        case .superAdmin:                                              return "👑"
        case .centralPresident, .centralVicePresident:                return "⭐️"
        case .centralOperatingTeamMember, .centralEducationTeamMember: return "⭐️"
        case .chapterPresident:                                       return "🏛️"
        case .schoolPresident, .schoolVicePresident:                  return "🏫"
        case .schoolPartLeader, .schoolEtcAdmin:                      return "🚩"
        case .challenger:                                             return ""
        }
    }

    /// 아이콘 포함 표시명 (아이콘이 없으면 한글 표시명만 반환)
    public var displayName: String {
        icon.isEmpty ? korean : "\(icon) \(korean)"
    }
}
