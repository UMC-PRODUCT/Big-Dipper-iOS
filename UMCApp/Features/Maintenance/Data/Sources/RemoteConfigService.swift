import FirebaseCore
import FirebaseRemoteConfig
import Foundation
import MaintenanceDomain
import os

/// Firebase Remote Config 기반 킬스위치·강제 업데이트 정보 조회 서비스.
///
/// `RemoteConfig.remoteConfig()`는 `FirebaseApp.configure()` 이후에만 안전하게 호출할 수
/// 있다. `remoteConfig`를 lazy로 유지해, 이 서비스가 `FirebaseApp.configure()`보다 먼저
/// DI 컨테이너에 등록·생성되어도 실제 Firebase 접근은 최초 사용 시점까지 지연된다.
///
/// `GoogleService-Info.plist`가 없어 `FirebaseApp`이 구성되지 못한 환경(CI 등)에서는
/// `remoteConfig`가 `nil`로 유지되어, Firebase SDK의 fatalError 없이 항상 fail-open
/// (점검 비활성·업데이트 불필요)으로 동작한다.
public final class RemoteConfigService: RemoteConfigServiceProtocol {

    // MARK: - Constant

    private enum Key {
        static let enabled = "maintenance_enabled"
        static let title = "maintenance_title"
        static let message = "maintenance_message"
        static let minimumVersion = "ios_min_version"
    }

    private enum DefaultValue {
        static let title = "서비스 점검 안내"
        static let message = "보다 나은 서비스 제공을 위해 점검 중입니다.\n잠시 후 다시 이용해 주세요."
    }

    private enum Constants {
        /// `check()` 1회당 두 UseCase가 순차 호출해도 `fetchAndActivate()`가 한 번만
        /// 실행되도록 묶어주는 창. Firebase의 `minimumFetchInterval`(release 600초)보다
        /// 훨씬 짧게 잡아, 정당한 재확인(포그라운드 복귀 등)은 그대로 새로 페치한다.
        static let refreshCoalesceWindow: TimeInterval = 5
    }

    // MARK: - Property

    private let fetchTimeout: TimeInterval
    private let refreshCoalescer = RefreshCoalescer(
        coalesceWindow: Constants.refreshCoalesceWindow
    )

    private lazy var remoteConfig: RemoteConfig? = {
        guard FirebaseApp.app() != nil else { return nil }
        return Self.makeRemoteConfig(fetchTimeout: fetchTimeout)
    }()

    // MARK: - Init

    public init(fetchTimeout: TimeInterval = 4) {
        self.fetchTimeout = fetchTimeout
    }

    // MARK: - Function

    public func fetchMaintenanceStatus() async -> MaintenanceInfo? {
        #if DEBUG
        if MaintenanceDebugOverride.isMaintenanceForced {
            return MaintenanceInfo(
                isActive: true,
                title: DefaultValue.title,
                message: DefaultValue.message
            )
        }
        #endif

        guard let remoteConfig else { return nil }
        await refreshIfPossible(remoteConfig)
        return currentMaintenanceInfo(remoteConfig)
    }

    public func fetchMinimumSupportedVersion() async -> String? {
        #if DEBUG
        if MaintenanceDebugOverride.isForceUpdateForced {
            return MaintenanceDebugOverride.forcedMinimumVersion
        }
        #endif

        guard let remoteConfig else { return nil }
        await refreshIfPossible(remoteConfig)
        let minimumVersion = remoteConfig[Key.minimumVersion].stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return minimumVersion.isEmpty ? nil : minimumVersion
    }
}

// MARK: - Private Helper

extension RemoteConfigService {
    private static func makeRemoteConfig(fetchTimeout: TimeInterval) -> RemoteConfig {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 600
        #endif
        settings.fetchTimeout = fetchTimeout
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults([
            Key.enabled: false as NSObject,
            Key.title: DefaultValue.title as NSObject,
            Key.message: DefaultValue.message as NSObject,
            Key.minimumVersion: "" as NSObject,
        ])
        return remoteConfig
    }

    /// `RefreshCoalescer`로 묶어 중복 실행을 막고, 실제 페치는 여기서 수행한다.
    ///
    /// 페치 실패는 로그만 남기고 삼킨다 — 원격 설정 접근이 불가하면 마지막으로
    /// 활성화된(또는 기본) 값으로 동작을 이어가는 fail-open 정책이다.
    private func refreshIfPossible(_ remoteConfig: RemoteConfig) async {
        await refreshCoalescer.run {
            do {
                _ = try await remoteConfig.fetchAndActivate()
            } catch {
                Self.logger.error(
                    "RemoteConfig fetchAndActivate 실패, 마지막 활성값으로 계속 진행: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func currentMaintenanceInfo(_ remoteConfig: RemoteConfig) -> MaintenanceInfo? {
        guard remoteConfig[Key.enabled].boolValue else { return nil }

        let title = remoteConfig[Key.title].stringValue
        let message = remoteConfig[Key.message].stringValue
        return MaintenanceInfo(
            isActive: true,
            title: title.isEmpty ? DefaultValue.title : title,
            message: message.isEmpty ? DefaultValue.message : message
        )
    }
}

// MARK: - Logging

extension RemoteConfigService {
    private static let logger = Logger(
        subsystem: "dev.umc.feature.maintenance.data",
        category: "RemoteConfigService"
    )
}
