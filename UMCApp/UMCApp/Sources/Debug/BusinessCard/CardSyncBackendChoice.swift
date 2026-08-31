//
//  CardSyncBackendChoice.swift
//  UMCApp
//
//  Created by euijjang97 on 8/30/26.
//

#if DEBUG
import Foundation
import CoreNetwork
import BusinessCardData

/// 명함첩 동기화를 어디에 붙일지 고르는 검증용 토글.
///
/// 서버에 명함 API가 **하나도 없다**(2026-08-30 확인). 그래서 릴리스는 `off` 고정이고
/// (DI가 `nil` 을 주입한다), 이 토글은 DEBUG 빌드에서 재조정 규칙을 눈으로 확인하려고
/// 둔다. `NearbyTransportChoice` 선례 그대로다.
///
/// `DIContainer` 가 앱 시작 시 한 번만 읽으므로 전환 후에는 앱을 다시 켜야 한다.
enum CardSyncBackendChoice: String, CaseIterable, Identifiable {

    /// 현행 동작. 명함첩은 완전한 로컬 전용이다.
    case off
    /// 서버 대체 응답. 재조정·삭제 전파·프라이버시 규칙을 서버 없이 돌려 본다.
    case mock
    /// 실서버. 배포되기 전까지는 전부 404다.
    case live

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:  return "끔 (릴리스와 동일)"
        case .mock: return "Mock"
        case .live: return "실서버"
        }
    }

    var caveat: String {
        switch self {
        case .off:
            return "동기화를 아예 부르지 않는다. 릴리스 빌드가 이 경로다."
        case .mock:
            return "2페이지 · 서버에서 사라진 항목 · email null · 2페이지째 실패를 재현한다."
        case .live:
            return "서버에 명함 API가 배포되기 전까지 전부 404다."
        }
    }

    // MARK: - Storage

    private static let storageKey = "debug.card.syncBackend"

    /// 기본값은 `off` — 검증 화면을 열었다는 이유로 없는 서버를 두드리지 않는다.
    static var current: CardSyncBackendChoice {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(CardSyncBackendChoice.init(rawValue:)) ?? .off
    }

    static func select(_ choice: CardSyncBackendChoice) {
        UserDefaults.standard.set(choice.rawValue, forKey: storageKey)
    }

    // MARK: - Function

    /// 이 선택에 해당하는 원격 구현. `nil` 이면 저장소가 로컬 전용으로 돈다.
    func makeRemote(adapter: @autoclosure () -> MoyaNetworkAdapter)
    -> (any ReceivedCardRemoteSyncing)? {
        switch self {
        case .off:  return nil
        case .mock: return MockCardExchangeRemote()
        case .live: return CardExchangeRemote(adapter: adapter())
        }
    }
}
#endif
