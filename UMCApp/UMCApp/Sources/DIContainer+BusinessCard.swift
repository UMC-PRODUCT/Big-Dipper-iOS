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
// Transport: 실기기는 MPCTransport, 시뮬레이터 DEBUG는 Mock(절대규칙 #5).
//
// ⚠️ `DIContainer.resolve`는 인스턴스를 캐싱한다 — 여기 등록되는 transport는 앱 수명
// 싱글톤이다. 그래서 실기기 transport 구현은 세션 상태(교환 완료 플래그·발견 endpoint
// 캐시)를 start 진입 시점에 스스로 리셋해야 한다.
extension DIContainer {
    func registerBusinessCardDependencies() {
        register(NearbyTransportProtocol.self) {
            // 검증 화면에서 Mock으로 전환할 수 있게 둔다(시뮬레이터는 실제 무선이 없다).
            #if DEBUG
            switch NearbyTransportChoice.current {
            case .multipeer: MPCTransport()
            case .mock:      MockNearbyTransport()
            }
            #else
            MPCTransport()
            #endif
        }

        register(BusinessCardRepositoryProtocol.self) {
            BusinessCardRepository(
                memberProfileRepository: self.resolve(MemberProfileRepositoryProtocol.self)
            )
        }
        // 상대 명함(QR 딥링크)은 캐시 없는 단발 조회라 내 명함과 저장소를 나눈다.
        register(PeerCardRepositoryProtocol.self) {
            PeerCardRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
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
        // UWB 거리 측정. transport 와 별개 계층인 이유는 NI 가 데이터를 나르지 못하기
        // 때문이다 — NearbyTransportProtocol 구현체로 두면 영원히 구현할 수 없다.
        register(PeerRangingCoordinator.self) {
            PeerRangingCoordinator()
        }

        // ViewModel이 resolve하는 단일 진입점 (MyPage 패턴).
        register(BusinessCardUseCaseProviding.self) {
            BusinessCardUseCaseProvider(
                businessCardRepository: self.resolve(BusinessCardRepositoryProtocol.self),
                peerCardRepository: self.resolve(PeerCardRepositoryProtocol.self),
                receivedCardRepository: self.resolve(ReceivedCardRepositoryProtocol.self),
                activityStatRepository: self.resolve(ActivityStatRepositoryProtocol.self),
                qrGenerator: self.resolve(QRCodeGenerating.self),
                transport: self.resolve(NearbyTransportProtocol.self),
                ranging: self.resolve(PeerRangingCoordinator.self)
            )
        }
    }
}
