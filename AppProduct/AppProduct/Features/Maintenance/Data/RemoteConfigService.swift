//
//  RemoteConfigService.swift
//  AppProduct
//
//  Firebase RemoteConfig 를 래핑하여 원격 점검 상태를 제공하는 서비스.
//

import Foundation
import FirebaseRemoteConfig

/// 원격 점검 상태를 가져오는 서비스.
protocol RemoteConfigServiceProtocol {

    /// 원격 구성을 갱신한 뒤 현재 점검 상태를 반환합니다.
    ///
    /// 갱신 실패·네트워크 없음·타임아웃이어도 예외를 던지지 않고,
    /// 마지막으로 활성화된 값(없으면 인앱 기본값 `enabled=false`)을 기준으로 판단합니다.
    /// 따라서 점검 중이 아니면 `nil` 을 반환해 진입을 허용합니다(fail-open).
    func fetchMaintenanceStatus() async -> MaintenanceInfo?

    /// 원격 구성을 갱신한 뒤 최소 지원 버전(`ios_min_version`)을 반환합니다.
    ///
    /// 콘솔 값이 비어 있거나 읽지 못하면 `nil` 을 반환해 강제 업데이트를
    /// 발동하지 않습니다(fail-open).
    func fetchMinimumSupportedVersion() async -> String?
}

/// Firebase RemoteConfig 기반 구현.
///
/// - Important: `RemoteConfig.remoteConfig()` 는 `FirebaseApp.configure()` 이후에만
///   유효하므로, 실제 인스턴스 생성을 `remoteConfig` lazy 프로퍼티로 지연시켜
///   최초 fetch 시점(앱 부팅 이후)에 생성합니다.
final class DefaultRemoteConfigService: RemoteConfigServiceProtocol {

    // MARK: - Key

    /// Firebase 콘솔의 RemoteConfig 파라미터 키와 글자까지 일치해야 합니다.
    private enum Key {
        static let enabled = "maintenance_enabled"
        static let title = "maintenance_title"
        static let message = "maintenance_message"
        static let minimumVersion = "ios_min_version"
    }

    // MARK: - Default Value

    /// 콘솔 값을 읽지 못했을 때 사용하는 인앱 기본값.
    private enum DefaultValue {
        static let title = "서비스 점검 안내"
        static let message = "보다 나은 서비스 제공을 위해 점검 중입니다.\n잠시 후 다시 이용해 주세요."
    }

    // MARK: - Property

    /// fetch 네트워크 최대 대기 시간(초). 초과 시 진입을 차단하지 않습니다.
    private let fetchTimeout: TimeInterval

    /// 최초 접근 시 Firebase 구성 이후에 생성됩니다.
    private lazy var remoteConfig: RemoteConfig = makeRemoteConfig()

    // MARK: - Init

    init(fetchTimeout: TimeInterval = 4) {
        self.fetchTimeout = fetchTimeout
    }

    // MARK: - RemoteConfigServiceProtocol

    func fetchMaintenanceStatus() async -> MaintenanceInfo? {
        await refreshIfPossible()
        return currentMaintenanceInfo()
    }

    func fetchMinimumSupportedVersion() async -> String? {
        await refreshIfPossible()
        let version = remoteConfig[Key.minimumVersion].stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    // MARK: - Private Function

    private func makeRemoteConfig() -> RemoteConfig {
        let config = RemoteConfig.remoteConfig()

        let settings = RemoteConfigSettings()
        #if DEBUG
        // 디버그에서는 캐시 없이 즉시 최신 값을 받아 점검 토글을 빠르게 검증한다.
        settings.minimumFetchInterval = 0
        #else
        // 킬스위치 반응성과 Firebase 쓰로틀링의 균형 (10분).
        settings.minimumFetchInterval = 600
        #endif
        settings.fetchTimeout = fetchTimeout
        config.configSettings = settings

        config.setDefaults([
            Key.enabled: NSNumber(value: false),
            Key.title: DefaultValue.title as NSString,
            Key.message: DefaultValue.message as NSString,
            Key.minimumVersion: "" as NSString
        ])
        return config
    }

    /// 원격 값을 best-effort 로 갱신합니다. 실패는 무시합니다(fail-open).
    ///
    /// 네트워크 대기 시간은 `configSettings.fetchTimeout` 으로 제한됩니다.
    private func refreshIfPossible() async {
        _ = try? await remoteConfig.fetchAndActivate()
    }

    /// 현재 활성화된 원격 값으로 점검 상태를 해석합니다.
    ///
    /// 점검 플래그가 꺼져 있으면 `nil` 을 반환합니다.
    private func currentMaintenanceInfo() -> MaintenanceInfo? {
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

#if DEBUG

/// 프리뷰/로컬 디버깅용 Mock 서비스.
///
/// 네트워크 없이 점검 화면을 독립적으로 띄워볼 때 사용합니다.
final class MockRemoteConfigService: RemoteConfigServiceProtocol {

    var stubbedInfo: MaintenanceInfo?
    var stubbedMinimumVersion: String?

    init(
        stubbedInfo: MaintenanceInfo? = nil,
        stubbedMinimumVersion: String? = nil
    ) {
        self.stubbedInfo = stubbedInfo
        self.stubbedMinimumVersion = stubbedMinimumVersion
    }

    func fetchMaintenanceStatus() async -> MaintenanceInfo? {
        stubbedInfo
    }

    func fetchMinimumSupportedVersion() async -> String? {
        stubbedMinimumVersion
    }
}

#endif
