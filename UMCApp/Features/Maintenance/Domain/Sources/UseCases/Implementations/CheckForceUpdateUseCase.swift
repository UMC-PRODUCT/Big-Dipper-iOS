import Foundation

/// 원격 최소 지원 버전(RemoteConfig) 대비 강제 업데이트 필요 여부를 판정하는 UseCase 구현체.
public final class CheckForceUpdateUseCase: CheckForceUpdateUseCaseProtocol {

    // MARK: - Property

    private let service: RemoteConfigServiceProtocol
    private let currentVersion: String

    // MARK: - Init

    public init(
        service: RemoteConfigServiceProtocol,
        currentVersion: String = Bundle.main.infoDictionary?[
            "CFBundleShortVersionString"
        ] as? String ?? "0.0.0"
    ) {
        self.service = service
        self.currentVersion = currentVersion
    }

    // MARK: - Function

    public func execute() async -> Bool {
        guard let minimumVersion = await service.fetchMinimumSupportedVersion() else {
            return false
        }
        return isVersion(currentVersion, lowerThan: minimumVersion)
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
}
