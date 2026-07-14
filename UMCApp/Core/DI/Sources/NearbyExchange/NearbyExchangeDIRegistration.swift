//
//  NearbyExchangeDIRegistration.swift
//  CoreDI
//
//  Created by euijjang97 on 4/23/26.
//

// Phase 1 기본 구현체: BLETransport 주입
// Phase 2 교체 분기점: UWBTransport + ARPairingCoordinator 조합으로 swap 예정.
//   교체 시 이 파일의 등록 클로저만 변경하면 피처 레이어 수정 없이 전환 가능.

// import CoreNearbyExchange  // CoreNearbyExchange 모듈 참조 — CoreDI가 해당 모듈을 링크하면 활성화

// TODO: CoreDI 타겟이 CoreNearbyExchange를 의존성으로 추가한 뒤 아래 코드를 활성화.
//       현재 CoreDI는 UMCFoundation만 의존하므로, 피처 레이어나 앱 타겟에서
//       NearbyTransportProtocol 등록을 수행하는 것을 권장한다.
//
// 등록 예시 (앱 타겟 또는 BusinessCardPresentation 모듈 초기화 시점에 호출):
//
//   container.register(NearbyTransportProtocol.self) {
//       BLETransport()   // Phase 1
//       // Phase 2: CompositeTransport([BLETransport(), NFCTransport()]) 또는 UWBTransport()
//   }

public enum NearbyExchangeDIRegistration {}
