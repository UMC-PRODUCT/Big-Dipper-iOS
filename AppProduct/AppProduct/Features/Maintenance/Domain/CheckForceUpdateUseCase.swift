//
//  CheckForceUpdateUseCase.swift
//  AppProduct
//
//  RemoteConfig 최소 지원 버전 기반의 강제 업데이트 판정 UseCase.
//

import Foundation

/// 강제 업데이트 필요 여부 판정 UseCase.
///
/// RemoteConfig 의 `ios_min_version` 보다 현재 앱 버전이 낮으면 `true` 를 반환합니다.
/// 패치 자리까지 포함한 전체 버전을 비교하므로, 패치 릴리스(예: 1.7.0 → 1.7.1)도
/// 콘솔 값만 올리면 구버전 진입을 차단할 수 있습니다.
protocol CheckForceUpdateUseCaseProtocol {

    /// 강제 업데이트가 필요한지 판정합니다.
    ///
    /// - Returns: 현재 버전이 최소 지원 버전보다 낮으면 `true`.
    ///   콘솔 값이 비어 있거나 읽지 못하면 `false` (fail-open).
    func execute() async -> Bool
}

/// `RemoteConfigService` 의 최소 지원 버전과 번들 버전을 비교하는 기본 구현.
final class CheckForceUpdateUseCase: CheckForceUpdateUseCaseProtocol {

    // MARK: - Property

    private let service: RemoteConfigServiceProtocol
    private let currentVersion: String

    // MARK: - Init

    init(
        service: RemoteConfigServiceProtocol,
        currentVersion: String = Bundle.main.infoDictionary?[
            "CFBundleShortVersionString"
        ] as? String ?? "0.0.0"
    ) {
        self.service = service
        self.currentVersion = currentVersion
    }

    // MARK: - Function

    func execute() async -> Bool {
        guard let minimumVersion = await service.fetchMinimumSupportedVersion() else {
            return false
        }
        return isVersion(currentVersion, lowerThan: minimumVersion)
    }

    // MARK: - Private Function

    /// 점(.) 구분 버전 문자열을 자리별 숫자로 비교합니다.
    ///
    /// 자리 수가 다르면 빈 자리를 0 으로 채워 비교합니다 ("1.7" == "1.7.0").
    /// 숫자가 아닌 자리는 0 으로 간주해 잘못된 콘솔 값으로 인한 오차단을 막습니다.
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
}
