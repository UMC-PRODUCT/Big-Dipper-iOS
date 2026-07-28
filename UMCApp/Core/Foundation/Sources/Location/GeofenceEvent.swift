//
//  GeofenceEvent.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/6/26.
//

import Foundation

/// 지오펜스 진입/이탈/실패 이벤트
///
/// `LocationManager`가 지오펜스 모니터링 중 관측한 상태 변화를 나타냅니다.
/// 연관값은 지오펜스 식별자(진입/이탈) 또는 실패 사유(실패)입니다.
public enum GeofenceEvent: Equatable, Sendable {
    case entered(String)
    case exited(String)
    case failed(String)
}
