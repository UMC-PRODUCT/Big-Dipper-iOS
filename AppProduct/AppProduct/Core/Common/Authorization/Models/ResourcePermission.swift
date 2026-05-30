//
//  ResourcePermission.swift
//  AppProduct
//
//  Created by euijjang97 on 2/17/26.
//

import Foundation

/// 권한 조회 대상 리소스 타입
enum AuthorizationResourceType: String, CaseIterable, Hashable {
    case curriculum = "CURRICULUM"
    case schedule = "SCHEDULE"
    case notice = "NOTICE"
    case chapter = "CHAPTER"
    case workbookSubmission = "WORKBOOK_SUBMISSION"
    case attendanceSheet = "ATTENDANCE_SHEET"
    case attendanceRecord = "ATTENDANCE_RECORD"
    case communityPost = "COMMUNITY_POST"
    case comment = "COMMUNITY_COMMENT"
}

/// 리소스 권한 타입
enum AuthorizationPermissionType: String, CaseIterable, Hashable {
    case read = "READ"
    case edit = "EDIT"
    case write = "WRITE"
    case delete = "DELETE"
    /// 출석 기록이 있는 일정에 대한 강제 삭제 권한 (일정 기수의 SUPER_ADMIN만 부여).
    case forceDelete = "FORCE_DELETE"
    case approve = "APPROVE"
    case check = "CHECK"
    case manage = "MANAGE"
}

/// 리소스 권한 조회 결과
struct ResourcePermission: Hashable {
    let resourceType: AuthorizationResourceType
    let resourceId: Int
    let grantedPermissions: Set<AuthorizationPermissionType>

    /// 특정 권한 보유 여부
    func has(_ permission: AuthorizationPermissionType) -> Bool {
        grantedPermissions.contains(permission)
    }

    /// 전달한 권한 중 하나라도 보유하는지 여부
    func hasAny(_ permissions: [AuthorizationPermissionType]) -> Bool {
        permissions.contains { grantedPermissions.contains($0) }
    }
}
