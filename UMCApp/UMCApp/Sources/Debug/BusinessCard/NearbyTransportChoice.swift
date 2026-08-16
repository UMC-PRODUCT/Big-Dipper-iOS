//
//  NearbyTransportChoice.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import Foundation

/// 근거리 교환에 어떤 transport 를 쓸지 고르는 검증용 토글.
///
/// MPC 로 옮기는 중이지만 Wi-Fi Aware 를 바로 지우지 않는다 — Wi-Fi Aware 왕복 교환은
/// 실기기에서 이미 검증됐고(2026-08-16), MPC 가 그만큼 도는 걸 확인하기 전에 지우면
/// 비교 대상이 사라진다. 둘을 나란히 돌려보고 나서 정리한다.
///
/// `UMCAppApp` 이 시작 시 한 번만 읽으므로 전환 후에는 앱을 다시 켜야 한다.
enum NearbyTransportChoice: String, CaseIterable, Identifiable {

    /// 페어링 없이 주변을 탐색한다. 시안이 그리는 흐름.
    case multipeer
    /// 사전 페어링된 기기끼리만. 고속이지만 처음 만난 사람과는 쓸 수 없다.
    case wifiAware
    /// 시뮬레이터용. 실제 무선 없이 흐름만 돌린다.
    case mock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .multipeer: return "MPC (권장)"
        case .wifiAware: return "Wi-Fi Aware"
        case .mock:      return "Mock"
        }
    }

    var caveat: String {
        switch self {
        case .multipeer:
            return "페어링 불필요. 발견 즉시 이름·파트·기수가 온다. Local Network 권한 필요."
        case .wifiAware:
            return "사전 페어링 필수 — 「기기 페어링」을 먼저 해야 한다. Wi-Fi 가 켜져 있어야 한다."
        case .mock:
            return "실제 무선을 쓰지 않는다. 시뮬레이터에서 흐름만 확인할 때."
        }
    }

    // MARK: - Storage

    private static let storageKey = "debug.nearby.transport"

    /// 기본값은 실기기 MPC · 시뮬레이터 Mock.
    static var current: NearbyTransportChoice {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let stored = NearbyTransportChoice(rawValue: raw) {
            return stored
        }
        #if targetEnvironment(simulator)
        return .mock
        #else
        return .multipeer
        #endif
    }

    static func select(_ choice: NearbyTransportChoice) {
        UserDefaults.standard.set(choice.rawValue, forKey: storageKey)
    }
}
#endif
