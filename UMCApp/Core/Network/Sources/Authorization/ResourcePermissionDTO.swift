//
//  ResourcePermissionDTO.swift
//  CoreNetwork
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation
import UMCFoundation

// MARK: - Main Response

/// 리소스 권한 조회 응답 DTO
public struct ResourcePermissionResponseDTO: Codable {

    // MARK: - Property

    public let resourceType: String
    public let resourceId: String
    public let permissions: [ResourcePermissionItemDTO]

    private enum CodingKeys: String, CodingKey {
        case resourceType
        case resourceId
        case permissions
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resourceType = try container.decode(String.self, forKey: .resourceType)
        resourceId = try container.decodeFlexibleString(forKey: .resourceId)
        permissions = try container.decodeIfPresent(
            [ResourcePermissionItemDTO].self,
            forKey: .permissions
        ) ?? []
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(resourceType, forKey: .resourceType)
        try container.encode(resourceId, forKey: .resourceId)
        try container.encode(permissions, forKey: .permissions)
    }
}

// MARK: - ResourcePermissionItemDTO

/// 단일 권한 항목 DTO
public struct ResourcePermissionItemDTO: Codable {

    // MARK: - Property

    public let permissionType: String
    public let hasPermission: Bool

    private enum CodingKeys: String, CodingKey {
        case permissionType
        case hasPermission
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        permissionType = try container.decode(String.self, forKey: .permissionType)
        hasPermission = try container.decodeBoolFlexibleIfPresent(forKey: .hasPermission) ?? false
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(permissionType, forKey: .permissionType)
        try container.encode(hasPermission, forKey: .hasPermission)
    }
}
