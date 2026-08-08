//
//  AuthorizationRepository.swift
//  CoreNetwork
//
//  Created by euijjang97 on 8/8/26.
//

import CoreDomain
import Foundation
import UMCFoundation

/// 공용 리소스 권한 Repository 구현체
public final class AuthorizationRepository: AuthorizationRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder

    // MARK: - Init

    public init(adapter: MoyaNetworkAdapter, decoder: JSONDecoder = JSONDecoder()) {
        self.adapter = adapter
        self.decoder = decoder
    }

    // MARK: - Function

    public func getResourcePermission(
        resourceType: AuthorizationResourceType,
        resourceId: String
    ) async throws -> ResourcePermission {
        let response = try await adapter.request(
            AuthorizationRouter.getResourcePermission(
                query: ResourcePermissionQuery(
                    resourceType: resourceType.rawValue,
                    resourceId: resourceId
                )
            )
        )

        let apiResponse = try decoder.decode(
            APIResponse<ResourcePermissionResponseDTO>.self,
            from: response.data
        )
        let dto = try apiResponse.unwrap()

        guard let mappedResourceType = AuthorizationResourceType(rawValue: dto.resourceType) else {
            throw RepositoryError.decodingError(
                detail: "Unknown resourceType: \(dto.resourceType)"
            )
        }

        let granted = Set(
            dto.permissions.compactMap { item -> AuthorizationPermissionType? in
                guard item.hasPermission else { return nil }
                return AuthorizationPermissionType(rawValue: item.permissionType)
            }
        )

        return ResourcePermission(
            resourceType: mappedResourceType,
            resourceId: dto.resourceId,
            grantedPermissions: granted
        )
    }
}
