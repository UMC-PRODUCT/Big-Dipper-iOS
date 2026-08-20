//
//  NearbyError.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation

public enum NearbyError: Error, Sendable {
    case permissionDenied
    case unsupported(String)
    /// Phase 2 이후 구현 예정인 기능에 접근했을 때
    case notImplemented
    case invalidPayload(String)
    case transportFailure(underlying: Error)
    case sessionExpired
    /// Wi-Fi Aware: 페어링된 기기가 없어 광고/탐색을 시작할 수 없음
    case notPaired

    public var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "근거리 교환에 필요한 권한이 거부되었습니다."
        case .unsupported(let detail):
            return "이 기기에서는 지원하지 않는 기능입니다: \(detail)"
        case .notImplemented:
            return "Phase 2에서 제공될 기능입니다."
        case .invalidPayload(let detail):
            return "잘못된 페이로드 형식입니다: \(detail)"
        case .transportFailure(let underlying):
            return "전송 중 오류가 발생했습니다: \(underlying.localizedDescription)"
        case .sessionExpired:
            return "교환 세션이 만료되었습니다."
        case .notPaired:
            return "페어링된 기기가 없습니다. 상대 기기와 먼저 페어링해 주세요."
        }
    }
}
