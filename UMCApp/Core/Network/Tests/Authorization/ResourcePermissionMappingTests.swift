//
//  ResourcePermissionMappingTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 8/8/26.
//

import CoreDomain
import Foundation
import Testing
import UMCFoundation
@testable import CoreNetwork

@Suite("ResourcePermission — 권한 응답 디코딩/도메인 매핑")
struct ResourcePermissionMappingTests {

    // MARK: - Fixtures

    private static func decodeDTO(
        resourceType: String = "NOTICE",
        resourceId: Any = 42,
        permissions: [[String: Any]]? = []
    ) throws -> ResourcePermissionResponseDTO {
        var json: [String: Any] = [
            "resourceType": resourceType,
            "resourceId": resourceId,
        ]
        if let permissions {
            json["permissions"] = permissions
        }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(ResourcePermissionResponseDTO.self, from: data)
    }

    // MARK: - Mapping

    @Test("허용된 권한만 매핑하고 숫자 resourceId는 String으로 흡수한다")
    func mapsGrantedPermissionsAndFlexibleResourceId() throws {
        let dto = try Self.decodeDTO(permissions: [
            ["permissionType": "EDIT", "hasPermission": true],
            ["permissionType": "DELETE", "hasPermission": false],
            ["permissionType": "MANAGE", "hasPermission": true],
        ])

        let permission = try dto.toDomain()

        #expect(permission.resourceType == .notice)
        #expect(permission.resourceId == "42")
        #expect(permission.grantedPermissions == [.edit, .manage])
        #expect(permission.has(.delete) == false)
    }

    @Test("알 수 없는 permissionType은 조용히 무시한다")
    func ignoresUnknownPermissionType() throws {
        let dto = try Self.decodeDTO(resourceId: "7", permissions: [
            ["permissionType": "TELEPORT", "hasPermission": true],
            ["permissionType": "READ", "hasPermission": true],
        ])

        let permission = try dto.toDomain()

        #expect(permission.grantedPermissions == [.read])
    }

    @Test("알 수 없는 resourceType은 디코딩 에러로 실패한다")
    func throwsOnUnknownResourceType() throws {
        let dto = try Self.decodeDTO(resourceType: "GALAXY", permissions: [])

        #expect(throws: RepositoryError.self) {
            try dto.toDomain()
        }
    }

    // MARK: - Decoding Leniency

    @Test("permissions 키가 없으면 권한 없음으로 디코딩한다")
    func treatsMissingPermissionsAsEmpty() throws {
        let dto = try Self.decodeDTO(resourceType: "SCHEDULE", permissions: nil)

        let permission = try dto.toDomain()

        #expect(permission.resourceType == .schedule)
        #expect(permission.grantedPermissions.isEmpty)
    }

    @Test("hasPermission이 문자열·숫자로 와도 Bool로 흡수하고 누락은 false로 본다")
    func absorbsFlexibleHasPermission() throws {
        let dto = try Self.decodeDTO(resourceType: "SCHEDULE", permissions: [
            ["permissionType": "READ", "hasPermission": "true"],
            ["permissionType": "EDIT", "hasPermission": 1],
            ["permissionType": "DELETE", "hasPermission": 0],
            ["permissionType": "FORCE_DELETE"],
        ])

        let permission = try dto.toDomain()

        #expect(permission.grantedPermissions == [.read, .edit])
    }

    // MARK: - hasAny

    @Test("hasAny는 전달한 권한 중 하나라도 보유하면 true다")
    func hasAnyMatchesSinglePermission() {
        let permission = ResourcePermission(
            resourceType: .notice,
            resourceId: "42",
            grantedPermissions: [.manage]
        )

        #expect(permission.hasAny([.write, .edit, .manage]))
        #expect(permission.hasAny([.approve, .check]) == false)
    }
}
