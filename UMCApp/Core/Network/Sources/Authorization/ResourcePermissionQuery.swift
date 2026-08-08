//
//  ResourcePermissionQuery.swift
//  CoreNetwork
//
//  Created by euijjang97 on 8/8/26.
//

/// 리소스 권한 조회 Query DTO
///
/// `GET /api/v1/authorization/resource-permission?resourceType=...&resourceId=...`
public struct ResourcePermissionQuery: Encodable {

    // MARK: - Property

    /// 권한 조회 대상 리소스 타입 (서버 계약 rawValue)
    public let resourceType: String

    /// 권한 조회 대상 리소스 식별자
    public let resourceId: String

    // MARK: - Init

    public init(resourceType: String, resourceId: String) {
        self.resourceType = resourceType
        self.resourceId = resourceId
    }

    // MARK: - Function

    /// Query Parameter Dictionary 변환
    var toParameters: [String: Any] {
        [
            "resourceType": resourceType,
            "resourceId": resourceId
        ]
    }
}
