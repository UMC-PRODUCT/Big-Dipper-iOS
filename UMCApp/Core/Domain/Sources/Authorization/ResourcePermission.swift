//
//  ResourcePermission.swift
//  CoreDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 권한 조회 대상 리소스 타입
public enum AuthorizationResourceType: String, CaseIterable, Hashable, Sendable {
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
public enum AuthorizationPermissionType: String, CaseIterable, Hashable, Sendable {
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
public struct ResourcePermission: Hashable, Sendable {

    // MARK: - Property

    public let resourceType: AuthorizationResourceType
    public let resourceId: String
    public let grantedPermissions: Set<AuthorizationPermissionType>

    // MARK: - Init

    public init(
        resourceType: AuthorizationResourceType,
        resourceId: String,
        grantedPermissions: Set<AuthorizationPermissionType>
    ) {
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.grantedPermissions = grantedPermissions
    }

    // MARK: - Function

    /// 특정 권한 보유 여부
    public func has(_ permission: AuthorizationPermissionType) -> Bool {
        grantedPermissions.contains(permission)
    }

    /// 전달한 권한 중 하나라도 보유하는지 여부
    public func hasAny(_ permissions: [AuthorizationPermissionType]) -> Bool {
        permissions.contains { grantedPermissions.contains($0) }
    }
}
