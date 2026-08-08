//
//  AuthorizationRepositoryProtocol.swift
//  CoreDomain
//
//  Created by euijjang97 on 8/8/26.
//

/// 공용 리소스 권한 Repository 인터페이스
public protocol AuthorizationRepositoryProtocol: Sendable {

    /// 특정 리소스에 대한 현재 사용자 권한을 조회합니다.
    func getResourcePermission(
        resourceType: AuthorizationResourceType,
        resourceId: String
    ) async throws -> ResourcePermission
}
