//
//  GuestMocks.swift
//  AppProduct
//

import Foundation

// MARK: - GuestTokenStore

/// 게스트 세션용 TokenStore
///
/// Keychain에 접근하지 않으며, 토큰은 항상 nil을 반환합니다.
actor GuestTokenStore: TokenStore {

    func getAccessToken() async -> String? { nil }

    func getRefreshToken() async -> String? { nil }

    func save(accessToken: String, refreshToken: String) async throws {}

    func clear() async throws {}
}

// MARK: - MockStorageRepository

/// 게스트 세션용 Storage Repository Mock
///
/// 파일 업로드 기능을 사용하지 않는 게스트 세션에서 의존성을 충족합니다.
final class MockStorageRepository: StorageRepositoryProtocol {

    func prepareUpload(
        fileName: String,
        contentType: String,
        fileSize: Int,
        category: StorageFileCategory
    ) async throws -> StoragePrepareUploadResponseDTO {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func uploadFile(
        to url: String,
        data: Data,
        method: String,
        headers: [String: String]?,
        contentType: String?
    ) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func confirmUpload(fileId: String) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func deleteFile(fileId: String) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }
}

// MARK: - MockAuthorizationRepository

/// 게스트 세션용 Authorization Repository Mock
///
/// 모든 리소스에 대해 빈 권한 집합을 반환합니다.
final class MockAuthorizationRepository: AuthorizationRepositoryProtocol {

    func getResourcePermission(
        resourceType: AuthorizationResourceType,
        resourceId: Int
    ) async throws -> ResourcePermission {
        ResourcePermission(
            resourceType: resourceType,
            resourceId: resourceId,
            grantedPermissions: []
        )
    }
}
