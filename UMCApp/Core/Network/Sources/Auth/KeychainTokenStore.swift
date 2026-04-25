//
//  KeychainTokenStore.swift
//  CoreNetwork
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import Security

/// Keychain을 사용한 토큰 저장소
///
/// Actor로 구현하여 thread-safety를 보장합니다.
/// 액세스 토큰과 리프레시 토큰을 iOS Keychain에 안전하게 저장하며,
/// 메모리 캐시를 사용해 반복적인 Keychain 접근을 줄입니다.
///
/// - Important:
///   - **Thread-safety**: Actor 격리로 동시 접근 안전
///   - **Accessibility**: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 사용
///     (디바이스 잠금 해제 후 접근 가능, 백업·동기화 안 됨)
///   - **메모리 캐시**: 첫 조회 시 Keychain에서 로드 후 캐싱
public actor KeychainTokenStore: TokenStore {

    // MARK: - Property

    private let service: String
    private let accessTokenKey: String
    private let refreshTokenKey: String

    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?
    private var isCacheLoaded: Bool = false

    // MARK: - Init

    public init(
        service: String = "com.ump.product",
        accessTokenKey: String = "accessToken",
        refreshTokenKey: String = "refreshToken"
    ) {
        self.service = service
        self.accessTokenKey = accessTokenKey
        self.refreshTokenKey = refreshTokenKey
    }

    // MARK: - TokenStore

    public func getAccessToken() async -> String? {
        await loadCached()
        return cachedAccessToken
    }

    public func getRefreshToken() async -> String? {
        await loadCached()
        return cachedRefreshToken
    }

    public func save(accessToken: String, refreshToken: String) async throws {
        try saveToKeychain(key: accessTokenKey, value: accessToken)
        try saveToKeychain(key: refreshTokenKey, value: refreshToken)

        cachedAccessToken = accessToken
        cachedRefreshToken = refreshToken

        #if DEBUG
        print("토큰 저장 완료")
        print("[Auth] saved accessToken: \(accessToken)")
        print("[Auth] saved refreshToken: \(refreshToken)")
        #endif
    }

    public func clear() async throws {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)

        cachedAccessToken = nil
        cachedRefreshToken = nil

        #if DEBUG
        print("토큰 삭제 완료")
        #endif
    }

    // MARK: - Private Methods

    private func loadCached() async {
        guard !isCacheLoaded else { return }

        cachedAccessToken = loadFromKeychain(key: accessTokenKey)
        cachedRefreshToken = loadFromKeychain(key: refreshTokenKey)
        isCacheLoaded = true
    }

    private func saveToKeychain(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        deleteFromKeychain(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - KeychainError

public enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "토큰 인코딩 실패"
        case .saveFailed(let status):
            return "Keychain 저장 실패 (status: \(status))"
        case .loadFailed(let status):
            return "Keychain 로드 실패 (status: \(status))"
        }
    }
}
