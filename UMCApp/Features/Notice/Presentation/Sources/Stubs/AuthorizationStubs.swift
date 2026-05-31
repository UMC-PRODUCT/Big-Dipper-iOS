//
//  AuthorizationStubs.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
  
// TODO: Auth 모듈 이식 후 교체
public enum AuthorizationResourceType { case notice }

public enum PermissionType { case write, edit, delete, manage }
  
public struct ResourcePermission {
    let permissions: Set<PermissionType>
    func hasAny(_ types: [PermissionType]) -> Bool {
        types.contains(where: { permissions.contains($0) })
    }
}
  
public protocol AuthorizationUseCaseProtocol {
    func getResourcePermission(
        resourceType: AuthorizationResourceType,
        resourceId: Int
    ) async throws -> ResourcePermission
}
