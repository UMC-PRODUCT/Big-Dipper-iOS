//
//  ActivitySection.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDomain
import Foundation

/// Activity 탭 루트가 노출하는 섹션
///
/// 챌린저/운영진 두 모드가 각각 3개 섹션을 갖고, 같은 자리(출석·스터디·구성원)의 섹션이
/// 서로 대응한다. 모드가 바뀌면 ``mapped(to:)`` 로 보고 있던 자리를 유지한다.
///
/// - Note: 표시 문자열은 ``title`` 로 노출한다. 레거시는 한글 문자열을 `rawValue` 로 썼지만,
///   `rawValue` 는 식별자(저장·비교)의 자리이지 화면 문구의 자리가 아니라 분리했다.
enum ActivitySection: String, Identifiable, Hashable, CaseIterable {

    // MARK: - Challenger

    case attendanceCheck
    case studyActivity
    case members

    // MARK: - Admin

    case attendanceManage
    case studyManage
    case memberManage

    // MARK: - Property

    var id: Self { self }

    /// 네비게이션 타이틀·섹션 메뉴에 표시할 문구
    var title: String {
        switch self {
        case .attendanceCheck: "출석 체크"
        case .studyActivity: "스터디/활동"
        case .members: "구성원"
        case .attendanceManage: "출석 관리"
        case .studyManage: "스터디 관리"
        case .memberManage: "멤버 관리"
        }
    }

    /// 섹션 메뉴 항목의 SF Symbol 이름
    var icon: String {
        switch self {
        case .attendanceCheck, .attendanceManage: "checkmark.circle"
        case .studyActivity, .studyManage: "book.pages"
        case .members, .memberManage: "person.3"
        }
    }

    // MARK: - Function

    /// 모드별 사용 가능한 섹션 목록 (메뉴 노출 순서)
    static func sections(for mode: ActivityMode) -> [ActivitySection] {
        switch mode {
        case .challenger: [.attendanceCheck, .studyActivity, .members]
        case .admin: [.attendanceManage, .studyManage, .memberManage]
        }
    }

    /// 모드별 기본 선택 섹션 (탭 진입 시 첫 화면)
    static func defaultSection(for mode: ActivityMode) -> ActivitySection {
        switch mode {
        case .challenger: .attendanceCheck
        case .admin: .attendanceManage
        }
    }

    /// 다른 모드에서 의미상 대응되는 섹션
    ///
    /// 모드 토글 직후에도 같은 성격의 화면(출석↔출석 관리 등)에 머물게 한다.
    /// 이미 그 모드에 속한 섹션이면 자기 자신을 돌려준다.
    func mapped(to mode: ActivityMode) -> ActivitySection {
        switch mode {
        case .challenger:
            switch self {
            case .attendanceCheck, .attendanceManage: .attendanceCheck
            case .studyActivity, .studyManage: .studyActivity
            case .members, .memberManage: .members
            }
        case .admin:
            switch self {
            case .attendanceCheck, .attendanceManage: .attendanceManage
            case .studyActivity, .studyManage: .studyManage
            case .members, .memberManage: .memberManage
            }
        }
    }
}
