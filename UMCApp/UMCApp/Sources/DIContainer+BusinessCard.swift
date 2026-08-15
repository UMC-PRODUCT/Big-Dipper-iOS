//
//  DIContainer+BusinessCard.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

import CoreDI
import CoreDomain
import CoreNearbyExchange
import CoreNetwork
import SwiftData
import BusinessCardData
import BusinessCardDomain
import BusinessCardPresentation

// BusinessCard(명함) 의존성 등록 — Repository 4종 + Transport + UseCase Provider.
// Transport: 실기기는 WiFiAwareTransport, 시뮬레이터 DEBUG는 Mock(절대규칙 #5).
//
// ⚠️ `DIContainer.resolve`는 인스턴스를 캐싱한다 — 여기 등록되는 transport는 앱 수명
// 싱글톤이다. 그래서 실기기 transport 구현은 세션 상태(교환 완료 플래그·발견 endpoint
// 캐시)를 start 진입 시점에 스스로 리셋해야 한다.
extension DIContainer {
    func registerBusinessCardDependencies() {
        register(NearbyTransportProtocol.self) {
            // Wi-Fi Aware는 실기기 전용 — 시뮬레이터 DEBUG는 Mock으로 흐름만 돌린다.
            #if DEBUG && targetEnvironment(simulator)
            MockNearbyTransport()
            #else
            WiFiAwareTransport()
            #endif
        }

        register(BusinessCardRepositoryProtocol.self) {
            BusinessCardRepository(
                memberProfileRepository: self.resolve(MemberProfileRepositoryProtocol.self)
            )
        }
        register(ReceivedCardRepositoryProtocol.self) {
            ReceivedCardRepository(modelContext: self.resolve(ModelContext.self))
        }
        register(ActivityStatRepositoryProtocol.self) {
            ActivityStatRepository(
                adapter: self.resolve(MoyaNetworkAdapter.self),
                memberProfileRepository: self.resolve(MemberProfileRepositoryProtocol.self)
            )
        }
        register(QRCodeGenerating.self) {
            CoreImageQRCodeGenerator()
        }

        // ViewModel이 resolve하는 단일 진입점 (MyPage 패턴).
        register(BusinessCardUseCaseProviding.self) {
            BusinessCardUseCaseProvider(
                businessCardRepository: self.resolve(BusinessCardRepositoryProtocol.self),
                receivedCardRepository: self.resolve(ReceivedCardRepositoryProtocol.self),
                activityStatRepository: self.resolve(ActivityStatRepositoryProtocol.self),
                qrGenerator: self.resolve(QRCodeGenerating.self),
                transport: self.resolve(NearbyTransportProtocol.self)
            )
        }
    }
}
