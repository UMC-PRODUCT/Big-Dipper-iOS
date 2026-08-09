//
//  CheckForceUpdateUseCase.swift
//  MaintenanceDomain
//
//  Created by euijjang97 on 6/10/26.
//

import Foundation

/// 원격 최소 지원 버전(RemoteConfig)과 App Store 게시 버전을 함께 보고
/// 강제 업데이트 필요 여부를 판정하는 UseCase 구현체.
public final class CheckForceUpdateUseCase: CheckForceUpdateUseCaseProtocol {

    // MARK: - Property

    private let service: RemoteConfigServiceProtocol
    private let appStoreVersionService: AppStoreVersionServiceProtocol?
    private let currentVersion: String

    // MARK: - Init

    public init(
        service: RemoteConfigServiceProtocol,
        appStoreVersionService: AppStoreVersionServiceProtocol? = nil,
        currentVersion: String = Bundle.main.infoDictionary?[
            "CFBundleShortVersionString"
        ] as? String ?? "0.0.0"
    ) {
        self.service = service
        self.appStoreVersionService = appStoreVersionService
        self.currentVersion = currentVersion
    }

    // MARK: - Function

    /// 두 게이트 중 하나라도 걸리면 강제 업데이트가 필요하다고 판정한다.
    ///
    /// - RemoteConfig 게이트: 패치 자리까지 비교하므로 운영자가 콘솔 값으로 차단선을
    ///   직접 올릴 수 있다.
    /// - App Store 게이트: 스토어 최신 버전과 Major.Minor 만 비교해, 콘솔 갱신을 빠뜨린
    ///   릴리즈에서도 마이너 이상 변경이면 자동으로 차단되는 안전망.
    public func execute() async -> Bool {
        async let remoteConfigGate = isBelowMinimumSupportedVersion()
        async let appStoreGate = isBelowAppStoreVersion()
        let (isBelowMinimum, isBelowAppStore) = await (remoteConfigGate, appStoreGate)
        return isBelowMinimum || isBelowAppStore
    }
}

// MARK: - Gate

extension CheckForceUpdateUseCase {
    private func isBelowMinimumSupportedVersion() async -> Bool {
        guard let minimumVersion = await service.fetchMinimumSupportedVersion() else {
            return false
        }
        return isVersion(currentVersion, lowerThan: minimumVersion)
    }

    /// 패치 자리 차단은 RemoteConfig 게이트 책임이라 Major.Minor 까지만 비교한다.
    /// (1.2 → 1.3 은 차단, 1.2.0 → 1.2.1 은 통과)
    private func isBelowAppStoreVersion() async -> Bool {
        guard let appStoreVersionService,
              let appStoreVersion = await appStoreVersionService.fetchLatestVersion() else {
            return false
        }
        return isVersion(
            majorMinor(of: currentVersion),
            lowerThan: majorMinor(of: appStoreVersion)
        )
    }
}

// MARK: - Private Helper

extension CheckForceUpdateUseCase {
    private func isVersion(_ current: String, lowerThan required: String) -> Bool {
        let currentParts = numericParts(of: current)
        let requiredParts = numericParts(of: required)
        let totalCount = max(currentParts.count, requiredParts.count)
        for index in 0..<totalCount {
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            let requiredPart = index < requiredParts.count ? requiredParts[index] : 0
            if currentPart != requiredPart {
                return currentPart < requiredPart
            }
        }
        return false
    }

    private func numericParts(of version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }

    private func majorMinor(of version: String) -> String {
        let components = version.split(separator: ".")
        guard components.count >= 2 else { return version }
        return "\(components[0]).\(components[1])"
    }
}
