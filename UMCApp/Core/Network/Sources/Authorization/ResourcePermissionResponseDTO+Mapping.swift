//
//  ResourcePermissionResponseDTO+Mapping.swift
//  CoreNetwork
//
//  Created by euijjang97 on 8/8/26.
//
//  `ResourcePermissionResponseDTO` → 도메인 모델 매핑.
//  `AuthorizationRepository` 안에 인라인돼 있던 변환을 `MemberProfileResponseDTO+Mapping` 과
//  같은 위치로 옮겨, 네트워크 스텁 없이 매핑 규칙만 단위 테스트할 수 있게 한다.
//

import CoreDomain
import Foundation
import UMCFoundation

// MARK: - toDomain

extension ResourcePermissionResponseDTO {

    /// DTO → `ResourcePermission` 도메인 모델 변환.
    ///
    /// - 허용되지 않은 권한(`hasPermission == false`)은 결과에서 제외한다.
    /// - 앱이 모르는 `permissionType` 은 조용히 버린다. 서버가 권한 종류를 추가해도
    ///   기존 클라이언트가 권한 조회 전체를 실패시키지 않게 하기 위함이다.
    /// - 반면 `resourceType` 은 무엇에 대한 권한인지를 규정하므로 모르는 값이면 실패시킨다.
    ///
    /// - Throws: 앱이 모르는 `resourceType` 일 때 `RepositoryError.decodingError`
    public func toDomain() throws -> ResourcePermission {
        guard let mappedResourceType = AuthorizationResourceType(rawValue: resourceType) else {
            throw RepositoryError.decodingError(detail: "Unknown resourceType: \(resourceType)")
        }

        let granted = Set(
            permissions.compactMap { item -> AuthorizationPermissionType? in
                guard item.hasPermission else { return nil }
                return AuthorizationPermissionType(rawValue: item.permissionType)
            }
        )

        return ResourcePermission(
            resourceType: mappedResourceType,
            resourceId: resourceId,
            grantedPermissions: granted
        )
    }
}
