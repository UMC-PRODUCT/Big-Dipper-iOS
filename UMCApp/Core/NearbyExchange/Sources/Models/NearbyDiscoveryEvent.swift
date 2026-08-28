//
//  NearbyDiscoveryEvent.swift
//  CoreNearbyExchange
//
//  Created by JEONG on 8/28/26.
//

import Foundation

/// 스캔 채널이 흘리는 이벤트.
///
/// 발견만 흘리던 시절에는 **피어가 사라졌다는 신호가 나갈 통로가 없었다.** transport 는
/// `lostPeer` 를 받고도 내부 딕셔너리만 정리했고, 그래서 상대가 앱을 종료해도 목록에 옛
/// 행이 남았다. 검증 화면은 구체 타입을 캐스팅해 폴링으로 우회했지만 제품 화면에는 그
/// 우회가 없었다.
///
/// 발견과 소실을 한 스트림에 실으면 **순서가 보장된다** — 별도 채널로 나누면 재발견이
/// 소실보다 먼저 도착해 살아 있는 행을 지우는 경합이 생긴다.
public enum NearbyDiscoveryEvent: Sendable {

    /// 주변에서 새로 발견했거나 광고 정보가 갱신된 피어.
    case found(DiscoveredPeer)

    /// 더 이상 보이지 않는 피어. 목록에서 그 행을 지워야 한다.
    case lost(peerID: String)

    /// 광고·탐색이 서지 못했다.
    ///
    /// 이 신호가 없으면 실패와 「주변에 아무도 없음」이 화면에서 똑같이 빈 목록으로
    /// 보인다. 권한을 거부한 사용자는 레이더가 도는 화면을 5분간 보다가 만료 안내를
    /// 받았다 — 원인과 무관한 문구다.
    case failed(NearbyError)
}
